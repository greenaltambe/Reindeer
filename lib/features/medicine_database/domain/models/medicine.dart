/// Where a medicine record came from.
///
/// [brand] and [generic] come from the bundled database; [custom] was typed in
/// by the person and must never be presented as database-verified.
enum MedicineKind {
  brand,
  generic,
  custom;

  static MedicineKind fromName(String? name) => MedicineKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => MedicineKind.custom,
  );
}

/// One search result from the bundled medicine database.
class MedicineHit {
  const MedicineHit({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.pack,
    required this.packQty,
    required this.composition,
    required this.form,
    required this.kind,
    required this.compositionMayBeIncomplete,
    required this.usedFor,
    this.uses = const [],
  });

  final int id;
  final String name;
  final String manufacturer;

  /// Pack label such as `strip of 10 tablets`.
  final String pack;

  /// First number in the pack label (tablets per strip, ml per bottle).
  final double? packQty;

  /// Display composition, for example `Paracetamol (650mg)`. Empty for generics.
  final String composition;

  /// `tablet`, `capsule`, `liquid`, `drops`, `injection`, `topical`,
  /// `inhaler`, `powder` or `other`.
  final String form;
  final MedicineKind kind;

  /// True when the product name lists more strengths than the database lists
  /// ingredients (the source keeps at most two).
  final bool compositionMayBeIncomplete;

  /// Short "what it is used for" text from the database, may be empty.
  final String usedFor;

  /// Conditions this medicine is used for, from the database (may be empty).
  final List<String> uses;

  bool get isGeneric => kind == MedicineKind.generic;

  /// Second line shown in result lists.
  String get subtitle {
    final parts = <String>[
      if (composition.isNotEmpty) composition,
      if (isGeneric) 'Generic (Jan Aushadhi list)' else manufacturer,
      if (pack.isNotEmpty) pack,
    ];
    return parts.join(' · ');
  }
}
