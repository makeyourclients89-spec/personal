package com.example.call_detection_flutter

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class CallScreeningServiceImpl : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        val handle = details.handle
        Log.i("CallDetection", "Screened call received; handle available=${handle != null}")
        // This starter service allows the call by default. It does not answer,
        // reject, record, route, or transmit call audio.
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSilenceCall(false)
            .build()
        respondToCall(details, response)
    }
}
