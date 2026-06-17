import 'package:flutter/services.dart';

import '../telemetry/telemetry_snapshot.dart';

typedef CarPlayMethodHandler =
    Future<Object?> Function(String method, Object? arguments);

class CarPlayService {
  const CarPlayService();

  static const MethodChannel _channel = MethodChannel(
    'com.cpritchard007.carplay_native_poc/data',
  );

  void registerMethodHandler(CarPlayMethodHandler handler) {
    _channel.setMethodCallHandler((MethodCall call) {
      return handler(call.method, call.arguments);
    });
  }

  Future<void> updateTelemetrySnapshot(TelemetrySnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>(
        'updateTelemetrySnapshot',
        snapshot.toMap(),
      );
    } on MissingPluginException {
      // The native bridge only exists on iOS for this proof of concept.
    }
  }
}
