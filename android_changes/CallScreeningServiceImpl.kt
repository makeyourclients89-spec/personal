package com.example.call_detection_flutter

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class CallScreeningServiceImpl : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        val handle = details.handle
        val number = handle?.schemeSpecificPart ?: "Unknown Caller"
        Log.i("CallDetection", "CallScreeningService screened call from: $number")
        
        // Broadcast screened call to Flutter UI
        MainActivity.sendScreenedCall(number, true)

        // Allow call through by default; does not reject or silence
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSilenceCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
        respondToCall(details, response)
    }
}
