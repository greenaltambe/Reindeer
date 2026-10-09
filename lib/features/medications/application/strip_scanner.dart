import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum ScanSource { camera, gallery }

/// Takes or picks a photo of a medicine strip or bottle and reads the printed
/// text on the phone (nothing is uploaded). Returns null when the person
/// cancels, and an empty string when no text was found.
Future<String?> scanPackageText(ScanSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source == ScanSource.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    maxWidth: 1800,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(picked.path),
    );
    return result.text;
  } finally {
    await recognizer.close();
  }
}
