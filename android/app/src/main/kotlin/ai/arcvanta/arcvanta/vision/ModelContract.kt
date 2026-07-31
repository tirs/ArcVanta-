package ai.arcvanta.arcvanta.vision

/**
 * The Kotlin half of `vision/contract/model_contract.json`.
 *
 * Nothing here is chosen locally. Every value is read off the contract, and
 * the graphs are checked against it at load time so a mismatched export fails
 * loudly on startup instead of quietly producing landmarks in the wrong place.
 */
object ModelContract {
    const val VERSION = 1

    const val DETECTOR_ASSET = "arcvanta_rtmdet_m_640.onnx"
    const val POSE_ASSET = "arcvanta_rtmpose_m_256x192.onnx"

    const val DETECTOR_INPUT = "images"
    const val DETECTOR_SIZE = 640
    const val DETECTOR_PAD_VALUE = 114

    /**
     * BGR order, because RTMDet sets `bgr_to_rgb=False` and was trained on
     * channels the way OpenCV loads them. The pose model below is the
     * opposite, so the two cannot share a channel order and each preprocessing
     * loop has to say which one it is writing.
     */
    val DETECTOR_MEAN = floatArrayOf(103.53f, 116.28f, 123.675f)
    val DETECTOR_STD = floatArrayOf(57.375f, 57.12f, 58.395f)

    const val POSE_INPUT = "input"
    const val POSE_WIDTH = 192
    const val POSE_HEIGHT = 256
    const val POSE_PADDING_FACTOR = 1.25f
    const val SIMCC_SPLIT_RATIO = 2.0f
    const val KEYPOINT_COUNT = 17

    /** RGB order, matching `bgr_to_rgb=True` in the mmpose config. */
    val POSE_MEAN = floatArrayOf(123.675f, 116.28f, 103.53f)
    val POSE_STD = floatArrayOf(58.395f, 57.12f, 57.375f)

    const val CLASS_PERSON = 0
    const val CLASS_BALL = 1
    const val CLASS_RIM = 2
    const val CLASS_BACKBOARD = 3

    /**
     * Below this a detection is not worth forwarding. Kept low because the
     * detector was trained on broadcast footage and scores lower on close-range
     * phone frames. The calibration solver grades the quality separately.
     */
    const val SCORE_THRESHOLD = 0.15f
}
