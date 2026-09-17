import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../../auth/presentation/sign_in_screen.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../widgets/attention_sheet.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'profile_screen.dart';

/// ProDefact's dashboard: search/filter, a real-data status strip, and
/// active/needs-attention/recent inspection cards. Sessions save and
/// work fully offline — sign-in only unlocks sync. New Inspection is
/// never duplicated here — the shared "+" bottom-nav action is the one
/// canonical entry point (see `AppShellScreen`).
class InspectionSessionsScreen extends ConsumerWidget {
  const InspectionSessionsScreen({super.key});

  static const routePath = '/home-inspection/sessions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider);
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final attention = ref.watch(attentionSessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: summaries.when(
          loading: () => const _ScreenScaffold(child: AppSkeletonCardList()),
          error: (error, stackTrace) => _ScreenScaffold(
            child: AppErrorView(
              message: 'Could not load saved inspections.',
              onRetry: () => ref.invalidate(sessionSummariesProvider),
            ),
          ),
          data: (sessions) => _DashboardBody(
            sessions: sessions,
            attentionCount: attention.length,
            displayName: profileAsync.value?.inspectorName,
            email: authState.value?.email,
          ),
        ),
      ),
    );
  }
}

/// The header (top bar + title) any state (loading/error/data) shows —
/// so a loading/error state still looks like part of the same screen
/// rather than a bare centered widget.
class _ScreenScaffold extends ConsumerWidget {
  const _ScreenScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(attentionCount: 0, displayName: null, email: null),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.attentionCount,
    required this.displayName,
    required this.email,
  });

  final int attentionCount;
  final String? displayName;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTopBar(
                showBrand: false,
                attentionCount: attentionCount,
                onAttentionTap: () => showAttentionSheet(context, ref),
                displayName: displayName,
                email: email,
                onAvatarTap: () => context.push(ProfileScreen.routePath),
              ),
            ),
            _AuthAction(authState: authState),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Inspections', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          'Track, review and complete your inspections.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

enum _DashboardFilter { all, inProgress, needsReview, reportReady, completed }

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({
    required this.sessions,
    required this.attentionCount,
    required this.displayName,
    required this.email,
  });

  final List<InspectionSessionSummary> sessions;
  final int attentionCount;
  final String? displayName;
  final String? email;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final _searchController = TextEditingController();
  String _query = '';
  _DashboardFilter _filter = _DashboardFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;

    final attention = sessions.where((s) => s.needsAttention).toList();
    final activeCount = sessions.where((s) => !s.isComplete).length;
    final needsReviewCount = sessions
        .where((s) => s.aiPendingReviewCount > 0)
        .length;
    final completedCount = sessions
        .where((s) => s.status == InspectionStatus.reported)
        .length;

    bool matchesQuery(InspectionSessionSummary s) {
      if (_query.isEmpty) return true;
      final propertyType = PropertyType.values.firstWhereOrNull(
        (p) => p.name == s.assetTypeId,
      );
      final haystack = [
        s.propertyTitle,
        s.propertyAddress,
        s.unitNumber,
        propertyType?.label,
        s.assetTypeId,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }

    bool matchesFilter(InspectionSessionSummary s) {
      return switch (_filter) {
        _DashboardFilter.all => true,
        _DashboardFilter.inProgress => s.status == InspectionStatus.inProgress,
        _DashboardFilter.needsReview => s.aiPendingReviewCount > 0,
        _DashboardFilter.reportReady =>
          s.status == InspectionStatus.aiReviewComplete,
        _DashboardFilter.completed => s.status == InspectionStatus.reported,
      };
    }

    final filtered = sessions.where(matchesQuery).where(matchesFilter).toList();
    final active = filtered.where((s) => !s.isComplete).toList();
    final recent = filtered.where((s) => s.isComplete).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Header(
          attentionCount: widget.attentionCount,
          displayName: widget.displayName,
          email: widget.email,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search by property name, address or unit…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in _DashboardFilter.values) ...[
                ChoiceChip(
                  label: Text(_filterLabel(option)),
                  selected: _filter == option,
                  onSelected: (_) => setState(() => _filter = option),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (sessions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.assignment_outlined,
                    value: '$activeCount',
                    label: 'Active',
                    caption: 'In progress',
                    dense: true,
                  ),
                ),
                const SizedBox(
                  height: 44,
                  child: VerticalDivider(width: AppSpacing.lg),
                ),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.priority_high,
                    value: '$needsReviewCount',
                    label: 'Needs Review',
                    caption: 'Awaiting review',
                    iconColor: AppColors.danger,
                    dense: true,
                  ),
                ),
                const SizedBox(
                  height: 44,
                  child: VerticalDivider(width: AppSpacing.lg),
                ),
                Expanded(
                  child: AppMetricCard(
                    icon: Icons.check_circle_outline,
                    value: '$completedCount',
                    label: 'Completed',
                    caption: 'All time',
                    iconColor: AppColors.success,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (sessions.isEmpty)
          const AppEmptyView(
            icon: Icons.assignment_outlined,
            title: 'No inspections yet',
            message: 'Start your first inspection with the + button below.',
          )
        else ...[
          if (attention.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Needs attention',
              subtitle: '${attention.length} inspection(s)',
            ),
            for (final summary in attention) _SessionCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (active.isNotEmpty) ...[
            AppSectionHeader(
              title: 'Active inspections',
              subtitle: '${active.length} in progress',
            ),
            for (final summary in active) _SessionCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (recent.isNotEmpty) ...[
            const AppSectionHeader(title: 'Recent'),
            for (final summary in recent) _SessionCard(summary: summary),
          ],
          if (active.isEmpty && recent.isEmpty && attention.isEmpty)
            const AppEmptyView(
              icon: Icons.search_off_outlined,
              title: 'No matching inspections',
              message: 'Try a different search or filter.',
            ),
        ],
      ],
    );
  }

  String _filterLabel(_DashboardFilter filter) => switch (filter) {
    _DashboardFilter.all => 'All',
    // Deliberately "Active", not "In Progress" — the latter is also
    // this filter's matching sessions' own status pill label
    // (`sessionLifecyclePresentation`), and having the exact same
    // string do double duty as both a filter chip and a status label
    // makes narrowing a `find.text(...)` widget lookup in tests
    // ambiguous.
    _DashboardFilter.inProgress => 'Active',
    _DashboardFilter.needsReview => 'Needs Review',
    _DashboardFilter.reportReady => 'Report Ready',
    _DashboardFilter.completed => 'Completed',
  };
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.summary});

  final InspectionSessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final authState = ref.watch(authStateProvider);
    final canSync =
        authState.value != null &&
        (summary.ownerUid == null || summary.ownerUid == authState.value!.uid);
    final (_, _, accentColor, _) = sessionLifecyclePresentation(summary.status);

    // Real, derived — never fabricated: "review resolved" is processed
    // findings minus those still genuinely pending review, both cheap
    // counts the summary already exposes (see `InspectionSessionSummary`
    // for why a full per-area/per-suggestion fraction isn't available
    // at this list granularity without an expensive per-card load).
    final aiTotal = summary.aiEligibleFindingsCount;
    final aiProcessed = summary.aiProcessedFindingsCount;
    final reviewTotal = aiProcessed;
    final reviewResolved = (aiProcessed - summary.aiPendingReviewCount).clamp(
      0,
      aiProcessed,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppInspectionCard(
        title: summary.propertyTitle?.isNotEmpty == true
            ? summary.propertyTitle!
            : (propertyType?.label ?? summary.assetTypeId),
        subtitle: [
          summary.unitNumber,
          summary.propertyAddress,
        ].whereType<String>().join(' · '),
        illustrationKind: propertyType == PropertyType.highRise
            ? AppPropertyIllustrationKind.highRise
            : AppPropertyIllustrationKind.landed,
        statusPill: SessionLifecyclePill(status: summary.status),
        accentColor: accentColor,
        onTap: () => resumeAndOpenInspection(context, ref, summary.id),
        syncStatus: summary.syncStatus,
        pendingSyncCount: summary.pendingSyncCount,
        physicalComplete: summary.status != InspectionStatus.inProgress,
        aiFraction: aiTotal == 0 ? null : aiProcessed / aiTotal,
        aiFractionLabel: aiTotal == 0 ? null : '$aiProcessed/$aiTotal',
        reviewFraction: reviewTotal == 0 ? null : reviewResolved / reviewTotal,
        reviewFractionLabel: reviewTotal == 0
            ? null
            : '$reviewResolved/$reviewTotal',
        trailing: PopupMenuButton<_SessionAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => switch (action) {
            _SessionAction.sync => _syncOne(context, ref),
            _SessionAction.delete => _confirmDelete(
              context,
              ref,
              propertyType?.label ?? summary.assetTypeId,
            ),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: canSync,
              value: _SessionAction.sync,
              child: const ListTile(
                leading: Icon(Icons.cloud_sync_outlined),
                title: Text('Sync now'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _SessionAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncOne(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(syncCoordinatorProvider)
        .syncSession(summary.id);
    ref.invalidate(sessionSummariesProvider);
    if (!context.mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Synced.')));
      return;
    }
    // Never surface Firestore/Firebase terminology or a raw outcome
    // name — local data is always safe regardless of a sync failure
    // (see docs/firebase.md, "Sync lifecycle").
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "We couldn't sync some changes. Your inspection is still saved "
          'on this device.',
        ),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _syncOne(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete inspection?'),
        content: Text(
          'This permanently deletes the "$label" inspection, its photos, '
          'and its report on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(activeSessionProvider.notifier).deleteSession(summary.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Inspection deleted.')));
  }
}

enum _SessionAction { sync, delete }

class _AuthAction extends ConsumerWidget {
  const _AuthAction({required this.authState});

  final AsyncValue<AuthUser?> authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = authState.value;
    if (user == null) {
      return IconButton(
        tooltip: 'Sign in',
        icon: const Icon(Icons.login),
        onPressed: () => context.push(SignInScreen.routePath),
      );
    }
    return IconButton(
      tooltip: 'Signed in as ${user.email ?? user.uid} — Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(authServiceProvider).signOut(),
    );
  }
}
