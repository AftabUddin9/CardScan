import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://center3.ntouch.ai/api';

  /// Save blob/file to server
  /// Returns the file ID (string) that can be used as reference
  static Future<String?> saveBlob({
    required String content, // Base64 encoded image
    String note = 'mobile-app',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/file-management/file/save-blob');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': content, 'note': note}),
      );

      // Print response for debugging
      print('=== Save Blob API Response ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==============================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // The API may return a string (file ID) or JSON
        final responseBody = response.body.trim();

        // Try to parse as JSON first
        try {
          final jsonResponse = jsonDecode(responseBody);
          if (jsonResponse is Map<String, dynamic>) {
          } else if (jsonResponse is String) {
            // If JSON is just a string, use it
            if (jsonResponse.isNotEmpty) {
              return jsonResponse;
            }
          }
        } catch (e) {
          // Not JSON, treat as plain string
        }

        // If not JSON or JSON parsing didn't work, treat as plain string
        final fileId = responseBody.replaceAll('"', '').trim();
        if (fileId.isNotEmpty) {
          return fileId;
        }

        print('Warning: API response may be invalid or same as fileUniqueName');
        print('Response: $responseBody');
        return null;
      } else {
        print('Error saving blob: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception saving blob: $e');
      return null;
    }
  }

  /// Complete visitor check-in
  /// Returns the response data
  static Future<Map<String, dynamic>?> completeCheckIn({
    required String name,
    required String email,
    required String profilePictureFileId, // Image reference from selfie
    required String purposeOfVisit,
    required List<Map<String, String>>
    files, // List with documentType and fileId
    required Map<String, String> dynamicData, // IdNumber, phone, company
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/visitor/anonymous-visitor/self-visitor-register',
      );

      final payload = {
        'name': name,
        'email': email,
        'profilePictureFileId': profilePictureFileId,
        'purposeOfVisit': purposeOfVisit,
        'files': files,
        'dynamicData': dynamicData,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // Print response for debugging
      print('=== Complete Check-In API Response ===');
      print('Status Code: ${response.statusCode}');
      print('Request Payload: ${jsonEncode(payload)}');
      print('Response Body: ${response.body}');
      print('======================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          // If response is not JSON, return as string
          return {'message': response.body};
        }
      } else {
        print(
          'Error completing check-in: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Exception completing check-in: $e');
      return null;
    }
  }

  /// Convert image file to base64 string
  static Future<String?> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }
}
