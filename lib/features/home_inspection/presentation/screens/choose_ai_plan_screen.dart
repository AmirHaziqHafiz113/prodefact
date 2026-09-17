import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/billing/billing_providers.dart';
import '../../providers/new_inspection_draft_providers.dart';
import '../../providers/user_profile_providers.dart';
import 'review_setup_screen.dart';

/// New Inspection setup, inserted between Area Configuration and Review
/// Setup: the inspector chooses how AI analysis will be paid for (Flex
/// Credits vs. House Pass) and the default AI quality tier — see
/// docs/commercial_model.md. Purely an in-memory draft edit, exactly
/// like every other setup step here; nothing is charged or activated
/// until AI actually runs later, and even then only after an explicit
/// per-finding estimate/approval (see `AreaInspectionScreen`).
class ChooseAiPlanScreen extends ConsumerStatefulWidget {
  const ChooseAiPlanScreen({super.key});

  static const routePath = '/home-inspection/choose-ai-plan';

  @override
  ConsumerState<ChooseAiPlanScreen> createState() => _ChooseAiPlanScreenState();
}

class _ChooseAiPlanScreenState extends ConsumerState<ChooseAiPlanScreen> {
  CommercialMode? _mode;
  AiLevel? _level;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(newInspectionDraftProvider);
    _mode = draft?.commercialMode ?? CommercialMode.flexCredits;
    _level = draft?.selectedAiLevel;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(commercialConfigProvider);
    // A best-effort default only — never blocks rendering on this being
    // ready, and never overrides an explicit choice already made.
    final profileDefault = ref.watch(userProfileProvider).value?.defaultAiLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose AI Plan')),
      body: SafeArea(
        child: configAsync.when(
          loading: () => const AppLoadingView(),
          error: (error, stackTrace) => AppErrorView(
            message:
                'Could not load AI plan options. Check your '
                'connection and try again.',
            onRetry: () => ref.invalidate(commercialConfigProvider),
          ),
          data: (config) {
            _level ??=
                profileDefault ??
                config.aiLevels
                    .firstWhere(
                      (l) => l.level == AiLevel.smart,
                      orElse: () => config.aiLevels.first,
                    )
                    .level;
            return _buildContent(context, config);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _mode != null && _level != null ? _continue : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CommercialConfig config) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'How should AI analysis be paid for?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Physical inspection is always free — this only affects the "
          'optional AI analysis step for each finding.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        _CommercialModeCard(
          icon: Icons.bolt_outlined,
          title: 'Flex Credits',
          description:
              'Pay only for the AI analyses you actually run, at '
              'the level you choose below.',
          selected: _mode == CommercialMode.flexCredits,
          onTap: () => setState(() => _mode = CommercialMode.flexCredits),
        ),
        const SizedBox(height: AppSpacing.sm),
        _CommercialModeCard(
          icon: Icons.verified_outlined,
          title:
              'House Pass — RM${config.housePass.priceMyr.toStringAsFixed(0)}',
          description:
              '${_labelFor(config, config.housePass.includedAiLevel)} AI '
              'analysis included for up to ${config.housePass.allowanceFindings} '
              'findings on this property. A higher level still costs '
              'Credits.',
          enabled: config.housePass.enabled,
          warning: config.housePass.isProductionReady
              ? null
              : 'Preview pricing — not yet finalized for real purchases.',
          selected: _mode == CommercialMode.housePass,
          onTap: config.housePass.enabled
              ? () => setState(() => _mode = CommercialMode.housePass)
              : null,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Default AI quality',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You can still choose a different level for any individual '
          'finding later.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final level in config.aiLevels)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AiLevelTile(
              info: level,
              selected: _level == level.level,
              onTap: () => setState(() => _level = level.level),
            ),
          ),
      ],
    );
  }

  String _labelFor(CommercialConfig config, AiLevel level) {
    return config.aiLevels
        .firstWhere(
          (l) => l.level == level,
          orElse: () => config.aiLevels.first,
        )
        .label;
  }

  void _continue() {
    final mode = _mode;
    final level = _level;
    if (mode == null || level == null) return;
    ref
        .read(newInspectionDraftProvider.notifier)
        .chooseCommercialPlan(commercialMode: mode, selectedAiLevel: level);
    context.push(ReviewSetupScreen.routePath);
  }
}

class _CommercialModeCard extends StatelessWidget {
  const _CommercialModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.warning,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final String? warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (warning != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          warning!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiLevelTile extends StatelessWidget {
  const _AiLevelTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final AiLevelInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(info.label),
        subtitle: Text(info.description),
        trailing: Text(
          'Up to ${info.maximumCredits} Credits',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
