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
import 'property_type_selection_screen.dart';

/// ProDefact's dashboard: active/recent inspection cards, a strong
/// "New Inspection" call to action, and a minimal sign-in affordance.
/// Sessions save and work fully offline — sign-in only unlocks sync.
class InspectionSessionsScreen extends ConsumerWidget {
  const InspectionSessionsScreen({super.key});

  static const routePath = '/home-inspection/sessions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspections'),
        actions: [_AuthAction(authState: authState)],
      ),
      body: SafeArea(
        child: summaries.when(
          loading: () => const AppLoadingView(message: 'Loading inspections…'),
          error: (error, stackTrace) => AppErrorView(
            message: 'Could not load saved inspections.',
            onRetry: () => ref.invalidate(sessionSummariesProvider),
          ),
          data: (sessions) => _DashboardBody(sessions: sessions, ref: ref),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PropertyTypeSelectionScreen.routePath),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.sessions, required this.ref});

  final List<InspectionSessionSummary> sessions;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const AppEmptyView(
        icon: Icons.assignment_outlined,
        title: 'No saved inspections yet.',
        message: 'Tap "New Inspection" below to get started.',
      );
    }

    final active = sessions.where((s) => !s.isComplete).toList();
    final recent = sessions.where((s) => s.isComplete).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        96,
      ),
      children: [
        if (active.isNotEmpty) ...[
          AppSectionHeader(
            title: 'Active inspections',
            subtitle: '${active.length} in progress',
          ),
          for (final summary in active)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SessionCard(summary: summary, ref: ref),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (recent.isNotEmpty) ...[
          const AppSectionHeader(title: 'Completed'),
          for (final summary in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SessionCard(summary: summary, ref: ref),
            ),
        ],
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.summary, required this.ref});

  final InspectionSessionSummary summary;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == summary.assetTypeId,
    );
    final authState = ref.watch(authStateProvider);
    final canSync =
        authState.value != null &&
        (summary.ownerUid == null || summary.ownerUid == authState.value!.uid);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _resume(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  propertyType == PropertyType.highRise
                      ? Icons.apartment_outlined
                      : Icons.house_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyType?.label ?? summary.assetTypeId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatUpdatedAt(summary.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        StatusPill(
                          label: summary.isComplete
                              ? 'Completed'
                              : 'Unfinished',
                          icon: summary.isComplete
                              ? Icons.check_circle_outline
                              : Icons.pending_outlined,
                          foreground: summary.isComplete
                              ? AppColors.success
                              : AppColors.warning,
                          background: summary.isComplete
                              ? AppColors.successBg
                              : AppColors.warningBg,
                          dense: true,
                        ),
                        SyncStatusPill(status: summary.syncStatus, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: canSync
                    ? 'Sync now'
                    : 'Sign in to sync this inspection',
                icon: const Icon(Icons.cloud_sync_outlined),
                onPressed: canSync ? () => _syncOne(context, ref) : null,
              ),
              IconButton(
                tooltip: 'Delete inspection',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(
                  context,
                  ref,
                  propertyType?.label ?? summary.assetTypeId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final resumed = await ref
        .read(activeSessionProvider.notifier)
        .resume(summary.id);
    if (!context.mounted) return;
    if (!resumed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open that inspection. Please try again.'),
        ),
      );
      return;
    }
    context.push('/home-inspection/inspection');
  }

  Future<void> _syncOne(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(syncCoordinatorProvider)
        .syncSession(summary.id);
    ref.invalidate(sessionSummariesProvider);
    if (!context.mounted) return;
    final message = result.isSuccess
        ? 'Synced.'
        : 'Sync failed: ${result.message ?? result.outcome.name}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  String _formatUpdatedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Last updated ${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

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
