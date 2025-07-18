package com.example.community_frontend

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yourapp/email"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openGmail") {
                val email = call.argument<String>("email")
                if (email.isNullOrEmpty()) {
                    result.error("INVALID_EMAIL", "Email address is missing", null)
                    return@setMethodCallHandler
                }

                try {
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("mailto:$email")
                    }

                    val packageManager = packageManager
                    val resolveInfos = packageManager.queryIntentActivities(intent, 0)

                    // Try to find Gmail package
                    var gmailFound = false
                    for (info in resolveInfos) {
                        if (info.activityInfo.packageName.contains("com.google.android.gm")) {
                            intent.setPackage(info.activityInfo.packageName)
                            gmailFound = true
                            break
                        }
                    }

                    if (resolveInfos.isNotEmpty()) {
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("UNAVAILABLE", "No email app found", null)
                    }

                } catch (e: Exception) {
                    result.error("ERROR", "Failed to open Gmail: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
