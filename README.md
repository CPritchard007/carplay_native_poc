# carplay_native_poc

Flutter proof-of-concept for driving a native iOS CarPlay UI from Flutter over a `MethodChannel`.

## What Changed

The CarPlay implementation in this repo is built from a small set of native iOS additions:

- A dedicated CarPlay scene configuration in [ios/Runner/Info.plist](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/Info.plist)
- A native bridge and CarPlay scene delegate in [ios/Runner/CarPlayManager.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/CarPlayManager.swift)
- Scene selection in [ios/Runner/AppDelegate.swift](/Users/curtispritchard/Workspace/personal/carplay_native_poc/ios/Runner/AppDelegate.swift)
- Flutter-to-native payload wiring in [lib/service/carplay_service.dart](/Users/curtispritchard/Workspace/personal/carplay_native_poc/lib/service/carplay_service.dart)

## Tutorial

The full reimplementation guide is in [docs/native-carplay-reimplementation.md](/Users/curtispritchard/Workspace/personal/carplay_native_poc/docs/native-carplay-reimplementation.md).
