import Foundation

/// The Swift half of `vision/contract/model_contract.json`.
///
/// Nothing here is chosen locally. Every value is read off the contract, and
/// the graphs are checked against it at load time so a mismatched export fails
/// loudly on startup instead of quietly producing landmarks in the wrong place.
enum ModelContract {
    static let version = 1

    static let detectorAsset = "arcvanta_rtmdet_m_640.onnx"
    static let poseAsset = "arcvanta_rtmpose_m_256x192.onnx"

    static let detectorInput = "images"
    static let detectorSize = 640
    static let detectorPadValue: Float = 114

    /// BGR order, because RTMDet sets `bgr_to_rgb=False` and was trained on
    /// channels the way the frame arrives. The pose constants below are the
    /// opposite, so the two preprocessing loops cannot be shared.
    static let detectorMean: [Float] = [103.53, 116.28, 123.675]
    static let detectorStd: [Float] = [57.375, 57.12, 58.395]

    static let poseInput = "input"
    static let poseWidth = 192
    static let poseHeight = 256
    static let posePaddingFactor: Float = 1.25
    static let simccSplitRatio: Float = 2.0
    static let keypointCount = 17

    static let poseMean: [Float] = [123.675, 116.28, 103.53]
    static let poseStd: [Float] = [58.395, 57.12, 57.375]

    static let classPerson = 0
    static let classBall = 1
    static let classRim = 2
    static let classBackboard = 3

    /// Below this a detection is not worth forwarding.
    static let scoreThreshold: Float = 0.35
}
