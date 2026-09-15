import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';

/// Overview of the physical inspection: the ordered queue of included
/// areas (plumbing-related areas first), each area's progress, and the
/// final action to complete the physical inspection once every area is
/// done.
class InspectionQueueScreen extends ConsumerWidget {
  const InspectionQueueScreen({super.key});

  static const routePath = '/home-inspection/inspection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(inspectionQueueProvider);
    final statuses = ref.watch(sectionStatusesProvider);
    final canComplete = ref.watch(isPhysicalInspectionCompleteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Physical Inspection')),
      body: queue.isEmpty
          ? const Center(child: Text('No areas to inspect.'))
          : ListView.builder(
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final section = queue[index];
                final status = statuses[section.id] ?? SectionStatus.notStarted;
                return ListTile(
                  title: Text(section.name),
                  subtitle: section.isPlumbing
                      ? const Text('Plumbing area — inspect first')
                      : null,
                  trailing: _StatusChip(status: status),
                  onTap: () =>
                      context.push('/home-inspection/inspection/${section.id}'),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: canComplete
                ? () => _completeInspection(context, ref)
                : null,
            child: const Text('Complete Physical Inspection'),
          ),
        ),
      ),
    );
  }

  Future<void> _completeInspection(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionProvider.notifier)
        .markPhysicalInspectionComplete();
    if (!context.mounted) return;
    context.push('/home-inspection/complete');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SectionStatus.notStarted => ('Not started', Colors.grey),
      SectionStatus.inProgress => ('In progress', Colors.orange),
      SectionStatus.completed => ('Completed', Colors.green),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}
