package ai.arcvanta.arcvanta.vision

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Turns the detector's rim box into the ellipse the calibration needs.
 *
 * The pose solve wants the ring's outline, and a box only bounds it. A
 * detection box around a circle seen in perspective is a tight fit to the
 * ellipse's extremes, so the ellipse inscribed in the box recovers the centre
 * and both axes; what it cannot recover is rotation, which the box has already
 * thrown away.
 *
 * That is good enough for a rim viewed from a phone on a tripod, where the
 * major axis is within a few degrees of horizontal. A rolled camera breaks the
 * assumption, so the roll measured from gravity is passed in and used as the
 * ellipse orientation rather than assuming zero.
 */
object RimEllipse {
    /**
     * Returns centre x, centre y, semi-major, semi-minor, rotation, or null
     * when the box is too small or too square to be a ring in perspective.
     */
    fun fromBox(box: Box, cameraRollRadians: Float): DoubleArray? {
        val halfWidth = box.width / 2.0
        val halfHeight = box.height / 2.0
        if (halfWidth < 8 || halfHeight < 2) return null

        // A ring is always at least a little foreshortened. A box as tall as it
        // is wide is a detection of something else, or of a rim seen from
        // directly above, which no phone placement produces.
        if (halfHeight > halfWidth) return null

        // The box bounds the rotated ellipse, so with a known rotation the
        // semi-axes come back out of the bounding relation:
        //   halfWidth^2  = a^2 cos^2 t + b^2 sin^2 t
        //   halfHeight^2 = a^2 sin^2 t + b^2 cos^2 t
        val theta = cameraRollRadians.toDouble()
        val c2 = cos(theta) * cos(theta)
        val s2 = sin(theta) * sin(theta)
        val determinant = c2 * c2 - s2 * s2
        if (abs(determinant) < 1e-6) return null

        val w2 = halfWidth * halfWidth
        val h2 = halfHeight * halfHeight
        val aSquared = (w2 * c2 - h2 * s2) / determinant
        val bSquared = (h2 * c2 - w2 * s2) / determinant
        if (aSquared <= 0 || bSquared <= 0) return null

        val a = sqrt(aSquared)
        val b = sqrt(bSquared)

        return doubleArrayOf(
            box.centreX.toDouble(),
            box.centreY.toDouble(),
            max(a, b),
            min(a, b),
            if (a >= b) theta else theta + Math.PI / 2,
        )
    }

    /** Camera roll about the optical axis, from the accelerometer. */
    fun rollFromGravity(gravity: FloatArray?): Float {
        if (gravity == null) return 0f
        // Image y runs down, so a level phone reads gravity along +y.
        return atan2(gravity[0], gravity[1])
    }
}
