import 'package:go_router/go_router.dart';

import '../../features/home_inspection/presentation/screens/area_configuration_screen.dart';
import '../../features/home_inspection/presentation/screens/area_inspection_screen.dart';
import '../../features/home_inspection/presentation/screens/element_inspection_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import '../../features/home_inspection/presentation/screens/inspection_sessions_screen.dart';
import '../../features/home_inspection/presentation/screens/next_stage_placeholder_screen.dart';
import '../../features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import '../presentation/home_shell_screen.dart';

/// Builds a fresh router. Each [ProDefactApp] instance owns its own router
/// (rather than sharing a module-level singleton) so that, e.g., separate
/// widget tests don't leak navigation state into one another.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: HomeShellScreen.routePath,
    routes: [
      GoRoute(
        path: HomeShellScreen.routePath,
        builder: (context, state) => const HomeShellScreen(),
      ),
      GoRoute(
        path: InspectionSessionsScreen.routePath,
        builder: (context, state) => const InspectionSessionsScreen(),
      ),
      GoRoute(
        path: PropertyTypeSelectionScreen.routePath,
        builder: (context, state) => const PropertyTypeSelectionScreen(),
      ),
      GoRoute(
        path: AreaConfigurationScreen.routePath,
        builder: (context, state) => const AreaConfigurationScreen(),
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
        path: '${InspectionQueueScreen.routePath}/:sectionId/:elementId',
        builder: (context, state) => ElementInspectionScreen(
          sectionId: state.pathParameters['sectionId']!,
          elementId: state.pathParameters['elementId']!,
        ),
      ),
      GoRoute(
        path: NextStagePlaceholderScreen.routePath,
        builder: (context, state) => const NextStagePlaceholderScreen(),
      ),
    ],
  );
}
