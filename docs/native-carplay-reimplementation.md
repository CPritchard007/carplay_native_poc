# Native CarPlay Reimplementation Guide

This guide documents the changes in this repository that enabled native iOS CarPlay support from a Flutter app, and how to reimplement the same setup in a fresh project.

## Scope

This workspace does not contain Git history, so this document is derived from the current source tree rather than commit-by-commit diffs. The implementation is centered in:

- [ios/Runner/AppDelegate.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/AppDelegate.swift)
- [ios/Runner/SceneDelegate.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/SceneDelegate.swift)
- [ios/Runner/CarPlayManager.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/CarPlayManager.swift)
- [ios/Runner/Info.plist](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Info.plist)
- [ios/Runner/Runner.entitlements](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Runner.entitlements)
- [lib/service/carplay_service.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/service/carplay_service.dart)
- [lib/main.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/main.dart)

## High-Level Architecture

The project does not render CarPlay UI in Flutter. Instead, Flutter sends a serialized payload over a `MethodChannel`, and native Swift converts that payload into real CarPlay templates:

1. Flutter builds a `CarPlayListTemplatePayload`.
2. Flutter calls `MethodChannel.invokeMethod('setRootTemplate', payload)`.
3. `CarPlayManager` receives the message in Swift.
4. `CarPlayManager` converts the payload into `CPListTemplate`, `CPListSection`, and `CPListItem`.
5. When a CarPlay head unit connects, the native layer pushes the template into `CPInterfaceController`.

This split is the key design choice. Flutter remains the source of data, while native iOS owns the actual CarPlay UI objects.

## Effective Changes From a Stock Flutter iOS App

### 1. Add CarPlay scene routing in `AppDelegate`

[ios/Runner/AppDelegate.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/AppDelegate.swift) now:

- Imports `CarPlay`
- Keeps the normal `FlutterAppDelegate` startup path
- Overrides `application(_:configurationForConnecting:options:)`
- Returns the `CarPlay` scene configuration when the incoming scene role is `.carTemplateApplication`
- Returns the normal `flutter` scene configuration for the main phone UI

Without this, iOS will not route the CarPlay connection to a dedicated CarPlay scene delegate.

### 2. Register both phone and CarPlay scenes in `Info.plist`

[ios/Runner/Info.plist](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Info.plist) contains a `UIApplicationSceneManifest` with two scene entries:

- `UIWindowSceneSessionRoleApplication`
  - Uses `SceneDelegate`
  - Represents the normal handset Flutter scene
- `CPTemplateApplicationSceneSessionRoleApplication`
  - Uses `CPTemplateApplicationScene`
  - Uses `CarPlaySceneDelegate`
  - Represents the CarPlay UI scene

This is the native iOS registration step that tells the app it supports a CarPlay template scene.

### 3. Add the CarPlay entitlement

[ios/Runner/Runner.entitlements](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Runner.entitlements) enables:

```xml
<key>com.apple.developer.carplay-driving-task</key>
<true/>
```

The Xcode project also points the Runner target at this entitlements file through `CODE_SIGN_ENTITLEMENTS` in [ios/Runner.xcodeproj/project.pbxproj](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner.xcodeproj/project.pbxproj).

Important: the local entitlements file is not sufficient by itself. The Apple Developer App ID and provisioning profile must also include the matching CarPlay capability, otherwise device signing will fail or the entitlement will not be honored.

### 4. Add a native CarPlay bridge manager

[ios/Runner/CarPlayManager.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/CarPlayManager.swift) is the main implementation file. It does four jobs:

- Holds the current `CPInterfaceController`
- Owns the `FlutterMethodChannel`
- Converts Flutter maps into CarPlay template objects
- Queues a root template if Flutter sends data before CarPlay connects

The queueing behavior matters. CarPlay and Flutter can come up in either order, so the implementation stores `queuedRootTemplate` and pushes it later once `didConnect` fires.

### 5. Add a CarPlay scene delegate

The same Swift file defines `CarPlaySceneDelegate`, which conforms to `CPTemplateApplicationSceneDelegate`.

It listens for:

- `didConnect interfaceController`
- `didDisconnect interfaceController`

On connect, it passes the controller to `CarPlayManager.shared.connect(...)`. On disconnect, it clears the native reference.

### 6. Register the Flutter method channel from the phone scene

[ios/Runner/SceneDelegate.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/SceneDelegate.swift) extends `FlutterSceneDelegate` and, once the main Flutter view controller exists, registers the CarPlay method channel with the controller’s `binaryMessenger`.

This is the bridge point between the Flutter runtime and the native CarPlay manager.

### 7. Add a Dart payload layer

[lib/service/carplay_service.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/service/carplay_service.dart) defines:

- `CarPlayListItem`
- `CarPlaySection`
- `CarPlayListTemplatePayload`
- `CarPlayService`

These classes serialize Dart data into `Map<String, Object?>` so Swift can reconstruct native `CPListTemplate` objects.

### 8. Add a Flutter demo screen

[lib/main.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/main.dart) provides a minimal UI that:

- Describes the bridge
- Sends demo list data
- Shows success or error state with a `SnackBar`

This file is not required for CarPlay itself, but it is useful for validating the bridge end-to-end.

## Step-By-Step Reimplementation

Use this sequence when recreating the setup in a new Flutter iOS app.

### Step 1. Start from a Flutter app with iOS scene support

Create a normal Flutter app:

```bash
flutter create my_app
```

If your iOS runner still uses the older single-scene setup, migrate it to the scene-based structure used by recent Flutter iOS templates before adding CarPlay. This repo already uses:

- `AppDelegate.swift`
- `SceneDelegate.swift`
- `UIApplicationSceneManifest`

### Step 2. Add the CarPlay entitlement

Create an entitlements file like [ios/Runner/Runner.entitlements](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Runner.entitlements):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.carplay-driving-task</key>
  <true/>
</dict>
</plist>
```

Then make sure the Runner target uses it via `CODE_SIGN_ENTITLEMENTS`.

Also enable the same CarPlay capability in:

- Apple Developer portal
- Your App ID
- Your provisioning profile
- Xcode Signing & Capabilities

If that Apple-side capability is missing, the code can compile but the app will not be correctly entitled for real device use.

### Step 3. Register a CarPlay scene in `Info.plist`

Add a CarPlay scene configuration under `UIApplicationSceneManifest`:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
  <key>UIApplicationSupportsMultipleScenes</key>
  <true/>
  <key>UISceneConfigurations</key>
  <dict>
    <key>CPTemplateApplicationSceneSessionRoleApplication</key>
    <array>
      <dict>
        <key>UISceneClassName</key>
        <string>CPTemplateApplicationScene</string>
        <key>UISceneConfigurationName</key>
        <string>CarPlay</string>
        <key>UISceneDelegateClassName</key>
        <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
      </dict>
    </array>
    <key>UIWindowSceneSessionRoleApplication</key>
    <array>
      <dict>
        <key>UISceneClassName</key>
        <string>UIWindowScene</string>
        <key>UISceneConfigurationName</key>
        <string>flutter</string>
        <key>UISceneDelegateClassName</key>
        <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
        <key>UISceneStoryboardFile</key>
        <string>Main</string>
      </dict>
    </array>
  </dict>
</dict>
```

Two details matter:

- The CarPlay configuration name is `CarPlay`
- The delegate class name matches your Swift symbol exactly

### Step 4. Route CarPlay scene connections in `AppDelegate`

Update your app delegate to return the correct scene configuration:

```swift
import CarPlay
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
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
```

This is the native switch that separates phone UI and CarPlay UI.

### Step 5. Create a native `CarPlayManager`

Create a Swift file modeled on [ios/Runner/CarPlayManager.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/CarPlayManager.swift).

Minimum responsibilities:

- Singleton instance
- `FlutterMethodChannel` setup
- `connect(interfaceController:)`
- `disconnect()`
- Translate method-channel payloads into `CPListTemplate`
- Cache a template until CarPlay is connected

The queueing pattern from this repo is worth preserving:

```swift
private var currentRootTemplate: CPListTemplate?
private var queuedRootTemplate: CPListTemplate?
```

That avoids a race where Flutter sends a template before the CarPlay scene exists.

### Step 6. Implement `CarPlaySceneDelegate`

Add a CarPlay scene delegate that forwards CarPlay lifecycle events into your manager:

```swift
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    CarPlayManager.shared.connect(interfaceController: interfaceController)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    CarPlayManager.shared.disconnect()
  }
}
```

This repo also implements the newer overloads that include `CPWindow`, which is a reasonable compatibility choice.

### Step 7. Register the method channel from `SceneDelegate`

Update the normal Flutter scene delegate so the native manager gets a messenger:

```swift
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    CarPlayManager.shared.registerMethodChannel(binaryMessenger: controller.binaryMessenger)
  }
}
```

If this registration never happens, Flutter can launch but your CarPlay bridge will never receive messages.

### Step 8. Add a Dart service wrapper

Mirror [lib/service/carplay_service.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/service/carplay_service.dart):

```dart
import 'package:flutter/services.dart';

class CarPlayService {
  static const MethodChannel _channel = MethodChannel(
    'com.cpritchard007.carplay_native_poc/data',
  );

  static Future<void> setRootTemplate(Map<String, Object?> payload) async {
    await _channel.invokeMethod<void>('setRootTemplate', payload);
  }
}
```

In this repo, the wrapper is a little stronger because it uses typed payload models instead of raw maps. That is the better version to copy.

### Step 9. Send a first template from Flutter

From Flutter, send a simple list payload once the app is running:

```dart
await CarPlayService.setRootTemplate(
  const CarPlayListTemplatePayload(
    title: 'Trips',
    sections: <CarPlaySection>[
      CarPlaySection(
        header: 'Upcoming',
        items: <CarPlayListItem>[
          CarPlayListItem(title: 'Office', subtitle: 'ETA 18 min'),
        ],
      ),
    ],
  ),
);
```

On the Swift side, map that payload into:

- `CPListTemplate`
- `CPListSection`
- `CPListItem`

### Step 10. Add a placeholder template for empty state

This repo shows a placeholder template while waiting for Flutter data. That behavior lives in `makeWaitingTemplate()` inside [ios/Runner/CarPlayManager.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/CarPlayManager.swift).

This is a good operational default because it proves the CarPlay scene is alive even if your Dart side has not sent data yet.

## Why This Implementation Works

The implementation works because it solves the three integration boundaries that usually block Flutter plus CarPlay work:

### Native scene boundary

CarPlay is not just another Flutter route. iOS expects a dedicated CarPlay scene and a CarPlay-specific delegate.

### UI ownership boundary

CarPlay screens are native `CPTemplate` objects, not arbitrary UIKit or Flutter views. The code respects that and only uses Flutter as the data producer.

### Launch-order boundary

The CarPlay interface controller and the Flutter runtime do not become available in a guaranteed order. The template queue inside `CarPlayManager` removes that race.

## Common Failure Modes

If you recreate this setup and it does not work, check these first:

1. `Info.plist` scene configuration names do not match the names returned by `AppDelegate`.
2. `CarPlaySceneDelegate` is misnamed or not in the target.
3. The entitlements file exists but is not connected through `CODE_SIGN_ENTITLEMENTS`.
4. The Apple Developer capability is missing from the App ID or provisioning profile.
5. `SceneDelegate` never registers the `FlutterMethodChannel`.
6. Flutter and Swift disagree on the channel name or method name.
7. Swift receives a payload shape that does not match `makeListTemplate(arguments:)`.

## Suggested Next Improvements

The current implementation is intentionally minimal. If you continue from here, the next useful upgrades are:

1. Add item selection callbacks from native CarPlay back into Flutter.
2. Support more template types such as grid, tab bar, or information templates.
3. Introduce stable identifiers for list items instead of only text fields.
4. Add integration tests around payload serialization and Swift parsing.
5. Replace the demo UI with application state from your real domain model.

## Summary

The native CarPlay support in this repo depends on a focused set of changes:

1. Add CarPlay entitlement and signing support.
2. Declare a CarPlay scene in `Info.plist`.
3. Route `.carTemplateApplication` scenes in `AppDelegate`.
4. Add a native `CarPlayManager` plus `CarPlaySceneDelegate`.
5. Register a `MethodChannel` from the Flutter scene.
6. Serialize template payloads in Dart and build `CPTemplate` objects in Swift.

That is the minimum structure to reproduce this proof of concept in another Flutter app.
