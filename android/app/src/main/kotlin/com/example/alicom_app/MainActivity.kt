package com.alicom.razinsoft

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "alicom/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Copies a file the app already wrote into the phone's own
                    // Downloads folder, so it shows up in Files like any other
                    // download. MediaStore needs no storage permission, but it
                    // only exists from Android 10 — older versions get null and
                    // fall back to the share sheet.
                    "saveToDownloads" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        if (sourcePath == null || fileName == null) {
                            result.error("bad_args", "sourcePath and fileName are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val source = File(sourcePath)
                            if (!source.exists()) {
                                result.error("missing_file", "No file at $sourcePath", null)
                                return@setMethodCallHandler
                            }
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            val resolver = contentResolver
                            val uri = resolver.insert(
                                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                values,
                            )
                            if (uri == null) {
                                result.error("insert_failed", "Could not create the download", null)
                                return@setMethodCallHandler
                            }
                            resolver.openOutputStream(uri).use { output ->
                                if (output == null) {
                                    result.error("open_failed", "Could not open the download", null)
                                    return@setMethodCallHandler
                                }
                                source.inputStream().use { it.copyTo(output) }
                            }
                            values.clear()
                            values.put(MediaStore.Downloads.IS_PENDING, 0)
                            resolver.update(uri, values, null, null)
                            result.success(fileName)
                        } catch (error: Exception) {
                            result.error("save_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
