import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/billing/firebase_billing_service.dart';
import 'package:prodefact/data/billing/firestore_wallet_activity_service.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/usage_details_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';

import '../support/test_repository.dart';

/// A wallet whose history includes a pre-Token Credits entry.
class _LegacyHistoryBilling extends FakeBillingService {
  _LegacyHistoryBilling() : super(initialBalanceTokens: 125840000);

  @override
  Future<List<WalletTransactionSummary>> loadRecentTransactions(
    String uid, {
    int limit = 30,
  }) async => [
    WalletTransactionSummary(
      id: 'legacy_credits_to_tokens_v1',
      type: WalletTransactionType.legacyMigration,
      direction: LedgerDirection.credit,
      amountTokens: 7340000,
      description: '734 Credits converted to 7340000 Tokens (same RM value)',
      createdAt: DateTime(2026, 10, 11),
    ),
    WalletTransactionSummary(
      id: 'old_topup',
      type: WalletTransactionType.topup,
      direction: LedgerDirection.credit,
      amountTokens: 0,
      legacyAmountCredits: 1000,
      description: 'Top Up — RM10',
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  @override
  Future<List<UsageRecordSummary>> loadUsageRecords(
    String uid, {
    int limit = 100,
  }) async => [
    UsageRecordSummary(
      id: 'job_1',
      operationType: 'aiAnalysis',
      tokensCharged: 9146,
      aiAnalysisTokens: 7000,
      storageTokens: 1000,
      processingTokens: 900,
      otherTokens: 246,
      createdAt: DateTime(2026, 10, 11),
      inspectionId: 'session_x',
    ),
  ];
}

void main() {
  group('Token formatting (integer-only)', () {
    test('balances in the hundreds of millions are grouped', () {
      expect(formatTokenCount(125840000), '125,840,000');
      expect(formatTokenCount(1000000), '1,000,000');
      expect(formatTokenCount(999), '999');
      expect(formatTokenCount(0), '0');
      expect(formatTokens(1), '1 Token');
      expect(formatTokens(9146), '9,146 Tokens');
    });

    test('RM value: 1,000,000 Tokens = RM1 (display only, integer maths)', () {
      expect(kTokensPerMyr, 1000000);
      expect(tokensAsMyr(125840000), 'RM125.84');
      expect(tokensAsMyr(10000000), 'RM10.00');
      expect(tokensAsMyr(1000000000), 'RM1,000.00');
      expect(tokensAsMyr(9146), '< RM0.01');
      expect(tokensAsMyr(0), 'RM0.00');
    });
  });

  group('legacy Credits migration (reads)', () {
    test('a wallet the backend has not migrated yet reads at its Token value '
        '(100 Credits = RM1); a migrated wallet reads Tokens directly', () {
      expect(tokenBalanceOf({'balanceCredits': 734}), 7340000);
      expect(
        tokenBalanceOf({'balanceTokens': 125840000, 'balanceCredits': 734}),
        125840000,
      );
      expect(tokenBalanceOf(null), 0);
    });

    test('a usage record parses into whole-Token categories that sum to the '
        'charge', () {
      final record = parseUsageRecord('job_1', {
        'operationType': 'aiAnalysis',
        'tokensCharged': 9146,
        'tokensByCategory': {
          'aiAnalysis': 7000,
          'storage': 1000,
          'processing': 900,
          'other': 246,
        },
        'createdAt': 1791700000000,
        'inspectionId': 'session_1',
      });
      expect(record.tokensCharged, 9146);
      expect(
        record.aiAnalysisTokens +
            record.storageTokens +
            record.processingTokens +
            record.otherTokens,
        record.tokensCharged,
      );
      expect(record.inspectionId, 'session_1');
    });

    test('callables are parsed in Tokens', () {
      final config = parseCommercialConfig({
        'tokensPerMyr': 1000000,
        'lowBalanceThresholdTokens': 5000000,
        'topUpPackages': [
          {'myr': 100, 'tokens': 100000000},
        ],
        'aiLevels': [
          {
            'id': 'smart',
            'label': 'Smart',
            'description': 'd',
            'maximumTokens': 27952,
          },
        ],
        'housePass': {
          'enabled': true,
          'priceMyr': 30,
          'includedAiLevel': 'smart',
          'allowanceFindings': 200,
          'isProductionReady': false,
        },
      });
      expect(config.tokensPerMyr, 1000000);
      expect(config.topUpPackages.single.tokens, 100000000);
      expect(config.aiLevels.single.maximumTokens, 27952);
    });

    test('a wallet cache row written before Tokens is ignored, so a Credits '
        'figure is never shown as Tokens', () async {
      final repository = createInMemoryRepository();
      addTearDown(repository.close);
      final db = repository.database;
      await db
          .into(db.walletCacheRows)
          .insert(
            WalletCacheRowsCompanion.insert(
              id: 'local',
              balanceCredits: 734,
              updatedAt: DateTime(2026, 9, 1),
            ),
          );
      expect(await repository.loadWalletCache(), isNull);

      await repository.saveWalletCache(
        WalletCache(balanceTokens: 125840000, updatedAt: DateTime(2026, 10)),
      );
      final cache = await repository.loadWalletCache();
      expect(cache!.balanceTokens, 125840000);
      expect(
        (await (db.select(db.walletCacheRows)).getSingle()).balanceTokens,
        125840000,
      );
    });
  });

  testWidgets('Home shows a 100M+ Token balance grouped, with its RM value',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          billingService: FakeBillingService(initialBalanceTokens: 125840000),
        ),
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('125,840,000 Tokens'), findsOneWidget);
    expect(find.text('≈ RM125.84'), findsOneWidget);
    expect(find.textContaining('Credit'), findsNothing);
  });

  testWidgets('Wallet: Token balance, legacy Credits history shown as Credits '
      '(never re-priced), and Usage details by category and inspection', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    final billing = _LegacyHistoryBilling();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(billingService: billing),
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOKEN BALANCE'), findsOneWidget);
    expect(find.text('125,840,000 Tokens'), findsOneWidget);
    expect(find.text('+1,000 Credits'), findsOneWidget);
    expect(find.textContaining('before Tokens'), findsOneWidget);
    expect(find.textContaining('Total used: 9,146 Tokens'), findsOneWidget);
  });

  testWidgets('Usage details shows the four plain categories and usage by '
      'inspection', (tester) async {
    final billing = _LegacyHistoryBilling();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(billingService: billing),
        child: const MaterialApp(home: UsageDetailsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('usage-total')), findsOneWidget);
    expect(find.text('9,146 Tokens'), findsOneWidget);
    for (final label in [
      'AI Analysis',
      'Storage',
      'Processing',
      'Other infrastructure',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('usage-inspection-session_x')),
        findsOneWidget);
  });
}
