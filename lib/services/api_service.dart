import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://center3.ntouch.ai/api';

  /// Save blob/file to server
  /// Accepts a File object and sends it with its extension
  static Future<String?> saveBlob({
    required File imageFile, // Image file with extension
  }) async {
    try {
      final url = Uri.parse('$baseUrl/file-management/file');

      // Get file extension from path
      final filePath = imageFile.path;
      final fileExtension = filePath.contains('.')
          ? filePath.substring(filePath.lastIndexOf('.'))
          : '.jpg'; // Default to .jpg if no extension found
      final fileName = 'image$fileExtension';

      // Create multipart request
      final request = http.MultipartRequest('POST', url);

      // Add file to request with 'Content' as the field name
      request.files.add(
        await http.MultipartFile.fromPath(
          'Content', // Field name for the file (as per API spec)
          imageFile.path,
          filename: fileName,
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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
            // Look for common field names that might contain the file ID
            final fileId =
                jsonResponse['fileId'] ??
                jsonResponse['id'] ??
                jsonResponse['reference'];
            if (fileId != null && fileId is String && fileId.isNotEmpty) {
              return fileId;
            }
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

        print('Warning: API response may be invalid');
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
    files, // List with fileType and fileId
    required Map<String, String> dynamicData, // IdNumber, phone, company
    String? hostEmployeeId,
    required Map<String, dynamic> visitSchedule,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/visitor/anonymous-visitor/self-visitor-register',
      );

      final payload = <String, dynamic>{
        'name': name,
        'email': email,
        'profilePictureFileId': profilePictureFileId,
        'purposeOfVisit': purposeOfVisit,
        'files': files,
        'dynamicData': dynamicData,
      };

      // Add hostEmployeeId if provided
      if (hostEmployeeId != null && hostEmployeeId.isNotEmpty) {
        payload['hostEmployeeId'] = hostEmployeeId;
      }

      // Add visitSchedule (always required)
      payload['visitSchedule'] = visitSchedule;

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

  /// Convert base64 string to temporary file
  static Future<File?> base64ToFile(
    String base64String, {
    String extension = '.jpg',
  }) async {
    try {
      final bytes = base64Decode(base64String);
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await tempFile.writeAsBytes(bytes);
      return tempFile;
    } catch (e) {
      print('Error converting base64 to file: $e');
      return null;
    }
  }

  /// Convert image file to base64 string (kept for backward compatibility if needed)
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
