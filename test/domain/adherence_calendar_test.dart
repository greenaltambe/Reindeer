import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/progress/presentation/adherence_calendar.dart';
import 'package:reindeer/features/symptoms/domain/symptom.dart';

void main() {
  testWidgets(
    'AdherenceCalendar30Days renders 30 days with pattern and color encoding',
    (tester) async {
      final now = DateTime(2026, 10, 30, 12, 0);
      final plan = MedicationPlan(
        id: 1,
        profileId: 'me',
        name: 'Metformin',
        doseUnit: DoseUnit.tablet,
        slotAmounts: const {DaySlot.morning: 1},
        startDate: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
      );

      final entries = [
        // Day 30 (today): Taken
        DoseEntry(
          plan: plan,
          dose: PlannedDose(
            planId: 1,
            slot: DaySlot.morning,
            at: DateTime(2026, 10, 30, 8, 0),
            amount: 1,
          ),
          status: DoseStatus.taken,
        ),
        // Day 29: Missed
        DoseEntry(
          plan: plan,
          dose: PlannedDose(
            planId: 1,
            slot: DaySlot.morning,
            at: DateTime(2026, 10, 29, 8, 0),
            amount: 1,
          ),
          status: DoseStatus.missed,
        ),
        // Day 28: Skipped
        DoseEntry(
          plan: plan,
          dose: PlannedDose(
            planId: 1,
            slot: DaySlot.morning,
            at: DateTime(2026, 10, 28, 8, 0),
            amount: 1,
          ),
          status: DoseStatus.skipped,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdherenceCalendar30Days(entries: entries, now: now),
            ),
          ),
        ),
      );

      // Verify symbols are displayed
      expect(find.text('✓'), findsAtLeast(1)); // In day cell and legend
      expect(find.text('✕'), findsAtLeast(1)); // In day cell and legend
      expect(find.text('–'), findsAtLeast(1)); // In day cell and legend

      // Verify 30 day cells are rendered
      expect(find.text('30'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
    },
  );

  testWidgets(
    'AdherenceCalendar30Days displays symptom indicator and supports tap',
    (tester) async {
      final now = DateTime(2026, 10, 30, 12, 0);
      final symptoms = [
        SymptomEntry(
          id: 1,
          symptom: 'Headache',
          severity: Severity.moderate,
          at: DateTime(2026, 10, 30, 9, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdherenceCalendar30Days(
                entries: const [],
                now: now,
                symptoms: symptoms,
              ),
            ),
          ),
        ),
      );

      // Verify legend contains symptom
      expect(find.text('Symptom'), findsOneWidget);

      // Tap on day 30 cell to open modal bottom sheet
      await tester.ensureVisible(find.text('30'));
      await tester.tap(find.text('30'));
      await tester.pumpAndSettle();

      // Check bottom sheet shows Headache
      expect(find.text('Symptoms & Feelings'), findsOneWidget);
      expect(find.text('Headache (Moderate)'), findsOneWidget);
    },
  );
}
