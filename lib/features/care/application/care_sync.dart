import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/data/dose_log_repository.dart';
import 'package:reindeer/features/adherence/data/miss_reason_repository.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Settings key: '1' while this phone has at least one caretaker. Nothing is
/// uploaded without it.
const String keyHasCaretakers = 'care_has_caretakers';

/// Settings key: this phone's [CareMode] name.
const String keyCareMode = 'care_mode';

const String _keyUploaded = 'care_uploaded';
const String _keyPatientState = 'care_patient_state';
const String _keyBatteryAlert = 'care_battery_alert_at';

/// At or below this level (and not charging) caretakers are warned.
const int lowBatteryLevel = 15;

/// One dose as uploaded for caretakers.
class SharedDose {
  const SharedDose(this.id, this.data, {required this.deadline});

  /// Document id: `date_planId_slot`.
  final String id;
  final Map<String, Object?> data;
  final DateTime deadline;

  /// Changes whenever anything the caretaker sees changes.
  String get fingerprint => jsonEncode(
    data.map((k, v) => MapEntry(k, v is DateTime ? v.toIso8601String() : v)),
  );
}

/// Builds the doses to share from yesterday to [daysAhead] days ahead.
/// Pure, so it is tested without Firebase.
List<SharedDose> buildSharedDoses({
  required List<MedicationPlan> plans,
  required Map<String, DoseLog> logs,
  required Map<String, String> reasons,
  required DateTime now,
  required List<PlannedDose> Function(MedicationPlan plan, DateTime day)
  dosesOn,
  int daysAhead = 2,
}) {
  final today = dateOnly(now);
  final out = <SharedDose>[];
  for (final plan in plans) {
    if (!plan.isActive) continue;
    final doses = <PlannedDose>[
      // One extra day so the last dose knows when the next one is.
      for (var i = -1; i <= daysAhead + 1; i++)
        ...dosesOn(plan, DateTime(today.year, today.month, today.day + i)),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final lastDay = DateTime(today.year, today.month, today.day + daysAhead);
    for (var i = 0; i < doses.length; i++) {
      final dose = doses[i];
      if (dateOnly(dose.at).isAfter(lastDay)) continue;
      final deadline = missedDeadline(
        dose.at,
        nextScheduledAt: i + 1 < doses.length ? doses[i + 1].at : null,
      );
      final log = logs[dose.key];
      final status = switch (log?.status) {
        DoseStatus.taken => 'taken',
        DoseStatus.skipped => 'skipped',
        _ => 'pending',
      };
      out.add(
        SharedDose('${dose.doseDate}_${dose.planId}_${dose.slot.name}', {
          'date': dose.doseDate,
          'at': dose.at,
          'deadline': deadline,
          'name': plan.name,
          'amount': plan.doseUnit.describe(dose.amount),
          'slot': dose.slot.name,
          'time': formatTime(dose.at),
          'status': status,
          if (log != null && status != 'pending') ...{
            'doneAt': log.actedAt,
            'doneTime': formatTime(log.actedAt),
          },
          if (status == 'skipped') 'reason': reasons[dose.key] ?? 'unknown',
        }, deadline: deadline),
      );
    }
  }
  return out;
}

/// Keeps the patient's shared doses and phone details up to date.
///
/// Writes only what changed since the last run, so a normal day costs a
/// handful of Firestore writes.
abstract final class CareSync {
  static Timer? _debounce;
  static Future<void> _running = Future<void>.value();

  /// Runs soon, folding bursts (Taken, then a skip reason) into one upload.
  static void requestSoon(Database db) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      _running = _running.then((_) => run(db));
    });
  }

  /// Uploads now. Never throws; sharing must not break reminders.
  static Future<void> run(Database db) async {
    try {
      final settings = SettingsRepository(db);
      if (await settings.get(keyHasCaretakers) != '1') return;
      if (!await CareBackend.init()) return;
      final user =
          FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
      if (user == null) return;
      await _syncDoses(db, settings, user.uid);
      await _syncPhone(settings, user.uid);
    } catch (e, s) {
      AppLogger.error('Caretaker sync failed', error: e, stackTrace: s);
    }
  }

  /// Forgets what was uploaded, for example after unlinking.
  static Future<void> reset(Database db) async {
    final settings = SettingsRepository(db);
    await settings.remove(_keyUploaded);
    await settings.remove(_keyPatientState);
  }

  static Future<void> _syncDoses(
    Database db,
    SettingsRepository settings,
    String uid,
  ) async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final from = DateTime(today.year, today.month, today.day - 1);
    final to = DateTime(today.year, today.month, today.day + 3);
    final anchors = await settings.loadMealAnchors();
    final reasons = await MissReasonRepository(db).between(from, to);
    final shared = buildSharedDoses(
      plans: await PlanRepository(db).all(),
      logs: await DoseLogRepository(db).between(from, to),
      reasons: {for (final e in reasons.entries) e.key: e.value.reason.name},
      now: now,
      dosesOn: (plan, day) => plan.dosesOn(day, anchors),
    );

    final uploaded = _decode(await settings.get(_keyUploaded));
    final next = <String, String>{};
    final col = FirebaseFirestore.instance.collection('patients/$uid/doses');
    final batch = FirebaseFirestore.instance.batch();
    var writes = 0;
    for (final dose in shared) {
      final print = dose.fingerprint;
      next[dose.id] = print;
      if (uploaded[dose.id] == print) continue;
      final data = <String, Object?>{
        for (final e in dose.data.entries)
          e.key: e.value is DateTime
              ? Timestamp.fromDate(e.value! as DateTime)
              : e.value,
      };
      if (!uploaded.containsKey(dose.id)) {
        // New to the server. A dose already past its deadline is history:
        // mark it as handled so it never raises a late alert.
        data['alerted'] = dose.deadline.isBefore(now);
      }
      if (data['status'] == 'pending') {
        data['doneAt'] = FieldValue.delete();
        data['doneTime'] = FieldValue.delete();
        data['reason'] = FieldValue.delete();
      }
      batch.set(col.doc(dose.id), data, SetOptions(merge: true));
      writes++;
    }
    // Doses that no longer exist (medicine stopped or changed) and are still
    // ahead: remove them so nobody is alerted about them.
    final todayIso = isoDate(today);
    for (final id in uploaded.keys) {
      if (next.containsKey(id)) continue;
      if (id.compareTo(todayIso) >= 0) {
        batch.delete(col.doc(id));
        writes++;
      }
    }
    if (writes > 0) await batch.commit();
    await settings.set(_keyUploaded, jsonEncode(next));
  }

  /// Battery and "last seen", written at most every 30 minutes unless the
  /// battery level changes noticeably.
  static Future<void> _syncPhone(
    SettingsRepository settings,
    String uid,
  ) async {
    int? level;
    var charging = false;
    try {
      final battery = Battery();
      level = await battery.batteryLevel;
      final state = await battery.batteryState;
      charging = state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      // Some phones do not report it; the rest still works.
    }
    final now = DateTime.now();
    final last = _decode(await settings.get(_keyPatientState));
    final lastAt = DateTime.tryParse(last['at'] ?? '');
    final bucket = level == null ? '' : '${level ~/ 10}|$charging';
    final due =
        lastAt == null ||
        now.difference(lastAt) > const Duration(minutes: 30) ||
        last['bucket'] != bucket;
    if (due) {
      await FirebaseFirestore.instance.doc('patients/$uid').set({
        'battery': ?level,
        'charging': charging,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await settings.set(
        _keyPatientState,
        jsonEncode({'at': now.toIso8601String(), 'bucket': bucket}),
      );
    }

    if (level != null && level <= lowBatteryLevel && !charging) {
      final lastAlert = DateTime.tryParse(
        await settings.get(_keyBatteryAlert) ?? '',
      );
      if (lastAlert == null ||
          now.difference(lastAlert) > const Duration(hours: 12)) {
        await CareBackend.sendPatientEvent('battery', level: level);
        await settings.set(_keyBatteryAlert, now.toIso8601String());
      }
    }
  }

  static Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return {};
    }
  }
}
