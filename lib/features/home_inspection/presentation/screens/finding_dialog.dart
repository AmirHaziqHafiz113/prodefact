import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/physical_inspection_providers.dart';

/// Shows the add/edit finding dialog. Pass [sectionId] and [elementId]
/// (and, optionally, [componentId]) to add a new finding; pass
/// [existing] to edit one — its description/notes are pre-filled and
/// its area/element/component references are left untouched.
Future<void> showFindingDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? sectionId,
  String? elementId,
  String? componentId,
  Finding? existing,
}) async {
  assert(
    existing != null || (sectionId != null && elementId != null),
    'sectionId and elementId are required when adding a new finding',
  );

  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );
  final notesController = TextEditingController(text: existing?.notes ?? '');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(existing == null ? 'Add finding' : 'Edit finding'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: descriptionController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Defect / observation',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Inspector notes'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${existing?.evidence.length ?? 0} photo(s) attached',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(existing == null ? 'Add' : 'Save'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final notifier = ref.read(inspectionFindingsProvider.notifier);
  if (existing == null) {
    notifier.addFinding(
      sectionId: sectionId!,
      elementId: elementId!,
      componentId: componentId,
      description: descriptionController.text,
      notes: notesController.text,
    );
  } else {
    notifier.updateFinding(
      findingId: existing.id,
      description: descriptionController.text,
      notes: notesController.text,
    );
  }
}
