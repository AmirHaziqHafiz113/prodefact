import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/custom_catalogue_providers.dart';
import 'add_custom_defect_dialog.dart';

/// "Other possible defects ▼": a manual, searchable alternative to the
/// AI's own top-4 candidates — the full controlled 222-entry catalogue,
/// most-related-to-this-finding first, filterable by a free-text
/// search. Selecting one is the inspector's own decision: it never
/// calls an AI/provider request and never spends another AI attempt.
///
/// Works for any finding with a photo, whatever its current state
/// (passed, needs review, manually corrected) — the caller supplies
/// [onSelected] to apply the choice the right way for that state (e.g.
/// `changeSuggestion` when a suggestion already exists, or
/// `manuallyClassifyFinding` for a failed finding that has none yet).
class RelatedDefectSelector extends ConsumerStatefulWidget {
  const RelatedDefectSelector({
    super.key,
    required this.keyId,
    required this.relatedContext,
    required this.onSelected,
  });

  /// Distinguishes this instance's keys (e.g. the finding/suggestion
  /// id) so several of these can live on one screen.
  final String keyId;

  final RelatedDefectContext relatedContext;

  final void Function(DefectCatalogueEntry entry) onSelected;

  @override
  ConsumerState<RelatedDefectSelector> createState() =>
      _RelatedDefectSelectorState();
}

class _RelatedDefectSelectorState extends ConsumerState<RelatedDefectSelector> {
  final _controller = TextEditingController();
  List<DefectCatalogueEntry> _ranked = const [];
  int _rankedForEntryCount = -1;
  String _query = '';

  /// Re-ranks only when the catalogue itself changed (a custom entry was
  /// added/archived), never on every keystroke.
  void _ensureRanked() {
    final count = DefectCatalogue.instance.entries.length;
    if (count == _rankedForEntryCount) return;
    _rankedForEntryCount = count;
    _ranked = rankRelatedDefects(widget.relatedContext);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customCatalogueProvider);
    _ensureRanked();
    final results = searchRelatedDefects(ranked: _ranked, query: _query);
    return Theme(
      // No divider lines from the default ExpansionTile theme — this
      // sits inside an already-bordered `_AttributedBlock`-style card.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('other-possible-defects-${widget.keyId}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Other possible defects',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TextField(
              key: ValueKey('related-defect-search-${widget.keyId}'),
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search all defects (e.g. "sliding door", "rusty")',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            key: ValueKey('related-defect-results-${widget.keyId}'),
            height: 280,
            child: results.isEmpty
                ? const Center(child: Text('No matching defects found.'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      return ListTile(
                        key: ValueKey(
                          'related-defect-${widget.keyId}-${entry.id}',
                        ),
                        dense: true,
                        title: Text(entry.defectDescription),
                        subtitle: Text(
                          '${entry.mainElementName} · ${entry.componentName}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _confirm(context, entry),
                      );
                    },
                  ),
          ),
          // Not in the list? Add it to this company's own catalogue —
          // never to the ProDefact master catalogue.
          Text(
            "Still can't find what you're looking for?",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('add-custom-defect-${widget.keyId}'),
              onPressed: () async {
                final entry = await showAddCustomDefectDialog(
                  context,
                  initialDescription: _query,
                );
                if (entry == null || !context.mounted) return;
                widget.onSelected(entry);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
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
            key: const ValueKey('confirm-related-defect'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use This Defect'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    widget.onSelected(entry);
  }
}
