import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../config/property_type.dart';
import '../../providers/session_detail_providers.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/attention_sheet.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'inspection_sessions_screen.dart';
import 'profile_screen.dart';
import 'top_up_screen.dart';
import 'wallet_screen.dart';

/// The Home tab: a greeting, a compact Credits summary, the single
/// most relevant active inspection shown as a rich progress hero, real
/// "needs attention" items, and a couple of recent inspections — with
/// inspection work still the primary entry point (New Inspection stays
/// one tap away via the shared "+" action, never duplicated here).
/// Every figure here comes from the same data the Inspections list and
/// Wallet screen already show; nothing is fabricated for this
/// dashboard. See docs/commercial_model.md and
/// docs/ui_design_system.md.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  static const routePath = '/home-inspection/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(sessionSummariesProvider);
    final balanceAsync = ref.watch(walletBalanceProvider);
    final cacheAsync = ref.watch(walletCacheProvider);
    final configAsync = ref.watch(commercialConfigProvider);
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final attention = ref.watch(attentionSessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTopBar(
              attentionCount: attention.length,
              onAttentionTap: () => showAttentionSheet(context, ref),
              displayName: profileAsync.value?.inspectorName,
              email: authState.value?.email,
              onAvatarTap: () => context.push(ProfileScreen.routePath),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _greeting(profileAsync.value?.inspectorName),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              "Let's keep your inspections moving.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _CreditsCard(
              balanceAsync: balanceAsync,
              cacheAsync: cacheAsync,
              creditsPerMyr: configAsync.value?.creditsPerMyr,
              onTopUp: () => context.push(TopUpScreen.routePath),
              onViewUsage: () => context.go(WalletScreen.routePath),
            ),
            const SizedBox(height: AppSpacing.lg),
            summariesAsync.when(
              loading: () => const AppSkeletonCardList(count: 1),
              error: (error, stackTrace) => AppErrorView(
                message: 'Could not load your inspections.',
                onRetry: () => ref.invalidate(sessionSummariesProvider),
              ),
              data: (sessions) =>
                  _HomeBody(sessions: sessions, attention: attention),
            ),
          ],
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

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({
    required this.balanceAsync,
    required this.cacheAsync,
    required this.creditsPerMyr,
    required this.onTopUp,
    required this.onViewUsage,
  });

  final AsyncValue<int> balanceAsync;
  final AsyncValue<WalletCache?> cacheAsync;
  final int? creditsPerMyr;
  final VoidCallback onTopUp;
  final VoidCallback onViewUsage;

  @override
  Widget build(BuildContext context) {
    final resolvedBalance =
        balanceAsync.value ?? cacheAsync.value?.balanceCredits;
    // Compact by design — this is a secondary summary, not Home's hero;
    // the active inspection below (when there is one) carries that role.
    // The row itself opens Wallet ("View Usage"); Top Up is the one
    // explicit button, so it never has to compete with a second one.
    // A soft brand-tinted surface (not the full dark hero treatment)
    // gives it real financial-product presence without competing with
    // the Active Inspection hero below.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewUsage,
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
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI CREDITS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryDark,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    resolvedBalance == null
                        ? Text(
                            balanceAsync.hasError ? 'Unavailable' : 'Loading…',
                            style: Theme.of(context).textTheme.titleMedium,
                          )
                        : AppAnimatedNumber(
                            value: resolvedBalance,
                            suffix: ' credits',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                    if (resolvedBalance != null &&
                        creditsPerMyr != null &&
                        creditsPerMyr! > 0)
                      Text(
                        '≈ RM${(resolvedBalance / creditsPerMyr!).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                onPressed: onTopUp,
                child: const Text('Top Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.sessions, required this.attention});

  final List<InspectionSessionSummary> sessions;
  final List<InspectionSessionSummary> attention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const AppEmptyView(
        icon: Icons.fact_check_outlined,
        title: 'No inspections yet',
        message: 'Start your first inspection with the + button below.',
      );
    }

    final activeSessions = sessions.where((s) => !s.isComplete).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final mostRelevant = activeSessions.firstOrNull;

    final recent = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentExcludingHero = recent
        .where((s) => s.id != mostRelevant?.id)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostRelevant != null)
          _ActiveInspectionHero(summary: mostRelevant)
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('No active inspection right now.'),
                  ),
                ],
              ),
            ),
          ),
        if (attention.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Needs attention',
            trailing: TextButton(
              onPressed: () => showAttentionSheet(context, ref),
              child: const Text('View all'),
            ),
          ),
          AppGroupedList(
            children: [
              for (final summary in attention.take(2))
                _AttentionListRow(summary: summary),
            ],
          ),
        ],
        if (recentExcludingHero.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Recent inspections',
            trailing: TextButton(
              onPressed: () => context.go(InspectionSessionsScreen.routePath),
              child: const Text('View all'),
            ),
          ),
          for (final summary in recentExcludingHero)
            _RecentInspectionTile(summary: summary),
        ],
      ],
    );
  }
}

/// A short, human relative timestamp ("2h ago", "Just now") — real
/// data (`summary.updatedAt`), never an estimate.
String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = dateTime.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

class _ActiveInspectionHero extends ConsumerWidget {
  const _ActiveInspectionHero({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(sessionDetailProvider(summary.id));
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final title = summary.propertyTitle?.isNotEmpty == true
        ? summary.propertyTitle!
        : (propertyType?.label ?? summary.assetTypeId);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => resumeAndOpenInspection(context, ref, summary.id),
      child: AppHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppPropertyIllustration(
                  kind: propertyType == PropertyType.landed
                      ? AppPropertyIllustrationKind.landed
                      : AppPropertyIllustrationKind.highRise,
                  size: 48,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.onHero),
                      ),
                      Text(
                        [
                          summary.unitNumber,
                          propertyType?.label,
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onHeroSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'Updated ${_relativeTime(summary.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onHeroMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Flexible(child: SessionLifecyclePillWhite()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            detailAsync.maybeWhen(
              data: (session) {
                if (session == null) return const SizedBox.shrink();
                final physical = PhysicalProgress.of(session);
                final ai = AiProcessingProgress.of(session);
                final review = AiReviewProgress.of(session);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    AppRingProgress(
                      value: physical.fraction,
                      label:
                          'Physical\n${physical.completed} of ${physical.totalAreas}',
                      color: Colors.white,
                      size: 76,
                    ),
                    AppRingProgress(
                      value: ai.fraction,
                      label:
                          'AI Analysed\n${ai.processed} of ${ai.totalEligible}',
                      color: Colors.white70,
                      size: 76,
                    ),
                    AppRingProgress(
                      value: review.fraction,
                      label: 'Reviewed\n${review.resolved} of ${review.total}',
                      color: Colors.white70,
                      size: 76,
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox(
                height: 76,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [SessionLifecyclePill] doesn't fit a dark hero background (its
/// background tints assume the light surface) — this renders the same
/// [sessionLifecyclePresentation] label with a translucent-white pill
/// instead, only used on [_ActiveInspectionHero]. An in-progress
/// session is the only status this hero ever actually shows (it only
/// ever renders for `!isComplete` summaries), so a single fixed label
/// is correct here rather than the full four-way switch.
class SessionLifecyclePillWhite extends StatelessWidget {
  const SessionLifecyclePillWhite({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'In Progress',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttentionListRow extends ConsumerWidget {
  const _AttentionListRow({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final title = summary.propertyTitle?.isNotEmpty == true
        ? summary.propertyTitle!
        : (propertyType?.label ?? summary.assetTypeId);
    final isFailed = summary.aiFailedFindingsCount > 0;
    final message = isFailed
        ? '${summary.aiFailedFindingsCount} AI ${summary.aiFailedFindingsCount == 1 ? 'analysis' : 'analyses'} failed'
        : '${summary.aiPendingReviewCount} finding${summary.aiPendingReviewCount == 1 ? '' : 's'} pending review';

    final color = isFailed ? AppColors.danger : AppColors.warning;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFailed ? Icons.error_outline : Icons.rate_review_outlined,
          size: 18,
          color: color,
        ),
      ),
      title: Text(title),
      subtitle: Text(message),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => resumeAndOpenInspection(context, ref, summary.id),
    );
  }
}

class _RecentInspectionTile extends ConsumerWidget {
  const _RecentInspectionTile({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final title = summary.propertyTitle?.isNotEmpty == true
        ? summary.propertyTitle!
        : (propertyType?.label ?? summary.assetTypeId);
    final (_, _, accentColor, _) = sessionLifecyclePresentation(summary.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppInspectionCard(
        title: title,
        subtitle: [
          summary.propertyAddress,
          '${propertyType?.label ?? ''} · ${_relativeTime(summary.updatedAt)}',
        ].whereType<String>().join(' · '),
        illustrationKind: propertyType == PropertyType.landed
            ? AppPropertyIllustrationKind.landed
            : AppPropertyIllustrationKind.highRise,
        statusPill: SessionLifecyclePill(status: summary.status),
        accentColor: accentColor,
        dense: true,
        onTap: () => resumeAndOpenInspection(context, ref, summary.id),
      ),
    );
  }
}
