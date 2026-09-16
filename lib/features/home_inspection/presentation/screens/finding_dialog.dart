import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';

/// Shows the add/edit finding sheet. Pass [sectionId] and [elementId]
/// (and, optionally, [componentId]) to add a new finding; pass
/// [existing] to edit one — its description/notes are pre-filled and
/// its area/element/component references are left untouched.
///
/// Evidence (photos) can only be attached once a finding already exists
/// — the "Add finding" sheet saves description/notes first; reopen the
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

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FindingSheet(
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      existing: existing,
    ),
  );
}

class _FindingSheet extends ConsumerStatefulWidget {
  const _FindingSheet({
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
  ConsumerState<_FindingSheet> createState() => _FindingSheetState();
}

class _FindingSheetState extends ConsumerState<_FindingSheet> {
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
    // this sheet stays open.
    final liveFinding = _isNew
        ? null
        : ref
              .watch(inspectionFindingsProvider)
              .firstWhereOrNull((f) => f.id == widget.existing!.id);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew ? 'Add finding' : 'Edit finding',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isNew)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Save this finding to attach photos.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _EvidenceSection(finding: liveFinding ?? widget.existing!),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _descriptionController,
                autofocus: _isNew,
                decoration: const InputDecoration(
                  labelText: 'Defect / observation',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Inspector notes'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_isNew ? 'Add' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pickEvidence(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        SizedBox(
          height: 104,
          child: finding.evidence.isEmpty
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(
                      'No photos yet',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              : ListView.separated(
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 96,
              height: 96,
              child: fileExists
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceMuted,
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
