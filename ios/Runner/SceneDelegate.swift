import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }

    let flutterViewController = FlutterViewController(
      engine: appDelegate.sharedFlutterEngine,
      nibName: nil,
      bundle: nil
    )
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    self.window = window
    window.makeKeyAndVisible()
  }
}
