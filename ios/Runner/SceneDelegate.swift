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

    DispatchQueue.main.async { [weak self] in
      self?.wireCaptureBridge(scene)
    }
  }

  private func wireCaptureBridge(_ scene: UIScene) {
    guard capture == nil,
          let windowScene = scene as? UIWindowScene else { return }

    let controller: FlutterViewController?
    if #available(iOS 15.0, *) {
      controller = windowScene.keyWindow?.rootViewController as? FlutterViewController
    } else {
      controller = windowScene.windows.first?.rootViewController as? FlutterViewController
    }

    guard let flutterVC = controller else { return }

    let engine = flutterVC.engine
    let registrar = engine.registrar(forPlugin: "ArcVantaVision")
    capture = CaptureBridge(
      messenger: engine.binaryMessenger,
      textures: registrar!.textures()
    )
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    capture?.dispose()
    capture = nil
    super.sceneDidDisconnect(scene)
  }
}
