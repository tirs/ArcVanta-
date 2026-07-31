package ai.arcvanta.arcvanta.vision

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import android.view.Surface
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * The Android half of the capture seam.
 *
 * Runs the camera, pushes frames through [VisionEngine], and reports what it
 * saw. It reports observations only: no phase, no shot, no measurement. Those
 * are decided in Dart, where one implementation serves both platforms and can
 * be tested without a device.
 */
class CaptureBridge(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    messenger: BinaryMessenger,
    private val textures: TextureRegistry,
) : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ArcVantaCapture"
        private const val METHOD_CHANNEL = "ai.arcvanta/capture"
        private const val EVENT_CHANNEL = "ai.arcvanta/capture/events"

        /** Arbitrary, but must not collide with another requester in the app. */
        const val CAMERA_PERMISSION_REQUEST = 4711

        /** Analysis resolution. Higher costs frame rate for no extra reach. */
        private const val ANALYSIS_WIDTH = 1280
        private const val ANALYSIS_HEIGHT = 720

        /**
         * Below this share of the requested rate the phone is not keeping up,
         * and the guard starts skipping pose on alternate frames. Detection
         * keeps running on every frame: losing the ball loses the shot, while
         * losing a pose only softens one frame of the mechanics track.
         */
        private const val THERMAL_FLOOR = 0.7
    }

    private val methods = MethodChannel(messenger, METHOD_CHANNEL)
    private val events = EventChannel(messenger, EVENT_CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    private var sink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var engine: VisionEngine? = null
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var preview: Preview? = null
    private var texture: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null

    /** Published to Dart so the preview widget can mount the camera stream. */
    private var previewTextureId: Long? = null

    private val running = AtomicBoolean(false)
    private val poseEnabled = AtomicBoolean(false)

    private var intrinsics: Intrinsics? = null
    private var gravity: FloatArray? = null
    private var hasTripod = true
    private var highFrameRate = true
    private var thermalGuard = true

    private var frameCount = 0
    private var fpsWindowStart = 0L
    private var processedFps = 0
    private var lastLuma = 0.55f
    private var lastClipped = 0.02f
    private var motionPixels = 0.4f

    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gravityListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            gravity = event.values.copyOf(3)
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    private data class Intrinsics(
        val focalX: Double,
        val focalY: Double,
        val centreX: Double,
        val centreY: Double,
        val width: Int,
        val height: Int,
        val fromDevice: Boolean,
    )

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        stopCamera()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        engine?.close()
        engine = null
        analysisExecutor.shutdown()
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        this.sink = sink
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "requestCameraPermission" -> requestCameraPermission(result)
            "startPreview" -> {
                poseEnabled.set(false)
                hasTripod = call.argument<Boolean>("tripod") ?: true
                start(result)
            }
            "stopPreview" -> {
                stopCamera()
                result.success(null)
            }
            "start" -> {
                poseEnabled.set(call.argument<Boolean>("pose") ?: true)
                highFrameRate = call.argument<Boolean>("highFrameRate") ?: true
                thermalGuard = call.argument<Boolean>("thermalGuard") ?: true
                hasTripod = call.argument<Boolean>("tripod") ?: true
                start(result)
            }
            "pause" -> {
                running.set(false)
                result.success(null)
            }
            "resume" -> {
                running.set(true)
                result.success(null)
            }
            "stop" -> {
                stopCamera()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Shows the system camera prompt and reports what the user chose.
     *
     * Distinguishing a plain refusal from a permanent one matters: Android
     * stops showing the dialog after the second decline, so an app that keeps
     * asking looks broken. `shouldShowRequestPermissionRationale` returning
     * false after a denial is how the platform says "this dialog will not
     * appear again", and the caller uses that to offer Settings instead.
     */
    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (hasCameraPermission()) {
            result.success(mapOf("status" to "granted"))
            return
        }

        val activity = lifecycleOwner as? Activity
        if (activity == null) {
            result.success(
                mapOf(
                    "status" to "denied",
                    "detail" to "no activity is attached to show the prompt",
                ),
            )
            return
        }

        pendingPermission?.let {
            // A second request while one is in flight would strand the first
            // result and crash the engine on reply.
            it.success(mapOf("status" to "denied", "detail" to "superseded"))
        }
        pendingPermission = result

        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST,
        )
    }

    /**
     * Called by the activity when the system prompt closes.
     *
     * @return true when this bridge consumed the result.
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != CAMERA_PERMISSION_REQUEST) return false

        val reply = pendingPermission ?: return true
        pendingPermission = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        if (granted) {
            reply.success(mapOf("status" to "granted"))
            return true
        }

        val activity = lifecycleOwner as? Activity
        val canAskAgain = activity != null &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                activity,
                Manifest.permission.CAMERA,
            )

        reply.success(
            mapOf("status" to if (canAskAgain) "denied" else "permanentlyDenied"),
        )
        return true
    }

    private fun availability(): Map<String, Any?> {
        if (!hasCameraPermission()) {
            return mapOf(
                "unavailable" to "cameraPermissionDenied",
                "detail" to "camera permission has not been granted",
            )
        }

        val loaded = try {
            engine ?: VisionEngine.create(context).also { engine = it }
        } catch (error: ModelsMissingException) {
            return mapOf("unavailable" to "modelsMissing", "detail" to error.detail)
        } catch (error: ContractMismatchException) {
            return mapOf("unavailable" to "contractMismatch", "detail" to error.detail)
        } catch (error: Exception) {
            Log.e(TAG, "Could not load the vision models", error)
            return mapOf("unavailable" to "modelsMissing", "detail" to error.message)
        }

        return mapOf(
            "contractVersion" to ModelContract.VERSION,
            "detectorVersion" to loaded.detectorVersion,
            "poseVersion" to loaded.poseVersion,
            "backend" to loaded.backend,
        )
    }

    private fun start(result: MethodChannel.Result) {
        val ready = availability()
        if (ready.containsKey("unavailable")) {
            result.error(
                ready["unavailable"] as String,
                ready["detail"] as String?,
                null,
            )
            return
        }

        sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)?.let {
            sensors.registerListener(gravityListener, it, SensorManager.SENSOR_DELAY_GAME)
        }

        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                bind(future.get())
                running.set(true)
                result.success(mapOf("textureId" to previewTextureId))
            } catch (error: Exception) {
                Log.e(TAG, "Could not open the camera", error)
                result.error("cameraUnavailable", error.message, null)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    /**
     * Binds analysis and preview together.
     *
     * The preview is a separate use case rather than a rendering of the
     * analysis frames: CameraX gives the preview stream the resolution and
     * pipeline the hardware is tuned for, while analysis stays at the lower
     * resolution the models want. Sharing one stream would force a choice
     * between a soft preview and a slow detector.
     */
    private fun bind(cameraProvider: ProcessCameraProvider) {
        provider = cameraProvider
        cameraProvider.unbindAll()

        val selector = CameraSelector.DEFAULT_BACK_CAMERA
        readIntrinsics()

        val targetFps = if (highFrameRate) 60 else 30
        val imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(android.util.Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT))
            // Dropping frames is the right failure: a late measurement of an
            // old frame is worse than no measurement of it.
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()

        imageAnalysis.setAnalyzer(analysisExecutor, ::analyse)
        analysis = imageAnalysis

        val entry = texture ?: textures.createSurfaceTexture().also { texture = it }
        val previewUseCase = Preview.Builder().build()
        previewUseCase.setSurfaceProvider(::provideSurface)
        preview = previewUseCase

        val camera = cameraProvider.bindToLifecycle(
            lifecycleOwner,
            selector,
            previewUseCase,
            imageAnalysis,
        )
        applyFrameRate(camera, targetFps)
        previewTextureId = entry.id()
    }

    /**
     * Asks the sensor for the requested capture rate.
     *
     * Advisory: a device that cannot hold 60 fps at this resolution will
     * quietly stay at 30, which is the right outcome. The rate the session
     * actually ran at is measured per frame and recorded with it, so the
     * stored session reports what happened rather than what was asked for.
     */
    private fun applyFrameRate(camera: androidx.camera.core.Camera, fps: Int) {
        try {
            val control = androidx.camera.camera2.interop.Camera2CameraControl
                .from(camera.cameraControl)
            control.setCaptureRequestOptions(
                androidx.camera.camera2.interop.CaptureRequestOptions.Builder()
                    .setCaptureRequestOption(
                        android.hardware.camera2.CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                        android.util.Range(fps, fps),
                    )
                    .build(),
            )
        } catch (error: Exception) {
            Log.w(TAG, "Could not set the capture rate to $fps", error)
        }
    }

    /**
     * Hands CameraX a surface backed by the Flutter texture.
     *
     * The surface is recreated per request because CameraX may ask again after
     * a resolution change, and reusing a released surface is a black preview
     * with no error anywhere.
     */
    private fun provideSurface(request: SurfaceRequest) {
        val entry = texture ?: run {
            request.willNotProvideSurface()
            return
        }

        val surfaceTexture = entry.surfaceTexture()
        surfaceTexture.setDefaultBufferSize(
            request.resolution.width,
            request.resolution.height,
        )

        previewSurface?.release()
        val surface = Surface(surfaceTexture)
        previewSurface = surface

        request.provideSurface(surface, analysisExecutor) { result ->
            // Only release when this specific surface is finished with; the
            // callback also fires for surfaces already replaced above.
            if (previewSurface === surface) previewSurface = null
            result.surface.release()
        }
    }

    private fun stopCamera() {
        running.set(false)
        analysis?.clearAnalyzer()
        provider?.unbindAll()
        analysis = null
        preview = null
        provider = null
        previewSurface?.release()
        previewSurface = null
        texture?.release()
        texture = null
        previewTextureId = null
        sensors.unregisterListener(gravityListener)
    }

    /**
     * Focal length from the camera's own reported field of view.
     *
     * Everything the product reports in metres scales with this, so it is read
     * from the device where possible and the fact that it was assumed is
     * forwarded when it is not.
     */
    private fun readIntrinsics() {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        var focalPixels: Double? = null

        try {
            for (id in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing != CameraCharacteristics.LENS_FACING_BACK) continue

                val focalMm = characteristics
                    .get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    ?.firstOrNull() ?: continue
                val sensorSize = characteristics
                    .get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: continue

                // Horizontal field of view from the physical sensor width,
                // then back to pixels at the analysis resolution.
                val fov = 2 * atan((sensorSize.width / 2.0) / focalMm)
                focalPixels = (ANALYSIS_WIDTH / 2.0) / kotlin.math.tan(fov / 2)
                break
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not read the lens characteristics", error)
        }

        val assumed = focalPixels == null
        // 65 degrees is the middle of the range for a phone main camera.
        val focal = focalPixels ?: ((ANALYSIS_WIDTH / 2.0) / kotlin.math.tan(Math.toRadians(32.5)))

        intrinsics = Intrinsics(
            focalX = focal,
            focalY = focal,
            centreX = ANALYSIS_WIDTH / 2.0,
            centreY = ANALYSIS_HEIGHT / 2.0,
            width = ANALYSIS_WIDTH,
            height = ANALYSIS_HEIGHT,
            fromDevice = !assumed,
        )
    }

    private fun analyse(image: ImageProxy) {
        try {
            if (!running.get() || sink == null) return
            val loaded = engine ?: return

            val width = image.width
            val height = image.height
            val rgb = toRgb(image)
            measureExposure(rgb)

            val boxes = loaded.detect(rgb, width, height)
            val people = boxes.filter { it.classId == ModelContract.CLASS_PERSON }
                .sortedByDescending { it.width * it.height }
                .take(3)

            val payload = HashMap<String, Any?>()
            payload["type"] = "detections"
            payload["tMs"] = image.imageInfo.timestamp / 1_000_000L

            val poseThisFrame = poseEnabled.get() && !shouldSkipPose()
            payload["people"] = people.map { box ->
                val landmarks = if (poseThisFrame) {
                    loaded.estimatePose(rgb, width, height, box)
                } else {
                    null
                }
                mapOf(
                    "box" to doubleArrayOf(
                        box.left.toDouble(),
                        box.top.toDouble(),
                        box.right.toDouble(),
                        box.bottom.toDouble(),
                    ),
                    "score" to box.score.toDouble(),
                    "keypoints" to flatten(landmarks),
                )
            }

            payload["ball"] = boxes.firstOrNull { it.classId == ModelContract.CLASS_BALL }
                ?.let(::boxPayload)

            val rim = boxes.filter { it.classId == ModelContract.CLASS_RIM }
                .maxByOrNull { it.score }
            payload["rim"] = rim?.let(::boxPayload)
            payload["rimEllipse"] = rim?.let {
                RimEllipse.fromBox(it, RimEllipse.rollFromGravity(gravity))
            }

            payload["backboard"] = boxes
                .filter { it.classId == ModelContract.CLASS_BACKBOARD }
                .maxByOrNull { it.score }
                ?.let(::boxPayload)

            intrinsics?.let { lens ->
                // The analysis stream may not be the resolution asked for.
                val scaleX = width.toDouble() / lens.width
                val scaleY = height.toDouble() / lens.height
                payload["intrinsics"] = mapOf(
                    "fx" to lens.focalX * scaleX,
                    "fy" to lens.focalY * scaleY,
                    "cx" to lens.centreX * scaleX,
                    "cy" to lens.centreY * scaleY,
                    "width" to width,
                    "height" to height,
                    "fromDevice" to lens.fromDevice,
                )
            }

            payload["gravity"] = gravity?.let {
                doubleArrayOf(it[0].toDouble(), it[1].toDouble(), it[2].toDouble())
            }
            payload["conditions"] = mapOf(
                "meanLuma" to lastLuma.toDouble(),
                "clipped" to lastClipped.toDouble(),
                "motion" to motionPixels.toDouble(),
                "frameRate" to processedFps,
                "tripod" to hasTripod,
            )
            payload["fps"] = processedFps
            payload["thermalHeadroom"] = thermalHeadroom()
            payload["backend"] = loaded.backend

            tickFps()
            main.post { sink?.success(payload) }
        } catch (error: Exception) {
            Log.e(TAG, "Frame analysis failed", error)
            main.post {
                sink?.success(
                    mapOf(
                        "type" to "error",
                        "code" to "analysisFailed",
                        "message" to error.message,
                    ),
                )
            }
        } finally {
            image.close()
        }
    }

    private fun boxPayload(box: Box) = mapOf(
        "box" to doubleArrayOf(
            box.left.toDouble(),
            box.top.toDouble(),
            box.right.toDouble(),
            box.bottom.toDouble(),
        ),
        "score" to box.score.toDouble(),
    )

    /** Landmarks travel as one flat array: fifty-one boxed doubles per person
     *  per frame is not free at thirty frames a second. */
    private fun flatten(landmarks: Landmarks?): DoubleArray {
        val values = DoubleArray(ModelContract.KEYPOINT_COUNT * 3)
        if (landmarks == null) return values
        for (k in 0 until ModelContract.KEYPOINT_COUNT) {
            values[k * 3] = landmarks.xs[k].toDouble()
            values[k * 3 + 1] = landmarks.ys[k].toDouble()
            values[k * 3 + 2] = landmarks.scores[k].toDouble()
        }
        return values
    }

    private fun toRgb(image: ImageProxy): ByteArray {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val width = image.width
        val height = image.height

        val out = ByteArray(width * height * 3)
        val row = ByteArray(rowStride)
        var offset = 0

        for (y in 0 until height) {
            buffer.position(y * rowStride)
            val length = min(rowStride, buffer.remaining())
            buffer.get(row, 0, length)
            for (x in 0 until width) {
                val source = x * pixelStride
                out[offset++] = row[source]
                out[offset++] = row[source + 1]
                out[offset++] = row[source + 2]
            }
        }
        return out
    }

    /**
     * Scene brightness and how much of it is clipped.
     *
     * Sampled sparsely: this runs every frame and the calibration only needs
     * to know whether the gym is dim or the windows are blowing out.
     */
    private fun measureExposure(rgb: ByteArray) {
        var sum = 0L
        var clipped = 0
        var samples = 0
        var i = 0
        while (i < rgb.size - 2) {
            val luma = ((rgb[i].toInt() and 0xFF) * 299 +
                (rgb[i + 1].toInt() and 0xFF) * 587 +
                (rgb[i + 2].toInt() and 0xFF) * 114) / 1000
            sum += luma
            if (luma >= 250 || luma <= 5) clipped++
            samples++
            i += 3 * 97
        }
        if (samples == 0) return
        lastLuma = (sum.toFloat() / samples) / 255f
        lastClipped = clipped.toFloat() / samples
    }

    /**
     * Whether to drop pose on this frame to stay ahead of the thermal cliff.
     *
     * Only ever alternate frames, never a run of them: pose at fifteen a
     * second still describes a shooting motion, while a two-second gap does
     * not, and the athlete would see the skeleton stall rather than thin.
     */
    private fun shouldSkipPose(): Boolean {
        if (!thermalGuard) return false
        val target = if (highFrameRate) 60.0 else 30.0
        if (processedFps == 0 || processedFps >= target * THERMAL_FLOOR) {
            return false
        }
        return frameCount % 2 == 1
    }

    private fun tickFps() {
        frameCount++
        val now = System.currentTimeMillis()
        if (fpsWindowStart == 0L) fpsWindowStart = now
        val elapsed = now - fpsWindowStart
        if (elapsed >= 1000) {
            processedFps = (frameCount * 1000 / elapsed).toInt()
            frameCount = 0
            fpsWindowStart = now
        }
    }

    /**
     * How much sustained-performance budget is left.
     *
     * Derived from the frame rate actually being held rather than from a
     * thermal API, because what matters to a measurement is whether frames are
     * arriving fast enough to see a release, not the die temperature.
     */
    private fun thermalHeadroom(): Double {
        if (processedFps == 0) return 1.0
        return max(0.0, min(1.0, processedFps / 30.0))
    }
}
