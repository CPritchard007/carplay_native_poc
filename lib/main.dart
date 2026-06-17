import 'package:flutter/material.dart';

import 'telemetry/telemetry_controller.dart';
import 'telemetry/telemetry_snapshot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TelemetryController.instance.initialize();
  runApp(MyApp(controller: TelemetryController.instance));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.controller});

  final TelemetryControlling controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarPlay Native POC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F4C5C)),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final TelemetryControlling controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final TelemetrySnapshot snapshot = controller.snapshot;
        final bool canStart =
            !snapshot.isTracking &&
            snapshot.status != TelemetryStatus.starting &&
            snapshot.status != TelemetryStatus.stopping;
        final bool canStop =
            snapshot.isTracking &&
            snapshot.status != TelemetryStatus.starting &&
            snapshot.status != TelemetryStatus.stopping;

        return Scaffold(
          appBar: AppBar(title: const Text('Background Telemetry')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Track GPS telemetry for CarPlay and speak the current direction in background mode.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: canStart ? controller.startTracking : null,
                    child: const Text('Start Background Mode'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: canStop ? controller.stopTracking : null,
                    child: const Text('Stop Background Mode'),
                  ),
                  const SizedBox(height: 24),
                  _StatusSection(snapshot: snapshot),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: <Widget>[
                        _MetricCard(
                          label: 'Latitude',
                          value: _formatCoordinate(snapshot.latitude),
                        ),
                        _MetricCard(
                          label: 'Longitude',
                          value: _formatCoordinate(snapshot.longitude),
                        ),
                        _MetricCard(
                          label: 'Rotation',
                          value: _formatRotation(
                            snapshot.headingDegrees,
                            snapshot.directionLabel,
                          ),
                        ),
                        _MetricCard(
                          label: 'Elevation',
                          value: _formatElevation(snapshot.altitudeMeters),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.snapshot});

  final TelemetrySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[
      Text(
        'Status: ${snapshot.status.label}',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Updated: ${_formatUpdatedAt(snapshot.updatedAtIso8601)}',
        style: theme.textTheme.bodyMedium,
      ),
    ];

    if (snapshot.errorMessage case final String errorMessage?) {
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          errorMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCoordinate(double? value) {
  if (value == null) {
    return 'Unavailable';
  }

  return value.toStringAsFixed(6);
}

String _formatRotation(double? headingDegrees, String? directionLabel) {
  if (headingDegrees == null) {
    return 'Unavailable';
  }

  final String suffix = directionLabel == null ? '' : ' $directionLabel';
  return '${headingDegrees.toStringAsFixed(1)}°$suffix';
}

String _formatElevation(double? altitudeMeters) {
  if (altitudeMeters == null) {
    return 'Unavailable';
  }

  return '${altitudeMeters.toStringAsFixed(1)} m';
}

String _formatUpdatedAt(String? updatedAtIso8601) {
  if (updatedAtIso8601 == null) {
    return 'Never';
  }

  final DateTime? parsed = DateTime.tryParse(updatedAtIso8601);
  if (parsed == null) {
    return updatedAtIso8601;
  }

  final DateTime local = parsed.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}
