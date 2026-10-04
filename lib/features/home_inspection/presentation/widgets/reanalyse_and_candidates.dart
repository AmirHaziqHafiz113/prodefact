import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';

enum _ReanalyseChoice { asIs, editNote }

/// "Reanalyse": a NEW AI analysis of any finding, only ever on request.
/// Offers Reanalyse As-Is, Edit Note & Reanalyse, or Cancel, and says
/// plainly (without alarm) that it uses another AI analysis.
Future<void> showReanalyseDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Finding finding,
}) async {
  final choice = await showDialog<_ReanalyseChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reanalyse this finding?'),
      content: const Text(
        'AI will look at this photo again and give a fresh result. This '
        'uses one more AI analysis. The current result is kept in the '
        'finding\'s history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('reanalyse-edit-note'),
          onPressed: () => Navigator.of(context).pop(_ReanalyseChoice.editNote),
          child: const Text('Edit Note & Reanalyse'),
        ),
        FilledButton(
          key: const ValueKey('reanalyse-as-is'),
          onPressed: () => Navigator.of(context).pop(_ReanalyseChoice.asIs),
          child: const Text('Reanalyse As-Is'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  String? newNote;
  if (choice == _ReanalyseChoice.editNote) {
    newNote = await _editNote(context, finding.defectNote ?? '');
    if (newNote == null || !context.mounted) return;
  }
  final started = await ref
      .read(activeSessionProvider.notifier)
      .reanalyseFinding(finding.id, newNote: newNote);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        started
            ? 'Reanalysing…'
            : 'This finding needs a photo and a quick note, and can\'t be '
                  'reanalysed while AI is already working on it.',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<String?> _editNote(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit note & reanalyse'),
      content: TextField(
        key: const ValueKey('reanalyse-note-field'),
        controller: controller,
        autofocus: true,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Quick defect note',
          hintText: 'Shorthand, BM or English is fine.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Reanalyse'),
        ),
      ],
    ),
  );
}

/// Up to 4 catalogue defects the AI thought possible, as tappable
/// options (Element, Component, Defect description — never raw ids).
/// Choosing one confirms it as the inspector's decision; it never calls
/// the AI again.
class PossibleDefectsList extends ConsumerWidget {
  const PossibleDefectsList({
    super.key,
    required this.suggestion,
    this.excludeEntryId,
  });

  final AiSuggestion suggestion;

  /// The entry already offered above (with Accept), not repeated here.
  final String? excludeEntryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = DefectCatalogue.instance;
    final entries = [
      for (final id in suggestion.suggestedCandidateEntryIds)
        if (id != excludeEntryId) ?catalogue.byId(id),
    ].take(4).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('possible-defects-${suggestion.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          excludeEntryId == null
              ? 'Possible defects'
              : 'Other possible defects',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final entry in entries)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              key: ValueKey('candidate-${entry.id}'),
              title: Text(entry.defectDescription),
              subtitle: Text(
                '${entry.mainElementName} · ${entry.componentName}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirm(context, ref, entry),
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    DefectCatalogueEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use this defect?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Element: ${entry.mainElementName}'),
            Text('Component: ${entry.componentName}'),
            const SizedBox(height: AppSpacing.xs),
            Text(entry.defectDescription),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-candidate'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use This Defect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The inspector's own decision (no AI call); its corrective action
    // comes from the catalogue entry.
    ref
        .read(activeSessionProvider.notifier)
        .changeSuggestion(suggestion.id, entry.id);
  }
}
