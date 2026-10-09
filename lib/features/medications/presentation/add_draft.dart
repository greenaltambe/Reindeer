import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';

/// What the add flow carries from the search screen to the details screen.
///
/// [hit] is null for a medicine the person typed in themselves.
class AddDraft {
  const AddDraft({this.hit, this.customName = '', this.prefill});

  final MedicineHit? hit;
  final String customName;

  /// Schedule read from a typed prescription line, if there was one.
  final ParsedShorthand? prefill;

  bool get isCustom => hit == null;
}
