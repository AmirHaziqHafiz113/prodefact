import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App shell landing screen. Phase 1 only offers Home Inspection — other
/// industries will get their own entry points here once they exist.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  static const routePath = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ProDefact')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.push('/home-inspection/sessions'),
          child: const Text('Start Home Inspection'),
        ),
      ),
    );
  }
}
