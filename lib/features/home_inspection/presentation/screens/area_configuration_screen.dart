import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/home_inspection_providers.dart';

/// Lets the inspector configure which areas apply to this property before
/// physical inspection begins: include/exclude, rename, remove, add
/// custom areas, or reset back to the property type's defaults.
class AreaConfigurationScreen extends ConsumerWidget {
  const AreaConfigurationScreen({super.key});

  static const routePath = '/home-inspection/areas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = ref.watch(selectedPropertyTypeProvider);
    final sections = ref.watch(configuredAreasProvider);
    final notifier = ref.read(configuredAreasProvider.notifier);
    final includedCount = sections.where((s) => s.isIncluded).length;
    final plumbingCount = sections
        .where((s) => s.isIncluded && s.isPlumbing)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          propertyType == null
              ? 'Configure Areas'
              : '${propertyType.label} Areas',
        ),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore),
            onPressed: propertyType == null ? null : notifier.resetToDefaults,
          ),
        ],
      ),
      body: sections.isEmpty
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
                        onRename: () =>
                            _showRenameDialog(context, notifier, section),
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
                  onPressed: propertyType == null
                      ? null
                      : () => _showAddAreaDialog(context, notifier),
                  icon: const Icon(Icons.add),
                  label: const Text('Add area'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: sections.any((s) => s.isIncluded)
                      ? () => context.push('/home-inspection/inspection')
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

  Future<void> _showRenameDialog(
    BuildContext context,
    ConfiguredAreas notifier,
    Section section,
  ) async {
    final controller = TextEditingController(text: section.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Area name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null) {
      notifier.rename(section.id, newName);
    }
  }

  Future<void> _showAddAreaDialog(
    BuildContext context,
    ConfiguredAreas notifier,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Area name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null) {
      notifier.addCustom(name);
    }
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.section,
    required this.onToggleIncluded,
    required this.onRename,
    required this.onRemove,
  });

  final Section section;
  final VoidCallback onToggleIncluded;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: section.isIncluded ? null : AppColors.surfaceAlt,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        title: Text(
          section.name,
          style: section.isIncluded
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.textMuted),
        ),
        subtitle: section.isPlumbing
            ? const Padding(
                padding: EdgeInsets.only(top: 4),
                child: StatusPill(
                  label: 'Plumbing area — inspect first',
                  icon: Icons.plumbing_outlined,
                  foreground: AppColors.plumbing,
                  background: AppColors.plumbingBg,
                  dense: true,
                ),
              )
            : null,
        leading: Switch(
          value: section.isIncluded,
          onChanged: (_) => onToggleIncluded(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit),
              onPressed: onRename,
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
