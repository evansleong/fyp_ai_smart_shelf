import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<Map<String, String?>?> scanIcCard(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    final lines = recognizedText.text.split('\n');
    if (lines.isEmpty) return null;

    String? extractedNric;
    String? extractedName;
    String? extractedGender;
    String extractedReligion = 'Non-Muslim'; // Default to Non-Muslim

    final nricPattern = RegExp(r'\d{6}-\d{2}-\d{4}');
    final namePattern = RegExp(r'^[A-Z\s]{5,}$');

    for (final line in lines) {
        final originalLine = line.trim();
        if (originalLine.isEmpty) continue;

        // Use a case-insensitive version for keyword matching
        final upperCaseLine = originalLine.toUpperCase();

        // Find and capture the NRIC
        if (nricPattern.hasMatch(originalLine.replaceAll(' ', '')) && extractedNric == null) {
            extractedNric = originalLine.replaceAll(' ', '');
            continue;
        }

        // --- NEW LOGIC: Detect Gender and Religion ---
        if (upperCaseLine.contains('PEREMPUAN')) {
          extractedGender = 'Female';
        } else if (upperCaseLine.contains('LELAKI')) {
          extractedGender = 'Male';
        }

        if (upperCaseLine.contains('ISLAM')) {
          extractedReligion = 'Muslim';
        }
        // --- END NEW LOGIC ---

        // Find the name (often in all caps)
        // Let's refine this: A name usually doesn't have address keywords.
        if (namePattern.hasMatch(upperCaseLine) && extractedName == null && extractedNric != null) {
            extractedName = originalLine;
            continue;
        }
        
    }

    // Ensure we found at least the critical data
    if (extractedNric == null || extractedName == null) {
      return null;
    }

    return {
      'nric': extractedNric,
      'name': extractedName,
      'gender': extractedGender,      // Return the detected gender
      'religion': extractedReligion,  // Return the detected religion
    };
  }
}