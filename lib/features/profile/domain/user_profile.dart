/// The person using the app: only what Reindeer actually needs.
class UserProfile {
  const UserProfile({required this.name, this.birthYear, this.heightCm});

  final String name;
  final int? birthYear;

  /// Used only to work out BMI for weight readings.
  final double? heightCm;

  /// Approximate age (year of birth only); null when not given.
  int? ageAt(DateTime now) => birthYear == null ? null : now.year - birthYear!;

  bool isMinor(DateTime now) {
    final age = ageAt(now);
    return age != null && age < 18;
  }

  String get firstName {
    final t = name.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }
}
