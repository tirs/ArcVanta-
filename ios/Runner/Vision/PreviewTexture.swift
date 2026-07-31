import CoreVideo
import Flutter
import Foundation

/// Publishes camera frames to Flutter as a platform texture.
///
/// The same `CVPixelBuffer` the analysis reads is handed to the compositor, so
/// the preview is the exact frame that produced the measurement rather than a
/// second stream that might be a frame or two out of step with it.
///
/// Flutter pulls buffers on its own raster thread while the capture queue is
/// pushing new ones, so the handoff is guarded. The lock is held only for the
/// pointer swap, never across a copy.
final class PreviewTexture: NSObject, FlutterTexture {
    private let lock = NSLock()
    private var latest: CVPixelBuffer?

    /// Assigned once the texture is registered, so the bridge can tell Dart
    /// which id to mount and can unregister on teardown.
    private(set) var identifier: Int64 = 0

    private weak var registry: FlutterTextureRegistry?

    func register(with registry: FlutterTextureRegistry) {
        self.registry = registry
        identifier = registry.register(self)
    }

    func unregister() {
        registry?.unregisterTexture(identifier)
        registry = nil
        lock.lock()
        latest = nil
        lock.unlock()
    }

    func push(_ buffer: CVPixelBuffer) {
        lock.lock()
        latest = buffer
        lock.unlock()
        registry?.textureFrameAvailable(identifier)
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = latest else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}
