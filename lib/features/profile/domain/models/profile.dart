/// A person whose medications are managed on this device (self, parent, child).
///
/// Only a display name is required; birth year is optional to keep personal
/// data minimal.
class Profile {
  const Profile({required this.id, required this.displayName, this.birthYear});

  final String id;
  final String displayName;
  final int? birthYear;
}
