import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import 'inspection_overview_screen.dart';

/// "How to capture a good defect photo" — shown once when a NEW
/// inspection starts (between setup and the inspection itself), never
/// before each photo and never on resume. It can be reopened from the
/// inspection screens' "Photo Guide" action.
///
/// Guidance only: defects differ in location, size, orientation, height,
/// angle and access, so nothing here asks for a fixed angle, distance or
/// framing — the inspector's professional judgement decides.
class PhotoGuideScreen extends StatelessWidget {
  const PhotoGuideScreen({super.key, this.startsInspection = false});

  static const routePath = '/photo-guide';

  /// The first-run route for a new inspection: its button continues
  /// into the inspection (replacing this screen).
  static const startRoutePath = '$routePath?start=1';

  /// True on the first-run route; false when reopened for reference.
  final bool startsInspection;

  static const guidelines = [
    'Capture one defect per image.',
    'Keep the defect reasonably clear and visible.',
    'Avoid excessive blur where possible.',
    'Make sure there is enough lighting to understand the image.',
    'Avoid being unnecessarily far away or extremely close.',
    'Include some surrounding context where useful so the component or '
        'location can be understood.',
    'Add a short inspector note when the defect is difficult to prove '
        'visually.',
  ];

  static const noteExamples = [
    'Hollow tile',
    'Intermittent leak',
    'Loose fitting',
    'Sound-related defect',
    'Touch or test-related defect',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'How to capture a good defect photo',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Good photos help ProDefact understand the defect more '
            'accurately and produce a clearer report.',
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (i, line) in guidelines.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}.', style: textTheme.titleSmall),
                  ),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When the note matters more than the photo',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final example in noteExamples)
                    Text('• $example', style: textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'These are guidance only. Defects appear in different locations, '
            'sizes, orientations, heights and angles, and some are hard to '
            'reach — there is no required angle, distance or framing. Use '
            'your professional judgement.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: () => startsInspection
                ? context.pushReplacement(InspectionOverviewScreen.routePath)
                : Navigator.of(context).maybePop(),
            child: Text(startsInspection ? 'Start Inspection' : 'Got It'),
          ),
        ),
      ),
    );
  }
}

/// The small, non-intrusive way to reopen the guide during an
/// inspection. Never opens it by itself.
class PhotoGuideAction extends StatelessWidget {
  const PhotoGuideAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('photo-guide-action'),
      tooltip: 'Photo Guide',
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push(PhotoGuideScreen.routePath),
    );
  }
}
