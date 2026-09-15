import 'package:flutter/material.dart';

/// Reached once AI review is complete (every suggestion resolved).
/// Placeholder for report generation — out of scope until a later
/// phase.
class ReportPlaceholderScreen extends StatelessWidget {
  const ReportPlaceholderScreen({super.key});

  static const routePath = '/home-inspection/report';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'AI review is complete.\n\n'
            'Report generation comes next (coming in a later phase).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
