package com.rumata.map

import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.rumata.gol_sepet_takip/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPublicDocumentsDir" -> result.success(
                    Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOCUMENTS
                    ).absolutePath
                )
                else -> result.notImplemented()
            }
        }
    }
}
