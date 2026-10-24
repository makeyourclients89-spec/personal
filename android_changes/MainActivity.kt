package com.example.call_detection_flutter

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val methodChannelName = "call_detection/telephony"
    private val eventChannelName = "call_detection/events"
    private val requestCodePermissions = 501
    private val requestCodeRole = 401

    private var pendingRoleResult: MethodChannel.Result? = null
    private var pendingPermResult: MethodChannel.Result? = null

    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var speechRecognizer: SpeechRecognizer? = null

    companion object {
        var eventSink: EventChannel.EventSink? = null

        fun sendCallEvent(state: String, number: String) {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(
                    mapOf(
                        "event" to "call_state",
                        "state" to state,
                        "phoneNumber" to number,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            }
        }

        fun sendScreenedCall(number: String, allowed: Boolean) {
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(
                    mapOf(
                        "event" to "call_screened",
                        "phoneNumber" to number,
                        "allowed" to allowed,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initTts()
        initTelephonyListener()
    }

    private fun initTts() {
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isTtsReady = true
                // Prefer Hindi (India) or English (India)
                val hiResult = tts?.setLanguage(Locale("hi", "IN"))
                if (hiResult == TextToSpeech.LANG_MISSING_DATA || hiResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.setLanguage(Locale("en", "IN"))
                }
                tts?.setSpeechRate(0.95f)

                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(mapOf("event" to "tts_started", "id" to utteranceId))
                        }
                    }

                    override fun onDone(utteranceId: String?) {
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(mapOf("event" to "tts_finished", "id" to utteranceId))
                        }
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(mapOf("event" to "tts_error", "id" to utteranceId))
                        }
                    }
                })
            }
        }
    }

    private fun initTelephonyListener() {
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                    telephonyManager.registerTelephonyCallback(
                        mainExecutor,
                        object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                            override fun onCallStateChanged(state: Int) {
                                val stateStr = when (state) {
                                    TelephonyManager.CALL_STATE_RINGING -> "RINGING"
                                    TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
                                    else -> "IDLE"
                                }
                                sendCallEvent(stateStr, "Real Call")
                            }
                        }
                    )
                }
            } else {
                @Suppress("DEPRECATION")
                telephonyManager.listen(object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        val stateStr = when (state) {
                            TelephonyManager.CALL_STATE_RINGING -> "RINGING"
                            TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
                            else -> "IDLE"
                        }
                        sendCallEvent(stateStr, phoneNumber ?: "Unknown")
                    }
                }, PhoneStateListener.LISTEN_CALL_STATE)
            }
        } catch (e: Exception) {
            Log.w("CallDetection", "Telephony listener initialization error: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPermissionsStatus" -> {
                        result.success(checkAllPermissionsStatus())
                    }
                    "requestRuntimePermissions" -> {
                        requestAppRuntimePermissions(result)
                    }
                    "requestCallScreeningRole" -> {
                        requestScreeningRole(result)
                    }
                    "openAppSettings" -> {
                        openAppDetailsSettings()
                        result.success(true)
                    }
                    "openDefaultAppsSettings" -> {
                        openDefaultApps()
                        result.success(true)
                    }
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val lang = call.argument<String>("lang") ?: "hi"
                        speakText(text, lang)
                        result.success(true)
                    }
                    "stopSpeaking" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    "startListening" -> {
                        startSpeechRecognition(result)
                    }
                    "stopListening" -> {
                        speechRecognizer?.stopListening()
                        result.success(true)
                    }
                    "vibrate" -> {
                        val duration = call.argument<Int>("duration") ?: 400
                        triggerVibration(duration.toLong())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkAllPermissionsStatus(): Map<String, Any> {
        val phoneState = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val callLog = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
        val audio = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        var screeningRole = false
        var roleSupported = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                roleSupported = true
                screeningRole = roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
            }
        }

        return mapOf(
            "phoneState" to phoneState,
            "callLog" to callLog,
            "audio" to audio,
            "notification" to notification,
            "screeningRole" to screeningRole,
            "roleSupported" to roleSupported,
            "androidVersion" to Build.VERSION.SDK_INT
        )
    }

    private fun requestAppRuntimePermissions(result: MethodChannel.Result) {
        val list = mutableListOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.RECORD_AUDIO
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            list.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val ungranted = list.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (ungranted.isEmpty()) {
            result.success("ALL_GRANTED")
            return
        }

        pendingPermResult = result
        ActivityCompat.requestPermissions(this, ungranted.toTypedArray(), requestCodePermissions)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == requestCodePermissions) {
            val statusMap = checkAllPermissionsStatus()
            pendingPermResult?.success("REQUESTED")
            pendingPermResult = null

            Handler(Looper.getMainLooper()).post {
                eventSink?.success(
                    mapOf(
                        "event" to "permissions_updated",
                        "status" to statusMap
                    )
                )
            }
        }
    }

    private fun requestScreeningRole(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager == null || !roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                result.error("UNAVAILABLE", "इस डिवाइस पर Call Screening role उपलब्ध नहीं है।", null)
                return
            }

            if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                result.success("ALREADY_HELD")
                return
            }

            pendingRoleResult = result
            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
            startActivityForResult(intent, requestCodeRole)
        } else {
            result.error("UNSUPPORTED", "Android 10 (API 29) या नया संस्करण चाहिए।", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCodeRole) {
            val isHeld = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) == true
            } else false

            val outcome = if (resultCode == Activity.RESULT_OK || isHeld) "ROLE_GRANTED" else "ROLE_DENIED"
            pendingRoleResult?.success(outcome)
            pendingRoleResult = null

            Handler(Looper.getMainLooper()).post {
                eventSink?.success(
                    mapOf(
                        "event" to "role_updated",
                        "held" to isHeld
                    )
                )
            }
        }
    }

    private fun openAppDetailsSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun openDefaultApps() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val intent = Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } else {
                openAppDetailsSettings()
            }
        } catch (e: Exception) {
            openAppDetailsSettings()
        }
    }

    private fun speakText(text: String, lang: String) {
        if (!isTtsReady || tts == null) return
        val locale = if (lang == "en") Locale("en", "IN") else Locale("hi", "IN")
        tts?.language = locale
        val utteranceId = "utt_${System.currentTimeMillis()}"
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun startSpeechRecognition(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("NO_MIC_PERMISSION", "Microphone permission required", null)
            return
        }

        Handler(Looper.getMainLooper()).post {
            try {
                if (speechRecognizer == null) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            eventSink?.success(mapOf("event" to "speech_ready"))
                        }
                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rmsdB: Float) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {}
                        override fun onError(error: Int) {
                            eventSink?.success(mapOf("event" to "speech_error", "code" to error))
                        }
                        override fun onResults(results: Bundle?) {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = matches?.firstOrNull() ?: ""
                            eventSink?.success(mapOf("event" to "speech_result", "text" to text))
                        }
                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = matches?.firstOrNull() ?: ""
                            eventSink?.success(mapOf("event" to "speech_partial", "text" to text))
                        }
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "hi-IN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                }
                speechRecognizer?.startListening(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("SPEECH_ERROR", e.message, null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun triggerVibration(durationMs: Long) {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                vibrator?.vibrate(durationMs)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}
