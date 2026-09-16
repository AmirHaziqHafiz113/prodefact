import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';

/// Reached once AI review is complete (every suggestion resolved) —
/// see `docs/report.md` for the full report gate and lifecycle this
/// screen drives: generate, preview, share/export, and regenerate if
/// the underlying inspection data changes afterward.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  static const routePath = '/home-inspection/report';

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No active inspection.',
        ),
      );
    }

    final report = session.report;
    final isStale = report?.isStaleRelativeTo(session.updatedAt) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Column(
        children: [
          if (_errorMessage != null)
            AppInlineErrorBanner(
              message: 'Report generation failed: $_errorMessage',
              onDismiss: () => setState(() => _errorMessage = null),
            ),
          if (isStale)
            const AppInlineWarningBanner(
              message:
                  'Inspection data has changed since this report was '
                  'generated. Regenerate for an up-to-date report.',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _ReadinessCard(session: session, report: report),
          ),
          Expanded(
            child: report == null
                ? _NotGeneratedView(
                    isGenerating: _isGenerating,
                    onGenerate: _generate,
                  )
                : _ReportReadyView(
                    filePath: report.filePath,
                    isGenerating: _isGenerating,
                    onRegenerate: _generate,
                    onShare: () =>
                        ref.read(activeSessionProvider.notifier).shareReport(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(activeSessionProvider.notifier)
        .generateReport();

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _errorMessage = result.isSuccess ? null : _messageFor(result);
    });
  }

  String _messageFor(ReportGenerationResult result) {
    return switch (result.outcome) {
      ReportGenerationOutcome.physicalInspectionIncomplete =>
        'Physical inspection is not complete yet.',
      ReportGenerationOutcome.aiReviewIncomplete =>
        'AI review is not complete yet.',
      ReportGenerationOutcome.sessionNotFound => 'Inspection not found.',
      ReportGenerationOutcome.failure => result.message ?? 'Unknown error.',
      ReportGenerationOutcome.success => '',
    };
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.session, required this.report});

  final InspectionSession session;
  final Report? report;

  @override
  Widget build(BuildContext context) {
    final areaCount = session.sections.where((s) => s.isIncluded).length;
    final findingCount = session.findings.length;
    final photoCount = session.findings.fold<int>(
      0,
      (sum, f) => sum + f.evidence.length,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReadinessStat(
                    icon: Icons.map_outlined,
                    value: '$areaCount',
                    label: 'Areas',
                  ),
                ),
                Expanded(
                  child: _ReadinessStat(
                    icon: Icons.report_gmailerrorred_outlined,
                    value: '$findingCount',
                    label: 'Findings',
                  ),
                ),
                Expanded(
                  child: _ReadinessStat(
                    icon: Icons.photo_camera_outlined,
                    value: '$photoCount',
                    label: 'Photos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            report == null
                ? const StatusPill(
                    label: 'Not generated',
                    icon: Icons.description_outlined,
                    foreground: AppColors.textSecondary,
                    background: AppColors.neutralBg,
                    dense: true,
                  )
                : StatusPill(
                    label:
                        'Generated ${_formatGeneratedAt(report!.generatedAt)}',
                    icon: Icons.check_circle_outline,
                    foreground: AppColors.success,
                    background: AppColors.successBg,
                    dense: true,
                  ),
          ],
        ),
      ),
    );
  }

  String _formatGeneratedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }
}

class _ReadinessStat extends StatelessWidget {
  const _ReadinessStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _NotGeneratedView extends StatelessWidget {
  const _NotGeneratedView({
    required this.isGenerating,
    required this.onGenerate,
  });

  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'AI review is complete. Generate the Home Inspection '
              'report using the inspector-approved findings.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isGenerating ? null : onGenerate,
              child: isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate Report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportReadyView extends StatelessWidget {
  const _ReportReadyView({
    required this.filePath,
    required this.isGenerating,
    required this.onRegenerate,
    required this.onShare,
  });

  final String filePath;
  final bool isGenerating;
  final VoidCallback onRegenerate;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PdfPreview(
            build: (format) async {
              final file = File(filePath);
              if (!await file.exists()) return Uint8List(0);
              return file.readAsBytes();
            },
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: false,
            allowPrinting: false,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isGenerating ? null : onRegenerate,
                    child: isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Regenerate'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: onShare,
                    child: const Text('Share / Export'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
