import 'package:reindeer/features/medications/domain/models/dose_unit.dart';

/// The person's usual meal times, as minutes since midnight.
///
/// Doses are tied to these ("after breakfast"), so changing breakfast time
/// moves every dose that depends on it.
class MealAnchors {
  const MealAnchors({
    this.breakfast = 8 * 60,
    this.lunch = 13 * 60 + 30,
    this.dinner = 20 * 60 + 30,
  });

  final int breakfast;
  final int lunch;
  final int dinner;

  int anchorFor(DaySlot slot) => switch (slot) {
    DaySlot.morning => breakfast,
    DaySlot.afternoon => lunch,
    DaySlot.night => dinner,
  };

  /// Reminder time (minutes since midnight) for [slot] given [timing].
  int minutesFor(DaySlot slot, MealTiming timing) =>
      (anchorFor(slot) + timing.offsetMinutes).clamp(0, 24 * 60 - 1).toInt();

  MealAnchors copyWith({int? breakfast, int? lunch, int? dinner}) =>
      MealAnchors(
        breakfast: breakfast ?? this.breakfast,
        lunch: lunch ?? this.lunch,
        dinner: dinner ?? this.dinner,
      );
}
