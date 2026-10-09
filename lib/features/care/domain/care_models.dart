import 'package:reindeer/core/i18n/strings.dart';

/// How a phone is used: for the owner's own medicines, or only to look after
/// someone else's.
enum CareMode {
  patient,
  caretaker;

  static CareMode fromName(String? name) =>
      name == CareMode.caretaker.name ? CareMode.caretaker : CareMode.patient;
}

/// One patient <-> caretaker connection, seen from either phone.
class CareLink {
  const CareLink({
    required this.id,
    required this.patientUid,
    required this.caretakerUid,
    this.patientName = '',
    this.nickname = '',
    this.caretakerName = '',
    this.caretakerPhone = '',
    this.notifyTaken = false,
    this.notifySkipped = true,
  });

  factory CareLink.fromMap(String id, Map<String, dynamic> m) => CareLink(
    id: id,
    patientUid: m['patientUid'] as String? ?? '',
    caretakerUid: m['caretakerUid'] as String? ?? '',
    patientName: m['patientName'] as String? ?? '',
    nickname: m['nickname'] as String? ?? '',
    caretakerName: m['caretakerName'] as String? ?? '',
    caretakerPhone: m['caretakerPhone'] as String? ?? '',
    notifyTaken: m['notifyTaken'] == true,
    notifySkipped: m['notifySkipped'] != false,
  );

  final String id;
  final String patientUid;
  final String caretakerUid;

  /// The name the patient gave themselves.
  final String patientName;

  /// What the caretaker calls the patient ("Mom").
  final String nickname;
  final String caretakerName;
  final String caretakerPhone;
  final bool notifyTaken;
  final bool notifySkipped;

  /// The patient's name as the caretaker sees it.
  String get patientLabel => nickname.isNotEmpty
      ? nickname
      : (patientName.isNotEmpty ? patientName : tr('Your family member'));

  /// The caretaker's name as the patient sees it.
  String get caretakerLabel =>
      caretakerName.isNotEmpty ? caretakerName : tr('Your caretaker');
}

/// Shared details of a patient's phone.
class PatientInfo {
  const PatientInfo({
    this.name = '',
    this.phone = '',
    this.battery,
    this.charging = false,
    this.lastSeen,
  });

  factory PatientInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PatientInfo();
    return PatientInfo(
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      battery: (m['battery'] as num?)?.toInt(),
      charging: m['charging'] == true,
      lastSeen: _date(m['lastSeen']),
    );
  }

  final String name;
  final String phone;
  final int? battery;
  final bool charging;
  final DateTime? lastSeen;

  bool get batteryLow => battery != null && battery! <= 15 && !charging;
}

/// One dose as the caretaker sees it.
class CareDose {
  const CareDose({
    required this.id,
    required this.date,
    required this.at,
    required this.deadline,
    required this.name,
    required this.amount,
    required this.time,
    required this.status,
    this.doneTime = '',
    this.reason = '',
  });

  factory CareDose.fromMap(String id, Map<String, dynamic> m) => CareDose(
    id: id,
    date: m['date'] as String? ?? '',
    at: _date(m['at']) ?? DateTime.now(),
    deadline: _date(m['deadline']) ?? DateTime.now(),
    name: m['name'] as String? ?? '',
    amount: m['amount'] as String? ?? '',
    time: m['time'] as String? ?? '',
    status: m['status'] as String? ?? 'pending',
    doneTime: m['doneTime'] as String? ?? '',
    reason: m['reason'] as String? ?? '',
  );

  final String id;
  final String date;
  final DateTime at;
  final DateTime deadline;
  final String name;
  final String amount;
  final String time;

  /// `pending`, `taken` or `skipped`.
  final String status;
  final String doneTime;

  /// A `MissReasonType` name, or empty.
  final String reason;

  bool get taken => status == 'taken';
  bool get skipped => status == 'skipped';
  bool isLate(DateTime now) => status == 'pending' && now.isAfter(at);
  bool isMissed(DateTime now) => status == 'pending' && now.isAfter(deadline);
}

/// A patient asking a caretaker to buy medicines.
class CareRequest {
  const CareRequest({
    required this.id,
    required this.items,
    required this.hasPhoto,
    required this.createdAt,
  });

  final String id;
  final List<String> items;
  final bool hasPhoto;
  final DateTime createdAt;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  // Firestore Timestamps expose toDate(); kept dynamic so this file needs no
  // Firebase import and stays easy to test.
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return v is DateTime ? v : null;
  }
}
