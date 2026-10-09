package com.example.reindeer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingText: String = ""

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQ_SAVE && requestCode != REQ_PICK) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult
        pendingResult = null
        val uri = data?.data
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || uri == null) {
            if (requestCode == REQ_SAVE) result.success(false) else result.success(null)
            return
        }
        try {
            if (requestCode == REQ_SAVE) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(pendingText.toByteArray(Charsets.UTF_8)) }
                pendingText = ""
                result.success(true)
            } else {
                val text = contentResolver.openInputStream(uri)?.use { String(it.readBytes(), Charsets.UTF_8) }
                result.success(text)
            }
        } catch (e: Exception) {
            if (requestCode == REQ_SAVE) result.success(false) else result.success(null)
        }
    }

    companion object {
        private const val REQ_SAVE = 4101
        private const val REQ_PICK = 4102
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reindeer/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "Share"
                        try {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(send, title))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "dial" -> {
                        val number = (call.argument<String>("number") ?: "").filter { it.isDigit() || it == '+' }
                        try {
                            startActivity(Intent(Intent.ACTION_DIAL, android.net.Uri.parse("tel:$number")))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "sms" -> {
                        val number = (call.argument<String>("number") ?: "").filter { it.isDigit() || it == '+' }
                        val body = call.argument<String>("text") ?: ""
                        try {
                            val intent = Intent(Intent.ACTION_SENDTO, android.net.Uri.parse("smsto:$number")).apply {
                                putExtra("sms_body", body)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "saveTextFile" -> {
                        try {
                            pendingResult = result
                            pendingText = call.argument<String>("text") ?: ""
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "reindeer-backup.json")
                            }
                            startActivityForResult(intent, REQ_SAVE)
                        } catch (e: Exception) {
                            pendingResult = null
                            result.success(false)
                        }
                    }
                    "pickTextFile" -> {
                        try {
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, REQ_PICK)
                        } catch (e: Exception) {
                            pendingResult = null
                            result.success(null)
                        }
                    }
                    "takeWidgetActions" -> {
                        try {
                            result.success(ReindeerWidgetProvider.takePending(applicationContext))
                        } catch (e: Exception) {
                            result.success("")
                        }
                    }
                    "updateWidget" -> {
                        try {
                            ReindeerWidgetProvider.save(applicationContext, call.argument<String>("text") ?: "")
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        try {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
