import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../providers/active_session_providers.dart';
import 'top_up_screen.dart';

/// The "Analyse" action on an `awaitingApproval` finding: shows the
/// real, server-computed AI cost estimate ("Up to N Credits") and asks
/// the inspector to explicitly approve before anything runs — this is
/// the only place [ActiveInspectionSession.approveAndRunAnalysis] is
/// ever called from the UI. See docs/commercial_model.md ("The
/// estimate -> approval -> reservation -> settlement protocol").
Future<void> showAnalyseApprovalDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String findingId,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
    ),
  );

  AnalysisEstimate? estimate;
  try {
    estimate = await ref
        .read(activeSessionProvider.notifier)
        .estimateFindingAnalysis(findingId);
  } finally {
    if (context.mounted) Navigator.of(context).pop(); // close the spinner
  }

  if (!context.mounted) return;
  if (estimate == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not check pricing'),
        content: const Text(
          'Check your connection and try again — physical inspection is '
          'never affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  if (!estimate.eligible) {
    await _showIneligibleDialog(context, estimate);
    return;
  }

  final approvedLevel = await showDialog<AiLevel>(
    context: context,
    builder: (context) => _EstimateApprovalDialog(
      findingId: findingId,
      initialEstimate: estimate!,
    ),
  );
  if (approvedLevel == null || !context.mounted) return;

  ref
      .read(activeSessionProvider.notifier)
      .approveAndRunAnalysis(findingId, aiLevel: approvedLevel);
}

Future<void> _showIneligibleDialog(
  BuildContext context,
  AnalysisEstimate estimate,
) async {
  final showTopUp =
      estimate.reason == EstimateIneligibleReason.insufficientCredits;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Not enough Credits'),
      content: Text(_reasonMessage(estimate)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not Now'),
        ),
        if (showTopUp)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(TopUpScreen.routePath);
            },
            child: const Text('Top Up to Analyse'),
          ),
      ],
    ),
  );
}

String _reasonMessage(AnalysisEstimate estimate) {
  return switch (estimate.reason) {
    EstimateIneligibleReason.insufficientCredits =>
      '${estimate.maximumCredits} Credits required, '
          '${estimate.currentBalance} Credits available. Physical '
          'inspection is never affected — you can still classify this '
          'finding manually.',
    EstimateIneligibleReason.housePassAllowanceReached =>
      "This inspection's House Pass allowance has been used up. Top up "
          'with Flex Credits to keep analysing.',
    EstimateIneligibleReason.housePassNotActive =>
      "This inspection's House Pass isn't active yet.",
    EstimateIneligibleReason.unknown ||
    null => 'AI analysis is not available for this finding right now.',
  };
}

String _levelLabel(AiLevel level) => switch (level) {
  AiLevel.fast => 'Fast',
  AiLevel.smart => 'Smart',
  AiLevel.expert => 'Expert',
};

/// The approval dialog itself — lets the inspector switch AI level for
/// just this one finding (re-checking the real price on every change;
/// never computed client-side) before approving. Returns the approved
/// [AiLevel] via `Navigator.pop`, or null if cancelled/dismissed.
class _EstimateApprovalDialog extends ConsumerStatefulWidget {
  const _EstimateApprovalDialog({
    required this.findingId,
    required this.initialEstimate,
  });

  final String findingId;
  final AnalysisEstimate initialEstimate;

  @override
  ConsumerState<_EstimateApprovalDialog> createState() =>
      _EstimateApprovalDialogState();
}

class _EstimateApprovalDialogState
    extends ConsumerState<_EstimateApprovalDialog> {
  late AnalysisEstimate _estimate = widget.initialEstimate;
  bool _reestimating = false;

  Future<void> _selectLevel(AiLevel level) async {
    if (level == _estimate.aiLevel) return;
    setState(() => _reestimating = true);
    final next = await ref
        .read(activeSessionProvider.notifier)
        .estimateFindingAnalysis(widget.findingId, aiLevel: level);
    if (!mounted) return;
    setState(() {
      if (next != null) _estimate = next;
      _reestimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(commercialConfigProvider);
    final creditsPerMyr = configAsync.value?.creditsPerMyr;
    final housePassIncludedLevel = configAsync.value?.housePass.includedAiLevel;
    final finding = ref
        .watch(activeSessionProvider)
        ?.findings
        .firstWhereOrNull((f) => f.id == widget.findingId);
    final evidencePhoto = finding?.evidence.firstOrNull;

    final estimate = _estimate;
    final levelLabel = _levelLabel(estimate.aiLevel);
    final isSurcharge =
        estimate.paymentMode == CommercialMode.housePass &&
        !estimate.includedInHousePass &&
        estimate.surchargeCredits > 0;

    return AlertDialog(
      title: Text('$levelLabel AI'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evidencePhoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.file(
                  File(evidencePhoto.filePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SegmentedButton<AiLevel>(
            segments: [
              for (final level in AiLevel.values)
                ButtonSegment(value: level, label: Text(_levelLabel(level))),
            ],
            selected: {estimate.aiLevel},
            onSelectionChanged: _reestimating
                ? null
                : (selection) => _selectLevel(selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_reestimating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (estimate.includedInHousePass)
            const Text('Included in your House Pass — no Credits charged.')
          else if (isSurcharge) ...[
            Text(
              'House Pass includes ${_levelLabel(housePassIncludedLevel ?? AiLevel.smart)} '
              'AI.',
            ),
            const SizedBox(height: 4),
            Text('$levelLabel: +${estimate.surchargeCredits} Credits'),
          ] else ...[
            Text('Up to: ${estimate.maximumCredits} Credits'),
            if (creditsPerMyr != null && creditsPerMyr > 0) ...[
              const SizedBox(height: 4),
              Text(
                '≈ RM${(estimate.maximumCredits / creditsPerMyr).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Balance: ${estimate.currentBalance} Credits',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: _reestimating
              ? null
              : () => Navigator.of(context).pop(estimate.aiLevel),
          child: Text(
            isSurcharge
                ? 'Use $levelLabel · +${estimate.surchargeCredits} Credits'
                : 'Analyse with AI',
          ),
        ),
      ],
    );
  }
}
