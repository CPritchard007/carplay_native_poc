import 'package:carplay_native_poc/main.dart';
import 'package:carplay_native_poc/telemetry/telemetry_controller.dart';
import 'package:carplay_native_poc/telemetry/telemetry_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders idle telemetry screen', (WidgetTester tester) async {
    final FakeTelemetryController controller = FakeTelemetryController(
      const TelemetrySnapshot.initial(),
    );

    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('Background Telemetry'), findsOneWidget);
    expect(find.text('Start Background Mode'), findsOneWidget);
    expect(find.text('Stop Background Mode'), findsOneWidget);
    expect(find.text('Status: Idle'), findsOneWidget);
  });

  testWidgets('renders running telemetry screen', (WidgetTester tester) async {
    final FakeTelemetryController controller = FakeTelemetryController(
      const TelemetrySnapshot(
        isTracking: true,
        status: TelemetryStatus.running,
      ),
    );

    await tester.pumpWidget(MyApp(controller: controller));

    final FilledButton startButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    final OutlinedButton stopButton = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );

    expect(startButton.onPressed, isNull);
    expect(stopButton.onPressed, isNotNull);
    expect(find.text('Status: Running'), findsOneWidget);
  });

  testWidgets('renders populated telemetry cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FakeTelemetryController controller = FakeTelemetryController(
      const TelemetrySnapshot(
        isTracking: true,
        latitude: 43.653226,
        longitude: -79.383184,
        headingDegrees: 182.4,
        altitudeMeters: 112.8,
        directionLabel: 'S',
        status: TelemetryStatus.running,
        updatedAtIso8601: '2026-06-16T14:25:30.000Z',
      ),
    );

    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('43.653226'), findsOneWidget);
    expect(find.text('-79.383184'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(find.text('112.8 m'), findsOneWidget);
  });
}

class FakeTelemetryController extends ChangeNotifier
    implements TelemetryControlling {
  FakeTelemetryController(this._snapshot);

  TelemetrySnapshot _snapshot;

  @override
  TelemetrySnapshot get snapshot => _snapshot;

  @override
  Future<void> startTracking() async {
    _snapshot = _snapshot.copyWith(
      isTracking: true,
      status: TelemetryStatus.running,
    );
    notifyListeners();
  }

  @override
  Future<void> stopTracking() async {
    _snapshot = _snapshot.copyWith(
      isTracking: false,
      status: TelemetryStatus.idle,
    );
    notifyListeners();
  }
}
