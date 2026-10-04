import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/features/barcode/presentation/scan_screen.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/add_measurement_screen.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';
import 'package:reindeer/features/health/presentation/measurement_detail_screen.dart';
import 'package:reindeer/features/medications/presentation/add_details_screen.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medications/presentation/add_search_screen.dart';
import 'package:reindeer/features/medications/presentation/medications_screen.dart';
import 'package:reindeer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:reindeer/features/progress/presentation/progress_screen.dart';
import 'package:reindeer/features/profile/presentation/profile_screen.dart';
import 'package:reindeer/features/settings/presentation/settings_screen.dart';
import 'package:reindeer/features/today/presentation/today_screen.dart';
import 'package:reindeer/shared/widgets/app_shell.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';

/// Whether first-run onboarding has been completed. Overridden in `main`.
final initialOnboardedProvider = Provider<bool>((ref) => true);

/// Provides the application's [GoRouter] configuration.
final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(initialOnboardedProvider);
  return GoRouter(
    initialLocation: onboarded ? AppRoutes.today : AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.add,
        builder: (context, state) => const AddSearchScreen(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: 'details',
            builder: (context, state) => AddDetailsScreen(
              draft: state.extra is AddDraft
                  ? state.extra! as AddDraft
                  : const AddDraft(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.medicines,
                builder: (context, state) => const MedicationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.health,
                builder: (context, state) => const HealthScreen(),
                routes: [
                  GoRoute(
                    path: ':type',
                    redirect: (context, state) =>
                        MeasureType.byName(
                              state.pathParameters['type'] ?? '',
                            ) ==
                            null
                        ? AppRoutes.health
                        : null,
                    builder: (context, state) => MeasurementDetailScreen(
                      type: MeasureType.byName(state.pathParameters['type']!)!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'add',
                        builder: (context, state) => AddMeasurementScreen(
                          type: MeasureType.byName(
                            state.pathParameters['type']!,
                          )!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyStateView(
        title: 'Route not found',
        message: 'No screen matches "${state.uri}".',
        icon: Icons.explore_off_outlined,
        actionLabel: 'Back to Today',
        onAction: () => context.go(AppRoutes.today),
      ),
    ),
  );
});
