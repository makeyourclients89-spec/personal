package com.example.call_detection_flutter

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "call_detection/role"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "requestCallScreeningRole") {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(RoleManager::class.java)
                        if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                            if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                                result.success("Call Screening role पहले से enabled है।")
                            } else {
                                startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), 401)
                                result.success("Android role request खोला गया।")
                            }
                        } else result.error("UNAVAILABLE", "इस डिवाइस पर Call Screening role उपलब्ध नहीं है।", null)
                    } else {
                        result.error("UNSUPPORTED", "इस prototype के लिए Android 10 या नया संस्करण बेहतर है।", null)
                    }
                } catch (e: Exception) {
                    result.error("ROLE_ERROR", e.message, null)
                }
            } else result.notImplemented()
        }
    }
}
