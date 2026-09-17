import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/house_pass_providers.dart';

/// House Pass purchase and status — a fixed-price (RM30) AI package for
/// one inspection. Backend remains authoritative throughout: this
/// screen never activates a pass itself, only calls `purchaseHousePass`
/// (creating a pending payment intent) and, in a debug build talking to
/// a sandbox-mode backend, `confirmSandboxPayment`. See
/// docs/commercial_model.md.
class HousePassScreen extends ConsumerStatefulWidget {
  const HousePassScreen({required this.inspectionId, super.key});

  final String inspectionId;

  static const routePath = '/home-inspection/house-pass';

  @override
  ConsumerState<HousePassScreen> createState() => _HousePassScreenState();
}

class _HousePassScreenState extends ConsumerState<HousePassScreen> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(housePassStatusProvider(widget.inspectionId));
    final session = ref.watch(activeSessionProvider);
    final propertyTitle = session?.propertyDetails.title;

    return Scaffold(
      appBar: AppBar(title: const Text('House Pass')),
      body: SafeArea(
        child: statusAsync.when(
          loading: () => const AppLoadingView(),
          error: (error, stackTrace) => AppErrorView(
            message: 'Could not load House Pass status.',
            onRetry: () =>
                ref.invalidate(housePassStatusProvider(widget.inspectionId)),
          ),
          data: (summary) => _buildContent(context, summary, propertyTitle),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HousePassSummary summary,
    String? propertyTitle,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _StatusHeaderCard(summary: summary, propertyTitle: propertyTitle),
        const SizedBox(height: AppSpacing.lg),
        if (_error != null) ...[
          AppInlineErrorBanner(
            message: _error!,
            onDismiss: () => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ..._actionsFor(summary),
      ],
    );
  }

  List<Widget> _actionsFor(HousePassSummary summary) {
    switch (summary.status) {
      case HousePassLifecycleStatus.purchaseRequired:
        return [
          Text(
            'A fixed-price AI package for this inspection. Includes '
            '${_levelLabel(summary.includedAiLevel)} AI for a fair-use '
            'allowance of ${summary.allowanceLimit ?? "a configured number of"} '
            'findings — a higher level or going over the allowance still '
            'costs Credits. Physical inspection is never affected either '
            'way.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _purchase,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Purchase House Pass'),
          ),
        ];
      case HousePassLifecycleStatus.paymentPending:
        return [
          Text(
            'Your House Pass purchase is awaiting payment confirmation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (kDebugMode && summary.pendingIntentId != null)
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
                      onPressed: _busy
                          ? null
                          : () => _confirmSandbox(summary.pendingIntentId!),
                      child: _busy
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
            )
          else
            const AppInlineWarningBanner(
              message: 'Online payment isn\'t available yet. Check back soon.',
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(housePassStatusProvider(widget.inspectionId)),
            child: const Text('Refresh status'),
          ),
        ];
      case HousePassLifecycleStatus.paymentFailed:
        return [
          Text(
            'Your last House Pass payment attempt failed. No Credits or '
            'pass activation happened.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _purchase,
            child: const Text('Try Again'),
          ),
        ];
      case HousePassLifecycleStatus.active:
        return [
          FilledButton.tonal(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ];
      case HousePassLifecycleStatus.allowanceReached:
        return [
          Text(
            "This House Pass's AI allowance has been used up for this "
            'inspection. You can keep analysing findings — it will use '
            'your Flex Credits instead. Physical inspection is never '
            'affected.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Continue with AI Credits'),
          ),
        ];
      case HousePassLifecycleStatus.expiredOrCancelled:
        return [
          Text(
            'This House Pass is no longer active.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ];
    }
  }

  String _levelLabel(AiLevel? level) => switch (level) {
    AiLevel.fast => 'Fast',
    AiLevel.smart => 'Smart',
    AiLevel.expert => 'Expert',
    null => 'the included',
  };

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(billingServiceProvider)
          .purchaseHousePass(widget.inspectionId);
      ref.invalidate(housePassStatusProvider(widget.inspectionId));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSandbox(String intentId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(billingServiceProvider).confirmSandboxPayment(intentId);
      ref.invalidate(housePassStatusProvider(widget.inspectionId));
      // A House Pass's allowance makes auto-analysing safe by default —
      // see `_AutoAnalyseToggle`'s doc comment. The inspector can still
      // switch it back off from the queue screen at any time.
      ref.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusHeaderCard extends StatelessWidget {
  const _StatusHeaderCard({required this.summary, this.propertyTitle});

  final HousePassSummary summary;
  final String? propertyTitle;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (summary.status) {
      HousePassLifecycleStatus.purchaseRequired => (
        'Purchase Required',
        Icons.verified_outlined,
        AppColors.textSecondary,
      ),
      HousePassLifecycleStatus.paymentPending => (
        'Payment Pending',
        Icons.hourglass_top_outlined,
        AppColors.warning,
      ),
      HousePassLifecycleStatus.paymentFailed => (
        'Payment Failed',
        Icons.error_outline,
        AppColors.danger,
      ),
      HousePassLifecycleStatus.active => (
        'House Pass Active',
        Icons.verified,
        AppColors.success,
      ),
      HousePassLifecycleStatus.allowanceReached => (
        'Allowance Reached',
        Icons.data_usage_outlined,
        AppColors.warning,
      ),
      HousePassLifecycleStatus.expiredOrCancelled => (
        'No Longer Active',
        Icons.block_outlined,
        AppColors.textMuted,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (propertyTitle?.isNotEmpty == true)
              _Row(label: 'Property', value: propertyTitle!),
            _Row(
              label: 'Price',
              value: 'RM${summary.priceMyr.toStringAsFixed(0)}',
            ),
            if (summary.includedAiLevel != null)
              _Row(
                label: 'Included AI',
                value: switch (summary.includedAiLevel!) {
                  AiLevel.fast => 'Fast',
                  AiLevel.smart => 'Smart',
                  AiLevel.expert => 'Expert',
                },
              ),
            if (summary.hasAllowanceInfo)
              _Row(
                label: 'Usage',
                value:
                    '${summary.allowanceUsed} / ${summary.allowanceLimit} '
                    'findings',
              ),
            if (!summary.isProductionReady) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Preview pricing — the final allowance for a real '
                'purchase is still being finalized.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
