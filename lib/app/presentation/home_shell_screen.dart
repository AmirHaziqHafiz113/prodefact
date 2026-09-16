import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_system.dart';

/// App shell landing screen. Phase 1 only offers Home Inspection — other
/// industries will get their own entry points here once they exist.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  static const routePath = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'ProDefact',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: Colors.white),
                semanticsLabel: 'ProDefact',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Professional property inspection, field to report.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  onPressed: () => context.push('/home-inspection/sessions'),
                  child: const Text('Start Home Inspection'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
