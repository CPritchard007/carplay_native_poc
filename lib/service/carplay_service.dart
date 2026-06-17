import 'package:flutter/services.dart';

class CarPlayListItem {
  const CarPlayListItem({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  Map<String, Object?> toMap() {
    return <String, Object?>{'title': title, 'subtitle': subtitle};
  }
}

class CarPlaySection {
  const CarPlaySection({this.header, required this.items});

  final String? header;
  final List<CarPlayListItem> items;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'header': header,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}

class CarPlayListTemplatePayload {
  const CarPlayListTemplatePayload({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<CarPlaySection> sections;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'title': title,
      'sections': sections.map((section) => section.toMap()).toList(),
    };
  }
}

class CarPlayService {
  static const MethodChannel _channel = MethodChannel(
    'com.cpritchard007.carplay_native_poc/data',
  );

  static Future<void> setRootTemplate(
    CarPlayListTemplatePayload payload,
  ) async {
    await _channel.invokeMethod<void>('setRootTemplate', payload.toMap());
  }
}
