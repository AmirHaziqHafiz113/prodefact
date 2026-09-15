import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';

/// Shown for "Edit" or "Reject / Correct" — both let the inspector
/// change element, component, defect type, recommendation, and notes;
/// only the resulting [AiSuggestionStatus] differs (`edited` vs
/// `rejected`). The AI's original `suggested*` values are never touched
/// by this dialog — see `AiSuggestion`.
Future<void> showAiSuggestionReviewDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Section section,
  required AiSuggestion suggestion,
  required bool isReject,
}) async {
  final elements = section.elements;
  String? selectedElementId =
      elements.any((e) => e.id == suggestion.finalElementId)
      ? suggestion.finalElementId
      : (elements.isEmpty ? null : elements.first.id);
  String? selectedComponentId = suggestion.finalComponentId;

  final defectController = TextEditingController(
    text: suggestion.finalDefectType ?? '',
  );
  final recommendationController = TextEditingController(
    text: suggestion.finalRecommendation ?? '',
  );
  final notesController = TextEditingController(
    text: suggestion.finalNotes ?? '',
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final selectedElement = elements.firstWhereOrNull(
          (e) => e.id == selectedElementId,
        );
        final components = selectedElement?.components ?? const [];
        if (!components.any((c) => c.id == selectedComponentId)) {
          selectedComponentId = null;
        }

        return AlertDialog(
          title: Text(isReject ? 'Reject & correct' : 'Edit suggestion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (elements.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedElementId,
                    decoration: const InputDecoration(labelText: 'Element'),
                    items: [
                      for (final element in elements)
                        DropdownMenuItem(
                          value: element.id,
                          child: Text(element.name),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      selectedElementId = value;
                      selectedComponentId = null;
                    }),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedComponentId,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final component in components)
                      DropdownMenuItem(
                        value: component.id,
                        child: Text(component.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedComponentId = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: defectController,
                  decoration: const InputDecoration(labelText: 'Defect type'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: recommendationController,
                  decoration: const InputDecoration(
                    labelText: 'Recommendation',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true) return;

  final notifier = ref.read(activeSessionProvider.notifier);
  if (isReject) {
    notifier.rejectSuggestion(
      suggestion.id,
      elementId: selectedElementId,
      componentId: selectedComponentId,
      defectType: defectController.text,
      recommendation: recommendationController.text,
      notes: notesController.text,
    );
  } else {
    notifier.editSuggestion(
      suggestion.id,
      elementId: selectedElementId,
      componentId: selectedComponentId,
      defectType: defectController.text,
      recommendation: recommendationController.text,
      notes: notesController.text,
    );
  }
}
