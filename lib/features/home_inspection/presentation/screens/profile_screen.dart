import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_build_info.dart';
import '../../../../app/theme/design_system.dart';
import '../../../../data/local/database_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/session_list_providers.dart';
import '../../providers/user_profile_providers.dart';
import '../widgets/attention_sheet.dart';

/// The signed-in inspector's profile: identity (from Firebase Auth,
/// read-only), on-device company/inspector-name prefill data (editable —
/// see `UserProfile`), AI defaults, and sign out. No Firebase technical
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
    final attentionCount = ref.watch(attentionSessionsProvider).length;

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
            AppTopBar(
              attentionCount: attentionCount,
              onAttentionTap: () => showAttentionSheet(context, ref),
            ),
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
                border: Border.all(color: AppColors.outline),
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
            const SizedBox(height: AppSpacing.xl),
            _SectionCard(
              icon: Icons.psychology_outlined,
              title: 'AI Preferences',
              subtitle: 'Default AI level for new inspections',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AiLevel>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      selectedBackgroundColor: AppColors.primary,
                      selectedForegroundColor: Colors.white,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AiLevel.fast, label: Text('Fast')),
                      ButtonSegment(value: AiLevel.smart, label: Text('Smart')),
                      ButtonSegment(
                        value: AiLevel.expert,
                        label: Text('Expert'),
                      ),
                    ],
                    selected: {_defaultAiLevel ?? AiLevel.smart},
                    onSelectionChanged: (selection) =>
                        setState(() => _defaultAiLevel = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _aiLevelDescription(_defaultAiLevel ?? AiLevel.smart),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              icon: Icons.description_outlined,
              title: 'Report Settings',
              subtitle: 'Manage your default report information',
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
            const SizedBox(height: AppSpacing.xl),
            // Subtle metadata, not a prominent card (§21 of the mission —
            // build info is informational only, never a destination).
            Center(
              child: Text(
                'Version ${AppBuildInfo.version} · Build ${AppBuildInfo.build}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
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

  String _aiLevelDescription(AiLevel level) => switch (level) {
    AiLevel.fast =>
      'Fastest results — best for straightforward inspections where '
          'speed matters most.',
    AiLevel.smart =>
      'Balanced speed and thoroughness — the right default for most '
          'inspections.',
    AiLevel.expert =>
      'Most thorough analysis — best for complex properties or when '
          'accuracy matters most.',
  };

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
