import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reindeer/features/medications/domain/ocr_rows.dart';

enum ScanSource { camera, gallery }

/// Takes or picks a photo of a medicine strip or bottle and reads the printed
/// text on the phone (nothing is uploaded). Returns null when the person
/// cancels, and an empty string when no text was found.
Future<String?> scanPackageText(ScanSource source) async {
  final result = await _pickAndRecognize(source, maxWidth: 1800, quality: 85);
  return result?.text;
}

/// Like [scanPackageText], for a doctor's prescription: a sharper photo, and
/// the text is put back in rows as it appears on the paper so each medicine
/// stays on the same line as its dose.
Future<String?> scanPrescriptionText(ScanSource source) async {
  final result = await _pickAndRecognize(source, maxWidth: 3000, quality: 95);
  if (result == null) return null;
  final lines = [
    for (final block in result.blocks)
      for (final line in block.lines) _toOcrLine(line),
  ];
  final rows = joinOcrRows(lines);
  return rows.isEmpty ? result.text : rows;
}

Future<RecognizedText?> _pickAndRecognize(
  ScanSource source, {
  required double maxWidth,
  required int quality,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source == ScanSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: quality,
  );
  if (picked == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    return await recognizer.processImage(InputImage.fromFilePath(picked.path));
  } finally {
    await recognizer.close();
  }
}

OcrLine _toOcrLine(TextLine line) {
  final box = line.boundingBox;
  var slope = 0.0;
  final p = line.cornerPoints;
  if (p.length >= 2 && p[1].x != p[0].x) {
    slope = (p[1].y - p[0].y) / (p[1].x - p[0].x);
  }
  return OcrLine(
    text: line.text,
    left: box.left,
    top: box.top,
    right: box.right,
    bottom: box.bottom,
    slope: slope,
  );
}
