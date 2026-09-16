import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/remote_providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import '../../features/home_inspection/presentation/screens/area_configuration_screen.dart';
import '../../features/home_inspection/presentation/screens/area_inspection_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_sessions_screen.dart';
import '../../features/home_inspection/presentation/screens/profile_screen.dart';
import '../../features/home_inspection/presentation/screens/property_details_screen.dart';
import '../../features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import '../../features/home_inspection/presentation/screens/report_screen.dart';
import '../../features/home_inspection/presentation/screens/review_setup_screen.dart';
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
    initialLocation: InspectionSessionsScreen.routePath,
    refreshListenable: GoRouterRefreshStream(
      ref.read(authServiceProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      if (!ref.read(firebaseReadyProvider)) return null;

      final isSignedIn = ref.read(authServiceProvider).currentUser != null;
      final goingToSignIn = state.matchedLocation == SignInScreen.routePath;
      final isGatedRoute = state.matchedLocation.startsWith(_gatedPathPrefix);

      if (!isSignedIn && isGatedRoute) return SignInScreen.routePath;
      if (isSignedIn && goingToSignIn) {
        return InspectionSessionsScreen.routePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: SignInScreen.routePath,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: InspectionSessionsScreen.routePath,
        builder: (context, state) => const InspectionSessionsScreen(),
      ),
      GoRoute(
        path: ProfileScreen.routePath,
        builder: (context, state) => const ProfileScreen(),
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
        path: ReviewSetupScreen.routePath,
        builder: (context, state) => const ReviewSetupScreen(),
      ),
      GoRoute(
        path: InspectionQueueScreen.routePath,
        builder: (context, state) => const InspectionQueueScreen(),
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
    ],
  );
}
