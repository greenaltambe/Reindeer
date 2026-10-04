/// Unit a single dose is measured in. Covers common Indian dosage forms.
enum DoseUnit {
  tablet,
  capsule,
  ml,
  drops,
  puffs,
  units,
  injection,
  application,
  sachet;

  /// Describes [amount] of this unit, for example `1 tablet` or `5 ml`.
  String describe(double amount) {
    final n = formatAmount(amount);
    final one = amount == 1;
    return switch (this) {
      DoseUnit.tablet => '$n ${one ? 'tablet' : 'tablets'}',
      DoseUnit.capsule => '$n ${one ? 'capsule' : 'capsules'}',
      DoseUnit.ml => '$n ml',
      DoseUnit.drops => '$n ${one ? 'drop' : 'drops'}',
      DoseUnit.puffs => '$n ${one ? 'puff' : 'puffs'}',
      DoseUnit.units => '$n ${one ? 'unit' : 'units'}',
      DoseUnit.injection => '$n ${one ? 'injection' : 'injections'}',
      DoseUnit.application => '$n ${one ? 'application' : 'applications'}',
      DoseUnit.sachet => '$n ${one ? 'sachet' : 'sachets'}',
    };
  }

  /// Short label used in pickers.
  String get label => switch (this) {
    DoseUnit.tablet => 'Tablet',
    DoseUnit.capsule => 'Capsule',
    DoseUnit.ml => 'ml (liquid)',
    DoseUnit.drops => 'Drops',
    DoseUnit.puffs => 'Puffs',
    DoseUnit.units => 'Units',
    DoseUnit.injection => 'Injection',
    DoseUnit.application => 'Apply',
    DoseUnit.sachet => 'Sachet',
  };

  /// Step used by the +/- buttons when choosing a dose amount.
  double get step => switch (this) {
    DoseUnit.tablet => 0.5,
    DoseUnit.ml => 2.5,
    _ => 1,
  };

  /// Maps the medicine database's `form` column to a sensible default unit.
  static DoseUnit fromForm(String? form) => switch (form) {
    'capsule' => DoseUnit.capsule,
    'liquid' => DoseUnit.ml,
    'drops' => DoseUnit.drops,
    'inhaler' => DoseUnit.puffs,
    'injection' => DoseUnit.injection,
    'topical' => DoseUnit.application,
    'powder' => DoseUnit.sachet,
    _ => DoseUnit.tablet,
  };

  static DoseUnit fromName(String? name) {
    for (final unit in DoseUnit.values) {
      if (unit.name == name) return unit;
    }
    return DoseUnit.tablet;
  }
}

/// `1` -> `1`, `0.5` -> `0.5`, `2.0` -> `2`.
String formatAmount(double a) =>
    a == a.roundToDouble() ? a.toInt().toString() : a.toString();

/// Part of the day a dose belongs to. Each maps to a meal anchor.
enum DaySlot {
  morning,
  afternoon,
  night;

  String get label => switch (this) {
    DaySlot.morning => 'Morning',
    DaySlot.afternoon => 'Afternoon',
    DaySlot.night => 'Night',
  };

  /// Which meal the slot is tied to.
  String get mealLabel => switch (this) {
    DaySlot.morning => 'breakfast',
    DaySlot.afternoon => 'lunch',
    DaySlot.night => 'dinner',
  };

  static DaySlot fromName(String name) => DaySlot.values.firstWhere(
    (s) => s.name == name,
    orElse: () => DaySlot.morning,
  );
}

/// Instruction relating the dose to food.
enum MealTiming {
  anytime,
  beforeFood,
  afterFood,
  withFood;

  String get label => switch (this) {
    MealTiming.anytime => "Doesn't matter",
    MealTiming.beforeFood => 'Before food',
    MealTiming.afterFood => 'After food',
    MealTiming.withFood => 'With food',
  };

  /// Reminder offset relative to the meal time.
  int get offsetMinutes => switch (this) {
    MealTiming.beforeFood => -30,
    MealTiming.afterFood => 30,
    _ => 0,
  };

  static MealTiming fromName(String? name) => MealTiming.values.firstWhere(
    (t) => t.name == name,
    orElse: () => MealTiming.anytime,
  );
}

/// Lifecycle state of a medication plan.
enum PlanStatus {
  active,
  paused,
  discontinued;

  static PlanStatus fromName(String? name) => PlanStatus.values.firstWhere(
    (s) => s.name == name,
    orElse: () => PlanStatus.active,
  );
}
