package com.azurekiln.qfli.forge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeCompiler: NativeCompilerBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeCompiler = NativeCompilerBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nativeCompiler?.close()
        nativeCompiler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
