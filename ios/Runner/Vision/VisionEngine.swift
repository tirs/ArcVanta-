import Foundation
import onnxruntime_objc

/// A detected box in source-image pixels.
struct Box {
    let classId: Int
    let left: Float
    let top: Float
    let right: Float
    let bottom: Float
    let score: Float

    var width: Float { right - left }
    var height: Float { bottom - top }
    var centreX: Float { (left + right) / 2 }
    var centreY: Float { (top + bottom) / 2 }
}

/// Landmarks for one person, in source-image pixels.
struct Landmarks {
    let xs: [Float]
    let ys: [Float]
    let scores: [Float]
}

enum VisionError: Error {
    case modelsMissing(String)
    case contractMismatch(String)
    case inference(String)

    var code: String {
        switch self {
        case .modelsMissing: return "modelsMissing"
        case .contractMismatch: return "contractMismatch"
        case .inference: return "analysisFailed"
        }
    }

    var detail: String {
        switch self {
        case .modelsMissing(let detail),
             .contractMismatch(let detail),
             .inference(let detail):
            return detail
        }
    }
}

/// Loads RTMDet and RTMPose and runs them on a frame.
///
/// Deliberately narrow: it turns pixels into boxes and landmarks and nothing
/// else. Every decision that depends on the geometry of the court, on where the
/// shot began or on what the numbers mean happens in Dart, so there is one
/// implementation of the measurement rather than one per platform.
final class VisionEngine {
    private let environment: ORTEnv
    private let detector: ORTSession
    private let pose: ORTSession

    let backend: String
    let detectorVersion: String
    let poseVersion: String

    private var detectorBuffer: [Float]
    private var poseBuffer: [Float]

    /// Finds a model file, checking the app bundle first (shipped models) and
    /// then Application Support (for future OTA-updated models).
    private static func resolveModel(_ filename: String) -> URL? {
        if let bundled = Bundle.main.url(forResource: (filename as NSString).deletingPathExtension,
                                         withExtension: (filename as NSString).pathExtension) {
            return bundled
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("vision", isDirectory: true)
        let url = appSupport.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        return nil
    }

    static func create() throws -> VisionEngine {
        guard let detectorURL = resolveModel(ModelContract.detectorAsset) else {
            throw VisionError.modelsMissing("\(ModelContract.detectorAsset) not found in bundle or app support")
        }
        guard let poseURL = resolveModel(ModelContract.poseAsset) else {
            throw VisionError.modelsMissing("\(ModelContract.poseAsset) not found in bundle or app support")
        }

        let environment = try ORTEnv(loggingLevel: .warning)

        // Providers are tried in order and the first that loads wins. Core ML
        // falls back per node without complaining, so which one took the graph
        // is recorded and reported rather than assumed.
        func load(_ url: URL) throws -> (ORTSession, String) {
            if let session = try? sessionWithCoreML(environment, url) {
                return (session, "CoreML")
            }
            if let session = try? sessionWithXnnpack(environment, url) {
                return (session, "XNNPACK")
            }
            let options = try baseOptions()
            return (
                try ORTSession(env: environment, modelPath: url.path, sessionOptions: options),
                "CPU"
            )
        }

        let (detectorSession, detectorBackend) = try load(detectorURL)
        let (poseSession, poseBackend) = try load(poseURL)
        // The weaker of the two is what the session actually sustains.
        let backend = detectorBackend == poseBackend ? detectorBackend : "CPU"

        try verify(detector: detectorSession, pose: poseSession)

        return VisionEngine(
            environment: environment,
            detector: detectorSession,
            pose: poseSession,
            backend: backend,
            detectorVersion: version(of: detectorURL),
            poseVersion: version(of: poseURL)
        )
    }

    private static func baseOptions() throws -> ORTSessionOptions {
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(2)
        try options.setGraphOptimizationLevel(.all)
        return options
    }

    private static func sessionWithCoreML(
        _ environment: ORTEnv,
        _ url: URL
    ) throws -> ORTSession {
        let options = try baseOptions()

        let coreML = ORTCoreMLExecutionProviderOptions()
        // Subgraphs are allowed so a node Core ML cannot take does not push
        // the whole graph back to the CPU.
        coreML.enableOnSubgraphs = true
        // The GPU is worth using on devices without a Neural Engine; the
        // fallback is per node either way.
        coreML.onlyEnableForDevicesWithANE = false

        try options.appendCoreMLExecutionProvider(with: coreML)
        return try ORTSession(env: environment, modelPath: url.path, sessionOptions: options)
    }

    private static func sessionWithXnnpack(
        _ environment: ORTEnv,
        _ url: URL
    ) throws -> ORTSession {
        let options = try baseOptions()
        try options.appendExecutionProvider("XNNPACK", providerOptions: [
            "intra_op_num_threads": "2"
        ])
        return try ORTSession(env: environment, modelPath: url.path, sessionOptions: options)
    }

    /// Checks the graphs against the contract before a single frame runs.
    ///
    /// A pose model with a different input size would still produce
    /// plausible-looking landmarks, in the wrong places, and the error would
    /// surface as a wrong elbow angle rather than as a crash.
    private static func verify(detector: ORTSession, pose: ORTSession) throws {
        let detectorInputs = try detector.inputNames()
        guard detectorInputs.contains(ModelContract.detectorInput) else {
            throw VisionError.contractMismatch(
                "input '\(ModelContract.detectorInput)' is not in the graph; "
                    + "found \(detectorInputs)"
            )
        }

        let poseInputs = try pose.inputNames()
        guard poseInputs.contains(ModelContract.poseInput) else {
            throw VisionError.contractMismatch(
                "input '\(ModelContract.poseInput)' is not in the graph; found \(poseInputs)"
            )
        }

        let poseOutputs = try pose.outputNames()
        for required in ["simcc_x", "simcc_y"] {
            guard poseOutputs.contains(required) else {
                throw VisionError.contractMismatch(
                    "pose graph has no '\(required)'; found \(poseOutputs)"
                )
            }
        }
    }

    /// Sidecar written by the export script, so a session records what ran.
    private static func version(of model: URL) -> String {
        let sidecar = model.deletingPathExtension().appendingPathExtension("version")
        guard let text = try? String(contentsOf: sidecar, encoding: .utf8) else {
            return "unpinned"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private init(
        environment: ORTEnv,
        detector: ORTSession,
        pose: ORTSession,
        backend: String,
        detectorVersion: String,
        poseVersion: String
    ) {
        self.environment = environment
        self.detector = detector
        self.pose = pose
        self.backend = backend
        self.detectorVersion = detectorVersion
        self.poseVersion = poseVersion
        self.detectorBuffer = [Float](
            repeating: 0,
            count: 3 * ModelContract.detectorSize * ModelContract.detectorSize
        )
        self.poseBuffer = [Float](
            repeating: 0,
            count: 3 * ModelContract.poseHeight * ModelContract.poseWidth
        )
    }

    /// Runs detection on a frame already converted to RGB.
    ///
    /// `rgb` is width times height times 3 bytes. Letterboxing keeps the aspect
    /// ratio so boxes map back to source pixels by one scale and one offset.
    func detect(rgb: UnsafePointer<UInt8>, width: Int, height: Int) throws -> [Box] {
        let size = ModelContract.detectorSize
        let scale = min(Float(size) / Float(width), Float(size) / Float(height))
        let scaledWidth = Int((Float(width) * scale).rounded())
        let scaledHeight = Int((Float(height) * scale).rounded())
        // Bottom-right, matching mmdet's Pad. Centring the image is
        // self-consistent arithmetic that still shows the network a layout it
        // never saw in training.
        let padX = 0
        let padY = 0
        let plane = size * size

        // Pad first, then draw the resized image into the middle.
        detectorBuffer.withUnsafeMutableBufferPointer { data in
            for channel in 0..<3 {
                let padded = (ModelContract.detectorPadValue - ModelContract.detectorMean[channel])
                    / ModelContract.detectorStd[channel]
                for i in (channel * plane)..<((channel + 1) * plane) {
                    data[i] = padded
                }
            }

            for y in 0..<scaledHeight {
                let sourceY = min(max(Int(Float(y) / scale), 0), height - 1)
                let destinationRow = (y + padY) * size
                for x in 0..<scaledWidth {
                    let sourceX = min(max(Int(Float(x) / scale), 0), width - 1)
                    let source = (sourceY * width + sourceX) * 3
                    let destination = destinationRow + x + padX
                    for channel in 0..<3 {
                        // channel 0 is blue: RTMDet trains with
                        // bgr_to_rgb=False, and blue is byte 2 of an RGB pixel.
                        let value = Float(rgb[source + (2 - channel)])
                        data[channel * plane + destination] =
                            (value - ModelContract.detectorMean[channel])
                            / ModelContract.detectorStd[channel]
                    }
                }
            }
        }

        let shape: [NSNumber] = [1, 3, NSNumber(value: size), NSNumber(value: size)]
        let tensor = try ORTValue(
            tensorData: NSMutableData(
                bytes: &detectorBuffer,
                length: detectorBuffer.count * MemoryLayout<Float>.size
            ),
            elementType: .float,
            shape: shape
        )

        let outputs = try detector.run(
            withInputs: [ModelContract.detectorInput: tensor],
            outputNames: Set(try detector.outputNames()),
            runOptions: nil
        )

        let names = try detector.outputNames()
        guard let detsValue = outputs[names[0]], let labelsValue = outputs[names[1]] else {
            throw VisionError.inference("the detector returned no boxes")
        }

        // The end2end export emits [1, N, 5] scored boxes and [1, N] labels,
        // already through non-maximum suppression.
        let dets = try floats(from: detsValue)
        let labels = try ints(from: labelsValue)
        let count = min(dets.count / 5, labels.count)

        var boxes: [Box] = []
        boxes.reserveCapacity(count)
        for i in 0..<count {
            let score = dets[i * 5 + 4]
            if score < ModelContract.scoreThreshold { continue }
            boxes.append(
                Box(
                    classId: labels[i],
                    left: (dets[i * 5] - Float(padX)) / scale,
                    top: (dets[i * 5 + 1] - Float(padY)) / scale,
                    right: (dets[i * 5 + 2] - Float(padX)) / scale,
                    bottom: (dets[i * 5 + 3] - Float(padY)) / scale,
                    score: score
                )
            )
        }
        return boxes
    }

    /// Top-down pose for one person box.
    ///
    /// The box is expanded to the model's aspect ratio before the crop, which
    /// is what the training-time pipeline does; cropping the box as given would
    /// squash the subject and move every landmark.
    func estimatePose(
        rgb: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        box: Box
    ) throws -> Landmarks {
        let aspect = Float(ModelContract.poseWidth) / Float(ModelContract.poseHeight)
        var cropWidth = box.width * ModelContract.posePaddingFactor
        var cropHeight = box.height * ModelContract.posePaddingFactor
        if cropWidth / cropHeight > aspect {
            cropHeight = cropWidth / aspect
        } else {
            cropWidth = cropHeight * aspect
        }

        let originX = box.centreX - cropWidth / 2
        let originY = box.centreY - cropHeight / 2
        let stepX = cropWidth / Float(ModelContract.poseWidth)
        let stepY = cropHeight / Float(ModelContract.poseHeight)
        let plane = ModelContract.poseHeight * ModelContract.poseWidth

        poseBuffer.withUnsafeMutableBufferPointer { data in
            for y in 0..<ModelContract.poseHeight {
                let sourceY = min(max(Int(originY + Float(y) * stepY), 0), height - 1)
                for x in 0..<ModelContract.poseWidth {
                    let sourceX = min(max(Int(originX + Float(x) * stepX), 0), width - 1)
                    let source = (sourceY * width + sourceX) * 3
                    let destination = y * ModelContract.poseWidth + x
                    for channel in 0..<3 {
                        let value = Float(rgb[source + channel])
                        data[channel * plane + destination] =
                            (value - ModelContract.poseMean[channel])
                            / ModelContract.poseStd[channel]
                    }
                }
            }
        }

        let shape: [NSNumber] = [
            1, 3,
            NSNumber(value: ModelContract.poseHeight),
            NSNumber(value: ModelContract.poseWidth),
        ]
        let tensor = try ORTValue(
            tensorData: NSMutableData(
                bytes: &poseBuffer,
                length: poseBuffer.count * MemoryLayout<Float>.size
            ),
            elementType: .float,
            shape: shape
        )

        let outputs = try pose.run(
            withInputs: [ModelContract.poseInput: tensor],
            outputNames: ["simcc_x", "simcc_y"],
            runOptions: nil
        )

        guard let xValue = outputs["simcc_x"], let yValue = outputs["simcc_y"] else {
            throw VisionError.inference("the pose graph returned no distributions")
        }

        let simccX = try floats(from: xValue)
        let simccY = try floats(from: yValue)
        let binsX = simccX.count / ModelContract.keypointCount
        let binsY = simccY.count / ModelContract.keypointCount

        var xs = [Float](repeating: 0, count: ModelContract.keypointCount)
        var ys = [Float](repeating: 0, count: ModelContract.keypointCount)
        var scores = [Float](repeating: 0, count: ModelContract.keypointCount)

        // RTMPose predicts an independent distribution per axis, so each is an
        // argmax and the landmark score is the product of the two peaks.
        for k in 0..<ModelContract.keypointCount {
            let (indexX, peakX) = argmax(simccX, offset: k * binsX, count: binsX)
            let (indexY, peakY) = argmax(simccY, offset: k * binsY, count: binsY)

            let localX = Float(indexX) / ModelContract.simccSplitRatio
            let localY = Float(indexY) / ModelContract.simccSplitRatio

            xs[k] = originX + localX * stepX
            ys[k] = originY + localY * stepY
            scores[k] = max(0, min(1, peakX * peakY))
        }

        return Landmarks(xs: xs, ys: ys, scores: scores)
    }

    private func argmax(
        _ values: [Float],
        offset: Int,
        count: Int
    ) -> (Int, Float) {
        var bestIndex = 0
        var best = values[offset]
        for i in 1..<count where values[offset + i] > best {
            best = values[offset + i]
            bestIndex = i
        }
        return (bestIndex, best)
    }

    private func floats(from value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }

    private func ints(from value: ORTValue) throws -> [Int] {
        let info = try value.tensorTypeAndShapeInfo()
        let data = try value.tensorData() as Data
        switch info.elementType {
        case .int64:
            return data.withUnsafeBytes { raw in
                raw.bindMemory(to: Int64.self).map { Int($0) }
            }
        case .int32:
            return data.withUnsafeBytes { raw in
                raw.bindMemory(to: Int32.self).map { Int($0) }
            }
        default:
            throw VisionError.contractMismatch(
                "labels came back as \(info.elementType), expected int64"
            )
        }
    }
}
