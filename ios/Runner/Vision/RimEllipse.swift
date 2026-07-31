import Foundation

/// Turns the detector's rim box into the ellipse the calibration needs.
///
/// The pose solve wants the ring's outline, and a box only bounds it. A
/// detection box around a circle seen in perspective is a tight fit to the
/// ellipse's extremes, so the ellipse inscribed in the box recovers the centre
/// and both axes; what it cannot recover is rotation, which the box has already
/// thrown away.
///
/// That is good enough for a rim viewed from a phone on a tripod, where the
/// major axis is within a few degrees of horizontal. A rolled camera breaks the
/// assumption, so the roll measured from gravity is passed in and used as the
/// ellipse orientation rather than assuming zero.
enum RimEllipse {
    /// Returns centre x, centre y, semi-major, semi-minor, rotation, or nil
    /// when the box is too small or too square to be a ring in perspective.
    static func fromBox(_ box: Box, cameraRoll: Double) -> [Double]? {
        let halfWidth = Double(box.width) / 2
        let halfHeight = Double(box.height) / 2
        if halfWidth < 8 || halfHeight < 2 { return nil }

        // A ring is always at least a little foreshortened. A box as tall as it
        // is wide is a detection of something else, or of a rim seen from
        // directly above, which no phone placement produces.
        if halfHeight > halfWidth { return nil }

        // The box bounds the rotated ellipse, so with a known rotation the
        // semi-axes come back out of the bounding relation:
        //   halfWidth^2  = a^2 cos^2 t + b^2 sin^2 t
        //   halfHeight^2 = a^2 sin^2 t + b^2 cos^2 t
        let c2 = cos(cameraRoll) * cos(cameraRoll)
        let s2 = sin(cameraRoll) * sin(cameraRoll)
        let determinant = c2 * c2 - s2 * s2
        if abs(determinant) < 1e-6 { return nil }

        let w2 = halfWidth * halfWidth
        let h2 = halfHeight * halfHeight
        let aSquared = (w2 * c2 - h2 * s2) / determinant
        let bSquared = (h2 * c2 - w2 * s2) / determinant
        if aSquared <= 0 || bSquared <= 0 { return nil }

        let a = sqrt(aSquared)
        let b = sqrt(bSquared)

        return [
            Double(box.centreX),
            Double(box.centreY),
            max(a, b),
            min(a, b),
            a >= b ? cameraRoll : cameraRoll + .pi / 2,
        ]
    }

    /// Camera roll about the optical axis, from the accelerometer.
    static func roll(fromGravity gravity: [Double]?) -> Double {
        guard let gravity, gravity.count >= 2 else { return 0 }
        // Image y runs down, so a level phone reads gravity along +y.
        return atan2(gravity[0], gravity[1])
    }
}
