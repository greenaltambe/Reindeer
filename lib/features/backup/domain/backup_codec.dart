import 'dart:convert';

/// Tables included in a backup, in the order they are restored.
const backupTables = <String>[
  'profiles',
  'plans',
  'dose_logs',
  'refills',
  'settings',
  'profile_conditions',
  'measurements',
  'allergies',
  'symptoms',
  'dots_observations',
];

/// Version of the backup layout. Bump when a table changes shape.
const backupSchema = 5;

typedef BackupData = Map<String, List<Map<String, Object?>>>;

final _columnName = RegExp(r'^[a-z][a-z0-9_]*$');

/// Turns table rows into the text saved in a backup file.
String encodeBackup(BackupData tables, DateTime now) => jsonEncode({
  'app': 'reindeer',
  'schema': backupSchema,
  'created': now.toIso8601String(),
  'tables': tables,
});

/// Reads backup text. Throws [FormatException] with a message fit to show the
/// person when the file is not a Reindeer backup.
BackupData decodeBackup(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    throw const FormatException('This file is not a Reindeer backup.');
  }
  if (root is! Map || root['app'] != 'reindeer') {
    throw const FormatException('This file is not a Reindeer backup.');
  }
  final schema = root['schema'];
  if (schema is! int || schema > backupSchema) {
    throw const FormatException(
      'This backup is from a newer version of Reindeer. Update the app and try again.',
    );
  }
  final tables = root['tables'];
  if (tables is! Map) {
    throw const FormatException('This backup has no data in it.');
  }
  final out = <String, List<Map<String, Object?>>>{};
  for (final name in backupTables) {
    final rows = tables[name];
    if (rows == null) {
      out[name] = const [];
      continue;
    }
    if (rows is! List) {
      throw FormatException('The "$name" part of this backup is damaged.');
    }
    final clean = <Map<String, Object?>>[];
    for (final r in rows) {
      if (r is! Map) {
        throw FormatException('The "$name" part of this backup is damaged.');
      }
      final row = <String, Object?>{};
      for (final e in r.entries) {
        final k = e.key;
        if (k is! String || !_columnName.hasMatch(k)) {
          throw FormatException('The "$name" part of this backup is damaged.');
        }
        final v = e.value;
        if (v != null && v is! num && v is! String) {
          throw FormatException('The "$name" part of this backup is damaged.');
        }
        row[k] = v;
      }
      clean.add(row);
    }
    out[name] = clean;
  }
  return out;
}

/// How many records a backup holds, for a confirmation message.
({int medicines, int doses, int readings}) summarize(BackupData d) => (
  medicines: d['plans']?.length ?? 0,
  doses: d['dose_logs']?.length ?? 0,
  readings: d['measurements']?.length ?? 0,
);
