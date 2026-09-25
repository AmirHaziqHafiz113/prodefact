import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../config/property_type.dart';
import '../../providers/session_list_providers.dart';
import 'app_bottom_sheet.dart';
import 'session_navigation.dart';

/// The bell icon's destination on Home/Wallet — real, currently-open
/// items only (a pending AI review or a failed classification; see
/// `attentionSessionsProvider`), never a fabricated notifications feed.
/// Tapping a row resumes that inspection directly.
Future<void> showAttentionSheet(BuildContext context, WidgetRef ref) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => const _AttentionSheet(),
  );
}

class _AttentionSheet extends ConsumerWidget {
  const _AttentionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(attentionSessionsProvider);
    return AppSheetFrame(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Needs attention',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text("You're all caught up — nothing needs attention."),
              )
            else
              for (final summary in items) _AttentionRow(summary: summary),
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final title = summary.propertyTitle?.isNotEmpty == true
        ? summary.propertyTitle!
        : (propertyType?.label ?? summary.assetTypeId);
    final message = summary.aiFailedFindingsCount > 0
        ? '${summary.aiFailedFindingsCount} AI ${summary.aiFailedFindingsCount == 1 ? 'analysis' : 'analyses'} failed'
        : '${summary.aiPendingReviewCount} finding${summary.aiPendingReviewCount == 1 ? '' : 's'} pending review';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.dangerBg,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.priority_high,
          color: AppColors.danger,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text(message),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pop();
        resumeAndOpenInspection(context, ref, summary.id);
      },
    );
  }
}
