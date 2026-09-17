import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/remote_providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import '../../features/home_inspection/presentation/screens/area_configuration_screen.dart';
import '../../features/home_inspection/presentation/screens/area_inspection_screen.dart';
import '../../features/home_inspection/presentation/screens/choose_ai_plan_screen.dart';
import '../../features/home_inspection/presentation/screens/home_dashboard_screen.dart';
import '../../features/home_inspection/presentation/screens/house_pass_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_sessions_screen.dart';
import '../../features/home_inspection/presentation/screens/profile_screen.dart';
import '../../features/home_inspection/presentation/screens/property_details_screen.dart';
import '../../features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import '../../features/home_inspection/presentation/screens/report_details_screen.dart';
import '../../features/home_inspection/presentation/screens/report_screen.dart';
import '../../features/home_inspection/presentation/screens/review_setup_screen.dart';
import '../../features/home_inspection/presentation/screens/top_up_screen.dart';
import '../../features/home_inspection/presentation/screens/wallet_screen.dart';
import 'app_shell_screen.dart';
import 'go_router_refresh_stream.dart';

/// Every route that requires a signed-in inspector once Firebase is
/// configured — the dashboard, creating/configuring/physically
/// inspecting a property, AI review, and the report. See the
/// `redirect` callback below for the actual gate.
const _gatedPathPrefix = '/home-inspection';

/// Builds a fresh router. Each [ProDefactApp] instance owns its own router
/// (rather than sharing a module-level singleton) so that, e.g., separate
/// widget tests don't leak navigation state into one another.
///
/// Authentication hard gate: whenever Firebase is actually configured
/// (`firebaseReadyProvider`), no route under [_gatedPathPrefix] —
/// dashboard, new inspection, physical inspection, AI review, report —
/// is reachable without a signed-in session; an unauthenticated
/// attempt is redirected to [SignInScreen] before that screen's
/// `builder` ever runs, and a signed-in inspector is bounced away from
/// the sign-in screen back to the dashboard. Legitimate, previously-
/// persisted Firebase sessions restore automatically (see
/// `FirebaseAuthService`) and are not affected by this — the gate only
/// ever blocks a genuinely unauthenticated caller, never a
/// currently-offline-but-already-signed-in one.
///
/// When Firebase is **not** configured at all (local-only/demo/test
/// builds — see `docs/firebase.md`), there is no backend to
/// authenticate against, so this gate does not apply and the existing
/// fully-offline behavior is unchanged — see
/// `docs/production_readiness.md` ("Offline-first guarantees").
GoRouter buildAppRouter(WidgetRef ref) {
  return GoRouter(
    // Starts on the splash screen — see its own doc comment and the
    // `redirect` logic below, which routes away from it the instant
    // there's something real to show (immediately, in local-only mode;
    // the moment `authStateProvider` resolves, once Firebase is
    // configured). The Inspections tab (not Home) is still the actual
    // landing screen after that — this preserves the app's existing
    // "the dashboard is the inspections list" behavior exactly; Home is
    // an additional aggregate/wallet-glance tab, one tap away, not a
    // replacement for it. See docs/commercial_model.md ("Routing
    // audit").
    initialLocation: SplashScreen.routePath,
    refreshListenable: GoRouterRefreshStream(
      ref.read(authServiceProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      final onSplash = state.matchedLocation == SplashScreen.routePath;

      // `main.dart` already fully awaits `Firebase.initializeApp` (and
      // `currentUser` is a synchronous, already-resolved getter — see
      // `FirebaseAuthService`) before this router is ever built, so
      // `firebaseReadyProvider` and the current sign-in state are both
      // known immediately here — there is no real async gap left to
      // gate on by the time this callable runs. Splash still exists as
      // its own route/screen (see `SplashScreen`) for the moment
      // between the OS launching the app and this first frame; nothing
      // here holds it open artificially.
      if (!ref.read(firebaseReadyProvider)) {
        return onSplash ? InspectionSessionsScreen.routePath : null;
      }

      final isSignedIn = ref.read(authServiceProvider).currentUser != null;
      final goingToSignIn = state.matchedLocation == SignInScreen.routePath;
      final isGatedRoute = state.matchedLocation.startsWith(_gatedPathPrefix);

      if (onSplash) {
        return isSignedIn
            ? InspectionSessionsScreen.routePath
            : SignInScreen.routePath;
      }
      if (!isSignedIn && isGatedRoute) return SignInScreen.routePath;
      if (isSignedIn && goingToSignIn) {
        return InspectionSessionsScreen.routePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: SplashScreen.routePath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: SignInScreen.routePath,
        builder: (context, state) => const SignInScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeDashboardScreen.routePath,
                builder: (context, state) => const HomeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: InspectionSessionsScreen.routePath,
                builder: (context, state) => const InspectionSessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: WalletScreen.routePath,
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfileScreen.routePath,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: TopUpScreen.routePath,
        builder: (context, state) => const TopUpScreen(),
      ),
      GoRoute(
        path: PropertyTypeSelectionScreen.routePath,
        builder: (context, state) => const PropertyTypeSelectionScreen(),
      ),
      GoRoute(
        path: PropertyDetailsScreen.routePath,
        builder: (context, state) => const PropertyDetailsScreen(),
      ),
      GoRoute(
        path: AreaConfigurationScreen.routePath,
        builder: (context, state) => const AreaConfigurationScreen(),
      ),
      GoRoute(
        path: ChooseAiPlanScreen.routePath,
        builder: (context, state) => const ChooseAiPlanScreen(),
      ),
      GoRoute(
        path: ReviewSetupScreen.routePath,
        builder: (context, state) => const ReviewSetupScreen(),
      ),
      GoRoute(
        path: InspectionQueueScreen.routePath,
        builder: (context, state) => const InspectionQueueScreen(),
      ),
      GoRoute(
        path: '${HousePassScreen.routePath}/:inspectionId',
        builder: (context, state) => HousePassScreen(
          inspectionId: state.pathParameters['inspectionId']!,
        ),
      ),
      GoRoute(
        path: '${InspectionQueueScreen.routePath}/:sectionId',
        builder: (context, state) =>
            AreaInspectionScreen(sectionId: state.pathParameters['sectionId']!),
      ),
      GoRoute(
        path: AiReviewOverviewScreen.routePath,
        builder: (context, state) => const AiReviewOverviewScreen(),
      ),
      GoRoute(
        path: ReportScreen.routePath,
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: ReportDetailsScreen.routePath,
        builder: (context, state) => const ReportDetailsScreen(),
      ),
    ],
  );
}
