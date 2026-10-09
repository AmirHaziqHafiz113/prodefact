import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../providers/session_detail_providers.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'inspection_sessions_screen.dart';
import 'profile_screen.dart';
import 'property_type_selection_screen.dart';
import 'review_inbox_screen.dart';
import 'top_up_screen.dart';
import 'wallet_screen.dart';

/// The Home tab — the at-a-glance starting point, NOT another
/// inspections list. Each block has its own destination:
///
/// - the active inspection → **Continue Inspection** (its Overview);
/// - **Needs review** rows → that inspection's AI Review (the Review tab
///   when there are several);
/// - **Latest report** → that inspection's Report;
/// - **Start New Inspection** → New Inspection setup;
/// - the credits card → Wallet;
/// - **View all inspections** → the Inspections tab.
///
/// Every figure comes from the same real data the other screens show.
/// See docs/ux_architecture.md.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  static const routePath = '/home-inspection/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sessionSummariesProvider);
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(sessionSummariesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              120,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(profileAsync.value?.inspectorName),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          formatInspectionDate(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  AppAvatar(
                    displayName: profileAsync.value?.inspectorName,
                    email: authState.value?.email,
                    onTap: () => context.go(ProfileScreen.routePath),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              summariesAsync.when(
                loading: () => const AppSkeletonCardList(count: 2),
                error: (error, stackTrace) => AppErrorView(
                  message: 'Could not load your inspections.',
                  onRetry: () => ref.invalidate(sessionSummariesProvider),
                ),
                data: (sessions) => _HomeBody(sessions: sessions),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(String? inspectorName) {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : (hour < 17 ? 'afternoon' : 'evening');
    final firstName = inspectorName?.trim().isNotEmpty == true
        ? inspectorName!.trim().split(RegExp(r'\s+')).first
        : null;
    return firstName == null
        ? 'Good $timeOfDay'
        : 'Good $timeOfDay, $firstName';
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.sessions});

  final List<InspectionSessionSummary> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attention = ref.watch(attentionSessionsProvider);
    final pendingSyncCount = ref.watch(totalPendingSyncCountProvider);

    final byRecent = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final active = byRecent.firstWhereOrNull(
      (s) => s.status == InspectionStatus.inProgress,
    );
    final latestReport = byRecent.firstWhereOrNull(
      (s) =>
          s.status == InspectionStatus.reported ||
          s.status == InspectionStatus.aiReviewComplete,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sessions.isEmpty)
          const _WelcomeCard()
        else if (active != null)
          _ActiveInspectionHero(summary: active)
        else
          const _NoActiveCard(),
        if (active != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('home-start-new'),
            onPressed: () =>
                context.push(PropertyTypeSelectionScreen.routePath),
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Start New Inspection'),
          ),
        ],
        if (attention.isNotEmpty || pendingSyncCount > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Needs attention',
            trailing: attention.length > 1
                ? TextButton(
                    onPressed: () => context.go(ReviewInboxScreen.routePath),
                    child: const Text('Review inbox'),
                  )
                : null,
          ),
          AppGroupedList(
            children: [
              for (final summary in attention.take(3))
                _AttentionRow(summary: summary),
              if (pendingSyncCount > 0)
                _SyncPendingRow(count: pendingSyncCount),
            ],
          ),
        ],
        if (latestReport != null) ...[
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Latest report'),
          _LatestReportCard(summary: latestReport),
        ],
        const SizedBox(height: AppSpacing.xl),
        const _CreditsCard(),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            key: const ValueKey('home-view-all'),
            onPressed: () => context.go(InspectionSessionsScreen.routePath),
            icon: const Icon(Icons.list_alt_outlined),
            label: Text('View all inspections (${sessions.length})'),
          ),
        ],
      ],
    );
  }
}

/// First run: what the app is for and the one thing to do.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined, size: 36),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No inspections yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Set up a property, walk each area, and photograph defects — '
            'AI classifies every photo while you keep working.',
            style: TextStyle(color: AppColors.onHeroSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          _HeroButton(
            key: const ValueKey('home-start-first'),
            label: 'Start New Inspection',
            icon: Icons.add_home_work_outlined,
            onPressed: () =>
                context.push(PropertyTypeSelectionScreen.routePath),
          ),
        ],
      ),
    );
  }
}

class _NoActiveCard extends StatelessWidget {
  const _NoActiveCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No inspection in progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('home-start-new'),
              onPressed: () =>
                  context.push(PropertyTypeSelectionScreen.routePath),
              icon: const Icon(Icons.add_home_work_outlined),
              label: const Text('Start New Inspection'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A white button for the dark hero surface.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDark,
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// The most recently updated in-progress inspection: photo, identity,
/// real area progress, and Continue Inspection (→ its Overview).
class _ActiveInspectionHero extends ConsumerWidget {
  const _ActiveInspectionHero({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sessionDetailProvider(summary.id)).value;
    final physical = detail == null ? null : PhysicalProgress.of(detail);
    final subtitle = [
      if (summary.unitNumber?.isNotEmpty == true) 'Unit ${summary.unitNumber}',
      summary.propertyAddress,
    ].whereType<String>().join(' · ');

    // The whole card and its button share ONE destination: the
    // inspection's Overview.
    return InkWell(
      key: const ValueKey('home-active-hero'),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => resumeAndOpenInspection(context, ref, summary.id),
      child: AppHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CONTINUE WHERE YOU LEFT OFF',
              style: TextStyle(
                color: AppColors.onHeroMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppPropertyPhoto(
                  photoPath: summary.coverPhotoPath,
                  kind: illustrationKindFor(summary.assetTypeId),
                  width: 64,
                  height: 64,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summaryTitle(summary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onHero,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onHeroSecondary,
                            fontSize: 13,
                          ),
                        ),
                      Text(
                        'Updated ${formatRelativeTime(summary.updatedAt)}',
                        style: const TextStyle(
                          color: AppColors.onHeroMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: physical?.fraction ?? 0,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                physical == null
                    ? 'Loading progress…'
                    : physical.totalAreas == 0
                    ? 'No areas started yet'
                    : '${physical.completed} of ${physical.totalAreas} areas '
                          'complete',
                '${summary.findingsCount} finding'
                    '${summary.findingsCount == 1 ? '' : 's'}',
                if (summary.aiPendingReviewCount > 0)
                  '${summary.aiPendingReviewCount} to review',
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.onHeroSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HeroButton(
              key: const ValueKey('home-continue'),
              label: 'Continue Inspection',
              icon: Icons.arrow_forward,
              onPressed: () =>
                  resumeAndOpenInspection(context, ref, summary.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// One inspection waiting on the inspector — opens its AI Review
/// (only the findings that need a decision), not its Overview.
class _AttentionRow extends ConsumerWidget {
  const _AttentionRow({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFailed = summary.aiFailedFindingsCount > 0;
    final message = isFailed
        ? '${summary.aiFailedFindingsCount} AI ${summary.aiFailedFindingsCount == 1 ? 'analysis' : 'analyses'} failed'
        : '${summary.aiPendingReviewCount} finding${summary.aiPendingReviewCount == 1 ? '' : 's'} pending review';

    return AppActionRow(
      key: ValueKey('home-attention-${summary.id}'),
      icon: isFailed ? Icons.error_outline : Icons.rate_review_outlined,
      iconColor: isFailed ? AppColors.danger : AppColors.warning,
      title: summaryTitle(summary),
      subtitle: message,
      onTap: () => resumeAndOpenReview(context, ref, summary.id),
    );
  }
}

/// The aggregate "N items waiting to sync" row — real evidence-photo
/// counts from [totalPendingSyncCountProvider], matching the wording
/// and cloud icon the per-session sync strip already uses. Opens the
/// Inspections list (each card carries its own sync state and a "Sync
/// now" action) since it isn't tied to a single session.
class _SyncPendingRow extends StatelessWidget {
  const _SyncPendingRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      icon: Icons.cloud_sync_outlined,
      iconColor: AppColors.warning,
      title: '$count item${count == 1 ? '' : 's'} waiting to sync',
      subtitle: 'Saved on this device — syncs when online',
      onTap: () => context.go(InspectionSessionsScreen.routePath),
    );
  }
}

/// The most recent inspection with a report (or one ready to generate)
/// — opens the existing Report screen for it.
class _LatestReportCard extends ConsumerWidget {
  const _LatestReportCard({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generated = summary.status == InspectionStatus.reported;
    return Card(
      key: const ValueKey('home-latest-report'),
      clipBehavior: Clip.antiAlias,
      child: AppActionRow(
        icon: Icons.picture_as_pdf_outlined,
        iconColor: generated ? AppColors.success : AppColors.info,
        title: summaryTitle(summary),
        subtitle: generated
            ? 'Report generated · ${formatRelativeTime(summary.updatedAt)}'
            : 'Report ready to generate',
        trailing: AppStatusChip(
          status: generated ? AppStatus.completed : AppStatus.reportReady,
          label: generated ? 'Completed' : 'Ready',
        ),
        onTap: () => resumeAndOpenReport(context, ref, summary.id),
      ),
    );
  }
}

/// A compact usage/balance card: the row opens Wallet; Top Up is its one
/// button.
class _CreditsCard extends ConsumerWidget {
  const _CreditsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final cache = ref.watch(walletCacheProvider).value;
    final creditsPerMyr = ref
        .watch(commercialConfigProvider)
        .value
        ?.creditsPerMyr;
    final balance = balanceAsync.value ?? cache?.balanceCredits;

    return Card(
      key: const ValueKey('home-credits'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(WalletScreen.routePath),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.bolt_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI credits',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    balance == null
                        ? Text(
                            balanceAsync.hasError ? 'Unavailable' : 'Loading…',
                            style: Theme.of(context).textTheme.titleMedium,
                          )
                        : AppAnimatedNumber(
                            value: balance,
                            suffix: ' credits',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                    if (balance != null &&
                        creditsPerMyr != null &&
                        creditsPerMyr > 0)
                      Text(
                        '≈ RM${(balance / creditsPerMyr).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                ),
                onPressed: () => context.push(TopUpScreen.routePath),
                child: const Text('Top Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
