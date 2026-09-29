package com.mwstudio.popverse

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppIconSwitcher.reconcile(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppIconSwitcher.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val alias = call.argument<String>("alias")
                        if (alias == null) {
                            result.error("ARG", "alias is required", null)
                        } else {
                            result.success(AppIconSwitcher.apply(this, alias))
                        }
                    }
                    "currentIcon" -> result.success(AppIconSwitcher.current(this))
                    else -> result.notImplemented()
                }
            }
    }
}
