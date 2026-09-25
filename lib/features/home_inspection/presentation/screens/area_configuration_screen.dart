import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/new_inspection_draft_providers.dart';
import 'property_type_selection_screen.dart';
import 'review_setup_screen.dart';

/// Lets the inspector configure which areas apply to this property
/// before starting the inspection: include/exclude, rename, add/edit
/// custom areas (with a plumbing/inspect-first flag), remove, or reset
/// back to the property type's defaults. The **only** place area
/// management happens — no other screen exposes "Add area" (see
/// docs/ui_design_system.md, "Routing cleanup").
///
/// Everything here edits an in-memory [NewInspectionDraft] — nothing is
/// persisted, and no inspection exists, until the inspector taps
/// "Start Inspection". Backing out of this screen at any point simply
/// discards the draft; see `docs/production_readiness.md` ("New
/// Inspection flow").
class AreaConfigurationScreen extends ConsumerStatefulWidget {
  const AreaConfigurationScreen({super.key});

  static const routePath = '/home-inspection/areas';

  @override
  ConsumerState<AreaConfigurationScreen> createState() =>
      _AreaConfigurationScreenState();
}

class _AreaConfigurationScreenState
    extends ConsumerState<AreaConfigurationScreen> {
  bool _showInfoBanner = true;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(newInspectionDraftProvider);
    final notifier = ref.read(newInspectionDraftProvider.notifier);
    final sections = draft?.sections ?? const <Section>[];
    final includedCount = sections.where((s) => s.isIncluded).length;
    final plumbingCount = sections
        .where((s) => s.isIncluded && s.isPlumbing)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Areas'),
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
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppWizardStepper(
                        stepLabels: PropertyTypeSelectionScreen.wizardSteps,
                        currentIndex: 2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Select the areas to include in this inspection.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: AppMetricCard(
                              icon: Icons.layers_outlined,
                              value: '$includedCount',
                              label: 'areas selected',
                              caption:
                                  'Out of ${sections.length} standard areas',
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: AppMetricCard(
                              icon: Icons.water_drop_outlined,
                              value: '$plumbingCount',
                              label: 'plumbing-first',
                              caption: 'Will be inspected first',
                              iconColor: AppColors.plumbing,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                      if (_showInfoBanner) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Manage all inspection areas here',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      'Add, remove or customize areas for '
                                      'this inspection.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setState(() => _showInfoBanner = false),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppSectionHeader(
                        title: 'Standard Areas',
                        subtitle:
                            '$includedCount of ${sections.length} selected',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      for (final section in sections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AreaCard(
                            section: section,
                            onToggleIncluded: () =>
                                notifier.toggleIncluded(section.id),
                            onEdit: () => _showEditAreaDialog(
                              context,
                              notifier,
                              section: section,
                            ),
                            onRemove: () => notifier.remove(section.id),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _showEditAreaDialog(context, notifier),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Newly Discovered Area'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            style: BorderStyle.solid,
                          ),
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ],
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
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: sections.any((s) => s.isIncluded)
                      ? () => context.push(ReviewSetupScreen.routePath)
                      : null,
                  child: const Text('Continue'),
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
      title: Text(widget.isNew ? 'Add newly discovered area' : 'Edit area'),
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

enum _AreaAction { edit, remove }

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
            AppFallbackThumbnail(
              icon: section.isPlumbing
                  ? Icons.plumbing_outlined
                  : Icons.chair_outlined,
              size: 44,
              radius: AppRadius.sm,
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
            Switch(
              value: section.isIncluded,
              onChanged: (_) => onToggleIncluded(),
            ),
            PopupMenuButton<_AreaAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => switch (action) {
                _AreaAction.edit => onEdit(),
                _AreaAction.remove => onRemove(),
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _AreaAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _AreaAction.remove,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
