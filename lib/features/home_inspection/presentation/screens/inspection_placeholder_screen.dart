import 'package:flutter/material.dart';

/// Placeholder for the start of the physical inspection flow (Phase 3).
/// Reached once the inspector has finished configuring areas and taps
/// Continue.
class InspectionPlaceholderScreen extends StatelessWidget {
  const InspectionPlaceholderScreen({super.key});

  static const routePath = '/home-inspection/inspection';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection')),
      body: const Center(
        child: Text('Physical inspection starts here (coming in Phase 3).'),
      ),
    );
  }
}
