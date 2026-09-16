import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';

/// The "Change" action: a searchable/filterable picker over the
/// **controlled defect catalogue** — the inspector selects an entry,
/// never types a technical defect name. Calling
/// [ActiveInspectionSession.changeSuggestion] with the chosen catalogue
/// id moves the suggestion to [AiSuggestionStatus.edited]; the AI's
/// original `suggested*` values are never touched by this dialog — see
/// `AiSuggestion`.
Future<void> showAiSuggestionReviewDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AiSuggestion suggestion,
}) async {
  final chosenId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CataloguePickerSheet(),
  );
  if (chosenId == null) return;
  ref
      .read(activeSessionProvider.notifier)
      .changeSuggestion(suggestion.id, chosenId);
}

/// The "Classify Manually" action on a `failed` finding — same
/// searchable catalogue picker, but for a finding with no `AiSuggestion`
/// at all yet (the classification attempt itself errored before AI
/// returned anything) — see
/// [ActiveInspectionSession.manuallyClassifyFinding].
Future<void> showManualClassificationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String findingId,
}) async {
  final chosenId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CataloguePickerSheet(),
  );
  if (chosenId == null) return;
  ref
      .read(activeSessionProvider.notifier)
      .manuallyClassifyFinding(findingId, chosenId);
}

class _CataloguePickerSheet extends StatefulWidget {
  const _CataloguePickerSheet();

  @override
  State<_CataloguePickerSheet> createState() => _CataloguePickerSheetState();
}

class _CataloguePickerSheetState extends State<_CataloguePickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = DefectCatalogue.instance.search(_query);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search defects (e.g. "leaking tap")',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('No matching defects found.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final entry = results[index];
                          return ListTile(
                            title: Text(entry.defectDescription),
                            subtitle: Text(
                              '${entry.mainElementName} / '
                              '${entry.componentName}',
                            ),
                            onTap: () => Navigator.of(context).pop(entry.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
