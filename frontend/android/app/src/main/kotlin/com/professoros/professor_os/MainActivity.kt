package com.professoros.professor_os

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.professoros/mobile_proctor"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKioskMode" -> {
                    try {
                        startLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "stopKioskMode" -> {
                    try {
                        stopLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "setSecureFlag" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    try {
                        if (enabled) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SECURE_FLAG_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
