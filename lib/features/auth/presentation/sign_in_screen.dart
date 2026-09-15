import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/remote/remote_providers.dart';

/// Minimal email/password sign-in, deliberately small: this is
/// additive to the app, not a gate. Every inspection screen works fully
/// without ever visiting this one — see docs/firebase.md.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  static const routePath = '/sign-in';

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Create account' : 'Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!firebaseReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Cloud sync isn\'t configured for this build yet, so '
                  'sign-in is unavailable. Inspections still save and work '
                  'fully offline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            TextField(
              controller: _emailController,
              enabled: firebaseReady && !_isSubmitting,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: firebaseReady && !_isSubmitting,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: firebaseReady && !_isSubmitting ? _submit : null,
              child: Text(_isSignUp ? 'Create account' : 'Sign in'),
            ),
            TextButton(
              onPressed: firebaseReady && !_isSubmitting
                  ? () => setState(() => _isSignUp = !_isSignUp)
                  : null,
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await authService.signUpWithEmail(email, password);
      } else {
        await authService.signInWithEmail(email, password);
      }
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
