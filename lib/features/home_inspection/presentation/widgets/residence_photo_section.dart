import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';

/// The optional "Residence / Unit Photo" (report cover) controls, shared by
/// New Inspection setup and Report Details. It only displays [path] and
/// reports the inspector's choice — every screen reads and writes the SAME
/// underlying photo (the session's report metadata, or the setup draft that
/// becomes it), so there is exactly one source of truth.
///
/// This is NOT a defect photo: choosing one never creates a finding, never
/// runs defect AI and never appears in Area Findings or AI Review.
class ResidencePhotoSection extends StatelessWidget {
  const ResidencePhotoSection({
    super.key,
    required this.path,
    required this.onChoose,
    required this.onRemove,
    this.busy = false,
  });

  /// The current photo's local path, or null for none (the report shows its
  /// placeholder then).
  final String? path;

  /// Called with the chosen source (camera / gallery).
  final void Function(EvidenceSource source) onChoose;
  final VoidCallback onRemove;

  /// A pick is in progress (buttons disabled).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final current = path;
    return AppFormSectionCard(
      icon: Icons.photo_outlined,
      title: 'Residence / Unit Photo',
      subtitle: 'Optional — shown on page 1 of the report',
      children: [
        if (current != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ColoredBox(
              color: AppColors.surfaceAlt,
              child: SizedBox(
                key: const ValueKey('residence-photo-preview'),
                height: 160,
                width: double.infinity,
                child: Image.file(
                  File(current),
                  fit: BoxFit.contain,
                  // Bounded decode: a preview never needs the full original.
                  cacheWidth: 1280,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.photo_outlined)),
                ),
              ),
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('residence-photo-gallery'),
              onPressed: busy ? null : () => onChoose(EvidenceSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(current == null ? 'Choose photo' : 'Change photo'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('residence-photo-camera'),
              onPressed: busy ? null : () => onChoose(EvidenceSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
            if (current != null)
              TextButton(
                key: const ValueKey('residence-photo-remove'),
                onPressed: busy ? null : onRemove,
                child: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
