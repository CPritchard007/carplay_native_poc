import 'package:flutter/material.dart';
import 'package:carplay_native_poc/service/carplay_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarPlay Native POC',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _sendDemoTemplate(BuildContext context) async {
    try {
      await CarPlayService.setRootTemplate(
        const CarPlayListTemplatePayload(
          title: 'Trips',
          sections: <CarPlaySection>[
            CarPlaySection(
              header: 'Upcoming',
              items: <CarPlayListItem>[
                CarPlayListItem(title: 'Office', subtitle: 'ETA 18 min'),
                CarPlayListItem(title: 'Airport', subtitle: 'ETA 42 min'),
              ],
            ),
            CarPlaySection(
              header: 'Recent',
              items: <CarPlayListItem>[
                CarPlayListItem(title: 'Home', subtitle: '12 King St W'),
                CarPlayListItem(title: 'Gym', subtitle: '401 Adelaide St W'),
              ],
            ),
          ],
        ),
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent demo CarPlay template to native iOS.'),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send CarPlay data: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CarPlay Native Bridge')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Send a native CarPlay list template from Flutter over a MethodChannel.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect the app to CarPlay, then use the button below to push a native list template to the CarPlay scene.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _sendDemoTemplate(context),
              child: const Text('Send Demo CarPlay Data'),
            ),
          ],
        ),
      ),
    );
  }
}
