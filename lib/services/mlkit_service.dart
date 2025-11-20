import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/card_data.dart';

class MLKitService {
  final TextRecognizer _textRecognizer;

  MLKitService() : _textRecognizer = TextRecognizer();

  /// Recognize text from image file using Google ML Kit
  Future<CardData?> recognizeTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return null;
      }

      // Parse the recognized text to extract card data
      return _parseTextToCardData(recognizedText.text);
    } catch (e) {
      // ignore: avoid_print
      print('Error recognizing text with ML Kit: $e');
      return null;
    }
  }

  /// Parse recognized text to extract card data
  /// This is a basic parser - you can enhance it based on your needs
  CardData _parseTextToCardData(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    String? fullName;
    String? documentNumber;
    String? dateOfBirth;
    String? expiryDate;
    String? address;
    String? nationality;

    // Try to extract common patterns
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Look for document number (usually alphanumeric, 6-20 chars)
      if (documentNumber == null) {
        final docMatch = RegExp(r'[A-Z0-9]{6,20}').firstMatch(line);
        if (docMatch != null && line.length < 25) {
          documentNumber = docMatch.group(0);
        }
      }

      // Look for dates (DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, etc.)
      final datePatterns = [
        RegExp(r'\d{2}[/-]\d{2}[/-]\d{4}'),
        RegExp(r'\d{4}[/-]\d{2}[/-]\d{2}'),
        RegExp(r'\d{2}\s+\w{3}\s+\d{4}'),
      ];
      
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final dateValue = match.group(0);
          if (dateValue != null) {
            if (dateOfBirth == null) {
              dateOfBirth = dateValue;
            } else if (expiryDate == null && dateValue != dateOfBirth) {
              expiryDate = dateValue;
            }
          }
        }
      }

      // Look for name (usually 2-4 words, starts with capital)
      if (fullName == null && line.length > 5 && line.length < 50) {
        final namePattern = RegExp(r'^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+$');
        if (namePattern.hasMatch(line)) {
          fullName = line;
        }
      }

      // Look for address keywords
      if (address == null && (line.contains('Street') || 
          line.contains('Road') || 
          line.contains('Avenue') ||
          line.contains('City') ||
          line.contains('State') ||
          RegExp(r'\d+.*(?:Street|Road|Avenue|Lane|Drive)').hasMatch(line))) {
        address = line;
      }

      // Look for nationality/country
      if (nationality == null) {
        final countryPattern = RegExp(r'\b(?:USA|UK|CAN|AUS|IND|PAK|BGD|CHN|JPN|KOR|DEU|FRA|ITA|ESP|NLD|BEL|SWE|NOR|DNK|FIN|POL|CZE|HUN|ROU|BGR|GRC|TUR|RUS|BRA|ARG|MEX|ZAF|EGY|NGA|KEN|MAR|TUN|DZA|LBY|SDN|ETH|UGA|TZA|MOZ|ZWE|BWA|NAM|AGO|GHA|SEN|MLI|BFA|NER|TCD|CMR|GAB|COG|CAF|TGO|BEN|GNB|GIN|SLE|LBR|CIV|GHA|MRT|DJI|SOM|ERI|COM|MDG|MUS|SYC|STP|GNQ|CPV|GMB|SWZ|LSO|BWA|ZMB|MWI|MOZ|ZWE|NAM|AGO|GAB|COG|CAF|TGO|BEN|GNB|GIN|SLE|LBR|CIV|GHA|MRT|DJI|SOM|ERI|COM|MDG|MUS|SYC|STP|GNQ|CPV|GMB|SWZ|LSO)\b', caseSensitive: false);
        if (countryPattern.hasMatch(line)) {
          nationality = countryPattern.firstMatch(line)?.group(0);
        }
      }
    }

    // If we found a name-like pattern but not in fullName, use first substantial line
    if (fullName == null && lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.length > 5 && firstLine.length < 50 && 
          !RegExp(r'^\d+').hasMatch(firstLine)) {
        fullName = firstLine;
      }
    }

    return CardData(
      fullName: fullName,
      documentNumber: documentNumber,
      dateOfBirth: dateOfBirth,
      expiryDate: expiryDate,
      address: address,
      nationality: nationality,
      rawText: text,
    );
  }

  /// Dispose the text recognizer
  void dispose() {
    _textRecognizer.close();
  }
}

