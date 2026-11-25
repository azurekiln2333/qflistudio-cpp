package com.azurekiln.qfli.forge

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ProgressBar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nativeCompiler: NativeCompilerBridge? = null
    private var startupChannel: MethodChannel? = null
    private var startupOverlay: View? = null
    private var startupProgress: ProgressBar? = null
    private var progress = 0
    private var flutterDisplayed = false

    // Surface mode delays Android's entire first draw, including the loading bar.
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (flutterDisplayed) return
        val content = findViewById<ViewGroup>(android.R.id.content)
        val overlay = layoutInflater.inflate(R.layout.startup_splash, content, false)
        val bar = overlay.findViewById<ProgressBar>(R.id.startup_progress)
        startupOverlay = overlay
        startupProgress = bar
        bar.progress = progress
        overlay.addOnLayoutChangeListener { _, left, _, right, _, _, _, _, _ ->
            val density = resources.displayMetrics.density
            val available = right - left - overlay.paddingLeft - overlay.paddingRight - (64 * density).toInt()
            val width = minOf((420 * density).toInt(), available.coerceAtLeast(0))
            if (bar.layoutParams.width != width) {
                bar.layoutParams = (bar.layoutParams as FrameLayout.LayoutParams).apply { this.width = width }
            }
        }
        ViewCompat.setOnApplyWindowInsetsListener(overlay) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
        content.addView(overlay)
        ViewCompat.requestApplyInsets(overlay)
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterDisplayed = true
        startupProgress?.progress = 1000
        startupOverlay?.let { overlay ->
            overlay.animate().alpha(0f).setDuration(180).withEndAction {
                (overlay.parent as? ViewGroup)?.removeView(overlay)
                startupOverlay = null
                startupProgress = null
            }.start()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeCompiler = NativeCompilerBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        startupChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qfli_forge/startup").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "startupProgress") {
                    result.notImplemented()
                } else {
                    val value = (call.argument<Any>("progress") as? Number)?.toDouble()
                    if (value == null || !value.isFinite()) {
                        result.error("invalid_progress", "Startup progress must be finite", null)
                    } else {
                        progress = (value.coerceIn(0.0, 1.0) * 1000).toInt()
                        startupProgress?.setProgress(progress, true)
                        result.success(null)
                    }
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        startupChannel?.setMethodCallHandler(null)
        startupChannel = null
        nativeCompiler?.close()
        nativeCompiler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        startupOverlay?.animate()?.cancel()
        startupOverlay = null
        startupProgress = null
        super.onDestroy()
    }
}
