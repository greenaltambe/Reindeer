import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/features/tb/presentation/tb_screen.dart';
import 'package:reindeer/features/tb/presentation/tb_setup_screen.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/router/transitions.dart';
import 'package:reindeer/features/allergy/presentation/allergy_screen.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/care/presentation/add_caretaker_flow.dart';
import 'package:reindeer/features/care/presentation/ask_for_medicines_flow.dart';
import 'package:reindeer/features/care/presentation/care_home_screen.dart';
import 'package:reindeer/features/care/presentation/family_screen.dart';
import 'package:reindeer/features/care/presentation/join_as_caretaker_flow.dart';
import 'package:reindeer/features/care/presentation/medicine_request_screen.dart';
import 'package:reindeer/features/health/domain/measure_type.dart';
import 'package:reindeer/features/health/presentation/add_measurement_screen.dart';
import 'package:reindeer/features/health/presentation/health_screen.dart';
import 'package:reindeer/features/health/presentation/measurement_detail_screen.dart';
import 'package:reindeer/features/medications/presentation/add_details_screen.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medications/presentation/add_search_screen.dart';
import 'package:reindeer/features/medications/presentation/medications_screen.dart';
import 'package:reindeer/features/medications/presentation/prescription_change_screen.dart';
import 'package:reindeer/features/medications/presentation/prescription_scan_review_screen.dart';
import 'package:reindeer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:reindeer/features/progress/presentation/progress_screen.dart';
import 'package:reindeer/features/profile/presentation/profile_screen.dart';
import 'package:reindeer/features/profile/presentation/you_screen.dart';
import 'package:reindeer/features/refills/presentation/refills_screen.dart';
import 'package:reindeer/features/safety/presentation/medical_id_screen.dart';
import 'package:reindeer/features/settings/presentation/settings_screen.dart';
import 'package:reindeer/features/symptoms/presentation/symptom_diary_screen.dart';
import 'package:reindeer/features/today/presentation/today_screen.dart';
import 'package:reindeer/shared/widgets/app_shell.dart';
import 'package:reindeer/shared/widgets/branch_fader.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';

/// Whether first-run onboarding has been completed. Overridden in `main`.
final initialOnboardedProvider = Provider<bool>((ref) => true);

/// Provides the application's [GoRouter] configuration.
final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(initialOnboardedProvider);
  final caretakerOnly = ref.read(initialCareModeProvider) == CareMode.caretaker;
  return GoRouter(
    initialLocation: !onboarded
        ? AppRoutes.onboarding
        : (caretakerOnly ? AppRoutes.care : AppRoutes.today),
    routes: [
      GoRoute(
        path: AppRoutes.care,
        pageBuilder: (context, state) =>
            reindeerPage(state, const CareHomeScreen()),
        routes: [
          GoRoute(
            path: 'request/:uid/:id',
            pageBuilder: (context, state) => reindeerPage(
              state,
              MedicineRequestScreen(
                patientUid: state.pathParameters['uid']!,
                requestId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.family,
        pageBuilder: (context, state) =>
            reindeerPage(state, const FamilyScreen()),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) =>
                reindeerPage(state, const AddCaretakerFlow()),
          ),
          GoRoute(
            path: 'join',
            pageBuilder: (context, state) =>
                reindeerPage(state, const JoinAsCaretakerFlow()),
          ),
          GoRoute(
            path: 'ask',
            pageBuilder: (context, state) =>
                reindeerPage(state, const AskForMedicinesFlow()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            reindeerPage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.add,
        pageBuilder: (context, state) =>
            reindeerPage(state, const AddSearchScreen()),
        routes: [
          GoRoute(
            path: 'details',
            pageBuilder: (context, state) => reindeerPage(
              state,
              AddDetailsScreen(
                draft: state.extra is AddDraft
                    ? state.extra! as AddDraft
                    : const AddDraft(),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            reindeerPage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.tb,
        pageBuilder: (context, state) => reindeerPage(state, const TbScreen()),
        routes: [
          GoRoute(
            path: 'setup',
            pageBuilder: (context, state) =>
                reindeerPage(state, const TbSetupScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.allergies,
        pageBuilder: (context, state) =>
            reindeerPage(state, const AllergyScreen()),
      ),
      GoRoute(
        path: AppRoutes.medicalId,
        pageBuilder: (context, state) =>
            reindeerPage(state, const MedicalIdScreen()),
      ),
      GoRoute(
        path: AppRoutes.symptoms,
        pageBuilder: (context, state) =>
            reindeerPage(state, const SymptomDiaryScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            reindeerPage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.prescriptionChange,
        pageBuilder: (context, state) =>
            reindeerPage(state, const PrescriptionChangeScreen()),
      ),
      GoRoute(
        path: AppRoutes.scanPrescription,
        pageBuilder: (context, state) =>
            reindeerPage(state, const PrescriptionScanReviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.doctorReport,
        redirect: (context, state) => AppRoutes.reports,
      ),
      GoRoute(
        path: AppRoutes.health,
        pageBuilder: (context, state) =>
            reindeerPage(state, const HealthScreen()),
        routes: [
          GoRoute(
            path: ':type',
            redirect: (context, state) =>
                MeasureType.byName(state.pathParameters['type'] ?? '') == null
                ? AppRoutes.health
                : null,
            pageBuilder: (context, state) => reindeerPage(
              state,
              MeasurementDetailScreen(
                type: MeasureType.byName(state.pathParameters['type']!)!,
              ),
            ),
            routes: [
              GoRoute(
                path: 'add',
                pageBuilder: (context, state) => reindeerPage(
                  state,
                  AddMeasurementScreen(
                    type: MeasureType.byName(state.pathParameters['type']!)!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            BranchFader(currentIndex: shell.currentIndex, children: children),
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
                path: AppRoutes.refills,
                builder: (context, state) => const RefillsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ProgressScreen(),
              ),
              GoRoute(
                path: AppRoutes.progress,
                redirect: (context, state) => AppRoutes.reports,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.you,
                builder: (context, state) => const YouScreen(),
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
