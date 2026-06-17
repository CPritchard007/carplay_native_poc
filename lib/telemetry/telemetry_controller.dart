import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../service/carplay_service.dart';
import 'telemetry_snapshot.dart';

enum TelemetryPermission { denied, deniedForever, whileInUse, always }

class TelemetryPosition {
  const TelemetryPosition({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
}

abstract class TelemetryLocationService {
  Future<bool> isServiceEnabled();

  Future<TelemetryPermission> checkPermission();

  Future<TelemetryPermission> requestPermission();

  Stream<TelemetryPosition> getPositionStream();

  Stream<bool> getServiceEnabledStream();
}

abstract class TelemetryHeadingService {
  Stream<double?> getHeadingStream();
}

abstract class TelemetrySpeechService {
  Future<void> initialize();

  Future<void> speakDirection(String directionLabel);

  Future<void> stop();
}

abstract class TelemetryRepeatingTask {
  void cancel();
}

typedef TelemetryRepeatingTaskFactory =
    TelemetryRepeatingTask Function(
      Duration interval,
      void Function() callback,
    );

abstract class TelemetryControlling extends Listenable {
  TelemetrySnapshot get snapshot;

  Future<void> startTracking();

  Future<void> stopTracking();
}

class TelemetryController extends ChangeNotifier
    implements TelemetryControlling {
  TelemetryController({
    required this._locationService,
    required this._headingService,
    required this._speechService,
    required this._bridge,
    TelemetryRepeatingTaskFactory? repeatingTaskFactory,
    DateTime Function()? now,
  }) : _repeatingTaskFactory = repeatingTaskFactory ?? _defaultRepeatingTask,
       _now = now ?? DateTime.now;

  static final TelemetryController instance = TelemetryController(
    locationService: GeolocatorTelemetryLocationService(),
    headingService: FlutterCompassTelemetryHeadingService(),
    speechService: FlutterTtsTelemetrySpeechService(),
    bridge: const CarPlayService(),
  );

  final TelemetryLocationService _locationService;
  final TelemetryHeadingService _headingService;
  final TelemetrySpeechService _speechService;
  final CarPlayService _bridge;
  final TelemetryRepeatingTaskFactory _repeatingTaskFactory;
  final DateTime Function() _now;

  TelemetrySnapshot _snapshot = const TelemetrySnapshot.initial();
  StreamSubscription<TelemetryPosition>? _positionSubscription;
  StreamSubscription<double?>? _headingSubscription;
  StreamSubscription<bool>? _serviceEnabledSubscription;
  TelemetryRepeatingTask? _speechTask;
  bool _initialized = false;

  @override
  TelemetrySnapshot get snapshot => _snapshot;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _bridge.registerMethodHandler(_handleBridgeMethodCall);
    await _speechService.initialize();
    _initialized = true;
    await _publishSnapshot();
  }

  @override
  Future<void> startTracking() async {
    if (_snapshot.isTracking || _snapshot.status == TelemetryStatus.starting) {
      return;
    }

    _updateSnapshot(
      _snapshot.copyWith(
        status: TelemetryStatus.starting,
        clearErrorMessage: true,
      ),
    );

    if (!await _locationService.isServiceEnabled()) {
      _updateSnapshot(
        _snapshot.copyWith(
          isTracking: false,
          status: TelemetryStatus.serviceDisabled,
          errorMessage: 'Location services are disabled.',
          updatedAtIso8601: _now().toIso8601String(),
        ),
      );
      return;
    }

    var permission = await _locationService.checkPermission();
    if (permission == TelemetryPermission.denied) {
      permission = await _locationService.requestPermission();
    }

    if (permission != TelemetryPermission.always) {
      _updateSnapshot(
        _snapshot.copyWith(
          isTracking: false,
          status: TelemetryStatus.permissionDenied,
          errorMessage: permission == TelemetryPermission.whileInUse
              ? 'Always location access is required for background telemetry.'
              : 'Location permission was not granted.',
          updatedAtIso8601: _now().toIso8601String(),
        ),
      );
      return;
    }

    await _positionSubscription?.cancel();
    await _headingSubscription?.cancel();
    await _serviceEnabledSubscription?.cancel();

    _positionSubscription = _locationService.getPositionStream().listen(
      _handlePositionUpdate,
      onError: _handleStreamError,
    );
    _headingSubscription = _headingService.getHeadingStream().listen(
      _handleHeadingUpdate,
      onError: _handleStreamError,
    );
    _serviceEnabledSubscription = _locationService
        .getServiceEnabledStream()
        .listen(_handleServiceEnabledChange, onError: _handleStreamError);

    _startSpeechLoop();
    _updateSnapshot(
      _snapshot.copyWith(
        isTracking: true,
        status: TelemetryStatus.running,
        clearErrorMessage: true,
        updatedAtIso8601: _now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> stopTracking() async {
    if (!_snapshot.isTracking && _snapshot.status == TelemetryStatus.idle) {
      return;
    }

    _updateSnapshot(
      _snapshot.copyWith(
        status: TelemetryStatus.stopping,
        clearErrorMessage: true,
      ),
    );

    await _positionSubscription?.cancel();
    await _headingSubscription?.cancel();
    await _serviceEnabledSubscription?.cancel();
    _positionSubscription = null;
    _headingSubscription = null;
    _serviceEnabledSubscription = null;
    _speechTask?.cancel();
    _speechTask = null;
    await _speechService.stop();

    _updateSnapshot(
      _snapshot.copyWith(
        isTracking: false,
        status: TelemetryStatus.idle,
        updatedAtIso8601: _now().toIso8601String(),
        clearErrorMessage: true,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    unawaited(_headingSubscription?.cancel());
    unawaited(_serviceEnabledSubscription?.cancel());
    _speechTask?.cancel();
    super.dispose();
  }

  Future<Object?> _handleBridgeMethodCall(
    String method,
    Object? arguments,
  ) async {
    switch (method) {
      case 'getTelemetrySnapshot':
        return _snapshot.toMap();
      case 'startTracking':
        await startTracking();
        return _snapshot.toMap();
      case 'stopTracking':
        await stopTracking();
        return _snapshot.toMap();
      default:
        throw MissingPluginException(
          'TelemetryController does not handle $method.',
        );
    }
  }

  void _handlePositionUpdate(TelemetryPosition position) {
    _updateSnapshot(
      _snapshot.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeMeters: position.altitudeMeters,
        updatedAtIso8601: _now().toIso8601String(),
      ),
    );
  }

  void _handleHeadingUpdate(double? headingDegrees) {
    if (headingDegrees == null) {
      return;
    }

    _updateSnapshot(
      _snapshot.copyWith(
        headingDegrees: headingDegrees,
        directionLabel: directionLabelForHeading(headingDegrees),
        updatedAtIso8601: _now().toIso8601String(),
      ),
    );
  }

  void _handleServiceEnabledChange(bool isEnabled) {
    if (isEnabled || !_snapshot.isTracking) {
      return;
    }

    unawaited(_stopForServiceDisabled());
  }

  Future<void> _stopForServiceDisabled() async {
    await _positionSubscription?.cancel();
    await _headingSubscription?.cancel();
    await _serviceEnabledSubscription?.cancel();
    _positionSubscription = null;
    _headingSubscription = null;
    _serviceEnabledSubscription = null;
    _speechTask?.cancel();
    _speechTask = null;
    await _speechService.stop();

    _updateSnapshot(
      _snapshot.copyWith(
        isTracking: false,
        status: TelemetryStatus.serviceDisabled,
        errorMessage: 'Location services were disabled.',
        updatedAtIso8601: _now().toIso8601String(),
      ),
    );
  }

  void _handleStreamError(Object error, [StackTrace? stackTrace]) {
    unawaited(_stopForError(error));
  }

  Future<void> _stopForError(Object error) async {
    await _positionSubscription?.cancel();
    await _headingSubscription?.cancel();
    await _serviceEnabledSubscription?.cancel();
    _positionSubscription = null;
    _headingSubscription = null;
    _serviceEnabledSubscription = null;
    _speechTask?.cancel();
    _speechTask = null;
    await _speechService.stop();

    _updateSnapshot(
      _snapshot.copyWith(
        isTracking: false,
        status: TelemetryStatus.error,
        errorMessage: error.toString(),
        updatedAtIso8601: _now().toIso8601String(),
      ),
    );
  }

  void _startSpeechLoop() {
    _speechTask?.cancel();
    _speechTask = _repeatingTaskFactory(const Duration(seconds: 15), () {
      final String? directionLabel = _snapshot.directionLabel;
      if (!_snapshot.isTracking || directionLabel == null) {
        return;
      }

      unawaited(_speechService.speakDirection(directionLabel));
    });
  }

  void _updateSnapshot(TelemetrySnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
    unawaited(_publishSnapshot());
  }

  Future<void> _publishSnapshot() {
    return _bridge.updateTelemetrySnapshot(_snapshot);
  }

  static TelemetryRepeatingTask _defaultRepeatingTask(
    Duration interval,
    void Function() callback,
  ) {
    return _TimerRepeatingTask(interval, callback);
  }
}

class GeolocatorTelemetryLocationService implements TelemetryLocationService {
  @override
  Future<bool> isServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<TelemetryPermission> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<TelemetryPermission> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Stream<TelemetryPosition> getPositionStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (Position position) => TelemetryPosition(
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeMeters: position.altitude,
      ),
    );
  }

  @override
  Stream<bool> getServiceEnabledStream() {
    return Geolocator.getServiceStatusStream().map(
      (ServiceStatus status) => status == ServiceStatus.enabled,
    );
  }

  TelemetryPermission _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return TelemetryPermission.denied;
      case LocationPermission.deniedForever:
        return TelemetryPermission.deniedForever;
      case LocationPermission.whileInUse:
        return TelemetryPermission.whileInUse;
      case LocationPermission.always:
        return TelemetryPermission.always;
      case LocationPermission.unableToDetermine:
        return TelemetryPermission.denied;
    }
  }
}

class FlutterCompassTelemetryHeadingService implements TelemetryHeadingService {
  @override
  Stream<double?> getHeadingStream() {
    final Stream<CompassEvent>? events = FlutterCompass.events;
    if (events == null) {
      return const Stream<double?>.empty();
    }

    return events.map((CompassEvent event) => event.heading);
  }
}

class FlutterTtsTelemetrySpeechService implements TelemetrySpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
    _initialized = true;
  }

  @override
  Future<void> speakDirection(String directionLabel) async {
    await _flutterTts.stop();
    await _flutterTts.speak('Direction $directionLabel');
  }

  @override
  Future<void> stop() {
    return _flutterTts.stop();
  }
}

class _TimerRepeatingTask implements TelemetryRepeatingTask {
  _TimerRepeatingTask(Duration interval, void Function() callback)
    : _timer = Timer.periodic(interval, (_) => callback());

  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}
