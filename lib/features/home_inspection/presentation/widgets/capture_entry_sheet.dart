import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../../providers/session_list_providers.dart';
import '../screens/property_type_selection_screen.dart';
import 'app_bottom_sheet.dart';
import 'session_navigation.dart';
import 'session_status_presentation.dart';

/// What the global "+" does: get the inspector to the camera for the
/// right inspection and area in as few taps as possible.
///
/// - No open inspection → straight into New Inspection setup.
/// - Otherwise a sheet: pick an open inspection (or start a new one),
///   then pick the area, then the camera opens in that area. Each saved
///   photo becomes one finding and AI starts in the background, so the
///   inspector can keep capturing.
///
/// See docs/ux_architecture.md ("Each door has one destination").
Future<void> startCaptureFlow(BuildContext context, WidgetRef ref) async {
  final List<InspectionSessionSummary> summaries =
      ref.read(sessionSummariesProvider).value ??
      await ref.read(sessionSummariesProvider.future) ??
      const [];
  if (!context.mounted) return;
  final open =
      summaries.where((s) => s.status == InspectionStatus.inProgress).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  if (open.isEmpty) {
    context.push(PropertyTypeSelectionScreen.routePath);
    return;
  }

  final choice = await showAppBottomSheet<_CaptureChoice>(
    context: context,
    builder: (sheetContext) => _InspectionPickerSheet(open: open.take(5)),
  );
  if (choice == null || !context.mounted) return;
  if (choice.startNew) {
    context.push(PropertyTypeSelectionScreen.routePath);
    return;
  }

  final resumed = await ref
      .read(activeSessionProvider.notifier)
      .resume(choice.sessionId!);
  if (!context.mounted) return;
  if (!resumed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open that inspection. Please try again.'),
      ),
    );
    return;
  }
  final session = ref.read(activeSessionProvider)!;
  final queue = ref.read(inspectionQueueProvider);
  final area = await showAppBottomSheet<Section>(
    context: context,
    builder: (sheetContext) => _AreaPickerSheet(
      session: session,
      queue: queue,
      suggested: continueAreaFor(session, queue),
    ),
  );
  if (area == null || !context.mounted) return;
  context.push(areaFindingsLocation(area.id, capture: true));
}

class _CaptureChoice {
  const _CaptureChoice.session(String this.sessionId) : startNew = false;
  const _CaptureChoice.newInspection() : sessionId = null, startNew = true;

  final String? sessionId;
  final bool startNew;
}

class _InspectionPickerSheet extends StatelessWidget {
  const _InspectionPickerSheet({required this.open});

  final Iterable<InspectionSessionSummary> open;

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Capture a finding',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              2,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Choose the inspection you are working on.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          for (final summary in open)
            InkWell(
              key: ValueKey('capture-session-${summary.id}'),
              onTap: () =>
                  Navigator.of(context).pop(_CaptureChoice.session(summary.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    AppPropertyPhoto(
                      photoPath: summary.coverPhotoPath,
                      kind: illustrationKindFor(summary.assetTypeId),
                      width: 48,
                      height: 48,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summaryTitle(summary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${summary.findingsCount} finding'
                            '${summary.findingsCount == 1 ? '' : 's'} · '
                            'updated ${formatRelativeTime(summary.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          const Divider(height: AppSpacing.lg),
          AppActionRow(
            key: const ValueKey('capture-new-inspection'),
            icon: Icons.add_home_work_outlined,
            title: 'Start a new inspection',
            onTap: () =>
                Navigator.of(context).pop(const _CaptureChoice.newInspection()),
          ),
        ],
      ),
    );
  }
}

class _AreaPickerSheet extends StatelessWidget {
  const _AreaPickerSheet({
    required this.session,
    required this.queue,
    required this.suggested,
  });

  final InspectionSession session;
  final List<Section> queue;
  final Section? suggested;

  @override
  Widget build(BuildContext context) {
    final ordered = [?suggested, ...queue.where((s) => s.id != suggested?.id)];
    return AppSheetFrame(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Which area?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (ordered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'This inspection has no areas yet. Open it from Inspections '
                'and add an area first.',
              ),
            ),
          for (final section in ordered)
            AppActionRow(
              key: ValueKey('capture-area-${section.id}'),
              icon: section.isPlumbing
                  ? Icons.plumbing_outlined
                  : Icons.chair_outlined,
              iconColor: section.isPlumbing
                  ? AppColors.plumbing
                  : AppColors.primary,
              title: section.name,
              subtitle: section.id == suggested?.id
                  ? 'Suggested — where you left off'
                  : _countLabel(section),
              onTap: () => Navigator.of(context).pop(section),
            ),
        ],
      ),
    );
  }

  String? _countLabel(Section section) {
    final count = session.findings
        .where((f) => f.sectionId == section.id)
        .length;
    final state = areaVisitStateOf(session, section);
    if (state == AreaVisitState.completed) return 'Completed';
    return count == 0 ? null : '$count finding${count == 1 ? '' : 's'}';
  }
}
