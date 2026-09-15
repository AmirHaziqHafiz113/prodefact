import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/session_list_providers.dart';
import 'property_type_selection_screen.dart';

/// Lists locally-saved Home Inspection sessions so the inspector can
/// resume an unfinished one or start a new inspection. This is the
/// minimal "home screen" Phase 4 needs to make resume behavior usable
/// and testable — not a full dashboard.
class InspectionSessionsScreen extends ConsumerWidget {
  const InspectionSessionsScreen({super.key});

  static const routePath = '/home-inspection/sessions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home Inspections')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load saved inspections: $error')),
        data: (sessions) => sessions.isEmpty
            ? const Center(child: Text('No saved inspections yet.'))
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final summary = sessions[index];
                  final propertyTypeLabel = PropertyType.values
                      .firstWhereOrNull((p) => p.name == summary.assetTypeId)
                      ?.label;
                  return ListTile(
                    title: Text(propertyTypeLabel ?? summary.assetTypeId),
                    subtitle: Text(_formatUpdatedAt(summary.updatedAt)),
                    trailing: Chip(
                      label: Text(
                        summary.isComplete ? 'Completed' : 'Unfinished',
                      ),
                      backgroundColor:
                          (summary.isComplete ? Colors.green : Colors.orange)
                              .withValues(alpha: 0.15),
                    ),
                    onTap: () => _resume(context, ref, summary.id),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PropertyTypeSelectionScreen.routePath),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    await ref.read(activeSessionProvider.notifier).resume(sessionId);
    if (!context.mounted) return;
    context.push('/home-inspection/inspection');
  }

  String _formatUpdatedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Last updated ${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
