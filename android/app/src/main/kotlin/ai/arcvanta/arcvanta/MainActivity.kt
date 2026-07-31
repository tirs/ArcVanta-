package ai.arcvanta.arcvanta

import ai.arcvanta.arcvanta.vision.CaptureBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var capture: CaptureBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capture = CaptureBridge(
            context = applicationContext,
            lifecycleOwner = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            textures = flutterEngine.renderer,
        )
    }

    /**
     * The camera prompt's answer arrives here, not on the bridge, so it has to
     * be handed across. Flutter's own plugins never see this request code.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        val handled = capture?.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        ) ?: false

        if (!handled) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onDestroy() {
        capture?.dispose()
        capture = null
        super.onDestroy()
    }
}
