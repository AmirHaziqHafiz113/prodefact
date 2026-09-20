import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/new_inspection_draft_providers.dart';
import 'inspection_queue_screen.dart';
import 'property_type_selection_screen.dart';

/// New Inspection setup, the final step before a session is actually
/// created: a read-only summary of everything configured so far
/// (property, type, address, selected areas, plumbing areas, inspector,
/// date), plus the explicit "Start Inspection" action.
///
/// This is the **only** place [NewInspectionDraftNotifier.startInspection]
/// is called — see its doc comment for why area configuration itself
/// must never trigger persistence directly.
class ReviewSetupScreen extends ConsumerWidget {
  const ReviewSetupScreen({super.key});

  static const routePath = '/home-inspection/review';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(newInspectionDraftProvider);

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Setup')),
        body: const AppEmptyView(
          icon: Icons.home_work_outlined,
          title: 'No inspection setup in progress.',
        ),
      );
    }

    final details = draft.propertyDetails ?? PropertyDetails.empty;
    final includedAreas = draft.sections.where((s) => s.isIncluded).toList();
    final plumbingAreas = includedAreas.where((s) => s.isPlumbing).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Review Setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const AppWizardStepper(
              stepLabels: PropertyTypeSelectionScreen.wizardSteps,
              currentIndex: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: details.title.isEmpty
                  ? draft.propertyType.label
                  : details.title,
              subtitle: draft.propertyType.label,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryCard(
              rows: [
                ('Unit', details.unitNumber?.isNotEmpty == true
                    ? details.unitNumber!
                    : 'Not set'),
                if (details.address != null) ('Address', details.address!),
                if (details.resolvedProjectDeveloperName != null)
                  ('Project / Developer', details.resolvedProjectDeveloperName!),
                if (details.blockTower != null)
                  ('Block / Tower', details.blockTower!),
                if (details.clientName != null) ('Client', details.clientName!),
                if (details.contactNumber != null)
                  ('Contact', details.contactNumber!),
                (
                  'Inspector',
                  details.inspectorName?.isNotEmpty == true
                      ? details.inspectorName!
                      : 'Not set',
                ),
                (
                  'Inspection date & time',
                  details.inspectionDate != null
                      ? _formatDateTime(details.inspectionDate!)
                      : 'Not set',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: 'Selected areas',
              subtitle: '${includedAreas.length} of ${draft.sections.length}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final area in includedAreas)
                  StatusPill(
                    label: area.name,
                    icon: area.isPlumbing
                        ? Icons.plumbing_outlined
                        : Icons.check_circle_outline,
                    foreground: area.isPlumbing
                        ? AppColors.plumbing
                        : AppColors.primary,
                    background: area.isPlumbing
                        ? AppColors.plumbingBg
                        : AppColors.primary.withValues(alpha: 0.08),
                    dense: true,
                  ),
              ],
            ),
            if (plumbingAreas.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${plumbingAreas.length} plumbing area(s) will be shown '
                'first so water tests can run while you continue '
                'inspecting other areas.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StartInspectionButton(
                  enabled:
                      includedAreas.isNotEmpty &&
                      (details.unitNumber?.trim().isNotEmpty ?? false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The explicit, final setup action — this is the only place a draft
/// actually becomes a persisted, dashboard-visible inspection. Guards
/// against a double-tap starting two sessions.
class _StartInspectionButton extends ConsumerStatefulWidget {
  const _StartInspectionButton({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_StartInspectionButton> createState() =>
      _StartInspectionButtonState();
}

class _StartInspectionButtonState
    extends ConsumerState<_StartInspectionButton> {
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: widget.enabled && !_isStarting ? _start : null,
      child: _isStarting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Text('Start Inspection'),
    );
  }

  Future<void> _start() async {
    setState(() => _isStarting = true);
    final started = await ref
        .read(newInspectionDraftProvider.notifier)
        .startInspection();
    if (!mounted) return;
    if (!started) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start the inspection. Please try again.'),
        ),
      );
      return;
    }
    // Setup no longer asks Flex Credits vs. House Pass (see the QA/QC
    // simplification pass) — every new inspection starts straight into
    // the queue, with that commercial decision available later, from
    // the queue's own "House Pass" action, only if the inspector wants
    // it.
    context.push(InspectionQueueScreen.routePath);
  }
}
