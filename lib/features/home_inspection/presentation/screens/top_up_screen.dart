import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/commercial_error_presentation.dart';

/// Top Up: choose an RM amount, see the Credits it buys, and create a
/// payment intent. **No real payment gateway is configured for this
/// project** (see docs/commercial_model.md, "Payment architecture") —
/// completing a top-up via [BillingService.confirmSandboxPayment] is
/// only ever offered in a debug build (`kDebugMode`, a compile-time
/// constant that's `false` — and this whole branch unreachable — in any
/// release build), and even then the backend itself refuses to confirm
/// anything unless it's deployed with `PAYMENTS_MODE=sandbox`. A
/// release build has no path to a fake top-up success at all.
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  static const routePath = '/home-inspection/wallet/top-up';

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  double? _selectedMyr;
  final _customAmountController = TextEditingController();
  TopUpIntent? _intent;
  bool _creatingIntent = false;
  bool _confirming = false;
  String? _error;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(commercialConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Top Up')),
      body: SafeArea(
        child: configAsync.when(
          loading: () => const AppLoadingView(),
          error: (error, stackTrace) => AppErrorView(
            message:
                'Could not load top-up options. Check your '
                'connection and try again.',
            onRetry: () => ref.invalidate(commercialConfigProvider),
          ),
          data: (config) => _buildContent(context, config),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CommercialConfig config) {
    if (_intent != null) {
      return _buildIntentSummary(context, _intent!);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Choose an amount',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final package in config.topUpPackages)
              ChoiceChip(
                label: Text(
                  'RM${package.myr.toStringAsFixed(0)} · '
                  '${package.credits} Credits',
                ),
                selected: _selectedMyr == package.myr,
                onSelected: (_) => setState(() {
                  _selectedMyr = package.myr;
                  _customAmountController.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Or enter a custom amount (RM)'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _customAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'RM '),
          onChanged: (value) => setState(() {
            _selectedMyr = double.tryParse(value);
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${config.creditsPerMyr} Credits per RM1 — the exact amount is '
          'confirmed by the server, never calculated on this device.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInlineErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed:
              (_selectedMyr != null && _selectedMyr! > 0 && !_creatingIntent)
              ? _createIntent
              : null,
          child: _creatingIntent
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Proceed to Payment'),
        ),
      ],
    );
  }

  Widget _buildIntentSummary(BuildContext context, TopUpIntent intent) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'RM${intent.amountMyr.toStringAsFixed(0)} top-up',
            subtitle: 'You will receive ${intent.creditsAmount} Credits',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            AppInlineErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (kDebugMode) ...[
            // Debug/test builds only — see the class doc comment. This
            // branch is dead code (and compiled out) in any release
            // build, and even here the backend independently refuses to
            // confirm anything unless it's deployed with
            // PAYMENTS_MODE=sandbox.
            Card(
              color: AppColors.warningBg,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug build — sandbox payment',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No real payment provider is configured. This '
                      'button only works if the backend is deployed with '
                      'PAYMENTS_MODE=sandbox, and never in production.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _confirming ? null : _confirmSandbox,
                      child: _confirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simulate Payment (Debug Only)'),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const AppInlineWarningBanner(
              message: 'Online payment isn\'t available yet. Check back soon.',
            ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => setState(() {
              _intent = null;
              _error = null;
            }),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _createIntent() async {
    final amount = _selectedMyr;
    if (amount == null) return;
    setState(() {
      _creatingIntent = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(billingServiceProvider)
          .createTopUpIntent(amount);
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _creatingIntent = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _creatingIntent = false;
        _error = CommercialErrorPresentation.messageFor(
          'Top-up intent creation',
          error,
          stackTrace,
        );
      });
    }
  }

  Future<void> _confirmSandbox() async {
    final intent = _intent;
    if (intent == null) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final confirmation = await ref
          .read(billingServiceProvider)
          .confirmSandboxPayment(intent.intentId);
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(walletTransactionsProvider);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${confirmation.creditsAdded} Credits. New balance: '
            '${confirmation.newBalance}.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = CommercialErrorPresentation.messageFor(
          'Top-up sandbox confirmation',
          error,
          stackTrace,
        );
      });
    }
  }
}
