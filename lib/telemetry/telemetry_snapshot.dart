enum TelemetryStatus {
  idle,
  starting,
  running,
  stopping,
  permissionDenied,
  serviceDisabled,
  error,
}

TelemetryStatus telemetryStatusFromWireValue(String value) {
  return TelemetryStatus.values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => TelemetryStatus.error,
  );
}

extension TelemetryStatusWireValue on TelemetryStatus {
  String get wireValue {
    switch (this) {
      case TelemetryStatus.idle:
        return 'idle';
      case TelemetryStatus.starting:
        return 'starting';
      case TelemetryStatus.running:
        return 'running';
      case TelemetryStatus.stopping:
        return 'stopping';
      case TelemetryStatus.permissionDenied:
        return 'permissionDenied';
      case TelemetryStatus.serviceDisabled:
        return 'serviceDisabled';
      case TelemetryStatus.error:
        return 'error';
    }
  }

  String get label {
    switch (this) {
      case TelemetryStatus.idle:
        return 'Idle';
      case TelemetryStatus.starting:
        return 'Starting';
      case TelemetryStatus.running:
        return 'Running';
      case TelemetryStatus.stopping:
        return 'Stopping';
      case TelemetryStatus.permissionDenied:
        return 'Permission Denied';
      case TelemetryStatus.serviceDisabled:
        return 'Service Disabled';
      case TelemetryStatus.error:
        return 'Error';
    }
  }
}

class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.isTracking,
    required this.status,
    this.latitude,
    this.longitude,
    this.headingDegrees,
    this.altitudeMeters,
    this.directionLabel,
    this.updatedAtIso8601,
    this.errorMessage,
  });

  const TelemetrySnapshot.initial()
    : this(isTracking: false, status: TelemetryStatus.idle);

  final bool isTracking;
  final double? latitude;
  final double? longitude;
  final double? headingDegrees;
  final double? altitudeMeters;
  final String? directionLabel;
  final TelemetryStatus status;
  final String? updatedAtIso8601;
  final String? errorMessage;

  TelemetrySnapshot copyWith({
    bool? isTracking,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    double? headingDegrees,
    bool clearHeadingDegrees = false,
    double? altitudeMeters,
    bool clearAltitudeMeters = false,
    String? directionLabel,
    bool clearDirectionLabel = false,
    TelemetryStatus? status,
    String? updatedAtIso8601,
    bool clearUpdatedAtIso8601 = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TelemetrySnapshot(
      isTracking: isTracking ?? this.isTracking,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      headingDegrees: clearHeadingDegrees
          ? null
          : (headingDegrees ?? this.headingDegrees),
      altitudeMeters: clearAltitudeMeters
          ? null
          : (altitudeMeters ?? this.altitudeMeters),
      directionLabel: clearDirectionLabel
          ? null
          : (directionLabel ?? this.directionLabel),
      status: status ?? this.status,
      updatedAtIso8601: clearUpdatedAtIso8601
          ? null
          : (updatedAtIso8601 ?? this.updatedAtIso8601),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'isTracking': isTracking,
      'latitude': latitude,
      'longitude': longitude,
      'headingDegrees': headingDegrees,
      'altitudeMeters': altitudeMeters,
      'directionLabel': directionLabel,
      'status': status.wireValue,
      'updatedAtIso8601': updatedAtIso8601,
      'errorMessage': errorMessage,
    };
  }
}

String directionLabelForHeading(double headingDegrees) {
  const List<String> labels = <String>[
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
  ];
  final double normalized = (headingDegrees % 360 + 360) % 360;
  final int index = (((normalized + 22.5) % 360) / 45).floor();
  return labels[index];
}
