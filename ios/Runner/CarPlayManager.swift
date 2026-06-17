import CarPlay
import Flutter
import Foundation

private struct TelemetrySnapshot {
  let isTracking: Bool
  let latitude: Double?
  let longitude: Double?
  let headingDegrees: Double?
  let altitudeMeters: Double?
  let directionLabel: String?
  let status: String
  let updatedAtIso8601: String?
  let errorMessage: String?

  init?(_ arguments: [String: Any]) {
    guard let isTracking = arguments["isTracking"] as? Bool,
          let status = arguments["status"] as? String else {
      return nil
    }

    self.isTracking = isTracking
    latitude = arguments["latitude"] as? Double
    longitude = arguments["longitude"] as? Double
    headingDegrees = arguments["headingDegrees"] as? Double
    altitudeMeters = arguments["altitudeMeters"] as? Double
    directionLabel = arguments["directionLabel"] as? String
    self.status = status
    updatedAtIso8601 = arguments["updatedAtIso8601"] as? String
    errorMessage = arguments["errorMessage"] as? String
  }
}

final class CarPlayManager: NSObject {
  static let shared = CarPlayManager()

  private let channelName = "com.cpritchard007.carplay_native_poc/data"
  private var interfaceController: CPInterfaceController?
  private var methodChannel: FlutterMethodChannel?
  private var currentRootTemplate: CPTemplate?
  private var latestSnapshot: TelemetrySnapshot?

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
    renderWaitingTemplate()
    requestTelemetrySnapshot()
  }

  func disconnect() {
    interfaceController = nil
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateTelemetrySnapshot":
      guard let arguments = call.arguments as? [String: Any],
            let snapshot = TelemetrySnapshot(arguments) else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a telemetry snapshot map.",
            details: call.arguments
          )
        )
        return
      }

      latestSnapshot = snapshot
      render(snapshot: snapshot, animated: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestTelemetrySnapshot() {
    invokeFlutter(method: "getTelemetrySnapshot")
  }

  private func requestStartTracking() {
    invokeFlutter(method: "startTracking")
  }

  private func requestStopTracking() {
    invokeFlutter(method: "stopTracking")
  }

  private func invokeFlutter(method: String) {
    methodChannel?.invokeMethod(method, arguments: nil) { [weak self] result in
      guard let self else {
        return
      }

      if let error = result as? FlutterError {
        self.renderErrorTemplate(message: error.message ?? error.code)
        return
      }

      guard let arguments = result as? [String: Any],
            let snapshot = TelemetrySnapshot(arguments) else {
        return
      }

      self.latestSnapshot = snapshot
      self.render(snapshot: snapshot, animated: true)
    }
  }

  private func render(snapshot: TelemetrySnapshot, animated: Bool) {
    latestSnapshot = snapshot
    let template = makeInformationTemplate(snapshot: snapshot)
    currentRootTemplate = template
    interfaceController?.setRootTemplate(template, animated: animated)
  }

  private func renderWaitingTemplate() {
    let waitingItems = [
      CPInformationItem(title: "Status", detail: "Waiting for telemetry"),
      CPInformationItem(title: "Updated", detail: "Not yet available"),
    ]
    let template = CPInformationTemplate(
      title: "Telemetry",
      layout: .twoColumn,
      items: waitingItems,
      actions: [
        CPTextButton(
          title: "Start",
          textStyle: .confirm,
          handler: { [weak self] _ in
            self?.requestStartTracking()
          }
        ),
      ]
    )
    currentRootTemplate = template
    interfaceController?.setRootTemplate(template, animated: false)
  }

  private func renderErrorTemplate(message: String) {
    let items = [
      CPInformationItem(title: "Status", detail: "Error"),
      CPInformationItem(title: "Message", detail: message),
    ]
    let template = CPInformationTemplate(
      title: "Telemetry",
      layout: .twoColumn,
      items: items,
      actions: [
        CPTextButton(
          title: "Retry",
          textStyle: .normal,
          handler: { [weak self] _ in
            self?.requestTelemetrySnapshot()
          }
        ),
      ]
    )
    currentRootTemplate = template
    interfaceController?.setRootTemplate(template, animated: true)
  }

  private func makeInformationTemplate(snapshot: TelemetrySnapshot) -> CPInformationTemplate {
    let items = [
      CPInformationItem(title: "Status", detail: formattedStatus(snapshot.status)),
      CPInformationItem(title: "Latitude", detail: formatCoordinate(snapshot.latitude)),
      CPInformationItem(title: "Longitude", detail: formatCoordinate(snapshot.longitude)),
      CPInformationItem(title: "Rotation", detail: formatRotation(snapshot)),
      CPInformationItem(title: "Elevation", detail: formatElevation(snapshot.altitudeMeters)),
      CPInformationItem(title: "Updated", detail: formatUpdated(snapshot.updatedAtIso8601)),
      CPInformationItem(title: "Message", detail: snapshot.errorMessage ?? "Ready"),
    ]

    let actions: [CPTextButton]
    if snapshot.isTracking {
      actions = [
        CPTextButton(
          title: "Stop",
          textStyle: .cancel,
          handler: { [weak self] _ in
            self?.requestStopTracking()
          }
        ),
      ]
    } else {
      actions = [
        CPTextButton(
          title: "Start",
          textStyle: .confirm,
          handler: { [weak self] _ in
            self?.requestStartTracking()
          }
        ),
      ]
    }

    return CPInformationTemplate(
      title: "Telemetry",
      layout: .twoColumn,
      items: items,
      actions: actions
    )
  }

  private func formatCoordinate(_ value: Double?) -> String {
    guard let value else {
      return "Unavailable"
    }

    return String(format: "%.6f", value)
  }

  private func formatRotation(_ snapshot: TelemetrySnapshot) -> String {
    guard let headingDegrees = snapshot.headingDegrees else {
      return "Unavailable"
    }

    let headingText = String(format: "%.1f°", headingDegrees)
    if let directionLabel = snapshot.directionLabel {
      return "\(headingText) \(directionLabel)"
    }

    return headingText
  }

  private func formatElevation(_ value: Double?) -> String {
    guard let value else {
      return "Unavailable"
    }

    return String(format: "%.1f m", value)
  }

  private func formatUpdated(_ updatedAtIso8601: String?) -> String {
    guard let updatedAtIso8601 else {
      return "Never"
    }

    return updatedAtIso8601
  }

  private func formattedStatus(_ status: String) -> String {
    switch status {
    case "idle":
      return "Idle"
    case "starting":
      return "Starting"
    case "running":
      return "Running"
    case "stopping":
      return "Stopping"
    case "permissionDenied":
      return "Permission Denied"
    case "serviceDisabled":
      return "Service Disabled"
    default:
      return "Error"
    }
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
