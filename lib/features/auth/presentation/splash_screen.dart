import 'package:flutter/material.dart';

import '../../../app/theme/design_system.dart';

/// The app's startup screen and initial route (see `buildAppRouter`).
/// `main.dart` already fully awaits `Firebase.initializeApp` before the
/// router is even built, so by the time this screen's route is
/// evaluated there is no further async gap to gate on — the redirect
/// away from it (to Sign In or the dashboard) is immediate. This is
/// purely the app's identity for the moment between the OS launching
/// it and that first frame: no tap-to-continue, no fixed/fake delay,
/// nothing decorative layered on top of it.
///
/// A future pass that moves `Firebase.initializeApp` to run
/// concurrently with the first frame (rather than fully blocking
/// `runApp`) could make this screen genuinely state-gated on
/// `firebaseReadyProvider`'s resolution — deliberately not attempted
/// here, since it would change app-boot sequencing well beyond this
/// pass's scope.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const routePath = '/splash';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: 64, color: Colors.white),
            SizedBox(height: AppSpacing.lg),
            Text(
              'ProDefact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
