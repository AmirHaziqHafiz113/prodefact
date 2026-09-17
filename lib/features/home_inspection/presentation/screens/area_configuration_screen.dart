import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/new_inspection_draft_providers.dart';
import 'choose_ai_plan_screen.dart';

/// Lets the inspector configure which areas apply to this property
/// before starting the inspection: include/exclude, rename, add/edit
/// custom areas (with a plumbing/inspect-first flag), remove, or reset
/// back to the property type's defaults.
///
/// Everything here edits an in-memory [NewInspectionDraft] — nothing is
/// persisted, and no inspection exists, until the inspector taps
/// "Start Inspection". Backing out of this screen at any point simply
/// discards the draft; see `docs/production_readiness.md` ("New
/// Inspection flow").
class AreaConfigurationScreen extends ConsumerWidget {
  const AreaConfigurationScreen({super.key});

  static const routePath = '/home-inspection/areas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(newInspectionDraftProvider);
    final notifier = ref.read(newInspectionDraftProvider.notifier);
    final sections = draft?.sections ?? const <Section>[];
    final includedCount = sections.where((s) => s.isIncluded).length;
    final plumbingCount = sections
        .where((s) => s.isIncluded && s.isPlumbing)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          draft == null
              ? 'Configure Areas'
              : '${draft.propertyType.label} Areas',
        ),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore),
            onPressed: draft == null ? null : notifier.resetToDefaults,
          ),
        ],
      ),
      body: draft == null
          ? const AppEmptyView(
              icon: Icons.home_work_outlined,
              title: 'No property type selected.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatusPill(
                          label:
                              '$includedCount of ${sections.length} '
                              'areas selected',
                          icon: Icons.check_circle_outline,
                          foreground: AppColors.primary,
                          background: AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (plumbingCount > 0)
                        StatusPill(
                          label: '$plumbingCount plumbing-first',
                          icon: Icons.plumbing_outlined,
                          foreground: AppColors.plumbing,
                          background: AppColors.plumbingBg,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: sections.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _AreaCard(
                        section: section,
                        onToggleIncluded: () =>
                            notifier.toggleIncluded(section.id),
                        onEdit: () => _showEditAreaDialog(
                          context,
                          notifier,
                          section: section,
                        ),
                        onRemove: () => notifier.remove(section.id),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: draft == null
                      ? null
                      : () => _showEditAreaDialog(context, notifier),
                  icon: const Icon(Icons.add),
                  label: const Text('Add area'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: sections.any((s) => s.isIncluded)
                      ? () => context.push(ChooseAiPlanScreen.routePath)
                      : null,
                  child: const Text('Review & Start'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One dialog for both "Add area" (no [section]) and "Edit area"
  /// (existing [section]) — both need the same fields: a name, and
  /// whether the area contains plumbing and should be inspected first.
  Future<void> _showEditAreaDialog(
    BuildContext context,
    NewInspectionDraftNotifier notifier, {
    Section? section,
  }) async {
    final controller = TextEditingController(text: section?.name ?? '');
    final result = await showDialog<({String name, bool isPlumbing})>(
      context: context,
      builder: (context) => _AreaEditDialog(
        controller: controller,
        initialIsPlumbing: section?.isPlumbing ?? false,
        isNew: section == null,
      ),
    );
    if (result == null) return;

    if (section == null) {
      notifier.addCustom(result.name, isPlumbing: result.isPlumbing);
    } else {
      notifier.updateArea(
        section.id,
        name: result.name,
        isPlumbing: result.isPlumbing,
      );
    }
  }
}

class _AreaEditDialog extends StatefulWidget {
  const _AreaEditDialog({
    required this.controller,
    required this.initialIsPlumbing,
    required this.isNew,
  });

  final TextEditingController controller;
  final bool initialIsPlumbing;
  final bool isNew;

  @override
  State<_AreaEditDialog> createState() => _AreaEditDialogState();
}

class _AreaEditDialogState extends State<_AreaEditDialog> {
  late bool _isPlumbing = widget.initialIsPlumbing;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add area' : 'Edit area'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Area name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Contains plumbing'),
            subtitle: const Text(
              'Inspected first (e.g. leakage/ponding checks)',
            ),
            value: _isPlumbing,
            onChanged: (value) => setState(() => _isPlumbing = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop((name: widget.controller.text, isPlumbing: _isPlumbing)),
          child: Text(widget.isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.section,
    required this.onToggleIncluded,
    required this.onEdit,
    required this.onRemove,
  });

  final Section section;
  final VoidCallback onToggleIncluded;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // A Row/Column layout (rather than ListTile's fixed leading/title/
    // subtitle/trailing grid) so the plumbing indicator and a long
    // area name always have room to wrap or ellipsize instead of
    // overflowing past the action buttons — see
    // `docs/production_readiness.md` ("Area configuration overflow fix").
    return Card(
      color: section.isIncluded ? null : AppColors.surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Switch(
              value: section.isIncluded,
              onChanged: (_) => onToggleIncluded(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    section.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: section.isIncluded
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.textMuted),
                  ),
                  if (section.isPlumbing)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: StatusPill(
                        label: 'Plumbing area — inspect first',
                        icon: Icons.plumbing_outlined,
                        foreground: AppColors.plumbing,
                        background: AppColors.plumbingBg,
                        dense: true,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
