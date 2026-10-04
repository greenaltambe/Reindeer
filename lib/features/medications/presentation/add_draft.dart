import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';

/// What the add flow carries from the search screen to the details screen.
///
/// [hit] is null for a medicine the person typed in themselves. [barcode] is
/// the key of a scanned pack to remember once the medicine is saved.
class AddDraft {
  const AddDraft({this.hit, this.customName = '', this.barcode});

  final MedicineHit? hit;
  final String customName;
  final String? barcode;

  bool get isCustom => hit == null;
}
