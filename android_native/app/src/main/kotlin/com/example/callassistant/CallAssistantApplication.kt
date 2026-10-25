package com.example.callassistant

import android.app.Application
import com.example.callassistant.data.CallRepository
import com.example.callassistant.voip.TwilioVoiceManager
import com.example.callassistant.voip.WebCallBridgeManager

class CallAssistantApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        CallRepository.init(this)
        TwilioVoiceManager.init(this)
        WebCallBridgeManager.init(this)
    }
}
