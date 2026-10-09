import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/app_logger.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/firebase_options.dart';

/// Region of the Cloud Functions; must match `functions/index.js`.
const String _functionsRegion = 'asia-south1';

/// How long an invite code stays valid.
const Duration inviteLifetime = Duration(minutes: 15);

/// Why linking with a code failed, in words for the person.
class CareLinkException implements Exception {
  const CareLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything that talks to Firebase for caretaker sharing.
///
/// Nothing here runs until someone sets up sharing: a phone that never links
/// with a caretaker never signs in or sends anything.
abstract final class CareBackend {
  static bool _ready = false;

  /// Prepares Firebase. Safe to call many times and from background isolates.
  static Future<bool> init() async {
    if (_ready) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _ready = true;
    } catch (e, s) {
      AppLogger.error('Firebase set-up failed', error: e, stackTrace: s);
    }
    return _ready;
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// This phone's anonymous id, or null if it never set up sharing.
  static String? get uid =>
      _ready ? FirebaseAuth.instance.currentUser?.uid : null;

  /// Signs in anonymously (first time only) and registers this phone for
  /// notifications. Returns the id.
  static Future<String> signIn() async {
    if (!await init()) {
      throw CareLinkException(tr('Could not connect. Check the internet.'));
    }
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (user == null) {
      throw CareLinkException(tr('Could not connect. Check the internet.'));
    }
    await registerDevice();
    return user.uid;
  }

  /// Stores the notification token and language so alerts reach this phone
  /// in its language.
  static Future<void> registerDevice({String? token}) async {
    final id = uid;
    if (id == null) return;
    try {
      final t = token ?? await FirebaseMessaging.instance.getToken();
      await _db.doc('users/$id').set({
        'token': ?t,
        'lang': I18n.current.code,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      AppLogger.error('Could not register for alerts', error: e, stackTrace: s);
    }
  }

  // -------------------------------------------------------------------------
  // Patient side

  /// Saves what caretakers see about the patient.
  static Future<void> savePatientInfo({String? name, String? phone}) async {
    final id = uid;
    if (id == null) return;
    await _db.doc('patients/$id').set({
      'name': ?name,
      'phone': ?phone,
      'lang': I18n.current.code,
    }, SetOptions(merge: true));
  }

  /// Creates a fresh 6-digit code a caretaker can type in.
  static Future<String> createInvite({required String patientName}) async {
    final id = await signIn();
    await savePatientInfo(name: patientName);
    final random = Random.secure();
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = (100000 + random.nextInt(900000)).toString();
      try {
        final now = DateTime.now();
        // Fails (rules allow create only) if the code is already in use.
        await _db.doc('invites/$code').set({
          'patientUid': id,
          'patientName': patientName,
          'createdAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(now.add(inviteLifetime)),
        });
        return code;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    throw CareLinkException(tr('Could not make a code. Please try again.'));
  }

  static Future<void> cancelInvite(String code) async {
    try {
      await _db.doc('invites/$code').delete();
    } catch (_) {
      // Expires by itself.
    }
  }

  /// People who look after [patientUid].
  static Stream<List<CareLink>> caretakersOf(String patientUid) => _db
      .collection('links')
      .where('patientUid', isEqualTo: patientUid)
      .snapshots()
      .map(_links);

  /// Raises an alert, request or battery warning for this patient's caretakers.
  static Future<void> sendPatientEvent(
    String type, {
    List<String>? items,
    String? photoBase64,
    int? level,
  }) async {
    final id = uid;
    if (id == null) return;
    final events = _db.collection('patients/$id/events');
    final event = events.doc();
    final batch = _db.batch();
    if (photoBase64 != null) {
      // Same id as the event, so the caretaker can find it.
      batch.set(_db.doc('patients/$id/photos/${event.id}'), {
        'data': photoBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(event, {
      'type': type,
      'from': id,
      'createdAt': FieldValue.serverTimestamp(),
      'items': ?items,
      if (photoBase64 != null) 'hasPhoto': true,
      'level': ?level,
    });
    await batch.commit();
  }

  // -------------------------------------------------------------------------
  // Caretaker side

  /// Redeems a code. Returns the new link's id and the patient's name.
  static Future<({String linkId, String patientName})> claimInvite(
    String code, {
    required String name,
  }) async {
    final me = await signIn();
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: _functionsRegion)
              .httpsCallable('claimInvite')
              .call<Map<String, dynamic>>({'code': code, 'name': name});
      final patientUid = result.data['patientUid'] as String? ?? '';
      return (
        linkId: '${patientUid}_$me',
        patientName: result.data['patientName'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw CareLinkException(switch (e.message) {
        'bad-code' => tr(
          'That code did not work. Check the numbers, or ask for a new code.',
        ),
        'own-code' => tr(
          'This is your own code. Enter it on the other person\'s phone.',
        ),
        'too-many-tries' => tr('Too many tries. Please wait an hour.'),
        _ => tr('Could not connect. Check the internet.'),
      });
    }
  }

  /// People this phone looks after.
  static Stream<List<CareLink>> patientsOf(String caretakerUid) => _db
      .collection('links')
      .where('caretakerUid', isEqualTo: caretakerUid)
      .snapshots()
      .map(_links);

  static Future<void> updateLink(String linkId, Map<String, Object?> data) =>
      _db.doc('links/$linkId').update(data);

  static Future<void> unlink(String linkId) =>
      _db.doc('links/$linkId').delete();

  static Stream<PatientInfo> patientInfo(String patientUid) => _db
      .doc('patients/$patientUid')
      .snapshots()
      .map((d) => PatientInfo.fromMap(d.data()));

  /// The patient's doses on [date] (`yyyy-mm-dd`).
  static Stream<List<CareDose>> dosesOn(String patientUid, String date) => _db
      .collection('patients/$patientUid/doses')
      .where('date', isEqualTo: date)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) CareDose.fromMap(d.id, d.data())]
              ..sort((a, b) => a.at.compareTo(b.at)),
      );

  /// Recent medicine requests from the patient (newest first).
  static Stream<List<CareRequest>> requestsFrom(String patientUid) => _db
      .collection('patients/$patientUid/events')
      .orderBy('createdAt', descending: true)
      .limit(15)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (d.data()['type'] == 'request')
              CareRequest(
                id: d.id,
                items: [
                  for (final i in (d.data()['items'] as List? ?? const []))
                    '$i',
                ],
                hasPhoto: d.data()['hasPhoto'] == true,
                createdAt:
                    (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ),
        ],
      );

  static Future<CareRequest?> request(String patientUid, String id) async {
    final d = await _db.doc('patients/$patientUid/events/$id').get();
    final m = d.data();
    if (m == null) return null;
    return CareRequest(
      id: id,
      items: [for (final i in (m['items'] as List? ?? const [])) '$i'],
      hasPhoto: m['hasPhoto'] == true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// The prescription photo of request [id], base64-encoded JPEG.
  static Future<String?> photo(String patientUid, String id) async {
    final d = await _db.doc('patients/$patientUid/photos/$id').get();
    return d.data()?['data'] as String?;
  }

  /// "Send love" or "I'm on it" to a patient.
  static Future<void> sendToPatient(String patientUid, String type) async {
    final id = uid;
    if (id == null) return;
    await _db.collection('patients/$patientUid/events').add({
      'type': type,
      'from': id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static List<CareLink> _links(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) CareLink.fromMap(d.id, d.data()),
  ];
}
