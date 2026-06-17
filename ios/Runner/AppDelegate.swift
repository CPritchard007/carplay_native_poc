import CarPlay
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  let sharedFlutterEngine = FlutterEngine(name: "shared_carplay_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    sharedFlutterEngine.run()
    GeneratedPluginRegistrant.register(with: sharedFlutterEngine)
    CarPlayManager.shared.registerMethodChannel(
      binaryMessenger: sharedFlutterEngine.binaryMessenger
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configurationName =
      connectingSceneSession.role == .carTemplateApplication ? "CarPlay" : "flutter"

    return UISceneConfiguration(
      name: configurationName,
      sessionRole: connectingSceneSession.role
    )
  }
}
