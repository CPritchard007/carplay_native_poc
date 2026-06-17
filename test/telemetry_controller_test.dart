import 'dart:async';

import 'package:carplay_native_poc/service/carplay_service.dart';
import 'package:carplay_native_poc/telemetry/telemetry_controller.dart';
import 'package:carplay_native_poc/telemetry/telemetry_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('directionLabelForHeading', () {
    test('maps boundary headings to 8-way cardinal directions', () {
      expect(directionLabelForHeading(0), 'N');
      expect(directionLabelForHeading(22.5), 'NE');
      expect(directionLabelForHeading(90), 'E');
      expect(directionLabelForHeading(135), 'SE');
      expect(directionLabelForHeading(180), 'S');
      expect(directionLabelForHeading(225), 'SW');
      expect(directionLabelForHeading(270), 'W');
      expect(directionLabelForHeading(315), 'NW');
      expect(directionLabelForHeading(359.9), 'N');
    });
  });

  group('TelemetryController', () {
    test('starts tracking when permissions and services allow it', () async {
      final FakeTelemetryLocationService locationService =
          FakeTelemetryLocationService(
            isServiceEnabledValue: true,
            permission: TelemetryPermission.always,
          );
      final FakeTelemetryHeadingService headingService =
          FakeTelemetryHeadingService();
      final FakeTelemetrySpeechService speechService =
          FakeTelemetrySpeechService();
      final FakeCarPlayService bridge = FakeCarPlayService();

      final TelemetryController controller = TelemetryController(
        locationService: locationService,
        headingService: headingService,
        speechService: speechService,
        bridge: bridge,
        repeatingTaskFactory: fakeRepeatingTaskFactory,
        now: () => DateTime.utc(2026, 6, 16, 14, 25, 30),
      );

      await controller.initialize();
      await controller.startTracking();

      expect(controller.snapshot.isTracking, isTrue);
      expect(controller.snapshot.status, TelemetryStatus.running);
      expect(bridge.publishedSnapshots.last.isTracking, isTrue);
    });

    test(
      'enters permission denied when always permission is unavailable',
      () async {
        final TelemetryController controller = TelemetryController(
          locationService: FakeTelemetryLocationService(
            isServiceEnabledValue: true,
            permission: TelemetryPermission.denied,
            requestPermissionResult: TelemetryPermission.whileInUse,
          ),
          headingService: FakeTelemetryHeadingService(),
          speechService: FakeTelemetrySpeechService(),
          bridge: FakeCarPlayService(),
          repeatingTaskFactory: fakeRepeatingTaskFactory,
        );

        await controller.initialize();
        await controller.startTracking();

        expect(controller.snapshot.isTracking, isFalse);
        expect(controller.snapshot.status, TelemetryStatus.permissionDenied);
      },
    );

    test(
      'enters service disabled when location services are unavailable',
      () async {
        final TelemetryController controller = TelemetryController(
          locationService: FakeTelemetryLocationService(
            isServiceEnabledValue: false,
            permission: TelemetryPermission.always,
          ),
          headingService: FakeTelemetryHeadingService(),
          speechService: FakeTelemetrySpeechService(),
          bridge: FakeCarPlayService(),
          repeatingTaskFactory: fakeRepeatingTaskFactory,
        );

        await controller.initialize();
        await controller.startTracking();

        expect(controller.snapshot.isTracking, isFalse);
        expect(controller.snapshot.status, TelemetryStatus.serviceDisabled);
      },
    );

    test('stops tracking and speech cleanly', () async {
      final FakeTelemetrySpeechService speechService =
          FakeTelemetrySpeechService();
      final TelemetryController controller = TelemetryController(
        locationService: FakeTelemetryLocationService(
          isServiceEnabledValue: true,
          permission: TelemetryPermission.always,
        ),
        headingService: FakeTelemetryHeadingService(),
        speechService: speechService,
        bridge: FakeCarPlayService(),
        repeatingTaskFactory: fakeRepeatingTaskFactory,
      );

      await controller.initialize();
      await controller.startTracking();
      await controller.stopTracking();

      expect(controller.snapshot.isTracking, isFalse);
      expect(controller.snapshot.status, TelemetryStatus.idle);
      expect(speechService.stopCalls, 1);
    });

    test(
      'speaks every 15 seconds while tracking and skips missing direction',
      () async {
        final FakeTelemetryLocationService locationService =
            FakeTelemetryLocationService(
              isServiceEnabledValue: true,
              permission: TelemetryPermission.always,
            );
        final FakeTelemetryHeadingService headingService =
            FakeTelemetryHeadingService();
        final FakeTelemetrySpeechService speechService =
            FakeTelemetrySpeechService();
        final FakeRepeatingTask task = FakeRepeatingTask();

        final TelemetryController controller = TelemetryController(
          locationService: locationService,
          headingService: headingService,
          speechService: speechService,
          bridge: FakeCarPlayService(),
          repeatingTaskFactory: (_, void Function() callback) {
            task.callback = callback;
            return task;
          },
        );

        await controller.initialize();
        await controller.startTracking();

        task.fire();
        expect(speechService.spokenDirections, isEmpty);

        headingService.addHeading(91.0);
        await pumpEventQueue();
        task.fire();
        expect(speechService.spokenDirections, <String>['E']);

        await controller.stopTracking();
        task.fire();
        expect(speechService.spokenDirections, <String>['E']);
        expect(task.cancelled, isTrue);
      },
    );
  });
}

TelemetryRepeatingTask fakeRepeatingTaskFactory(
  Duration interval,
  void Function() callback,
) {
  return FakeRepeatingTask()..callback = callback;
}

class FakeTelemetryLocationService implements TelemetryLocationService {
  FakeTelemetryLocationService({
    required this.isServiceEnabledValue,
    required this.permission,
    TelemetryPermission? requestPermissionResult,
  }) : _requestPermissionResult = requestPermissionResult ?? permission;

  final bool isServiceEnabledValue;
  final TelemetryPermission permission;
  final TelemetryPermission _requestPermissionResult;
  final StreamController<TelemetryPosition> _positionController =
      StreamController<TelemetryPosition>.broadcast();
  final StreamController<bool> _serviceController =
      StreamController<bool>.broadcast();

  @override
  Future<TelemetryPermission> checkPermission() async => permission;

  @override
  Stream<TelemetryPosition> getPositionStream() => _positionController.stream;

  @override
  Stream<bool> getServiceEnabledStream() => _serviceController.stream;

  @override
  Future<bool> isServiceEnabled() async => isServiceEnabledValue;

  @override
  Future<TelemetryPermission> requestPermission() async {
    return _requestPermissionResult;
  }
}

class FakeTelemetryHeadingService implements TelemetryHeadingService {
  final StreamController<double?> _headingController =
      StreamController<double?>.broadcast();

  @override
  Stream<double?> getHeadingStream() => _headingController.stream;

  void addHeading(double heading) {
    _headingController.add(heading);
  }
}

class FakeTelemetrySpeechService implements TelemetrySpeechService {
  int stopCalls = 0;
  final List<String> spokenDirections = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speakDirection(String directionLabel) async {
    spokenDirections.add(directionLabel);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class FakeRepeatingTask implements TelemetryRepeatingTask {
  void Function()? callback;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
  }

  void fire() {
    if (!cancelled) {
      callback?.call();
    }
  }
}

class FakeCarPlayService extends CarPlayService {
  final List<TelemetrySnapshot> publishedSnapshots = <TelemetrySnapshot>[];

  @override
  void registerMethodHandler(CarPlayMethodHandler handler) {}

  @override
  Future<void> updateTelemetrySnapshot(TelemetrySnapshot snapshot) async {
    publishedSnapshots.add(snapshot);
  }
}
