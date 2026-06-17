import CarPlay
import Flutter
import Foundation

final class CarPlayManager: NSObject {
  static let shared = CarPlayManager()

  private let channelName = "com.cpritchard007.carplay_native_poc/data"
  private var interfaceController: CPInterfaceController?
  private var methodChannel: FlutterMethodChannel?
  private var currentRootTemplate: CPListTemplate?
  private var queuedRootTemplate: CPListTemplate?

  private override init() {
    super.init()
  }

  func registerMethodChannel(binaryMessenger: FlutterBinaryMessenger) {
    guard methodChannel == nil else {
      return
    }

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    methodChannel = channel
  }

  func connect(interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController

    if let queuedRootTemplate {
      currentRootTemplate = queuedRootTemplate
      self.interfaceController?.setRootTemplate(queuedRootTemplate, animated: true)
      self.queuedRootTemplate = nil
      return
    }

    if let currentRootTemplate {
      self.interfaceController?.setRootTemplate(currentRootTemplate, animated: false)
      return
    }

    let template = makeWaitingTemplate()
    currentRootTemplate = template
    self.interfaceController?.setRootTemplate(template, animated: false)
  }

  func disconnect() {
    interfaceController = nil
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setRootTemplate":
      guard let arguments = call.arguments as? [String: Any],
            let template = makeListTemplate(arguments: arguments) else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a map containing a title and sections.",
            details: call.arguments
          )
        )
        return
      }

      currentRootTemplate = template
      if let interfaceController {
        interfaceController.setRootTemplate(template, animated: true)
      } else {
        queuedRootTemplate = template
      }

      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func makeWaitingTemplate() -> CPListTemplate {
    let item = CPListItem(
      text: "Waiting for Flutter data",
      detailText: "Send a template over the MethodChannel to populate CarPlay."
    )
    let section = CPListSection(
      items: [item],
      header: "CarPlay",
      sectionIndexTitle: nil
    )
    return CPListTemplate(title: "CarPlay Native", sections: [section])
  }

  private func makeListTemplate(arguments: [String: Any]) -> CPListTemplate? {
    guard let title = arguments["title"] as? String,
          let sectionMaps = arguments["sections"] as? [[String: Any]] else {
      return nil
    }

    let sections = sectionMaps.compactMap(makeSection(from:))
    guard !sections.isEmpty else {
      return nil
    }

    return CPListTemplate(title: title, sections: sections)
  }

  private func makeSection(from map: [String: Any]) -> CPListSection? {
    guard let itemMaps = map["items"] as? [[String: Any]] else {
      return nil
    }

    let items = itemMaps.compactMap(makeItem(from:))
    guard !items.isEmpty else {
      return nil
    }

    let header = map["header"] as? String
    return CPListSection(
      items: items,
      header: header,
      sectionIndexTitle: nil
    )
  }

  private func makeItem(from map: [String: Any]) -> CPListItem? {
    guard let title = map["title"] as? String else {
      return nil
    }

    return CPListItem(text: title, detailText: map["subtitle"] as? String)
  }
}

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    CarPlayManager.shared.connect(interfaceController: interfaceController)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController,
    to window: CPWindow
  ) {
    CarPlayManager.shared.connect(interfaceController: interfaceController)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    CarPlayManager.shared.disconnect()
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController,
    from window: CPWindow
  ) {
    CarPlayManager.shared.disconnect()
  }
}
