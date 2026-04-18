import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/bird_detail/presentation/screens/bird_detail_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/identification/domain/entities/identified_bird.dart';
import '../../features/identification/presentation/screens/results_screen.dart';
import '../../features/record/domain/entities/recording_session.dart';
import '../../features/record/presentation/screens/record_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../widgets/app_bottom_nav.dart';

abstract class AppRouter {
  static final router = GoRouter(
    initialLocation: '/record',
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
    routes: [
      // Shell route with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppBottomNav(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/record',
                builder: (_, __) => const RecordScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, __) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Modal routes (no bottom nav)
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final session = state.extra as RecordingSession;
          return ResultsScreen(session: session);
        },
      ),

      GoRoute(
        path: '/bird/:speciesCode',
        builder: (context, state) {
          final bird = state.extra as IdentifiedBird;
          return BirdDetailScreen(bird: bird);
        },
      ),
    ],
  );
}
