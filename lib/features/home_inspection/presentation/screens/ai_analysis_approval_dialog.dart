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
  // AI needs a quick defect note first (QA #16); the finding card offers
  // "Add Note" instead of "Analyse" until one exists.
  final finding = ref
      .read(activeSessionProvider)
      ?.findings
      .firstWhereOrNull((f) => f.id == findingId);
  if (finding == null || !finding.hasDefectNote) return;

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
    builder: (context) =>
        _EstimateApprovalDialog(findingId: findingId, estimate: estimate!),
  );
  if (approved != true || !context.mounted) return;

  ref
      .read(activeSessionProvider.notifier)
      .approveAndRunAnalysis(findingId, aiLevel: kFieldAnalysisAiLevel);
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

/// The approval dialog — Smart AI only (QA #24): no Fast/Smart/Expert
/// choice and no billing-mechanism choice (QA #23). It shows the real,
/// server-computed cost for this finding and asks once. Pops `true` to
/// approve, or null if dismissed. Inspectors who don't want to be asked
/// per finding turn on Auto Analyse for the inspection instead.
class _EstimateApprovalDialog extends ConsumerWidget {
  const _EstimateApprovalDialog({
    required this.findingId,
    required this.estimate,
  });

  final String findingId;
  final AnalysisEstimate estimate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(commercialConfigProvider);
    final creditsPerMyr = configAsync.value?.creditsPerMyr;
    final finding = ref
        .watch(activeSessionProvider)
        ?.findings
        .firstWhereOrNull((f) => f.id == findingId);
    final evidencePhoto = finding?.evidence.firstOrNull;
    final chargedCredits = estimate.paymentMode == CommercialMode.housePass
        ? estimate.surchargeCredits
        : estimate.maximumCredits;

    return AlertDialog(
      title: const Text('Smart AI'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (evidencePhoto != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                // `maxFinite`, not `infinity`: AlertDialog measures its
                // content's intrinsic width, which an infinite width
                // can't answer.
                child: SizedBox(
                  width: double.maxFinite,
                  height: 160,
                  child: Image.file(
                    File(evidencePhoto.displayFilePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (estimate.includedInHousePass || chargedCredits == 0)
              const Text('Included with this inspection. No Credits charged.')
            else ...[
              Text('Up to $chargedCredits Credits'),
              if (creditsPerMyr != null && creditsPerMyr > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '≈ RM${(chargedCredits / creditsPerMyr).toStringAsFixed(2)}',
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Analyse'),
        ),
      ],
    );
  }
}
