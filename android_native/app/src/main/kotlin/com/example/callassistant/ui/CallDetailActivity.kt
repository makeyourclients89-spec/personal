package com.example.callassistant.ui

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.callassistant.R
import com.example.callassistant.data.CallRepository
import com.example.callassistant.databinding.ActivityCallDetailBinding
import com.example.callassistant.model.TranscriptItem
import java.util.Locale

class CallDetailActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCallDetailBinding
    private var tts: TextToSpeech? = null
    private var isPlaying = false
    private var currentPlayingIndex = 0
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityCallDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setSupportActionBar(binding.detailToolbar)
        binding.detailToolbar.setNavigationOnClickListener { finish() }

        initTts()

        val callId = intent.getStringExtra("callId") ?: ""
        val record = CallRepository.getCallById(callId)

        if (record == null) {
            finish()
            return
        }

        binding.tvDetailCallerName.text = record.callerName
        binding.tvDetailCallerNumber.text = "${record.callerNumber} • ${record.category}"
        binding.tvDetailStatusDuration.text = "Status: ${record.status.name} • Duration: ${record.durationSeconds}s"
        binding.tvRecordingDuration.text = "Recorded Audio • ${record.recordingDurationSeconds}s"
        binding.tvDetailSummary.text = record.aiSummary
        binding.tvDetailIntent.text = "Key Intent: ${record.keyIntent}"

        binding.rvDetailTranscript.layoutManager = LinearLayoutManager(this)
        binding.rvDetailTranscript.adapter = DetailTranscriptAdapter(record.transcript)

        // Audio Recording Player Play / Pause Action
        binding.fabPlayAudio.setOnClickListener {
            if (isPlaying) {
                stopPlayback()
            } else {
                startPlayback(record.transcript)
            }
        }
    }

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.setLanguage(Locale("hi", "IN"))
            }
        }
    }

    private fun startPlayback(transcript: List<TranscriptItem>) {
        if (transcript.isEmpty()) return
        isPlaying = true
        currentPlayingIndex = 0
        binding.fabPlayAudio.setImageResource(android.R.drawable.ic_media_pause)
        binding.tvPlaybackStatus.text = "Audio Playing... (Recorded Voice)"
        playNextTurn(transcript)
    }

    private fun playNextTurn(transcript: List<TranscriptItem>) {
        if (!isPlaying || currentPlayingIndex >= transcript.size) {
            stopPlayback()
            return
        }

        val item = transcript[currentPlayingIndex]
        val progress = ((currentPlayingIndex + 1).toFloat() / transcript.size * 100).toInt()
        binding.pbAudioPlayback.progress = progress

        tts?.speak(item.text, TextToSpeech.QUEUE_FLUSH, null, "detail_turn_$currentPlayingIndex")

        val waitMs = (item.text.length * 60L).coerceIn(2000L, 4500L)
        mainHandler.postDelayed({
            if (isPlaying) {
                currentPlayingIndex++
                playNextTurn(transcript)
            }
        }, waitMs)
    }

    private fun stopPlayback() {
        isPlaying = false
        tts?.stop()
        binding.fabPlayAudio.setImageResource(android.R.drawable.ic_media_play)
        binding.tvPlaybackStatus.text = "Tap play to listen to call recording"
        binding.pbAudioPlayback.progress = 0
    }

    override fun onDestroy() {
        stopPlayback()
        tts?.shutdown()
        super.onDestroy()
    }
}

class DetailTranscriptAdapter(
    private val items: List<TranscriptItem>
) : RecyclerView.Adapter<DetailTranscriptAdapter.ViewHolder>() {

    class ViewHolder(val view: View) : RecyclerView.ViewHolder(view) {
        val tvSpeaker: TextView = view.findViewById(R.id.tvSpeakerTag)
        val tvText: TextView = view.findViewById(R.id.tvTranscriptText)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val v = LayoutInflater.from(parent.context).inflate(R.layout.item_transcript_bubble, parent, false)
        return ViewHolder(v)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        holder.tvSpeaker.text = when (item.speaker) {
            "ai" -> "AI Assistant [${item.timestamp}]"
            "user" -> "You (Takeover) [${item.timestamp}]"
            else -> "Caller [${item.timestamp}]"
        }
        holder.tvSpeaker.setTextColor(
            if (item.speaker == "ai") ContextCompat.getColor(holder.view.context, R.color.amber_takeover)
            else if (item.speaker == "user") ContextCompat.getColor(holder.view.context, R.color.green_call)
            else ContextCompat.getColor(holder.view.context, R.color.accent)
        )
        holder.tvText.text = item.text
    }

    override fun getItemCount() = items.size
}
