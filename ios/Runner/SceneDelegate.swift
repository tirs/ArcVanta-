import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var capture: CaptureBridge?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let windowScene = scene as? UIWindowScene,
          let controller = windowScene.windows.first?.rootViewController as? FlutterViewController else {
      return
    }

    let engine = controller.engine!
    capture = CaptureBridge(
      messenger: engine.binaryMessenger,
      textures: engine.registrar(forPlugin: "ArcVantaVision")!.textures()
    )
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    capture?.dispose()
    capture = nil
    super.sceneDidDisconnect(scene)
  }
}
