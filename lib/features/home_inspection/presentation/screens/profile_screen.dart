import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_build_info.dart';
import '../../../../app/theme/design_system.dart';
import '../../../../data/local/database_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../auth/presentation/sign_in_screen.dart';
import '../../providers/custom_catalogue_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/app_bottom_sheet.dart';
import 'photo_guide_screen.dart';
import 'wallet_screen.dart';

/// Everything that belongs to the inspector and their company, grouped:
/// Account, Inspector & company (report branding prefill — see
/// `UserProfile`), AI Analysis Preference, Custom Catalogue, Wallet &
/// usage, App, and sign out. Identity comes from Firebase Auth
/// (read-only). No Firebase technical
/// identifiers (uid, tokens) are ever shown — only the email a real
/// person recognizes as their own.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static const routePath = '/home-inspection/profile';

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _companyName = TextEditingController();
  final _inspectorName = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;
  AiLevel? _defaultAiLevel;

  @override
  void dispose() {
    _companyName.dispose();
    _inspectorName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final profileAsync = ref.watch(userProfileProvider);
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final customCount = ref
        .watch(customCatalogueProvider)
        .value
        ?.where((d) => !d.archived)
        .length;
    final balance =
        ref.watch(walletBalanceProvider).value ??
        ref.watch(walletCacheProvider).value?.balanceCredits;

    profileAsync.whenData((profile) {
      if (!_prefilled) {
        _companyName.text = profile.companyName ?? '';
        _inspectorName.text = profile.inspectorName ?? '';
        _defaultAiLevel = profile.defaultAiLevel;
        _prefilled = true;
      }
    });

    final displayName = _inspectorName.text.isNotEmpty
        ? _inspectorName.text
        : (user?.email ?? 'Local inspector');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            // A soft branded identity surface — elevated above a plain
            // header row without going as dark/urgent as Home/Wallet's
            // hero, since Profile's job is identity, not a call to act.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.successBg, AppColors.surfaceAlt],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: AppBrandPattern(
                      color: AppColors.primary,
                      opacity: 0.06,
                    ),
                  ),
                  Row(
                    children: [
                      AppAvatar(
                        displayName: _inspectorName.text,
                        email: user?.email,
                        size: 64,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              user?.email ??
                                  'Not signed in — working offline, local only',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_companyName.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.apartment_outlined,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _companyName.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (user == null && firebaseReady) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                clipBehavior: Clip.antiAlias,
                child: AppActionRow(
                  key: const ValueKey('profile-sign-in'),
                  icon: Icons.login,
                  title: 'Sign in to sync',
                  subtitle:
                      'Back up inspections and use them on another device',
                  onTap: () => context.push(SignInScreen.routePath),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              icon: Icons.description_outlined,
              title: 'Inspector & company',
              subtitle: 'Prefilled on every new inspection and report',
              child: Column(
                children: [
                  TextField(
                    controller: _companyName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _inspectorName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Inspector name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // The one place the AI level is chosen: it applies silently
            // to every analysis (never asked per finding, at upload, or
            // in the approval dialog). Saved as soon as it is tapped.
            _SectionCard(
              icon: Icons.psychology_outlined,
              title: 'AI Analysis Preference',
              subtitle: 'Used for every finding you analyse',
              child: Column(
                children: [
                  for (final level in AiLevel.values)
                    ListTile(
                      key: ValueKey('ai-pref-${level.name}'),
                      contentPadding: EdgeInsets.zero,
                      selected:
                          (_defaultAiLevel ?? kFieldAnalysisAiLevel) == level,
                      leading: Icon(
                        (_defaultAiLevel ?? kFieldAnalysisAiLevel) == level
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(_aiLevelLabel(level)),
                      subtitle: Text(_aiLevelPreferenceCopy(level)),
                      onTap: () => _setAiPreference(level),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _GroupLabel('Account & tools'),
            AppGroupedList(
              children: [
                AppActionRow(
                  key: const ValueKey('profile-wallet'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet & usage',
                  subtitle: balance == null
                      ? 'AI credits, top up, House Pass'
                      : '$balance credits · top up, usage, House Pass',
                  onTap: () => context.push(WalletScreen.routePath),
                ),
                AppActionRow(
                  key: const ValueKey('profile-custom-catalogue'),
                  icon: Icons.library_add_outlined,
                  title: 'Custom Catalogue',
                  subtitle: customCount == null
                      ? 'Your company\'s own defect entries'
                      : '$customCount custom '
                            'entr${customCount == 1 ? 'y' : 'ies'}',
                  onTap: () => _showCustomCatalogue(context),
                ),
                AppActionRow(
                  key: const ValueKey('profile-photo-guide'),
                  icon: Icons.photo_camera_back_outlined,
                  title: 'Photo guide',
                  subtitle: 'Tips for photos AI can read',
                  onTap: () => context.push(PhotoGuideScreen.routePath),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            // QA build identifier: lets testers prove exactly which APK a
            // screenshot came from. Real version/build number from the
            // platform, plus the commit injected at build time.
            if (AppBuildInfo.isQaBuild)
              ref
                  .watch(appBuildInfoProvider)
                  .maybeWhen(
                    data: (info) => Center(
                      key: const ValueKey('qa-build-identifier'),
                      child: Column(
                        children: [
                          Text(
                            'ProDefact QA',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          for (final line in [
                            info.versionLabel,
                            info.buildLabel,
                          ])
                            SelectableText(
                              line,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.xl),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _aiLevelLabel(AiLevel level) => switch (level) {
    AiLevel.fast => 'Fast',
    AiLevel.smart => 'Smart',
    AiLevel.expert => 'Expert',
  };

  String _aiLevelPreferenceCopy(AiLevel level) => switch (level) {
    AiLevel.fast => 'Fastest and lowest cost',
    AiLevel.smart => 'Recommended · Default',
    AiLevel.expert => 'Best for difficult or unclear defects',
  };

  /// Persists only the AI level, keeping the stored names as they are
  /// (unsaved edits to the text fields are not saved by this tap).
  Future<void> _setAiPreference(AiLevel level) async {
    setState(() => _defaultAiLevel = level);
    final repository = ref.read(inspectionRepositoryProvider);
    final stored = await repository.loadUserProfile();
    await repository.saveUserProfile(
      UserProfile(
        companyName: stored.companyName,
        inspectorName: stored.inspectorName,
        defaultAiLevel: level,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI analysis set to ${_aiLevelLabel(level)}.')),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    await ref
        .read(inspectionRepositoryProvider)
        .saveUserProfile(
          UserProfile(
            companyName: orNull(_companyName),
            inspectorName: orNull(_inspectorName),
            defaultAiLevel: _defaultAiLevel,
          ),
        );
    ref.invalidate(userProfileProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        0,
        AppSpacing.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The company's custom defect entries, read-only. Entries are added
/// where they are needed — "Add New" in the defect selector — so the
/// inspector never has to leave a finding to create one.
Future<void> _showCustomCatalogue(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final entries =
            ref
                .watch(customCatalogueProvider)
                .value
                ?.where((d) => !d.archived)
                .toList() ??
            const [];
        return AppSheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Custom Catalogue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add an entry with "Add New" in any finding\'s defect '
                'selector. Custom entries are never sent to AI.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (entries.isEmpty)
                const AppEmptyView(
                  icon: Icons.library_add_outlined,
                  title: 'No custom entries yet',
                  message:
                      'When the catalogue lacks a defect you need, add it '
                      'from the defect selector on a finding.',
                )
              else
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.label_outline),
                    title: Text(entry.defectDescription),
                    subtitle: Text(
                      '${entry.elementName} · ${entry.componentName}',
                    ),
                  ),
            ],
          ),
        );
      },
    ),
  );
}
