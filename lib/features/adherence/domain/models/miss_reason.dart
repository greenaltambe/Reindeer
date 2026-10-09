import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// The 6 barrier-aware reasons why a dose was missed or skipped.
enum MissReasonType {
  forgot,
  ranOut,
  sideEffect,
  feltFine,
  cost,
  fastingTravel,
  unknown;

  static MissReasonType fromName(String? name) => MissReasonType.values
      .firstWhere((e) => e.name == name, orElse: () => MissReasonType.unknown);

  String get label => switch (this) {
    MissReasonType.forgot => tr('Forgot'),
    MissReasonType.ranOut => tr('Ran out'),
    MissReasonType.sideEffect => tr('Side effect'),
    MissReasonType.feltFine => tr('Felt fine'),
    MissReasonType.cost => tr('Cost / price'),
    MissReasonType.fastingTravel => tr('Fasting or travel'),
    MissReasonType.unknown => tr('Other / unknown'),
  };

  String get emoji => switch (this) {
    MissReasonType.forgot => '⏰',
    MissReasonType.ranOut => '📦',
    MissReasonType.sideEffect => '⚠️',
    MissReasonType.feltFine => '😊',
    MissReasonType.cost => '💰',
    MissReasonType.fastingTravel => '✈️',
    MissReasonType.unknown => '❓',
  };
}

/// Recorded reason for one missed or skipped dose.
class MissReason {
  const MissReason({
    this.id,
    required this.planId,
    required this.doseDate,
    required this.slot,
    required this.reason,
    this.note,
    required this.at,
  });

  final int? id;
  final int planId;
  final String doseDate;
  final DaySlot slot;
  final MissReasonType reason;
  final String? note;
  final DateTime at;

  String get doseKey => '$planId|$doseDate|${slot.name}';
}
