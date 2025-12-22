import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:blinkid_flutter/blinkid_flutter.dart';
import '../models/card_data.dart';

class BlinkIDService {
  // License keys for iOS and Android
  static const String _iosLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgFsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOall6T0RRd056QXdOVEFzSWtOeVpXRjBaV1JHYjNJaU9pSmlaREV6TkRCak9DMWxPR0V5TFRSaVlUTXRPR1l5WVMwd1l6azJObUpqWlRobU56VWlmUT09ajfX4bhTRgEmLAtWJ3DnCGNrNuamgpOqTbRDnL5L1qpwb+5/dspum4gVdnH0qgDFyZ52HAldTeQI8fFC81xmenXX3Q7KI87hIcq4a6obremoay/Y16uieI2v2LMyMg==';

  static const String _androidLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgBsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOall6T0RRd056QXhPRGNzSWtOeVpXRjBaV1JHYjNJaU9pSmlaREV6TkRCak9DMWxPR0V5TFRSaVlUTXRPR1l5WVMwd1l6azJObUpqWlRobU56VWlmUT098/pIMua/CfA3WAfLaVVZqGLiMYIkP7/dVQQ2ipxSk04Yiy+c9X4cYH9ioPWh+F3X2UYdQQ20SAHJZ75A0fJdQioSessvQtuk6IyWSh0+7Zh+KUX62kLwgGV2eg+blA==';

  bool _isSdkLoaded = false;
  // Reuse the same plugin instance
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
        print(
          'BlinkID native library not available. This may happen on emulators or unsupported architectures.',
        );
        // Don't throw - allow fallback to ML Kit
        return;
      }

      // Check for common error codes
      if (e.code == 'LICENSE_ERROR' || e.message?.contains('license') == true) {
        // ignore: avoid_print
        print('BlinkID license error');
        // Don't throw - allow fallback
        return;
      } else if (e.code == 'NETWORK_ERROR' ||
          e.message?.contains('network') == true) {
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
        print(
          'BlinkID SDK not available - native library may not be supported on this device/emulator',
        );
        return null; // Return null to allow fallback
      }

      //more
      final sdkSettings = BlinkIdSdkSettings(_licenseKey);
      sdkSettings.downloadResources = true;

      // Configure session settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.single;

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

      //more
      final classFilter = ClassFilter.withIncludedDocumentClasses([
        DocumentFilter(Country.saudiArabia),
        DocumentFilter(Country.bangladesh),
        DocumentFilter(Country.pakistan),
        DocumentFilter(Country.india),
        DocumentFilter(Country.usa, Region.california, DocumentType.passport),
        DocumentFilter(Country.uK),
      ]);

      // Perform scan with camera using default UX
      // ignore: undefined_identifier
      final result = await _plugin.performScan(
        _sdkSettings,
        sessionSettings,
        uiSettings,
        classFilter,
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
      // Extract personal information
      // Native (preferred)
      String? firstName = _getBestString(result.firstName);
      String? lastName = _getBestString(result.lastName);
      String? fullName = _getBestString(result.fullName);

      // English/Latin variants
      String? firstNameEnglish = _getLatinString(result.firstName);
      String? lastNameEnglish = _getLatinString(result.lastName);
      String? fullNameEnglish = _getLatinString(result.fullName);

      // If native is same as English, don't duplicate English variant
      if (firstName == firstNameEnglish) firstNameEnglish = null;
      if (lastName == lastNameEnglish) lastNameEnglish = null;
      if (fullName == fullNameEnglish) fullNameEnglish = null;

      // Extract document information
      String? documentNumber = _getBestString(result.documentNumber);
      String? documentNumberEnglish = _getLatinString(result.documentNumber);
      if (documentNumber == documentNumberEnglish) documentNumberEnglish = null;

      String? address = _getBestString(result.address);

      // Extract dates - format as YYYY-MM-DD
      String? dateOfBirth;
      if (result.dateOfBirth?.date != null) {
        final dob = result.dateOfBirth!.date!;
        dateOfBirth =
            "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      }

      String? expiryDate;
      if (result.dateOfExpiry?.date != null) {
        final expiry = result.dateOfExpiry!.date!;
        expiryDate =
            "${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}";
      }

      // Extract nationality
      String? nationality;
      if (result.nationality != null) {
        nationality = _getBestString(result.nationality);
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

      // Extract document image
      // Using dynamic to avoid analyzer errors if properties vary by version
      // ignore: avoid_dynamic_calls
      String? documentImageBase64;
      try {
        // ignore: avoid_dynamic_calls
        documentImageBase64 = (result as dynamic).fullDocumentFrontImage;
      } catch (_) {}

      if (documentImageBase64 == null) {
        try {
          // ignore: avoid_dynamic_calls
          documentImageBase64 = (result as dynamic).fullDocumentImage;
        } catch (_) {}
      }

      if (documentImageBase64 == null) {
        try {
          // ignore: avoid_dynamic_calls
          documentImageBase64 = (result as dynamic).firstDocumentImage;
        } catch (_) {}
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
        firstNameEnglish: firstNameEnglish,
        lastNameEnglish: lastNameEnglish,
        fullNameEnglish: fullNameEnglish,
        documentNumberEnglish: documentNumberEnglish,
        documentImageBase64: documentImageBase64,
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error extracting card data: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return CardData();
    }
  }

  /// Helper to extract latin/english string
  String? _getLatinString(StringResult? result) {
    if (result == null) return null;
    return result.latin;
  }

  /// Helper to extract string with preference for native script
  /// Returns native script if available, otherwise latin/value
  String? _getBestString(StringResult? result) {
    if (result == null) return null;

    // Collect available scripts
    final arabic = result.arabic;
    final cyrillic = result.cyrillic;
    final greek = result.greek;
    final latin = result.latin;
    final value = result.value;

    // Check for Native scripts
    if (arabic != null && arabic.isNotEmpty) return arabic;
    if (cyrillic != null && cyrillic.isNotEmpty) return cyrillic;
    if (greek != null && greek.isNotEmpty) return greek;

    // For other scripts (like Bangla)
    // If value is present and different from latin, assume value is native.
    if (value != null && value.isNotEmpty) {
      if (latin != null && latin.isNotEmpty && value != latin) {
        return value;
      }
    }

    // Fallback
    return value ?? latin;
  }

  /// Unload the SDK when done (optional, for cleanup)
  Future<void> unloadSdk({bool deleteCachedResources = false}) async {
    if (_isSdkLoaded) {
      try {
        // ignore: undefined_identifier
        await _plugin.unloadBlinkIdSdk(
          deleteCachedResources: deleteCachedResources,
        );
        _isSdkLoaded = false;
      } catch (e) {
        // ignore: avoid_print
        print('Error unloading BlinkID SDK: $e');
      }
    }
  }
}
