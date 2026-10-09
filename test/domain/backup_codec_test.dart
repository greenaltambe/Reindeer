import 'package:flutter_test/flutter_test.dart';
import 'package:reindeer/features/backup/domain/backup_codec.dart';

void main() {
  final data = <String, List<Map<String, Object?>>>{
    'plans': [
      {'id': 1, 'name': 'Metformin', 'stock': null, 'morning': 1.5},
    ],
    'allergies': [
      {'id': 1, 'profile_id': 'me', 'name': 'Penicillins'},
    ],
  };

  test('round trip keeps rows and fills missing tables', () {
    final text = encodeBackup(data, DateTime(2026, 10, 7));
    final back = decodeBackup(text);
    expect(back['plans']!.single['name'], 'Metformin');
    expect(back['plans']!.single['morning'], 1.5);
    expect(back['plans']!.single['stock'], isNull);
    expect(back['symptoms'], isEmpty);
    expect(summarize(back).medicines, 1);
  });

  test('rejects other files', () {
    expect(() => decodeBackup('hello'), throwsFormatException);
    expect(() => decodeBackup('{"app":"other"}'), throwsFormatException);
    expect(() => decodeBackup('[1,2]'), throwsFormatException);
  });

  test('rejects newer schema', () {
    expect(
      () => decodeBackup('{"app":"reindeer","schema":99,"tables":{}}'),
      throwsFormatException,
    );
  });

  test('rejects bad column names and damaged tables', () {
    expect(
      () => decodeBackup(
        '{"app":"reindeer","schema":3,"tables":{"plans":[{"name; drop":1}]}}',
      ),
      throwsFormatException,
    );
    expect(
      () => decodeBackup('{"app":"reindeer","schema":3,"tables":{"plans":5}}'),
      throwsFormatException,
    );
  });
}
