import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/session_list_providers.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'property_type_selection_screen.dart';

/// Managing every inspection job: search, status filters (All, Draft,
/// Active, Needs Review, Report Ready, Completed) and one card per
/// property. Tapping a card opens that inspection's Overview. Sessions
/// save and work fully offline — sign-in only unlocks sync. Starting an
/// inspection is the shared "+" action (and Home's Start New
/// Inspection); account actions live in Profile.
class InspectionSessionsScreen extends ConsumerWidget {
  const InspectionSessionsScreen({super.key});

  static const routePath = '/home-inspection/sessions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider);

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
          data: (sessions) => _DashboardBody(sessions: sessions),
        ),
      ),
    );
  }
}

/// The header any state (loading/error/data) shows — so a loading/error
/// state still looks like part of the same screen.
class _ScreenScaffold extends StatelessWidget {
  const _ScreenScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inspections', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          'Every property job, from draft to completed report.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

enum _DashboardFilter {
  all,
  draft,
  inProgress,
  needsReview,
  reportReady,
  completed,
}

bool _matches(_DashboardFilter filter, InspectionSessionSummary s) =>
    switch (filter) {
      _DashboardFilter.all => true,
      _DashboardFilter.draft => s.isDraft,
      // Drafts are in progress too — "Draft" just narrows to them.
      _DashboardFilter.inProgress => s.status == InspectionStatus.inProgress,
      _DashboardFilter.needsReview => s.needsAttention,
      _DashboardFilter.reportReady =>
        s.status == InspectionStatus.aiReviewComplete,
      _DashboardFilter.completed => s.status == InspectionStatus.reported,
    };

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.sessions});

  final List<InspectionSessionSummary> sessions;

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
    final sessions = [...widget.sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

    final searched = sessions.where(matchesQuery).toList();
    final filtered = searched.where((s) => _matches(_filter, s)).toList();
    final filterCounts = {
      for (final option in _DashboardFilter.values)
        option: searched.where((s) => _matches(option, s)).length,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        120,
      ),
      children: [
        const _Header(),
        const SizedBox(height: AppSpacing.lg),
        if (sessions.isNotEmpty) ...[
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
                    key: ValueKey('session-filter-${option.name}'),
                    label: Text(
                      '${_filterLabel(option)} (${filterCounts[option]})',
                    ),
                    selected: _filter == option,
                    onSelected: (_) => setState(() => _filter = option),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (sessions.isEmpty)
          AppEmptyView(
            icon: Icons.assignment_outlined,
            title: 'No inspections yet',
            message:
                'Start your first inspection — set up the property, then '
                'photograph defects area by area.',
            actionLabel: 'Start New Inspection',
            onAction: () => context.push(PropertyTypeSelectionScreen.routePath),
          )
        else if (filtered.isEmpty)
          AppEmptyView(
            icon: Icons.search_off_outlined,
            title: 'No matching inspections',
            message: _query.isNotEmpty
                ? 'Nothing matches "$_query". Try a different search.'
                : 'No inspections are ${_filterLabel(_filter).toLowerCase()} '
                      'right now.',
            actionLabel: 'Show all',
            onAction: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _filter = _DashboardFilter.all;
              });
            },
          )
        else
          for (final summary in filtered) _SessionCard(summary: summary),
      ],
    );
  }

  String _filterLabel(_DashboardFilter filter) => switch (filter) {
    _DashboardFilter.all => 'All',
    _DashboardFilter.draft => 'Draft',
    // Deliberately "Active", not "In Progress" — the latter is also the
    // matching sessions' own status chip label, and having the exact
    // same string do double duty as both a filter chip and a status
    // label makes narrowing a `find.text(...)` lookup in tests
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
    final (status, statusLabel) = sessionCardStatus(summary);
    final unresolved =
        summary.aiPendingReviewCount + summary.aiFailedFindingsCount;
    final aiTotal = summary.aiEligibleFindingsCount;
    // Real, derived — never fabricated (a per-area fraction needs a full
    // session load per card): the share of analysed findings already
    // settled; a report-ready or completed inspection is 100%.
    final settled =
        (summary.aiProcessedFindingsCount - summary.aiPendingReviewCount).clamp(
          0,
          aiTotal,
        );
    final (double? progress, String? progressLabel) = switch (summary.status) {
      InspectionStatus.reported => (1.0, 'Report generated'),
      InspectionStatus.aiReviewComplete => (1.0, 'Ready for report'),
      _ when aiTotal == 0 => (null, null),
      _ => (settled / aiTotal, '$settled of $aiTotal settled'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppInspectionCard(
        title: summaryTitle(summary),
        subtitle: [
          if (summary.unitNumber?.isNotEmpty == true)
            'Unit ${summary.unitNumber}',
          summary.propertyAddress,
        ].whereType<String>().join(' · '),
        illustrationKind: illustrationKindFor(summary.assetTypeId),
        photoPath: summary.coverPhotoPath,
        statusPill: AppStatusChip(status: status, label: statusLabel),
        dateLabel: formatInspectionDate(
          summary.inspectionDate ?? summary.createdAt,
        ),
        progress: progress,
        progressLabel: progressLabel,
        findingsCount: summary.findingsCount,
        unresolvedCount: unresolved,
        onTap: () => resumeAndOpenInspection(context, ref, summary.id),
        syncStatus: summary.syncStatus,
        pendingSyncCount: summary.pendingSyncCount,
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
