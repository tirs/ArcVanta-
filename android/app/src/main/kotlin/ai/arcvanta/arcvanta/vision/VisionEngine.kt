package ai.arcvanta.arcvanta.vision

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import ai.onnxruntime.providers.NNAPIFlags
import android.content.Context
import android.util.Log
import java.io.File
import java.nio.FloatBuffer
import java.util.EnumSet
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** A detected box in source-image pixels. */
data class Box(
    val classId: Int,
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val score: Float,
) {
    val width get() = right - left
    val height get() = bottom - top
    val centreX get() = (left + right) / 2f
    val centreY get() = (top + bottom) / 2f
}

/** Landmarks for one person, in source-image pixels. */
class Landmarks(val xs: FloatArray, val ys: FloatArray, val scores: FloatArray)

class ModelsMissingException(val detail: String) : Exception(detail)

class ContractMismatchException(val detail: String) : Exception(detail)

/**
 * Loads RTMDet and RTMPose and runs them on a frame.
 *
 * Deliberately narrow: it turns pixels into boxes and landmarks and nothing
 * else. Every decision that depends on the geometry of the court, on where the
 * shot began or on what the numbers mean happens in Dart, so there is one
 * implementation of the measurement rather than one per platform.
 */
class VisionEngine private constructor(
    private val environment: OrtEnvironment,
    private val detector: OrtSession,
    private val pose: OrtSession,
    val backend: String,
    val detectorVersion: String,
    val poseVersion: String,
) : AutoCloseable {

    companion object {
        private const val TAG = "ArcVantaVision"

        fun modelDirectory(context: Context) = File(context.filesDir, "vision")

        /**
         * Extracts a model from APK assets to the files directory if it has
         * not been placed there already. Future OTA updates can write into the
         * same directory and they will be preferred over the bundled copy.
         */
        private fun ensureModel(context: Context, directory: File, filename: String): File {
            val target = File(directory, filename)
            if (target.exists()) return target
            directory.mkdirs()
            try {
                context.assets.open(filename).use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                Log.i(TAG, "extracted $filename (${target.length() / 1024} KB)")
            } catch (e: Exception) {
                throw ModelsMissingException(
                    "$filename not found in assets or ${directory.path}: ${e.message}",
                )
            }
            return target
        }

        fun create(context: Context): VisionEngine {
            val directory = modelDirectory(context)
            val detectorFile = ensureModel(context, directory, ModelContract.DETECTOR_ASSET)
            val poseFile = ensureModel(context, directory, ModelContract.POSE_ASSET)

            val environment = OrtEnvironment.getEnvironment()
            var backend = "CPU"

            fun options(): OrtSession.SessionOptions {
                val options = OrtSession.SessionOptions()
                options.setIntraOpNumThreads(2)
                options.setOptimizationLevel(
                    OrtSession.SessionOptions.OptLevel.ALL_OPT,
                )
                return options
            }

            // Providers are tried in order and the first that loads wins. Both
            // NNAPI and XNNPACK fall back per node without complaining, so
            // which one took the graph is recorded and reported rather than
            // assumed.
            fun load(file: File): Pair<OrtSession, String> {
                try {
                    val options = options()
                    options.addNnapi(EnumSet.of(NNAPIFlags.USE_FP16))
                    return environment.createSession(file.path, options) to "NNAPI"
                } catch (error: OrtException) {
                    Log.w(TAG, "NNAPI unavailable for ${file.name}: ${error.message}")
                }
                try {
                    val options = options()
                    options.addXnnpack(mapOf("intra_op_num_threads" to "2"))
                    return environment.createSession(file.path, options) to "XNNPACK"
                } catch (error: OrtException) {
                    Log.w(TAG, "XNNPACK unavailable for ${file.name}: ${error.message}")
                }
                return environment.createSession(file.path, options()) to "CPU"
            }

            val (detectorSession, detectorBackend) = load(detectorFile)
            val (poseSession, poseBackend) = load(poseFile)
            // The weaker of the two is what the session actually sustains.
            backend = if (detectorBackend == poseBackend) detectorBackend else "CPU"

            verify(detectorSession, poseSession)

            return VisionEngine(
                environment = environment,
                detector = detectorSession,
                pose = poseSession,
                backend = backend,
                detectorVersion = versionOf(detectorFile),
                poseVersion = versionOf(poseFile),
            )
        }

        /**
         * Checks the graphs against the contract before a single frame runs.
         *
         * A pose model with a different input size would still produce
         * plausible-looking landmarks, in the wrong places, and the error
         * would surface as a wrong elbow angle rather than as a crash.
         */
        private fun verify(detector: OrtSession, pose: OrtSession) {
            fun shapeOf(session: OrtSession, name: String): LongArray {
                val info = session.inputInfo[name]
                    ?: throw ContractMismatchException(
                        "input '$name' is not in the graph; found ${session.inputInfo.keys}",
                    )
                return (info.info as ai.onnxruntime.TensorInfo).shape
            }

            val detectorShape = shapeOf(detector, ModelContract.DETECTOR_INPUT)
            if (detectorShape[2] != ModelContract.DETECTOR_SIZE.toLong() ||
                detectorShape[3] != ModelContract.DETECTOR_SIZE.toLong()
            ) {
                throw ContractMismatchException(
                    "detector expects ${detectorShape.toList()}, contract says " +
                        "${ModelContract.DETECTOR_SIZE}",
                )
            }

            val poseShape = shapeOf(pose, ModelContract.POSE_INPUT)
            if (poseShape[2] != ModelContract.POSE_HEIGHT.toLong() ||
                poseShape[3] != ModelContract.POSE_WIDTH.toLong()
            ) {
                throw ContractMismatchException(
                    "pose expects ${poseShape.toList()}, contract says " +
                        "${ModelContract.POSE_HEIGHT}x${ModelContract.POSE_WIDTH}",
                )
            }

            for (required in listOf("simcc_x", "simcc_y")) {
                if (!pose.outputInfo.containsKey(required)) {
                    throw ContractMismatchException(
                        "pose graph has no '$required'; found ${pose.outputInfo.keys}",
                    )
                }
            }
        }

        /** Sidecar written by the export script, so a session records what ran. */
        private fun versionOf(model: File): String {
            val sidecar = File(model.parentFile, model.nameWithoutExtension + ".version")
            return if (sidecar.exists()) sidecar.readText().trim() else "unpinned"
        }
    }

    private val detectorBuffer = FloatBuffer.allocate(
        3 * ModelContract.DETECTOR_SIZE * ModelContract.DETECTOR_SIZE,
    )
    private val poseBuffer = FloatBuffer.allocate(
        3 * ModelContract.POSE_HEIGHT * ModelContract.POSE_WIDTH,
    )

    /**
     * Runs detection on a frame held as RGB bytes.
     *
     * [rgb] is width times height times 3 bytes. Letterboxing keeps the aspect
     * ratio so boxes map back to source pixels by one scale and one offset.
     *
     * Two details here are not free choices, and both were wrong once:
     *
     * The detector eats BGR. RTMDet trains with `bgr_to_rgb=False`, so the
     * channels are written out reversed below and the means are indexed in
     * that same reversed order. The pose model wants RGB and gets it
     * unreversed, which is why the two loops cannot be shared.
     *
     * The padding goes bottom-right, not around the edges. mmdet's `Pad`
     * leaves the image in the top-left corner, and that is the geometry the
     * weights were fitted to; centring it is self-consistent arithmetic that
     * still shows the network a layout it never saw in training.
     */
    fun detect(rgb: ByteArray, width: Int, height: Int): List<Box> {
        val size = ModelContract.DETECTOR_SIZE
        val scale = min(size.toFloat() / width, size.toFloat() / height)
        val scaledWidth = (width * scale).roundToInt()
        val scaledHeight = (height * scale).roundToInt()
        val padX = 0
        val padY = 0

        detectorBuffer.clear()
        val plane = size * size
        val data = detectorBuffer.array()

        // Pad first, then draw the resized image into the middle.
        for (channel in 0 until 3) {
            val padded = (ModelContract.DETECTOR_PAD_VALUE - ModelContract.DETECTOR_MEAN[channel]) /
                ModelContract.DETECTOR_STD[channel]
            java.util.Arrays.fill(data, channel * plane, (channel + 1) * plane, padded)
        }

        for (y in 0 until scaledHeight) {
            val sourceY = (y / scale).toInt().coerceIn(0, height - 1)
            val destinationRow = (y + padY) * size
            for (x in 0 until scaledWidth) {
                val sourceX = (x / scale).toInt().coerceIn(0, width - 1)
                val source = (sourceY * width + sourceX) * 3
                val destination = destinationRow + x + padX
                for (channel in 0 until 3) {
                    // channel 0 is blue, and blue is byte 2 of an RGB pixel.
                    val value = (rgb[source + (2 - channel)].toInt() and 0xFF).toFloat()
                    data[channel * plane + destination] =
                        (value - ModelContract.DETECTOR_MEAN[channel]) /
                        ModelContract.DETECTOR_STD[channel]
                }
            }
        }
        detectorBuffer.position(0)

        val shape = longArrayOf(1, 3, size.toLong(), size.toLong())
        OnnxTensor.createTensor(environment, detectorBuffer, shape).use { tensor ->
            detector.run(mapOf(ModelContract.DETECTOR_INPUT to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                val dets = (result.get(0).value as Array<Array<FloatArray>>)[0]
                @Suppress("UNCHECKED_CAST")
                val labels = (result.get(1).value as Array<LongArray>)[0]

                val boxes = ArrayList<Box>(dets.size)
                for (i in dets.indices) {
                    val score = dets[i][4]
                    if (score < ModelContract.SCORE_THRESHOLD) continue
                    boxes.add(
                        Box(
                            classId = labels[i].toInt(),
                            left = (dets[i][0] - padX) / scale,
                            top = (dets[i][1] - padY) / scale,
                            right = (dets[i][2] - padX) / scale,
                            bottom = (dets[i][3] - padY) / scale,
                            score = score,
                        ),
                    )
                }
                return boxes
            }
        }
    }

    /**
     * Top-down pose for one person box.
     *
     * The box is expanded to the model's aspect ratio before the crop, which
     * is what the training-time pipeline does; cropping the box as given would
     * squash the subject and move every landmark.
     */
    fun estimatePose(rgb: ByteArray, width: Int, height: Int, box: Box): Landmarks {
        val aspect = ModelContract.POSE_WIDTH.toFloat() / ModelContract.POSE_HEIGHT
        var cropWidth = box.width * ModelContract.POSE_PADDING_FACTOR
        var cropHeight = box.height * ModelContract.POSE_PADDING_FACTOR
        if (cropWidth / cropHeight > aspect) {
            cropHeight = cropWidth / aspect
        } else {
            cropWidth = cropHeight * aspect
        }

        val originX = box.centreX - cropWidth / 2
        val originY = box.centreY - cropHeight / 2
        val stepX = cropWidth / ModelContract.POSE_WIDTH
        val stepY = cropHeight / ModelContract.POSE_HEIGHT

        poseBuffer.clear()
        val data = poseBuffer.array()
        val plane = ModelContract.POSE_HEIGHT * ModelContract.POSE_WIDTH

        for (y in 0 until ModelContract.POSE_HEIGHT) {
            val sourceY = (originY + y * stepY).toInt().coerceIn(0, height - 1)
            for (x in 0 until ModelContract.POSE_WIDTH) {
                val sourceX = (originX + x * stepX).toInt().coerceIn(0, width - 1)
                val source = (sourceY * width + sourceX) * 3
                val destination = y * ModelContract.POSE_WIDTH + x
                for (channel in 0 until 3) {
                    val value = (rgb[source + channel].toInt() and 0xFF).toFloat()
                    data[channel * plane + destination] =
                        (value - ModelContract.POSE_MEAN[channel]) /
                        ModelContract.POSE_STD[channel]
                }
            }
        }
        poseBuffer.position(0)

        val shape = longArrayOf(
            1,
            3,
            ModelContract.POSE_HEIGHT.toLong(),
            ModelContract.POSE_WIDTH.toLong(),
        )
        OnnxTensor.createTensor(environment, poseBuffer, shape).use { tensor ->
            pose.run(mapOf(ModelContract.POSE_INPUT to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                val simccX = (result.get("simcc_x").get().value as Array<Array<FloatArray>>)[0]
                @Suppress("UNCHECKED_CAST")
                val simccY = (result.get("simcc_y").get().value as Array<Array<FloatArray>>)[0]

                val xs = FloatArray(ModelContract.KEYPOINT_COUNT)
                val ys = FloatArray(ModelContract.KEYPOINT_COUNT)
                val scores = FloatArray(ModelContract.KEYPOINT_COUNT)

                // RTMPose predicts an independent distribution per axis, so
                // each is an argmax and the landmark score is the product of
                // the two peaks.
                for (k in 0 until ModelContract.KEYPOINT_COUNT) {
                    val (indexX, peakX) = argmax(simccX[k])
                    val (indexY, peakY) = argmax(simccY[k])

                    val localX = indexX / ModelContract.SIMCC_SPLIT_RATIO
                    val localY = indexY / ModelContract.SIMCC_SPLIT_RATIO

                    xs[k] = originX + localX * stepX
                    ys[k] = originY + localY * stepY
                    scores[k] = max(0f, min(1f, peakX * peakY))
                }
                return Landmarks(xs, ys, scores)
            }
        }
    }

    private fun argmax(values: FloatArray): Pair<Int, Float> {
        var bestIndex = 0
        var best = values[0]
        for (i in 1 until values.size) {
            if (values[i] > best) {
                best = values[i]
                bestIndex = i
            }
        }
        return bestIndex to best
    }

    override fun close() {
        detector.close()
        pose.close()
    }
}
