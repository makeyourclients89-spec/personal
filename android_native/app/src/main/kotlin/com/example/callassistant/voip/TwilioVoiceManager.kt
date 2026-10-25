package com.example.callassistant.voip

import android.content.Context
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.example.callassistant.data.CallRepository
import com.example.callassistant.model.CallRecord
import com.example.callassistant.model.CallStatus
import com.example.callassistant.model.CallerPersona
import com.example.callassistant.model.TranscriptItem
import java.util.Locale

object TwilioVoiceManager {
    private var context: Context? = null
    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    private val _callState = MutableLiveData(CallStatus.COMPLETED)
    val callState: LiveData<CallStatus> = _callState

    private val _countdownSeconds = MutableLiveData(10)
    val countdownSeconds: LiveData<Int> = _countdownSeconds

    private val _currentTranscript = MutableLiveData<List<TranscriptItem>>(emptyList())
    val currentTranscript: LiveData<List<TranscriptItem>> = _currentTranscript

    private val _liveSummary = MutableLiveData("")
    val liveSummary: LiveData<String> = _liveSummary

    private var countdownTimer: CountDownTimer? = null
    private var activePersona: CallerPersona? = null
    private var currentTurnIndex = 0
    private var callStartTime = 0L
    private val transcriptBuffer = mutableListOf<TranscriptItem>()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun init(appContext: Context) {
        context = appContext
        tts = TextToSpeech(appContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isTtsReady = true
                val result = tts?.setLanguage(Locale("hi", "IN"))
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.setLanguage(Locale("en", "IN"))
                }
            }
        }
    }

    fun startIncomingCall(persona: CallerPersona) {
        activePersona = persona
        currentTurnIndex = 0
        transcriptBuffer.clear()
        _currentTranscript.postValue(emptyList())
        _liveSummary.postValue("10s me pick karein ya AI automatically takeover karega...")
        _callState.postValue(CallStatus.RINGING)

        // 10-Second Countdown Timer
        countdownTimer?.cancel()
        _countdownSeconds.postValue(10)
        countdownTimer = object : CountDownTimer(10000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val sec = (millisUntilFinished / 1000).toInt() + 1
                _countdownSeconds.postValue(sec)
            }

            override fun onFinish() {
                _countdownSeconds.postValue(0)
                // 10 seconds expired: AI automatically takes over!
                startAiScreening(isAutoTriggered = true)
            }
        }.start()
    }

    fun answerByUser() {
        countdownTimer?.cancel()
        callStartTime = System.currentTimeMillis()
        _callState.postValue(CallStatus.HUMAN_ANSWERED)
        _liveSummary.postValue("Direct Call: Aap caller se directly connect hain.")
        
        transcriptBuffer.add(TranscriptItem("user", "Aapne call 10s ke andar directly pick kar li.", "00:01"))
        _currentTranscript.postValue(transcriptBuffer.toList())

        // Start persona conversation directly with user
        executeNextScriptTurn()
    }

    fun startAiScreening(isAutoTriggered: Boolean = false) {
        countdownTimer?.cancel()
        callStartTime = System.currentTimeMillis()
        _callState.postValue(CallStatus.AI_ANSWERED)

        val summaryText = if (isAutoTriggered) {
            "10s timeout complete: AI Assistant ne automatically call takeover kar li."
        } else {
            "User ne AI Screen Now tap karke call AI ko handover ki."
        }
        _liveSummary.postValue(summaryText)

        executeNextScriptTurn()
    }

    fun takeOverCall() {
        if (_callState.value != CallStatus.AI_ANSWERED) return

        tts?.stop()
        _callState.postValue(CallStatus.USER_TAKEOVER)
        _liveSummary.postValue("Takeover: AI stepped aside! You are now speaking directly with the caller.")

        transcriptBuffer.add(TranscriptItem("user", "[Takeover] Aapne call ka charge le liya hai.", "00:15"))
        _currentTranscript.postValue(transcriptBuffer.toList())
    }

    fun addExternalTranscript(speaker: String, text: String) {
        val elapsedSec = if (callStartTime > 0) {
            ((System.currentTimeMillis() - callStartTime) / 1000).toInt()
        } else 0
        val timestamp = String.format(Locale.getDefault(), "%02d:%02d", elapsedSec / 60, elapsedSec % 60)
        transcriptBuffer.add(TranscriptItem(speaker, text, timestamp))
        _currentTranscript.postValue(transcriptBuffer.toList())
    }

    fun declineCall() {
        countdownTimer?.cancel()
        tts?.stop()
        val persona = activePersona ?: return

        val record = CallRecord(
            id = "call_${System.currentTimeMillis()}",
            callerName = persona.name,
            callerNumber = persona.number,
            timestamp = System.currentTimeMillis(),
            durationSeconds = 0,
            category = persona.category,
            status = CallStatus.DECLINED,
            keyIntent = "Call declined before screening.",
            aiSummary = "User ne 10-second window ke andar call reject kar di.",
            urgency = "None",
            hasRecording = false,
            transcript = listOf(TranscriptItem("user", "Call was declined.", "00:00"))
        )
        CallRepository.addCallRecord(record)
        _callState.postValue(CallStatus.DECLINED)
    }

    fun endCall() {
        countdownTimer?.cancel()
        tts?.stop()
        val persona = activePersona ?: return
        val currentStatus = _callState.value ?: CallStatus.COMPLETED

        val duration = if (callStartTime > 0) {
            ((System.currentTimeMillis() - callStartTime) / 1000).toInt()
        } else 15

        val finalStatus = when (currentStatus) {
            CallStatus.USER_TAKEOVER -> CallStatus.USER_TAKEOVER
            CallStatus.HUMAN_ANSWERED -> CallStatus.HUMAN_ANSWERED
            else -> CallStatus.AI_ANSWERED
        }

        val record = CallRecord(
            id = "call_${System.currentTimeMillis()}",
            callerName = persona.name,
            callerNumber = persona.number,
            timestamp = callStartTime.takeIf { it > 0 } ?: System.currentTimeMillis(),
            durationSeconds = duration,
            category = persona.category,
            status = finalStatus,
            keyIntent = persona.expectedIntent,
            aiSummary = _liveSummary.value ?: "Call successfully completed.",
            urgency = persona.urgency,
            transcript = transcriptBuffer.toList(),
            hasRecording = true,
            recordingDurationSeconds = duration,
            recordingUrl = "https://api.twilio.com/recordings/call_${System.currentTimeMillis()}.wav"
        )

        CallRepository.addCallRecord(record)
        _callState.postValue(CallStatus.COMPLETED)
    }

    private fun executeNextScriptTurn() {
        val persona = activePersona ?: return
        if (currentTurnIndex >= persona.script.size) {
            endCall()
            return
        }

        val step = persona.script[currentTurnIndex]
        mainHandler.postDelayed({
            if (_callState.value == CallStatus.COMPLETED || _callState.value == CallStatus.DECLINED) return@postDelayed

            transcriptBuffer.add(TranscriptItem(step.speaker, step.text, "00:${currentTurnIndex * 6 + 2}"))
            _currentTranscript.postValue(transcriptBuffer.toList())

            // Update live summary
            updateSummaryFromTurn(step)

            // Speak audio aloud
            if (isTtsReady) {
                if (step.speaker == "ai" && _callState.value == CallStatus.AI_ANSWERED) {
                    tts?.speak(step.text, TextToSpeech.QUEUE_FLUSH, null, "turn_$currentTurnIndex")
                } else if (step.speaker == "caller") {
                    tts?.speak(step.text, TextToSpeech.QUEUE_FLUSH, null, "turn_$currentTurnIndex")
                }
            }

            currentTurnIndex++
            executeNextScriptTurn()
        }, step.delayMs)
    }

    private fun updateSummaryFromTurn(step: com.example.callassistant.model.ScriptStep) {
        val text = step.text.lowercase()
        if (text.contains("swiggy") || text.contains("delivery") || text.contains("flat") || text.contains("guard")) {
            _liveSummary.postValue("Live Summary: Delivery partner gate par hai, guard ko parcel handover instructions diye gaye.")
        } else if (text.contains("bank") || text.contains("credit card") || text.contains("offer")) {
            _liveSummary.postValue("Live Summary: Promotional card offer identify kiya gaya aur DND request bheji gayi.")
        } else if (text.contains("google") || text.contains("interview") || text.contains("recruiting")) {
            _liveSummary.postValue("Live Summary: Job opportunity interview call. Assessment schedule email mangwayi gayi.")
        } else if (text.contains("inaam") || text.contains("lottery") || text.contains("fraud")) {
            _liveSummary.postValue("Live Summary: Alert! Fraud lottery scam detect karke terminate kiya gaya.")
        }
    }
}
