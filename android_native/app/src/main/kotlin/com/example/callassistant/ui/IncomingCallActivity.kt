package com.example.callassistant.ui

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.callassistant.databinding.ActivityIncomingCallBinding
import com.example.callassistant.model.CallStatus
import com.example.callassistant.voip.TwilioVoiceManager

class IncomingCallActivity : AppCompatActivity() {

    private lateinit var binding: ActivityIncomingCallBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityIncomingCallBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val callerName = intent.getStringExtra("callerName") ?: "Unknown Caller"
        val callerNumber = intent.getStringExtra("callerNumber") ?: "+91 98765 43210"

        binding.tvIncomingName.text = callerName
        binding.tvIncomingNumber.text = callerNumber

        // Observe 10-Second Countdown
        TwilioVoiceManager.countdownSeconds.observe(this) { sec ->
            binding.tvCountdownNumber.text = "${sec}s"
            binding.pbCountdown.progress = sec
        }

        // Observe Call State Transitions
        TwilioVoiceManager.callState.observe(this) { state ->
            when (state) {
                CallStatus.HUMAN_ANSWERED, CallStatus.AI_ANSWERED -> {
                    // Navigate to active call screen
                    val activeIntent = Intent(this, ActiveCallActivity::class.java).apply {
                        putExtra("callerName", callerName)
                        putExtra("callerNumber", callerNumber)
                    }
                    startActivity(activeIntent)
                    finish()
                }
                CallStatus.DECLINED, CallStatus.COMPLETED -> {
                    finish()
                }
                else -> {}
            }
        }

        // Action: Pick Call within 10s (Direct User Connect)
        binding.fabPick.setOnClickListener {
            TwilioVoiceManager.answerByUser()
        }

        // Action: AI Screen Now (Immediate AI Answer)
        binding.btnAiScreenNow.setOnClickListener {
            TwilioVoiceManager.startAiScreening(isAutoTriggered = false)
        }

        // Action: Decline Call
        binding.fabDecline.setOnClickListener {
            TwilioVoiceManager.declineCall()
            finish()
        }
    }
}
