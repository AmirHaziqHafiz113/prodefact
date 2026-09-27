import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'report_details_screen.dart';

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
      appBar: AppBar(
        title: const Text('Report'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(ReportDetailsScreen.routePath),
            icon: const Icon(Icons.edit_note_outlined, color: Colors.white),
            label: const Text(
              'Report Details',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      // QA #33: the page must stay scrollable with every action in
      // reach. Before a report exists everything scrolls together; once
      // one exists, the header area scrolls within a capped height so
      // the report preview and its actions always keep space.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final header = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                AppInlineErrorBanner(
                  message: 'Report generation failed: $_errorMessage',
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              if (isStale)
                AppInlineWarningBanner(
                  message:
                      'This inspection has an existing report (v${report!.version}). '
                      'Inspection data has changed since it was generated — '
                      'regenerating will create v${report.version + 1}.',
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
            ],
          );
          if (report == null) {
            return ListView(
              key: const ValueKey('report-scroll'),
              children: [
                header,
                _NotGeneratedView(
                  isGenerating: _isGenerating,
                  onGenerate: _generate,
                ),
              ],
            );
          }
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.45,
                ),
                child: SingleChildScrollView(child: header),
              ),
              Expanded(
                child: _ReportReadyView(
                  filePath: report.filePath,
                  isGenerating: _isGenerating,
                  onRegenerate: _generate,
                  onShare: () =>
                      ref.read(activeSessionProvider.notifier).shareReport(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    // Always reaches a terminal state (QA #33): an unexpected error must
    // never leave "generating" on, which disables every action.
    String? error;
    try {
      final result = await ref
          .read(activeSessionProvider.notifier)
          .generateReport();
      error = result.isSuccess ? null : _messageFor(result);
    } catch (e) {
      error = 'Something went wrong. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _errorMessage = error;
    });
  }

  String _messageFor(ReportGenerationResult result) {
    return switch (result.outcome) {
      ReportGenerationOutcome.physicalInspectionIncomplete =>
        'Physical inspection is not complete yet.',
      ReportGenerationOutcome.aiReviewIncomplete =>
        'AI review is not complete yet.',
      ReportGenerationOutcome.missingContactNumber =>
        'Add the client or agent contact number before generating the '
            'final report.',
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
    final physical = PhysicalProgress.of(session);
    final processing = AiProcessingProgress.of(session);
    final review = AiReviewProgress.of(session);
    final unresolved = session.aiSuggestions
        .where((s) => s.status == AiSuggestionStatus.rejected)
        .length;
    final metadata =
        session.reportMetadata ??
        ReportMetadata.fromPropertyDetails(session.propertyDetails);
    final hasContactNumber = metadata.contactNumber?.trim().isNotEmpty == true;

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
            if (findingCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Findings by area',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              AppBarChart(points: _findingsByArea(session), height: 56),
            ],
            const Divider(height: AppSpacing.xl),
            _ReadinessRow(
              label: 'Physical inspection',
              value: '${physical.completed}/${physical.totalAreas} complete',
              done: physical.completed >= physical.totalAreas,
            ),
            _ReadinessRow(
              label: 'AI analysis',
              value:
                  '${processing.processed}/${processing.totalEligible} '
                  'processed',
              done: processing.inFlight == 0,
            ),
            _ReadinessRow(
              label: 'Review',
              value: '${review.resolved}/${review.total} reviewed',
              done: review.pending == 0,
            ),
            if (unresolved > 0)
              _ReadinessRow(
                label: 'Unresolved',
                value: '$unresolved finding(s)',
                done: false,
                warningOnly: true,
              ),
            _ReadinessRow(
              label: 'Contact number',
              value: hasContactNumber ? 'Added' : 'Required',
              done: hasContactNumber,
            ),
            if (!hasContactNumber) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      context.push(ReportDetailsScreen.routePath),
                  child: const Text('Add contact number'),
                ),
              ),
            ],
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
                        'Generated v${report!.version} · '
                        '${_formatGeneratedAt(report!.generatedAt)}',
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

  /// Real per-area finding counts, in the same plumbing-first order the
  /// rest of the app already uses — never fabricated/estimated. Areas
  /// with zero findings are included too, so an area's absence from
  /// this chart is never mistaken for "not inspected."
  List<AppBarChartPoint> _findingsByArea(InspectionSession session) {
    final included = session.sections.where((s) => s.isIncluded);
    return [
      for (final section in included)
        AppBarChartPoint(
          label: section.name,
          value: session.findings
              .where((f) => f.sectionId == section.id)
              .length
              .toDouble(),
        ),
    ];
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.value,
    required this.done,
    this.warningOnly = false,
  });

  final String label;
  final String value;
  final bool done;

  /// An informational row (e.g. "Unresolved") that's never "done" but
  /// also isn't an in-progress state — shown in warning color rather
  /// than the pending/muted color the other rows use before they're
  /// done.
  final bool warningOnly;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : (warningOnly ? AppColors.warning : AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
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
              'Generate the Home Inspection report from the '
              'inspector-approved findings. The checks above show anything '
              'still outstanding.',
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
