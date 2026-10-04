import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/core/utils/reindeer_voice.dart';

void main() {
  test('greeting follows the time of day', () {
    expect(
      ReindeerVoice.greeting(DateTime(2026, 10, 3, 8)),
      startsWith('Good morning'),
    );
    expect(
      ReindeerVoice.greeting(DateTime(2026, 10, 3, 14)),
      startsWith('Good afternoon'),
    );
    expect(
      ReindeerVoice.greeting(DateTime(2026, 10, 3, 19)),
      startsWith('Good evening'),
    );
    expect(
      ReindeerVoice.greeting(DateTime(2026, 10, 3, 23)),
      startsWith('Good night'),
    );
  });

  test('Christmas week gets a seasonal line', () {
    expect(
      ReindeerVoice.greeting(DateTime(2026, 12, 24, 9)),
      contains('Ho ho'),
    );
  });
}
