import 'package:reindeer/features/medications/domain/models/dose_unit.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';

/// One medicine item parsed out of a scanned prescription photo.
class ScannedPrescriptionItem {
  ScannedPrescriptionItem({
    required this.name,
    this.composition = '',
    required this.slotAmounts,
    required this.mealTiming,
    required this.unit,
    this.durationDays,
    this.hit,
    this.isSelected = true,
  });

  String name;
  String composition;
  Map<DaySlot, double> slotAmounts;
  MealTiming mealTiming;
  DoseUnit unit;
  int? durationDays;
  MedicineHit? hit;
  bool isSelected;

  double get amountMorning => slotAmounts[DaySlot.morning] ?? 0;
  double get amountAfternoon => slotAmounts[DaySlot.afternoon] ?? 0;
  double get amountNight => slotAmounts[DaySlot.night] ?? 0;

  bool get hasActiveDose =>
      amountMorning > 0 || amountAfternoon > 0 || amountNight > 0;

  /// Human-readable schedule description for quick review, e.g. "1-0-1 · After food · 30 days"
  String get scheduleLabel {
    final m = fmt(amountMorning);
    final a = fmt(amountAfternoon);
    final n = fmt(amountNight);
    final parts = <String>['$m-$a-$n'];

    if (mealTiming != MealTiming.anytime) {
      parts.add(mealTiming.label);
    }
    if (durationDays != null) {
      parts.add(durationDays == 1 ? '1 day' : '$durationDays days');
    }
    return parts.join(' · ');
  }

  static String fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    if (v == 0.5) return '½';
    if (v == 1.5) return '1½';
    return v.toString();
  }
}

/// Parses multi-line doctor prescription text (printed or handwritten OCR)
/// into structured [ScannedPrescriptionItem] records.
class PrescriptionScanParser {
  const PrescriptionScanParser();

  static final _skipPatterns = RegExp(
    r'\b(hospital|clinic|nursing\s*home|patient|name|age|gender|sex|dr|doctor|mbbs|md|reg|review\s*after|follow\s*up|signature|pulse|bp|temp|weight|wt|investigation|diagnosis|complaint|phone|mob|mobile|date|email)\b|\bmmhg\b',
    caseSensitive: false,
  );

  static final _leadingIndex = RegExp(r'^\s*([0-9]+[.)\-:]|[•*#-])\s*');

  static final _formPrefixes = RegExp(
    r'\b(tab|tablets?|cap|capsules?|syp|syrup|inj|injection|oint|ointment|drops?|gel|cream|susp|suspension)\b\.?',
    caseSensitive: false,
  );

  static final _packagingNoise = RegExp(
    r'\b(strip|pack|bottle|box|mrp|rs|inr|qty|quantity)\b',
    caseSensitive: false,
  );

  static final _drugStrengthPattern = RegExp(
    r'(\d+\s*(mg|mcg|gm|ml)\b|\b\d{2,4}\b)',
    caseSensitive: false,
  );

  /// Takes raw OCR text and resolves each candidate prescription line against
  /// [MedicineSearchService], returning a structured list of items.
  static Future<List<ScannedPrescriptionItem>> parse(
    String rawText, {
    MedicineSearchService? searchService,
  }) async {
    final lines = rawText.split(RegExp(r'[\r\n]+'));
    final results = <ScannedPrescriptionItem>[];
    final seenNames = <String>{};

    for (final rawLine in lines) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      // Filter out pure symbols or lines with less than 2 letters
      final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;
      if (letterCount < 2) continue;

      // Clean leading Rx: or bullets/numbering (e.g. "Rx: 1. Tab Metformin")
      line = line.replaceFirst(RegExp(r'^\s*rx[:.]?\s*', caseSensitive: false), '').trim();
      line = line.replaceFirst(_leadingIndex, '').trim();

      if (line.isEmpty) continue;

      // Check for doctor/clinic/patient header noise
      if (_skipPatterns.hasMatch(line)) continue;

      final hasFormPrefix = _formPrefixes.hasMatch(line);

      // Parse clinical shorthand for dosage frequency (1-0-1, OD, BD, TDS, after food, etc.)
      final parsed = parseShorthand(line);

      // Clean the remaining query to identify the drug name
      var drugCandidate = parsed.query
          .replaceAll(_formPrefixes, ' ')
          .replaceAll(_packagingNoise, ' ')
          .replaceAll(RegExp(r'[^\w\s.+-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (drugCandidate.length < 2) continue;

      // Filter out lines that look like a standalone phone number or date
      if (RegExp(r'^[+\d\s\-().]+$').hasMatch(drugCandidate)) continue;

      // Attempt matching against bundled Indian Medicine Database
      MedicineHit? hit;
      if (searchService != null) {
        final directHits = await searchService.search(drugCandidate);
        if (directHits.isNotEmpty) {
          hit = directHits.first;
        } else {
          // If no direct hit, try first 2 words (e.g., "Telma 40" from "Telma 40 H")
          final words = drugCandidate.split(' ');
          if (words.length > 2) {
            final shortQuery = '${words[0]} ${words[1]}';
            final shortHits = await searchService.search(shortQuery);
            if (shortHits.isNotEmpty) {
              hit = shortHits.first;
            }
          }
        }
      }

      // Check plausibility: must have form prefix, DB hit, explicit dose schedule, or strength digits
      final hasDoseSchedule = parsed.amounts != null;
      final hasStrength = _drugStrengthPattern.hasMatch(drugCandidate);
      if (!hasFormPrefix && hit == null && !hasDoseSchedule && !hasStrength) {
        continue;
      }

      final resolvedName = hit != null ? hit.name : drugCandidate;
      final normalizedKey = resolvedName.toLowerCase().trim();
      if (seenNames.contains(normalizedKey)) continue;
      seenNames.add(normalizedKey);

      // Determine dose unit
      DoseUnit unit = DoseUnit.tablet;
      if (hit != null) {
        unit = DoseUnit.fromForm(hit.form);
      } else {
        final lower = rawLine.toLowerCase();
        if (lower.contains('cap')) {
          unit = DoseUnit.capsule;
        } else if (lower.contains('syp') || lower.contains('syrup')) {
          unit = DoseUnit.ml;
        } else if (lower.contains('drop')) {
          unit = DoseUnit.drops;
        }
      }

      // Default slot amounts: if none detected, default to 1 tablet morning (1-0-0)
      final slotAmounts = <DaySlot, double>{
        DaySlot.morning: parsed.amounts?[DaySlot.morning] ?? 1.0,
        DaySlot.afternoon: parsed.amounts?[DaySlot.afternoon] ?? 0.0,
        DaySlot.night: parsed.amounts?[DaySlot.night] ?? 0.0,
      };

      // Default meal timing: after food if none specified
      final mealTiming = parsed.timing ?? MealTiming.afterFood;

      results.add(
        ScannedPrescriptionItem(
          name: resolvedName,
          composition: hit?.composition ?? '',
          slotAmounts: slotAmounts,
          mealTiming: mealTiming,
          unit: unit,
          durationDays: parsed.days,
          hit: hit,
          isSelected: true,
        ),
      );
    }

    return results;
  }
}
