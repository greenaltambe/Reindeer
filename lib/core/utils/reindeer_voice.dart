import 'dart:math';

/// Small pieces of mascot personality: greetings, empty-state lines, and the
/// easter-egg quips shown when the reindeer is tapped.
abstract final class ReindeerVoice {
  /// Greeting under the Today title.
  static String greeting(DateTime now) {
    final base = switch (now.hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      >= 17 && < 21 => 'Good evening',
      _ => 'Good night',
    };
    if (now.month == 12 && now.day >= 20 && now.day <= 26) {
      return '$base. Ho ho, no skipping doses this week.';
    }
    return '$base. Your reindeer is on watch.';
  }

  static const String allDone = 'All done for today. Your reindeer is proud.';
  static const String nothingYet = 'Your reindeer has nothing to guard yet.';
  static const String perfectRun =
      'Not a single dose missed. Even Rudolph would be impressed.';

  static const List<String> _quips = [
    'Dasher, Dancer, Prancer... and your 8 PM dose.',
    'Rudolph had a glowing nose. You have a reminder.',
    'Reindeer fact: both males and females grow antlers.',
    'Reindeer fact: their knees click when they walk.',
    'Reindeer fact: their noses warm the cold air before it reaches the lungs.',
    'Slow and steady. Reindeer travel far one step at a time.',
  ];

  static String quip(Random random) => _quips[random.nextInt(_quips.length)];
}
