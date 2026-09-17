import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../providers/wallet_providers.dart';
import 'top_up_screen.dart';

/// The Wallet tab: real Credits balance, this-month usage stats, a
/// real-data usage-over-time graph, and a human-readable activity feed
/// — see docs/commercial_model.md. Compact by design (inspection work
/// stays primary in the app); nothing here ever computes a price or
/// grants Credits itself.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const routePath = '/home-inspection/wallet';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final cacheAsync = ref.watch(walletCacheProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final configAsync = ref.watch(commercialConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(walletTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _BalanceCard(balanceAsync: balanceAsync, cacheAsync: cacheAsync),
              const SizedBox(height: AppSpacing.md),
              configAsync.maybeWhen(
                data: (config) {
                  final balance =
                      balanceAsync.value ?? cacheAsync.value?.balanceCredits;
                  if (balance == null ||
                      balance >= config.lowBalanceThresholdCredits) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppInlineWarningBanner(
                      message:
                          'Your Credits balance is low. AI analysis will '
                          'ask you to top up before it runs — physical '
                          'inspection is never affected.',
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              FilledButton.icon(
                onPressed: () => context.push(TopUpScreen.routePath),
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Top Up'),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(title: 'This month'),
              const SizedBox(height: AppSpacing.sm),
              transactionsAsync.when(
                loading: () => const AppLoadingView(),
                error: (error, stackTrace) => AppErrorView(
                  message: 'Could not load your wallet activity.',
                  onRetry: () => ref.invalidate(walletTransactionsProvider),
                ),
                data: (transactions) =>
                    _ThisMonthAndUsage(transactions: transactions),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(title: 'Recent activity'),
              const SizedBox(height: AppSpacing.sm),
              transactionsAsync.maybeWhen(
                data: (transactions) => transactions.isEmpty
                    ? const AppEmptyView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No activity yet.',
                      )
                    : Column(
                        children: [
                          for (final transaction in transactions)
                            _ActivityTile(transaction: transaction),
                        ],
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceAsync, required this.cacheAsync});

  final AsyncValue<int> balanceAsync;
  final AsyncValue<WalletCache?> cacheAsync;

  @override
  Widget build(BuildContext context) {
    // Prefer the real, fresh balance; fall back to the local display
    // cache only while that's still loading or unavailable — never the
    // other way around (see docs/commercial_model.md).
    final resolvedBalance =
        balanceAsync.value ?? cacheAsync.value?.balanceCredits;
    final isStale = balanceAsync.value == null && resolvedBalance != null;

    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Credits',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            if (balanceAsync.isLoading && resolvedBalance == null)
              const SizedBox(
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else if (balanceAsync.hasError && resolvedBalance == null)
              Text(
                'Could not load your balance.',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: Colors.white),
              )
            else
              Text(
                '$resolvedBalance Credits',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isStale) ...[
              const SizedBox(height: 4),
              Text(
                'Last known balance — refreshing…',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThisMonthAndUsage extends StatelessWidget {
  const _ThisMonthAndUsage({required this.transactions});

  final List<WalletTransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = transactions.where(
      (t) => t.createdAt.year == now.year && t.createdAt.month == now.month,
    );
    final spent = thisMonth
        .where((t) => t.direction == LedgerDirection.debit)
        .fold<int>(0, (sum, t) => sum + t.amountCredits);
    final analysisCount = thisMonth
        .where((t) => t.type == WalletTransactionType.usage)
        .length;

    // Real Credits spent per day over the last 7 days — never a fake
    // or interpolated series.
    final days = List.generate(
      7,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i)),
    );
    final points = [
      for (final day in days)
        AppBarChartPoint(
          label: _weekdayLabel(day.weekday),
          value: transactions
              .where(
                (t) =>
                    t.direction == LedgerDirection.debit &&
                    t.createdAt.year == day.year &&
                    t.createdAt.month == day.month &&
                    t.createdAt.day == day.day,
              )
              .fold<int>(0, (sum, t) => sum + t.amountCredits)
              .toDouble(),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(label: 'Credits used', value: '$spent'),
            ),
            Expanded(
              child: _StatTile(label: 'Analyses run', value: '$analysisCount'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Usage — last 7 days',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppBarChart(
          points: points,
          emptyMessage: 'No usage in the last 7 days.',
        ),
      ],
    );
  }

  String _weekdayLabel(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.transaction});

  final WalletTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == LedgerDirection.credit;
    final (icon, color) = switch (transaction.type) {
      WalletTransactionType.topup => (
        Icons.add_card_outlined,
        AppColors.success,
      ),
      WalletTransactionType.usage => (Icons.smart_toy_outlined, AppColors.info),
      WalletTransactionType.reservation => (
        Icons.lock_clock_outlined,
        AppColors.textMuted,
      ),
      WalletTransactionType.reservationRelease => (
        Icons.undo_outlined,
        AppColors.textMuted,
      ),
      WalletTransactionType.refund => (
        Icons.replay_outlined,
        AppColors.success,
      ),
      WalletTransactionType.adjustment => (
        Icons.tune_outlined,
        AppColors.textMuted,
      ),
      WalletTransactionType.housePassPurchase => (
        Icons.verified_outlined,
        AppColors.primary,
      ),
      WalletTransactionType.unknown => (
        Icons.receipt_long_outlined,
        AppColors.textMuted,
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(transaction.description),
        subtitle: Text(_formatDate(transaction.createdAt)),
        trailing: transaction.amountCredits == 0
            ? null
            : Text(
                '${isCredit ? '+' : '-'}${transaction.amountCredits}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isCredit ? AppColors.success : AppColors.textPrimary,
                ),
              ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
