// lib/core/services/ocr_service.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<Map<String, String>?> scanIcCard(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    final lines = recognizedText.text.split('\n');
    if (lines.isEmpty) return null;

    String? extractedNric;
    String? extractedName;
    String extractedAddress = '';

    // More robust RegEx patterns for Malaysian IC
    final nricPattern = RegExp(r'\d{6}-\d{2}-\d{4}');
    final namePattern = RegExp(r"^([A-ZÀ-ÖØ-öø-ÿ\s'-]+ ){1,}[A-ZÀ-ÖØ-öø-ÿ\s'-]+$");
    final addressPattern = RegExp(r'\d{5}|\b(JALAN|JLN|TAMAN|TMN|LORONG|LRG|KAMPUNG|KG)\b', caseSensitive: false);

    bool addressStarted = false;
    for (final line in lines) {
        final currentLine = line.trim().replaceAll(' ', ''); // Remove spaces for NRIC matching
        final originalLine = line.trim(); // Keep original for other matches

        if (originalLine.isEmpty) continue;

        // Find and capture the NRIC
        if (nricPattern.hasMatch(currentLine) && extractedNric == null) {
            extractedNric = originalLine.replaceAll(' ', '');
            continue;
        }

        // Find the name using the more robust pattern
        if (namePattern.hasMatch(originalLine) && extractedName == null) {
            extractedName = originalLine;
            // Once the name is found, we assume the next lines are the address
            addressStarted = true;
            continue;
        }
        
        // If we've found the name or the line looks like an address, append it
        if (addressStarted || addressPattern.hasMatch(originalLine)) {
            extractedAddress += '$originalLine ';
        }
    }

    // Ensure we found all the necessary data
    if (extractedNric == null || extractedName == null || extractedAddress.trim().isEmpty) {
      return null;
    }

    return {
      'nric': extractedNric,
      'name': extractedName,
      'address': extractedAddress.trim(),
    };
  }
}