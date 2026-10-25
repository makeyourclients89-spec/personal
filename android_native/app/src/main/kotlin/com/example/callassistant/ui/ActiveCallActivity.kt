package com.example.callassistant.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.callassistant.R
import com.example.callassistant.databinding.ActivityActiveCallBinding
import com.example.callassistant.model.CallStatus
import com.example.callassistant.model.TranscriptItem
import com.example.callassistant.voip.TwilioVoiceManager

class ActiveCallActivity : AppCompatActivity() {

    private lateinit var binding: ActivityActiveCallBinding
    private val transcriptAdapter = LiveTranscriptAdapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityActiveCallBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val callerName = intent.getStringExtra("callerName") ?: "Caller"
        binding.tvActiveCallerName.text = callerName

        binding.rvLiveTranscript.layoutManager = LinearLayoutManager(this).apply {
            stackFromEnd = true
        }
        binding.rvLiveTranscript.adapter = transcriptAdapter

        // Observe Call State
        TwilioVoiceManager.callState.observe(this) { state ->
            when (state) {
                CallStatus.AI_ANSWERED -> {
                    binding.tvActiveCallStatus.text = "AI Assistant Screening Call..."
                    binding.tvActiveCallStatus.setTextColor(ContextCompat.getColor(this, R.color.accent))
                    binding.btnTakeoverCall.visibility = View.VISIBLE
                }
                CallStatus.USER_TAKEOVER -> {
                    binding.tvActiveCallStatus.text = "Connected: You took over call from AI"
                    binding.tvActiveCallStatus.setTextColor(ContextCompat.getColor(this, R.color.green_call))
                    binding.btnTakeoverCall.visibility = View.GONE
                }
                CallStatus.HUMAN_ANSWERED -> {
                    binding.tvActiveCallStatus.text = "Direct Call (Picked by You within 10s)"
                    binding.tvActiveCallStatus.setTextColor(ContextCompat.getColor(this, R.color.green_call))
                    binding.btnTakeoverCall.visibility = View.GONE
                }
                CallStatus.COMPLETED, CallStatus.DECLINED -> {
                    finish()
                }
                else -> {}
            }
        }

        // Observe Live Summary
        TwilioVoiceManager.liveSummary.observe(this) { summary ->
            if (summary.isNotEmpty()) {
                binding.tvActiveLiveSummary.text = summary
            }
        }

        // Observe Live Transcripts
        TwilioVoiceManager.currentTranscript.observe(this) { list ->
            transcriptAdapter.setItems(list)
            if (list.isNotEmpty()) {
                binding.rvLiveTranscript.smoothScrollToPosition(list.size - 1)
            }
        }

        // Action: TAKEOVER BUTTON
        binding.btnTakeoverCall.setOnClickListener {
            TwilioVoiceManager.takeOverCall()
        }

        // Action: End Call
        binding.btnEndCall.setOnClickListener {
            TwilioVoiceManager.endCall()
            finish()
        }
    }
}

class LiveTranscriptAdapter : RecyclerView.Adapter<LiveTranscriptAdapter.ViewHolder>() {
    private val items = mutableListOf<TranscriptItem>()

    fun setItems(newItems: List<TranscriptItem>) {
        items.clear()
        items.addAll(newItems)
        notifyDataSetChanged()
    }

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
            else ContextCompat.getColor(holder.view.context, android.R.color.white)
        )
        holder.tvText.text = item.text
    }

    override fun getItemCount() = items.size
}
