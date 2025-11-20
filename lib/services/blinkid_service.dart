import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:blinkid_flutter/blinkid_flutter.dart';
import '../models/card_data.dart';

class BlinkIDService {
  // License keys for iOS and Android
  static const String _iosLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgFsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOak0yTWpNd05EazBOamtzSWtOeVpXRjBaV1JHYjNJaU9pSTBNREF3Tm1NeE1DMWxPVEUyTFRRMVlqVXRZbVJpWWkweE1EYzBNRFE0T1RJM1lUTWlmUT09cGnOArKctQ1tmQ16k2M3s9ZFP987aY3pWSYOvjHW3d1vp7JgxZy3tvOK+fmLIH6XSbsQ+r38eytvqOuka+/hekZiWlv0JIayvw/z+uJMn4gBWjswQKOMOiWiGVPpFA==';
  
  static const String _androidLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgBsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOak0yTWpNd05EazFOemtzSWtOeVpXRjBaV1JHYjNJaU9pSTBNREF3Tm1NeE1DMWxPVEUyTFRRMVlqVXRZbVJpWWkweE1EYzBNRFE0T1RJM1lUTWlmUT093qO2Xfcr1cAO4h+iOcn/rY+aLXY+DvcDnV7sqDCbsuPpM4o47jMLBdUhocmyyd+6iBLjlfDBgUvPwC9nWYI9PVB+6pEEfQptC4aYBBHow4B0hCJgIYyp9rXGAzjTjw==';

  bool _isSdkLoaded = false;
  // Reuse the same plugin instance
  // ignore: undefined_identifier
  BlinkidFlutter? _blinkidPlugin;

  // Get the appropriate license key for the current platform
  String get _licenseKey {
    if (Platform.isAndroid) {
      return _androidLicenseKey;
    } else if (Platform.isIOS) {
      return _iosLicenseKey;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Get SDK settings with the appropriate license key
  BlinkIdSdkSettings get _sdkSettings {
    final settings = BlinkIdSdkSettings(_licenseKey);
    settings.downloadResources = true;
    return settings;
  }

  /// Get or create BlinkID plugin instance
  // ignore: undefined_identifier
  BlinkidFlutter get _plugin {
    _blinkidPlugin ??= BlinkidFlutter();
    return _blinkidPlugin!;
  }

  /// Check if BlinkID is available (native library loaded)
  bool get isAvailable => _isSdkLoaded;

  /// Initialize and load the BlinkID SDK
  Future<void> _ensureSdkLoaded() async {
    if (_isSdkLoaded) return;

    try {
      // Load SDK with proper error handling
      // ignore: undefined_identifier
      await _plugin.loadBlinkIdSdk(_sdkSettings);
      _isSdkLoaded = true;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Platform error loading BlinkID SDK: ${e.code} - ${e.message}');
      _isSdkLoaded = false;
      
      // Check for native library errors (common on emulators)
      if (e.message?.contains('libBlinkID.so') == true || 
          e.message?.contains('UnsatisfiedLinkError') == true ||
          e.message?.contains('library') == true) {
        // ignore: avoid_print
        print('BlinkID native library not available. This may happen on emulators or unsupported architectures.');
        // Don't throw - allow fallback to ML Kit
        return;
      }
      
      // Check for common error codes
      if (e.code == 'LICENSE_ERROR' || e.message?.contains('license') == true) {
        // ignore: avoid_print
        print('BlinkID license error');
        // Don't throw - allow fallback
        return;
      } else if (e.code == 'NETWORK_ERROR' || e.message?.contains('network') == true) {
        // ignore: avoid_print
        print('BlinkID network error');
        // Don't throw - allow fallback
        return;
      } else {
        // ignore: avoid_print
        print('BlinkID SDK load failed: ${e.message ?? e.code}');
        // Don't throw - allow fallback
        return;
      }
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error loading BlinkID SDK: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      _isSdkLoaded = false;
      // Don't rethrow - allow fallback to ML Kit
      // This prevents app crashes when BlinkID is not available
    }
  }

  /// Scan card using camera
  /// Uses the default BlinkID UX scanning experience
  Future<CardData?> scanWithCamera() async {
    try {
      // Try to load SDK, but handle errors gracefully
      await _ensureSdkLoaded();
      
      // Check if SDK is actually loaded
      if (!_isSdkLoaded) {
        // ignore: avoid_print
        print('BlinkID SDK not available - native library may not be supported on this device/emulator');
        return null; // Return null to allow fallback
      }

      // Configure session settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // Configure scanning settings
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
      scanningSettings.glareDetectionLevel = DetectionLevel.mid;
      scanningSettings.blurDetectionLevel = DetectionLevel.mid;

      // Configure image settings
      final imageSettings = CroppedImageSettings();
      imageSettings.returnDocumentImage = true;
      imageSettings.returnFaceImage = true;
      imageSettings.returnSignatureImage = false;
      scanningSettings.croppedImageSettings = imageSettings;

      // Assign scanning settings to session settings
      sessionSettings.scanningSettings = scanningSettings;

      // Configure UI settings (optional)
      final uiSettings = BlinkIdScanningUxSettings();
      uiSettings.showHelpButton = true;
      uiSettings.showOnboardingDialog = false;
      uiSettings.allowHapticFeedback = true;
      uiSettings.preferredCamera = PreferredCamera.back;

      // Perform scan with camera using default UX
      // ignore: undefined_identifier
      final result = await _plugin.performScan(
        _sdkSettings,
        sessionSettings,
        uiSettings,
      );

      if (result != null) {
        return _extractCardData(result);
      }

      return null;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Platform error during camera scan: ${e.code} - ${e.message}');
      throw Exception('Camera scan failed: ${e.message ?? e.code}');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error scanning with camera: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      throw Exception('Failed to scan card: ${e.toString()}');
    }
  }

  /// Scan card from image file
  /// Uses DirectAPI scanning for static images
  Future<CardData?> scanFromImage(File imageFile) async {
    try {
      // Try to load SDK, but don't fail if it doesn't work
      await _ensureSdkLoaded();
      
      // Check if SDK is actually loaded
      if (!_isSdkLoaded) {
        // ignore: avoid_print
        print('BlinkID SDK not available, will use ML Kit fallback');
        return null; // Return null to trigger fallback
      }

      // Configure session settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // Configure scanning settings
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
      scanningSettings.glareDetectionLevel = DetectionLevel.mid;
      scanningSettings.blurDetectionLevel = DetectionLevel.mid;

      // Configure image settings
      final imageSettings = CroppedImageSettings();
      imageSettings.returnDocumentImage = true;
      imageSettings.returnFaceImage = true;
      imageSettings.returnSignatureImage = false;
      scanningSettings.croppedImageSettings = imageSettings;

      // Assign scanning settings to session settings
      sessionSettings.scanningSettings = scanningSettings;

      // Read image file and convert to Base64
      final imageBytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      // Perform DirectAPI scan from image
      // ignore: undefined_identifier
      final result = await _plugin.performDirectApiScan(
        _sdkSettings,
        sessionSettings,
        imageBase64,
      );

      if (result != null) {
        return _extractCardData(result);
      }

      return null;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('Platform error scanning from image: ${e.code} - ${e.message}');
      // Return null instead of throwing to allow fallback
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error scanning from image with BlinkID: $e');
      // Return null instead of throwing to allow fallback
      return null;
    }
  }

  /// Extract card data from BlinkID result
  /// Based on BlinkID Flutter implementation guide
  CardData _extractCardData(BlinkIdScanningResult result) {
    try {
      // Extract personal information with multi-alphabet support
      // Priority: value > latin > arabic > cyrillic > greek
      String? firstName = result.firstName?.value ?? 
                          result.firstName?.latin ?? 
                          result.firstName?.arabic ?? 
                          result.firstName?.cyrillic ?? 
                          result.firstName?.greek;
      
      String? lastName = result.lastName?.value ?? 
                         result.lastName?.latin ?? 
                         result.lastName?.arabic ?? 
                         result.lastName?.cyrillic ?? 
                         result.lastName?.greek;
      
      String? fullName = result.fullName?.value ?? 
                         result.fullName?.latin ?? 
                         result.fullName?.arabic ?? 
                         result.fullName?.cyrillic ?? 
                         result.fullName?.greek;
      
      // Extract document information
      String? documentNumber = result.documentNumber?.value ?? 
                               result.documentNumber?.latin ?? 
                               result.documentNumber?.arabic ?? 
                               result.documentNumber?.cyrillic ?? 
                               result.documentNumber?.greek;
      
      String? address = result.address?.value ?? 
                        result.address?.latin ?? 
                        result.address?.arabic ?? 
                        result.address?.cyrillic ?? 
                        result.address?.greek;
      
      // Extract dates - format as YYYY-MM-DD
      String? dateOfBirth;
      if (result.dateOfBirth?.date != null) {
        final dob = result.dateOfBirth!.date!;
        dateOfBirth = "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      }
      
      String? expiryDate;
      if (result.dateOfExpiry?.date != null) {
        final expiry = result.dateOfExpiry!.date!;
        expiryDate = "${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}";
      }
      
      // Extract nationality
      String? nationality;
      if (result.nationality != null) {
        nationality = result.nationality!.value ?? 
                      result.nationality!.latin ?? 
                      result.nationality!.arabic ?? 
                      result.nationality!.cyrillic ?? 
                      result.nationality!.greek;
      }
      
      // Extract sex/gender
      String? sex = result.sex?.value;
      
      // Extract document type from documentClassInfo
      String? documentType = result.documentClassInfo?.documentType?.name;
      
      // Try to get raw text from MRZ if available
      String? rawText;
      if (result.subResults != null) {
        for (var subResult in result.subResults!) {
          if (subResult.mrz != null && subResult.mrz!.rawMRZString != null) {
            rawText = subResult.mrz!.rawMRZString;
            break;
          }
        }
      }
      
      return CardData(
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        documentNumber: documentNumber,
        dateOfBirth: dateOfBirth,
        expiryDate: expiryDate,
        address: address,
        nationality: nationality,
        sex: sex,
        documentType: documentType,
        rawText: rawText,
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error extracting card data: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return CardData();
    }
  }

  /// Unload the SDK when done (optional, for cleanup)
  Future<void> unloadSdk({bool deleteCachedResources = false}) async {
    if (_isSdkLoaded) {
      try {
        // ignore: undefined_identifier
        await _plugin.unloadBlinkIdSdk(deleteCachedResources: deleteCachedResources);
        _isSdkLoaded = false;
      } catch (e) {
        // ignore: avoid_print
        print('Error unloading BlinkID SDK: $e');
      }
    }
  }
}
