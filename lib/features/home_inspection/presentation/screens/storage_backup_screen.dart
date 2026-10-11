import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../data/backup/drive_backup_coordinator.dart';
import '../../providers/drive_backup_providers.dart';
import '../widgets/session_status_presentation.dart';

/// Profile → Storage & Backup: Google Drive backup of inspection
/// original photos. Shows the connected account, connection status, the
/// Auto Backup switch, waiting/failed uploads and the last successful
/// sync. See docs/drive_backup.md.
class StorageBackupScreen extends ConsumerStatefulWidget {
  const StorageBackupScreen({super.key});

  static const routePath = '/home-inspection/profile/backup';

  @override
  ConsumerState<StorageBackupScreen> createState() =>
      _StorageBackupScreenState();
}

class _StorageBackupScreenState extends ConsumerState<StorageBackupScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(driveBackupOverviewProvider);
    final coordinator = ref.read(driveBackupCoordinatorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Backup')),
      body: overviewAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppSkeletonCardList(count: 2),
        ),
        error: (error, stackTrace) => AppErrorView(
          message: 'Could not load backup status.',
          onRetry: () => ref.invalidate(driveBackupOverviewProvider),
        ),
        data: (overview) {
          final needsReconnect =
              overview.isConnected &&
              overview.blocker == DriveBackupBlocker.auth;
          final (status, statusLabel) = !overview.isConnected
              ? (AppStatus.notStarted, 'Not connected')
              : needsReconnect
              ? (AppStatus.failed, 'Reconnect needed')
              : (AppStatus.confirmed, 'Connected');
          final counts = overview.counts;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Text(
                'Original photos are backed up to your own Google Drive for '
                'long-term storage. ProDefact keeps a working copy for AI '
                'and reports.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.add_to_drive,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Google Drive',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  overview.connectedEmail ??
                                      'No account connected',
                                  key: const ValueKey('drive-account'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          AppStatusChip(status: status, label: statusLabel),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!overview.isConnected || needsReconnect)
                        FilledButton.icon(
                          key: const ValueKey('drive-connect'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => coordinator.connect(),
                                  'Could not connect Google Drive. Please '
                                  'try again.',
                                ),
                          icon: const Icon(Icons.link),
                          label: Text(
                            needsReconnect
                                ? 'Reconnect Google Drive'
                                : 'Connect Google Drive',
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          key: const ValueKey('drive-disconnect'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  coordinator.disconnect,
                                  'Could not disconnect. Please try again.',
                                ),
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'ProDefact can only see the files it creates in your '
                        'Drive — never the rest of it.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  key: const ValueKey('drive-auto-backup'),
                  value: overview.autoBackup,
                  onChanged: _busy
                      ? null
                      : (value) => _run(
                          () => coordinator.setAutoBackup(value),
                          'Could not change Auto Backup.',
                        ),
                  title: const Text('Auto Backup'),
                  subtitle: const Text(
                    'Back up each original photo after it is saved. Never '
                    'slows down capture or AI.',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'Backup status'),
              AppGroupedList(
                children: [
                  _CountRow(
                    key: const ValueKey('drive-waiting'),
                    icon: Icons.schedule,
                    label: 'Waiting to upload',
                    count:
                        counts.waiting + counts.uploading + counts.notStarted,
                    color: AppColors.info,
                  ),
                  _CountRow(
                    key: const ValueKey('drive-failed'),
                    icon: Icons.error_outline,
                    label: 'Failed — retrying automatically',
                    count: counts.failed,
                    color: AppColors.danger,
                  ),
                  _CountRow(
                    icon: Icons.cloud_done_outlined,
                    label: 'Backed up',
                    count: counts.verified,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                overview.lastSuccessAt == null
                    ? 'No successful backup yet.'
                    : 'Last successful backup '
                          '${formatRelativeTime(overview.lastSuccessAt!)}.',
                key: const ValueKey('drive-last-success'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_blockerText(overview) case final text?) ...[
                const SizedBox(height: AppSpacing.sm),
                AppInlineWarningBanner(message: text),
              ],
              if (counts.failed > 0 && overview.isConnected) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const ValueKey('drive-retry'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          coordinator.retryNow,
                          'Could not retry right now.',
                        ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry now'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String? _blockerText(DriveBackupOverview overview) {
    final waiting =
        overview.counts.waiting +
        overview.counts.failed +
        overview.counts.notStarted;
    if (waiting == 0) return null;
    return switch (overview.blocker) {
      DriveBackupBlocker.offline =>
        'You are offline. Photos wait safely and upload when you are back '
            'online.',
      DriveBackupBlocker.auth =>
        'Google Drive access expired. Reconnect to resume backups — nothing '
            'waiting has been lost.',
      DriveBackupBlocker.autoBackupOff =>
        'Auto Backup is off. Turn it on to back up waiting photos.',
      DriveBackupBlocker.notConnected =>
        'Connect Google Drive to back up your original photos.',
      DriveBackupBlocker.none => null,
    };
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text('$count', style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
