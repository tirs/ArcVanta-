import AVFoundation
import CoreMotion
import Flutter
import Foundation

/// The iOS half of the capture seam.
///
/// Runs the camera, pushes frames through `VisionEngine`, and reports what it
/// saw. It reports observations only: no phase, no shot, no measurement. Those
/// are decided in Dart, where one implementation serves both platforms and can
/// be tested without a device.
final class CaptureBridge: NSObject {
    private enum Channels {
        static let methods = "ai.arcvanta/capture"
        static let events = "ai.arcvanta/capture/events"
    }

    /// Analysis resolution. Higher costs frame rate for no extra reach.
    private static let analysisWidth = 1280
    private static let analysisHeight = 720

    private let methods: FlutterMethodChannel
    private let events: FlutterEventChannel
    private var sink: FlutterEventSink?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "ai.arcvanta.capture", qos: .userInitiated)
    private let motion = CMMotionManager()

    private let preview = PreviewTexture()
    private let textures: FlutterTextureRegistry
    private var previewRegistered = false

    private var engine: VisionEngine?
    private var running = false
    private var poseEnabled = false
    private var hasTripod = true
    private var highFrameRate = true
    private var thermalGuard = true
    private var useFrontCamera = false

    private var intrinsics: (fx: Double, fy: Double, cx: Double, cy: Double, fromDevice: Bool)?
    private var gravity: [Double]?

    private var frameCount = 0
    private var fpsWindowStart: CFTimeInterval = 0
    private var processedFps = 0
    private var meanLuma = 0.55
    private var clippedFraction = 0.02

    /// Scratch buffer for the RGB conversion, kept between frames so a
    /// thirty-times-a-second allocation of two megabytes does not thrash.
    private var rgb = [UInt8]()

    init(messenger: FlutterBinaryMessenger, textures: FlutterTextureRegistry) {
        self.textures = textures
        methods = FlutterMethodChannel(name: Channels.methods, binaryMessenger: messenger)
        events = FlutterEventChannel(name: Channels.events, binaryMessenger: messenger)
        super.init()

        methods.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
        events.setStreamHandler(self)
    }

    func dispose() {
        stopCamera()
        methods.setMethodCallHandler(nil)
        events.setStreamHandler(nil)
        engine = nil
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "availability":
            result(availability())
        case "requestCameraPermission":
            requestCameraPermission(result)
        case "startPreview":
            let arguments = call.arguments as? [String: Any]
            poseEnabled = false
            hasTripod = arguments?["tripod"] as? Bool ?? true
            useFrontCamera = arguments?["frontCamera"] as? Bool ?? false
            start(result)
        case "stopPreview":
            stopCamera()
            result(nil)
        case "start":
            let arguments = call.arguments as? [String: Any]
            poseEnabled = arguments?["pose"] as? Bool ?? true
            highFrameRate = arguments?["highFrameRate"] as? Bool ?? true
            thermalGuard = arguments?["thermalGuard"] as? Bool ?? true
            hasTripod = arguments?["tripod"] as? Bool ?? true
            useFrontCamera = arguments?["frontCamera"] as? Bool ?? false
            start(result)
        case "pause":
            running = false
            result(nil)
        case "resume":
            running = true
            result(nil)
        case "stop":
            stopCamera()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Shows the system camera prompt and reports what the user chose.
    ///
    /// iOS only ever presents this dialog once per install, so a `.denied`
    /// status is always permanent from the app's point of view and the caller
    /// has to send the user to Settings rather than ask again.
    private func requestCameraPermission(_ result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result(["status": "granted"])
        case .denied, .restricted:
            result(["status": "permanentlyDenied"])
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(["status": granted ? "granted" : "permanentlyDenied"])
                }
            }
        @unknown default:
            result(["status": "denied"])
        }
    }

    private func availability() -> [String: Any?] {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            return [
                "unavailable": "cameraPermissionDenied",
                "detail": "camera access has not been granted",
            ]
        }

        if engine == nil {
            do {
                engine = try VisionEngine.create()
            } catch let error as VisionError {
                return ["unavailable": error.code, "detail": error.detail]
            } catch {
                return ["unavailable": "modelsMissing", "detail": error.localizedDescription]
            }
        }

        guard let loaded = engine else {
            return ["unavailable": "modelsMissing", "detail": "the engine did not load"]
        }

        return [
            "contractVersion": ModelContract.version,
            "detectorVersion": loaded.detectorVersion,
            "poseVersion": loaded.poseVersion,
            "backend": loaded.backend,
        ]
    }

    private func start(_ result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard granted else {
                        result(
                            FlutterError(
                                code: "cameraPermissionDenied",
                                message: "camera access was refused",
                                details: nil
                            )
                        )
                        return
                    }
                    self?.start(result)
                }
            }
            return
        }

        let ready = availability()
        if let unavailable = ready["unavailable"] as? String {
            result(
                FlutterError(
                    code: unavailable,
                    message: ready["detail"] as? String,
                    details: nil
                )
            )
            return
        }

        do {
            try configure()
        } catch {
            result(
                FlutterError(
                    code: "cameraUnavailable",
                    message: error.localizedDescription,
                    details: nil
                )
            )
            return
        }

        startMotion()
        queue.async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                guard let self else { return }
                self.running = true
                if !self.previewRegistered {
                    self.preview.register(with: self.textures)
                    self.previewRegistered = true
                }
                result(["textureId": self.preview.identifier])
            }
        }
    }

    private func configure() throws {
        guard !session.isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            throw VisionError.inference("no usable \(useFrontCamera ? "front" : "back") camera")
        }

        session.inputs.forEach(session.removeInput)
        session.addInput(input)

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        // Dropping frames is the right failure: a late measurement of an old
        // frame is worse than no measurement of it.
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        if session.outputs.isEmpty, session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video) {
            // Asking for the per-frame intrinsics is what makes every metric
            // the app reports trustworthy rather than assumed.
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
            }
        }

        session.commitConfiguration()
        applyFrameRate(to: device)
        readFallbackIntrinsics(from: device)
    }

    /// Pins the sensor to the requested capture rate.
    ///
    /// Clamped to what the active format actually supports rather than
    /// assumed: asking a format for a rate outside its range throws, and a
    /// session that will not start is a worse outcome than one at 30 fps.
    private func applyFrameRate(to device: AVCaptureDevice) {
        let wanted = highFrameRate ? 60.0 : 30.0
        let supported = device.activeFormat.videoSupportedFrameRateRanges
        guard let range = supported.first else { return }

        let rate = min(max(wanted, range.minFrameRate), range.maxFrameRate)
        do {
            try device.lockForConfiguration()
            let duration = CMTime(value: 1, timescale: CMTimeScale(rate))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            // The rate stays whatever the format defaults to, which the
            // per-frame measurement will report accurately either way.
        }
    }

    /// Whether to drop pose on this frame to stay ahead of the thermal cliff.
    ///
    /// Only ever alternate frames, never a run of them: pose at fifteen a
    /// second still describes a shooting motion, while a two-second gap does
    /// not, and the athlete would see the skeleton stall rather than thin.
    private func shouldSkipPose() -> Bool {
        guard thermalGuard else { return false }
        let target = highFrameRate ? 60.0 : 30.0
        if processedFps == 0 || Double(processedFps) >= target * 0.7 {
            return false
        }
        return frameCount % 2 == 1
    }

    /// Focal length from the lens' field of view, used only until a frame
    /// arrives carrying the real intrinsic matrix.
    private func readFallbackIntrinsics(from device: AVCaptureDevice) {
        let fov = Double(device.activeFormat.videoFieldOfView) * .pi / 180
        let focal = fov > 0
            ? (Double(Self.analysisWidth) / 2) / tan(fov / 2)
            // 65 degrees is the middle of the range for a phone main camera.
            : (Double(Self.analysisWidth) / 2) / tan(32.5 * .pi / 180)

        intrinsics = (
            fx: focal,
            fy: focal,
            cx: Double(Self.analysisWidth) / 2,
            cy: Double(Self.analysisHeight) / 2,
            fromDevice: false
        )
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            // Reported in g and pointing down; scaled to match the Android
            // gravity sensor so Dart sees one convention.
            self?.gravity = [
                data.gravity.x * 9.81,
                -data.gravity.y * 9.81,
                data.gravity.z * 9.81,
            ]
        }
    }

    private func stopCamera() {
        running = false
        motion.stopDeviceMotionUpdates()
        if previewRegistered {
            preview.unregister()
            previewRegistered = false
        }
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func tickFps() {
        frameCount += 1
        let now = CACurrentMediaTime()
        if fpsWindowStart == 0 { fpsWindowStart = now }
        let elapsed = now - fpsWindowStart
        if elapsed >= 1 {
            processedFps = Int(Double(frameCount) / elapsed)
            frameCount = 0
            fpsWindowStart = now
        }
    }

    /// How much sustained-performance budget is left.
    ///
    /// Derived from the frame rate actually being held rather than from a
    /// thermal API, because what matters to a measurement is whether frames
    /// are arriving fast enough to see a release, not the die temperature.
    private func thermalHeadroom() -> Double {
        if processedFps == 0 { return 1 }
        return max(0, min(1, Double(processedFps) / 30))
    }
}

extension CaptureBridge: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        sink = eventSink
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}

extension CaptureBridge: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard running, sink != nil, let loaded = engine else { return }
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if previewRegistered { preview.push(pixels) }

        readIntrinsics(from: sampleBuffer)

        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }

        let width = CVPixelBufferGetWidth(pixels)
        let height = CVPixelBufferGetHeight(pixels)
        guard let base = CVPixelBufferGetBaseAddress(pixels) else { return }
        let stride = CVPixelBufferGetBytesPerRow(pixels)

        convertToRgb(base: base, stride: stride, width: width, height: height)

        do {
            let payload = try analyse(loaded, width: width, height: height, buffer: sampleBuffer)
            tickFps()
            DispatchQueue.main.async { [weak self] in self?.sink?(payload) }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.sink?([
                    "type": "error",
                    "code": (error as? VisionError)?.code ?? "analysisFailed",
                    "message": (error as? VisionError)?.detail ?? error.localizedDescription,
                ])
            }
        }
    }

    private func analyse(
        _ loaded: VisionEngine,
        width: Int,
        height: Int,
        buffer: CMSampleBuffer
    ) throws -> [String: Any] {
        var payload: [String: Any] = [:]
        payload["type"] = "detections"

        let stamp = CMSampleBufferGetPresentationTimeStamp(buffer)
        payload["tMs"] = Int(CMTimeGetSeconds(stamp) * 1000)

        let boxes: [Box] = try rgb.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return [] }
            return try loaded.detect(rgb: base, width: width, height: height)
        }

        let people = boxes
            .filter { $0.classId == ModelContract.classPerson }
            .sorted { $0.width * $0.height > $1.width * $1.height }
            .prefix(3)

        let poseThisFrame = poseEnabled && !shouldSkipPose()
        payload["people"] = try rgb.withUnsafeBufferPointer { pointer -> [[String: Any]] in
            guard let base = pointer.baseAddress else { return [] }
            return try people.map { box in
                let landmarks = poseThisFrame
                    ? try loaded.estimatePose(rgb: base, width: width, height: height, box: box)
                    : nil
                return [
                    "box": [
                        Double(box.left), Double(box.top),
                        Double(box.right), Double(box.bottom),
                    ],
                    "score": Double(box.score),
                    "keypoints": flatten(landmarks),
                ]
            }
        }

        payload["ball"] = boxes
            .first { $0.classId == ModelContract.classBall }
            .map(boxPayload)

        let rim = boxes
            .filter { $0.classId == ModelContract.classRim }
            .max { $0.score < $1.score }
        payload["rim"] = rim.map(boxPayload)
        payload["rimEllipse"] = rim.flatMap {
            RimEllipse.fromBox($0, cameraRoll: RimEllipse.roll(fromGravity: gravity))
        }

        payload["backboard"] = boxes
            .filter { $0.classId == ModelContract.classBackboard }
            .max { $0.score < $1.score }
            .map(boxPayload)

        if let lens = intrinsics {
            // The analysis stream may not be the resolution asked for.
            let scaleX = Double(width) / Double(Self.analysisWidth)
            let scaleY = Double(height) / Double(Self.analysisHeight)
            payload["intrinsics"] = [
                "fx": lens.fromDevice ? lens.fx : lens.fx * scaleX,
                "fy": lens.fromDevice ? lens.fy : lens.fy * scaleY,
                "cx": lens.fromDevice ? lens.cx : lens.cx * scaleX,
                "cy": lens.fromDevice ? lens.cy : lens.cy * scaleY,
                "width": width,
                "height": height,
                "fromDevice": lens.fromDevice,
            ]
        }

        payload["gravity"] = gravity
        payload["conditions"] = [
            "meanLuma": meanLuma,
            "clipped": clippedFraction,
            "motion": 0.4,
            "frameRate": processedFps,
            "tripod": hasTripod,
        ]
        payload["fps"] = processedFps
        payload["thermalHeadroom"] = thermalHeadroom()
        payload["backend"] = loaded.backend

        return payload
    }

    /// The real intrinsic matrix, when the connection is delivering it.
    ///
    /// This is the difference between a release angle that is right and one
    /// that is plausible, so it replaces the field-of-view estimate as soon as
    /// a frame carries it.
    private func readIntrinsics(from buffer: CMSampleBuffer) {
        guard
            let attachment = CMGetAttachment(
                buffer,
                key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                attachmentModeOut: nil
            ) as? Data
        else { return }

        let matrix: matrix_float3x3 = attachment.withUnsafeBytes { raw in
            raw.load(as: matrix_float3x3.self)
        }

        intrinsics = (
            fx: Double(matrix.columns.0.x),
            fy: Double(matrix.columns.1.y),
            cx: Double(matrix.columns.2.x),
            cy: Double(matrix.columns.2.y),
            fromDevice: true
        )
    }

    private func boxPayload(_ box: Box) -> [String: Any] {
        [
            "box": [
                Double(box.left), Double(box.top),
                Double(box.right), Double(box.bottom),
            ],
            "score": Double(box.score),
        ]
    }

    /// Landmarks travel as one flat array: fifty-one boxed doubles per person
    /// per frame is not free at thirty frames a second.
    private func flatten(_ landmarks: Landmarks?) -> [Double] {
        var values = [Double](repeating: 0, count: ModelContract.keypointCount * 3)
        guard let landmarks else { return values }
        for k in 0..<ModelContract.keypointCount {
            values[k * 3] = Double(landmarks.xs[k])
            values[k * 3 + 1] = Double(landmarks.ys[k])
            values[k * 3 + 2] = Double(landmarks.scores[k])
        }
        return values
    }

    /// BGRA to packed RGB, measuring exposure on the way through so the
    /// calibration knows whether the gym is dim or the windows are blowing out.
    private func convertToRgb(
        base: UnsafeMutableRawPointer,
        stride: Int,
        width: Int,
        height: Int
    ) {
        let needed = width * height * 3
        if rgb.count != needed {
            rgb = [UInt8](repeating: 0, count: needed)
        }

        let source = base.assumingMemoryBound(to: UInt8.self)
        var lumaSum = 0
        var clipped = 0
        var samples = 0

        rgb.withUnsafeMutableBufferPointer { destination in
            var offset = 0
            for y in 0..<height {
                let row = y * stride
                for x in 0..<width {
                    let i = row + x * 4
                    let blue = source[i]
                    let green = source[i + 1]
                    let red = source[i + 2]
                    destination[offset] = red
                    destination[offset + 1] = green
                    destination[offset + 2] = blue
                    offset += 3

                    // Sampled sparsely: this runs every frame and the
                    // calibration only needs the broad strokes.
                    if (y * width + x) % 97 == 0 {
                        let luma =
                            (Int(red) * 299 + Int(green) * 587 + Int(blue) * 114) / 1000
                        lumaSum += luma
                        if luma >= 250 || luma <= 5 { clipped += 1 }
                        samples += 1
                    }
                }
            }
        }

        if samples > 0 {
            meanLuma = Double(lumaSum) / Double(samples) / 255
            clippedFraction = Double(clipped) / Double(samples)
        }
    }
}
