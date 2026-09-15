import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';

/// Shows the add/edit finding dialog. Pass [sectionId] and [elementId]
/// (and, optionally, [componentId]) to add a new finding; pass
/// [existing] to edit one — its description/notes are pre-filled and
/// its area/element/component references are left untouched.
///
/// Evidence (photos) can only be attached once a finding already exists
/// — the "Add finding" dialog saves description/notes first; reopen the
/// finding via "Edit" to attach or remove photos.
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

  await showDialog<void>(
    context: context,
    builder: (_) => _FindingDialog(
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      existing: existing,
    ),
  );
}

class _FindingDialog extends ConsumerStatefulWidget {
  const _FindingDialog({
    this.sectionId,
    this.elementId,
    this.componentId,
    this.existing,
  });

  final String? sectionId;
  final String? elementId;
  final String? componentId;
  final Finding? existing;

  @override
  ConsumerState<_FindingDialog> createState() => _FindingDialogState();
}

class _FindingDialogState extends ConsumerState<_FindingDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isNew => widget.existing == null;

  @override
  Widget build(BuildContext context) {
    // Re-read the finding from provider state (rather than
    // widget.existing) so evidence add/remove is reflected live while
    // this dialog stays open.
    final liveFinding = _isNew
        ? null
        : ref
              .watch(inspectionFindingsProvider)
              .firstWhereOrNull((f) => f.id == widget.existing!.id);

    return AlertDialog(
      title: Text(_isNew ? 'Add finding' : 'Edit finding'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descriptionController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Defect / observation',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Inspector notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_isNew)
              Text(
                'Save this finding to attach photos.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              _EvidenceSection(finding: liveFinding ?? widget.existing!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: Text(_isNew ? 'Add' : 'Save')),
      ],
    );
  }

  void _save() {
    final notifier = ref.read(inspectionFindingsProvider.notifier);
    if (_isNew) {
      notifier.addFinding(
        sectionId: widget.sectionId!,
        elementId: widget.elementId!,
        componentId: widget.componentId,
        description: _descriptionController.text,
        notes: _notesController.text,
      );
    } else {
      notifier.updateFinding(
        findingId: widget.existing!.id,
        description: _descriptionController.text,
        notes: _notesController.text,
      );
    }
    Navigator.of(context).pop();
  }
}

class _EvidenceSection extends ConsumerWidget {
  const _EvidenceSection({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos (${finding.evidence.length})',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pickEvidence(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        if (finding.evidence.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: finding.evidence.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final evidence = finding.evidence[index];
                return _EvidenceThumbnail(
                  evidence: evidence,
                  onRemove: () => ref
                      .read(activeSessionProvider.notifier)
                      .removeEvidence(
                        findingId: finding.id,
                        evidenceId: evidence.id,
                      ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _pickEvidence(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<EvidenceSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(EvidenceSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(EvidenceSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await ref
        .read(activeSessionProvider.notifier)
        .addEvidence(findingId: finding.id, source: source);
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({required this.evidence, required this.onRemove});

  final Evidence evidence;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final file = File(evidence.filePath);
    final fileExists = file.existsSync();
    return Stack(
      children: [
        Semantics(
          label: fileExists
              ? 'Evidence photo'
              : 'Evidence photo unavailable — the file is missing',
          image: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: fileExists
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            tooltip: 'Remove photo',
            icon: const Icon(Icons.cancel, size: 20),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
