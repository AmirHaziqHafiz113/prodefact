import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../../auth/presentation/sign_in_screen.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/session_list_providers.dart';
import 'property_type_selection_screen.dart';

/// Lists locally-saved Home Inspection sessions so the inspector can
/// resume an unfinished one or start a new inspection. This is the
/// minimal "home screen" Phase 4 needs to make resume behavior usable
/// and testable — not a full dashboard.
///
/// Phase 5 adds a minimal sign-in affordance and a per-session sync
/// status/"Sync now" action. Neither is required to use the app —
/// sessions save and work fully offline either way.
class InspectionSessionsScreen extends ConsumerWidget {
  const InspectionSessionsScreen({super.key});

  static const routePath = '/home-inspection/sessions';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(sessionSummariesProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Inspections'),
        actions: [_AuthAction(authState: authState)],
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load saved inspections: $error')),
        data: (sessions) => sessions.isEmpty
            ? const Center(child: Text('No saved inspections yet.'))
            : ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final summary = sessions[index];
                  final propertyTypeLabel = PropertyType.values
                      .firstWhereOrNull((p) => p.name == summary.assetTypeId)
                      ?.label;
                  final canSync =
                      authState.value != null &&
                      (summary.ownerUid == null ||
                          summary.ownerUid == authState.value!.uid);
                  return ListTile(
                    title: Text(propertyTypeLabel ?? summary.assetTypeId),
                    subtitle: Text(_formatUpdatedAt(summary.updatedAt)),
                    leading: _SyncStatusIcon(status: summary.syncStatus),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            summary.isComplete ? 'Completed' : 'Unfinished',
                          ),
                          backgroundColor:
                              (summary.isComplete
                                      ? Colors.green
                                      : Colors.orange)
                                  .withValues(alpha: 0.15),
                        ),
                        IconButton(
                          tooltip: canSync
                              ? 'Sync now'
                              : 'Sign in to sync this inspection',
                          icon: const Icon(Icons.cloud_sync_outlined),
                          onPressed: canSync
                              ? () => _syncOne(context, ref, summary.id)
                              : null,
                        ),
                      ],
                    ),
                    onTap: () => _resume(context, ref, summary.id),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PropertyTypeSelectionScreen.routePath),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    await ref.read(activeSessionProvider.notifier).resume(sessionId);
    if (!context.mounted) return;
    context.push('/home-inspection/inspection');
  }

  Future<void> _syncOne(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
  ) async {
    final result = await ref
        .read(syncCoordinatorProvider)
        .syncSession(sessionId);
    ref.invalidate(sessionSummariesProvider);
    if (!context.mounted) return;
    final message = result.isSuccess
        ? 'Synced.'
        : 'Sync failed: ${result.message ?? result.outcome.name}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip, color) = switch (status) {
      SyncStatus.localOnly => (
        Icons.cloud_off_outlined,
        'Local only',
        Colors.grey,
      ),
      SyncStatus.pendingCreate || SyncStatus.pendingUpdate => (
        Icons.cloud_sync_outlined,
        'Sync pending',
        Colors.orange,
      ),
      SyncStatus.pendingDelete => (
        Icons.cloud_sync_outlined,
        'Delete pending',
        Colors.orange,
      ),
      SyncStatus.synced => (Icons.cloud_done_outlined, 'Synced', Colors.green),
    };
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }
}
