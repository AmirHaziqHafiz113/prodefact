import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

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
        body: const Center(child: Text('No active inspection.')),
      );
    }

    final report = session.report;
    final isStale = report?.isStaleRelativeTo(session.updatedAt) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Report generation failed: $_errorMessage',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (isStale)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Inspection data has changed since this report was '
                'generated. Regenerate for an up-to-date report.',
              ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI review is complete. Generate the Home Inspection '
              'report using the inspector-approved findings.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 12),
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
