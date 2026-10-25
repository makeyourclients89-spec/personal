package com.example.callassistant

import android.app.Application
import com.example.callassistant.data.CallRepository
import com.example.callassistant.voip.TwilioVoiceManager

class CallAssistantApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        CallRepository.init(this)
        TwilioVoiceManager.init(this)
    }
}
