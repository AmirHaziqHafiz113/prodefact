import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';

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
class RelatedDefectSelector extends StatefulWidget {
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
  State<RelatedDefectSelector> createState() => _RelatedDefectSelectorState();
}

class _RelatedDefectSelectorState extends State<RelatedDefectSelector> {
  final _controller = TextEditingController();
  late final List<DefectCatalogueEntry> _ranked = rankRelatedDefects(
    widget.relatedContext,
  );
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
