package com.example.callassistant.voip

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.example.callassistant.model.CallerPersona
import com.example.callassistant.ui.IncomingCallActivity
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object WebCallBridgeManager {

    private const val TAG = "WebCallBridge"
    private var context: Context? = null
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    // Host configurations: 192.168.1.41 for real device on same WiFi, 10.0.2.2 for emulator
    var serverHost = "192.168.1.41"
    var serverPort = 3000

    private val _isConnected = MutableLiveData(false)
    val isConnected: LiveData<Boolean> = _isConnected

    private val _currentCallSid = MutableLiveData<String?>(null)
    val currentCallSid: LiveData<String?> = _currentCallSid

    private val mainHandler = Handler(Looper.getMainLooper())

    fun init(appContext: Context) {
        context = appContext
        connect()
    }

    fun getWebCallingUrl(): String {
        return "http://$serverHost:$serverPort/call"
    }

    fun connect() {
        if (webSocket != null) return

        val wsUrl = "ws://$serverHost:$serverPort/app-bridge"
        Log.d(TAG, "Connecting to bridge: $wsUrl")

        val request = Request.Builder().url(wsUrl).build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(ws: WebSocket, response: Response) {
                Log.d(TAG, "Bridge Connected!")
                mainHandler.post { _isConnected.value = true }
                // Register as Android Client
                val reg = JSONObject().apply {
                    put("event", "REGISTER_ANDROID_APP")
                }
                ws.send(reg.toString())
            }

            override fun onMessage(ws: WebSocket, text: String) {
                Log.d(TAG, "Bridge message: $text")
                handleMessage(text)
            }

            override fun onClosed(ws: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Bridge closed")
                mainHandler.post { _isConnected.value = false }
                webSocket = null
                // Reconnect after 3s
                mainHandler.postDelayed({ connect() }, 3000)
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Bridge failure: ${t.message}")
                mainHandler.post { _isConnected.value = false }
                webSocket = null
                // Try fallback to 10.0.2.2 if on emulator or retry
                mainHandler.postDelayed({ connect() }, 5000)
            }
        })
    }

    private fun handleMessage(jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)
            when (json.optString("event")) {
                "INCOMING_CALL" -> {
                    val callSid = json.optString("callSid")
                    val callerName = json.optString("callerName", "Web Caller (Phone 2)")
                    val callerNumber = json.optString("callerNumber", "Free Web Link")

                    mainHandler.post {
                        _currentCallSid.value = callSid

                        val persona = CallerPersona(
                            name = callerName,
                            number = callerNumber,
                            category = "Direct Call",
                            scriptTurns = emptyList()
                        )

                        // Trigger native ringing & 10s countdown
                        TwilioVoiceManager.startIncomingCall(persona)

                        // Launch incoming call activity
                        context?.let { ctx ->
                            val intent = Intent(ctx, IncomingCallActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                putExtra("callerName", callerName)
                                putExtra("callerNumber", callerNumber)
                                putExtra("callSid", callSid)
                            }
                            ctx.startActivity(intent)
                        }
                    }
                }

                "AI_ANSWERED" -> {
                    val greeting = json.optString("greeting", "Namaste! Main AI Assistant hoon.")
                    mainHandler.post {
                        TwilioVoiceManager.startAiScreening(isAutoTriggered = true)
                        TwilioVoiceManager.addExternalTranscript("ai", greeting)
                    }
                }

                "TRANSCRIPT_UPDATE" -> {
                    val callerText = json.optString("callerText")
                    val aiText = json.optString("aiText")
                    mainHandler.post {
                        if (callerText.isNotEmpty()) {
                            TwilioVoiceManager.addExternalTranscript("caller", callerText)
                        }
                        if (aiText.isNotEmpty()) {
                            TwilioVoiceManager.addExternalTranscript("ai", aiText)
                        }
                    }
                }

                "CALL_ENDED" -> {
                    mainHandler.post {
                        _currentCallSid.value = null
                        TwilioVoiceManager.declineCall()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling bridge message", e)
        }
    }

    fun sendUserAnswer(callSid: String) {
        val json = JSONObject().apply {
            put("event", "USER_ANSWER")
            put("callSid", callSid)
        }
        webSocket?.send(json.toString())
    }

    fun sendUserTakeover(callSid: String) {
        val json = JSONObject().apply {
            put("event", "USER_TAKEOVER")
            put("callSid", callSid)
        }
        webSocket?.send(json.toString())
    }

    fun sendEndCall(callSid: String) {
        val json = JSONObject().apply {
            put("event", "END_CALL")
            put("callSid", callSid)
        }
        webSocket?.send(json.toString())
    }
}
