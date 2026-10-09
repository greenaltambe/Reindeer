import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/care/application/care_sync.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';

/// Mode read at start-up. Overridden in `main`.
final initialCareModeProvider = Provider<CareMode>((ref) => CareMode.patient);

/// Whether this phone is used for the owner's medicines or only to look
/// after others.
final careModeProvider = FutureProvider<CareMode>((ref) async {
  ref.watch(dataVersionProvider);
  return CareMode.fromName(
    await ref.watch(settingsRepositoryProvider).get(keyCareMode),
  );
});

Future<void> saveCareMode(WidgetRef ref, CareMode mode) async {
  await ref.read(settingsRepositoryProvider).set(keyCareMode, mode.name);
  ref.read(dataVersionProvider.notifier).bump();
}

/// This phone's sharing id; null until sharing is set up.
class CareUidNotifier extends Notifier<String?> {
  @override
  String? build() => CareBackend.uid;

  /// Signs in (first time only) and returns the id.
  Future<String> signIn() async {
    final id = await CareBackend.signIn();
    state = id;
    return id;
  }
}

final careUidProvider = NotifierProvider<CareUidNotifier, String?>(
  CareUidNotifier.new,
);

/// People who look after me.
final myCaretakersProvider = StreamProvider<List<CareLink>>((ref) {
  final uid = ref.watch(careUidProvider);
  if (uid == null) return Stream.value(const []);
  return CareBackend.caretakersOf(uid);
});

/// People I look after.
final myPatientsProvider = StreamProvider<List<CareLink>>((ref) {
  final uid = ref.watch(careUidProvider);
  if (uid == null) return Stream.value(const []);
  return CareBackend.patientsOf(uid);
});

final patientInfoProvider = StreamProvider.family<PatientInfo, String>(
  (ref, uid) => CareBackend.patientInfo(uid),
);

/// Today's date, changing only at midnight.
final _todayIsoProvider = Provider<String>(
  (ref) => isoDate(ref.watch(clockProvider).value ?? DateTime.now()),
);

final patientDosesTodayProvider = StreamProvider.family<List<CareDose>, String>(
  (ref, uid) {
    return CareBackend.dosesOn(uid, ref.watch(_todayIsoProvider));
  },
);

final patientRequestsProvider =
    StreamProvider.family<List<CareRequest>, String>(
      (ref, uid) => CareBackend.requestsFrom(uid),
    );

/// Keeps the local "has caretakers" flag in step with the server, and
/// uploads straight away when the first caretaker joins.
final careWatcherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<CareLink>>>(myCaretakersProvider, (prev, next) {
    final links = next.value;
    if (links == null) return;
    final db = ref.read(appDatabaseProvider);
    final settings = ref.read(settingsRepositoryProvider);
    () async {
      final had = await settings.get(keyHasCaretakers) == '1';
      final has = links.isNotEmpty;
      if (had == has) return;
      await settings.set(keyHasCaretakers, has ? '1' : '0');
      if (has) {
        await CareSync.reset(db);
        CareSync.requestSoon(db);
      }
    }();
  });
});
