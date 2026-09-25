import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'area_inspection_screen.dart' show chooseEvidenceSource;
import 'photo_annotation_screen.dart';

/// Opens every photo of one defect ticket (QA #20), starting at
/// [initialIndex].
Future<void> showFindingPhotos(
  BuildContext context, {
  required String findingId,
  int initialIndex = 0,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          PhotoViewerScreen(findingId: findingId, initialIndex: initialIndex),
    ),
  );
}

/// All photos of one defect, e.g. front angle, side angle, close-up
/// (QA #20). Each photo is shown whole in its own orientation, never
/// cropped or stretched (QA #18), and can be zoomed. From here the
/// inspector can add another angle, mark up a photo (the original is
/// kept; QA #14), view the original of a marked-up photo, or remove one
/// photo without touching the finding or its other photos.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    required this.findingId,
    this.initialIndex = 0,
    super.key,
  });

  final String findingId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _showOriginal = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _markUp(Evidence photo) async {
    final bytes = await showPhotoAnnotation(context, filePath: photo.filePath);
    if (bytes == null || !mounted) return;
    await ref
        .read(activeSessionProvider.notifier)
        .saveEvidenceAnnotation(
          findingId: widget.findingId,
          evidenceId: photo.id,
          pngBytes: bytes,
        );
    if (mounted) setState(() => _showOriginal = false);
  }

  Future<void> _addAngle(int currentCount) async {
    final source = await chooseEvidenceSource(context);
    if (source == null || !mounted) return;
    await ref
        .read(activeSessionProvider.notifier)
        .addEvidence(findingId: widget.findingId, source: source);
    if (!mounted) return;
    // Jump to the newly added photo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(currentCount);
    });
  }

  Future<void> _remove(Evidence photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text(
          'Only this photo is removed. The finding and its other photos '
          'stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove Photo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(activeSessionProvider.notifier)
        .removeEvidence(findingId: widget.findingId, evidenceId: photo.id);
  }

  @override
  Widget build(BuildContext context) {
    final finding = ref
        .watch(activeSessionProvider)
        ?.findings
        .firstWhereOrNull((f) => f.id == widget.findingId);
    final photos = finding?.evidence ?? const <Evidence>[];
    if (finding == null || photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: const AppEmptyView(
          icon: Icons.photo_outlined,
          title: 'No photos for this finding.',
        ),
      );
    }
    final index = _index.clamp(0, photos.length - 1);
    final current = photos[index];
    final canRemove = photos.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${index + 1} of ${photos.length}'),
        actions: [
          if (current.isAnnotated)
            TextButton(
              onPressed: () => setState(() => _showOriginal = !_showOriginal),
              child: Text(_showOriginal ? 'Show Markup' : 'Show Original'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: (value) => setState(() {
                  _index = value;
                  _showOriginal = false;
                }),
                itemBuilder: (context, i) {
                  final photo = photos[i];
                  final path = i == index && _showOriginal
                      ? photo.filePath
                      : photo.displayFilePath;
                  return InteractiveViewer(
                    maxScale: 6,
                    child: Center(
                      child: Image.file(
                        File(path),
                        key: ValueKey('photo-${photo.id}-$path'),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 48,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ViewerAction(
                    icon: Icons.draw_outlined,
                    label: current.isAnnotated ? 'Redo Markup' : 'Mark Up',
                    onPressed: () => _markUp(current),
                  ),
                  _ViewerAction(
                    icon: Icons.add_a_photo_outlined,
                    label: 'Add Angle',
                    onPressed: () => _addAngle(photos.length),
                  ),
                  _ViewerAction(
                    icon: Icons.delete_outline,
                    label: 'Remove Photo',
                    onPressed: canRemove ? () => _remove(current) : null,
                  ),
                ],
              ),
            ),
            if (!canRemove)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'A finding keeps at least one photo. Remove the finding '
                  'instead.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
