import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/billing/billing_providers.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/remote_providers.dart';

/// The real, authoritative Credits balance — read fresh from
/// [walletActivityServiceProvider] every time, and opportunistically
/// written through to the local [WalletCache] so the next app open has
/// something to show instantly/offline before this resolves. Never the
/// other way around: the cache is never treated as authoritative here.
final walletBalanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  final balance = await ref
      .watch(walletActivityServiceProvider)
      .loadBalance(uid);
  await ref
      .watch(inspectionRepositoryProvider)
      .saveWalletCache(
        WalletCache(balanceCredits: balance, updatedAt: DateTime.now()),
      );
  return balance;
});

/// The last-known balance cached locally — shown instantly (e.g. while
/// [walletBalanceProvider] is still loading, or offline) but never used
/// for a pricing/eligibility decision. See `WalletCache`'s doc comment.
final walletCacheProvider = FutureProvider.autoDispose<WalletCache?>((ref) {
  return ref.watch(inspectionRepositoryProvider).loadWalletCache();
});

/// Most-recent-first ledger entries for the Wallet screen's activity
/// feed and usage graph.
final walletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletTransactionSummary>>((ref) async {
      final uid = ref.watch(authStateProvider).value?.uid ?? '';
      return ref
          .watch(walletActivityServiceProvider)
          .loadRecentTransactions(uid, limit: 30);
    });
