import 'package:flutter/material.dart';

/// Reached once the inspector completes the physical inspection (all
/// included areas marked complete). Placeholder for the next stage — AI
/// review — which is out of scope until a later phase.
class NextStagePlaceholderScreen extends StatelessWidget {
  const NextStagePlaceholderScreen({super.key});

  static const routePath = '/home-inspection/complete';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physical Inspection Complete')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'All areas have been inspected.\n\n'
            'AI review of findings comes next (coming in a later phase).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
