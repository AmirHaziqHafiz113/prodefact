import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
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

  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => _EstimateApprovalDialog(estimate: estimate!),
  );
  if (approved != true || !context.mounted) return;

  ref
      .read(activeSessionProvider.notifier)
      .approveAndRunAnalysis(findingId, aiLevel: estimate.aiLevel);
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
      content: Text(_reasonMessage(estimate.reason)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        if (showTopUp)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(TopUpScreen.routePath);
            },
            child: const Text('Top Up'),
          ),
      ],
    ),
  );
}

String _reasonMessage(EstimateIneligibleReason? reason) {
  return switch (reason) {
    EstimateIneligibleReason.insufficientCredits =>
      "You don't have enough Credits for this analysis. Physical "
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

class _EstimateApprovalDialog extends StatelessWidget {
  const _EstimateApprovalDialog({required this.estimate});

  final AnalysisEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final levelLabel = switch (estimate.aiLevel) {
      AiLevel.fast => 'Fast',
      AiLevel.smart => 'Smart',
      AiLevel.expert => 'Expert',
    };

    return AlertDialog(
      title: const Text('Analyse with AI'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Level: $levelLabel'),
          const SizedBox(height: AppSpacing.sm),
          if (estimate.includedInHousePass)
            const Text('Included in your House Pass — no Credits charged.')
          else
            Text(
              'Up to ${estimate.maximumCredits} Credits — the exact '
              'amount depends on what AI actually uses, and you are never '
              'charged more than this.',
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Current balance: ${estimate.currentBalance} Credits',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
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
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
