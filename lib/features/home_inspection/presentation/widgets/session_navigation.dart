import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/active_session_providers.dart';
import '../screens/inspection_queue_screen.dart';

/// Resumes [sessionId] as the active session and opens its Inspection
/// Overview — the one shared "open this inspection" action every
/// inspection card (Home's hero/recent, Inspections list, the needs-
/// attention sheet) calls, rather than each screen re-implementing its
/// own copy of this resume-then-navigate sequence.
Future<void> resumeAndOpenInspection(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) async {
  final resumed = await ref
      .read(activeSessionProvider.notifier)
      .resume(sessionId);
  if (!context.mounted) return;
  if (!resumed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open that inspection. Please try again.'),
      ),
    );
    return;
  }
  context.push(InspectionQueueScreen.routePath);
}
