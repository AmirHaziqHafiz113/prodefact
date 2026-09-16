import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../data/local/database_providers.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/user_profile_providers.dart';

/// The signed-in inspector's profile: identity (from Firebase Auth,
/// read-only), on-device company/inspector-name prefill data (editable —
/// see `UserProfile`), and sign out. No Firebase technical identifiers
/// (uid, tokens) are ever shown — only the email a real person recognizes
/// as their own.
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

    profileAsync.whenData((profile) {
      if (!_prefilled) {
        _companyName.text = profile.companyName ?? '';
        _inspectorName.text = profile.inspectorName ?? '';
        _prefilled = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.email ?? 'Local inspector'),
                subtitle: Text(
                  user != null
                      ? 'Signed in'
                      : 'Not signed in — working offline, local only',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: 'Report details',
              subtitle: 'Prefills new inspections and the report cover page',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _companyName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Company name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _inspectorName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Inspector name'),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (user != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.pop();
                },
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'ProDefact',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
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
          ),
        );
    ref.invalidate(userProfileProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }
}
