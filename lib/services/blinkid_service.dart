import 'dart:io';
import 'dart:convert';
import 'package:blinkid_flutter/blinkid_flutter.dart';
import '../models/card_data.dart';

class BlinkIDService {
  // License keys for iOS and Android
  static const String _iosLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgFsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOak0yTWpNd05EazBOamtzSWtOeVpXRjBaV1JHYjNJaU9pSTBNREF3Tm1NeE1DMWxPVEUyTFRRMVlqVXRZbVJpWWkweE1EYzBNRFE0T1RJM1lUTWlmUT09cGnOArKctQ1tmQ16k2M3s9ZFP987aY3pWSYOvjHW3d1vp7JgxZy3tvOK+fmLIH6XSbsQ+r38eytvqOuka+/hekZiWlv0JIayvw/z+uJMn4gBWjswQKOMOiWiGVPpFA==';
  
  static const String _androidLicenseKey =
      'sRwCABRjb20uZXhhbXBsZS5jYXJkc2NhbgBsZXlKRGNtVmhkR1ZrVDI0aU9qRTNOak0yTWpNd05EazFOemtzSWtOeVpXRjBaV1JHYjNJaU9pSTBNREF3Tm1NeE1DMWxPVEUyTFRRMVlqVXRZbVJpWWkweE1EYzBNRFE0T1RJM1lUTWlmUT093qO2Xfcr1cAO4h+iOcn/rY+aLXY+DvcDnV7sqDCbsuPpM4o47jMLBdUhocmyyd+6iBLjlfDBgUvPwC9nWYI9PVB+6pEEfQptC4aYBBHow4B0hCJgIYyp9rXGAzjTjw==';

  bool _isSdkLoaded = false;

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

  /// Initialize and load the BlinkID SDK
  Future<void> _ensureSdkLoaded() async {
    if (_isSdkLoaded) return;

    try {
      // Initialize BlinkID plugin
      // Note: If you get analyzer errors here, check the actual exported class name
      // The class should be available at runtime - use IDE autocomplete to verify
      // ignore: undefined_identifier
      final blinkidPlugin = BlinkidFlutter();
      // ignore: undefined_identifier
      await blinkidPlugin.loadBlinkIdSdk(_sdkSettings);
      _isSdkLoaded = true;
    } catch (e) {
      // ignore: avoid_print
      print('Error loading BlinkID SDK: $e');
      rethrow;
    }
  }

  /// Scan card using camera
  /// Uses the default BlinkID UX scanning experience
  Future<CardData?> scanWithCamera() async {
    try {
      await _ensureSdkLoaded();

      // Configure session settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // Configure scanning settings
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.glareDetectionLevel = DetectionLevel.mid;

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
      final blinkidPlugin = BlinkidFlutter();
      // ignore: undefined_identifier
      final result = await blinkidPlugin.performScan(
        _sdkSettings,
        sessionSettings,
        uiSettings,
      );

      if (result != null) {
        return _extractCardData(result);
      }

      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error scanning with camera: $e');
      rethrow;
    }
  }

  /// Scan card from image file
  /// Uses DirectAPI scanning for static images
  Future<CardData?> scanFromImage(File imageFile) async {
    try {
      await _ensureSdkLoaded();

      // Configure session settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // Configure scanning settings
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.glareDetectionLevel = DetectionLevel.mid;

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
      final blinkidPlugin = BlinkidFlutter();
      // ignore: undefined_identifier
      final result = await blinkidPlugin.performDirectApiScan(
        _sdkSettings,
        sessionSettings,
        imageBase64,
      );

      if (result != null) {
        return _extractCardData(result);
      }

      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error scanning from image: $e');
      rethrow;
    }
  }

  /// Extract card data from BlinkID result
  CardData _extractCardData(BlinkIdScanningResult result) {
    try {
      // Access the result data - structure may vary
      // Try accessing single side results
      final firstSide = (result as dynamic).firstSideResult;
      final secondSide = (result as dynamic).secondSideResult;

      // Get data from first side (front) or second side (back)
      final firstData = firstSide?.data;
      final secondData = secondSide?.data;

      // Combine data from both sides, prioritizing first side
      return CardData(
        firstName: firstData?.firstName?.value ?? secondData?.firstName?.value,
        lastName: firstData?.lastName?.value ?? secondData?.lastName?.value,
        fullName: firstData?.fullName?.value ?? secondData?.fullName?.value,
        documentNumber: firstData?.documentNumber?.value ?? secondData?.documentNumber?.value,
        dateOfBirth: firstData?.dateOfBirth?.value?.toString() ?? secondData?.dateOfBirth?.value?.toString(),
        expiryDate: firstData?.dateOfExpiry?.value?.toString() ?? secondData?.dateOfExpiry?.value?.toString(),
        address: firstData?.address?.value ?? secondData?.address?.value,
        nationality: firstData?.nationality?.value ?? secondData?.nationality?.value,
        sex: firstData?.sex?.value ?? secondData?.sex?.value,
        documentType: firstData?.documentClass?.name ?? secondData?.documentClass?.name,
        rawText: firstData?.rawText ?? secondData?.rawText,
      );
    } catch (e) {
      // If the structure is different, try accessing data directly
      // ignore: avoid_print
      print('Error extracting card data, trying alternative structure: $e');
      
      // Try alternative: direct access to result properties
      try {
        final data = (result as dynamic).data ?? result;
        return CardData(
          firstName: data?.firstName?.value,
          lastName: data?.lastName?.value,
          fullName: data?.fullName?.value,
          documentNumber: data?.documentNumber?.value,
          dateOfBirth: data?.dateOfBirth?.value?.toString(),
          expiryDate: data?.dateOfExpiry?.value?.toString(),
          address: data?.address?.value,
          nationality: data?.nationality?.value,
          sex: data?.sex?.value,
          documentType: data?.documentClass?.name,
          rawText: data?.rawText,
        );
      } catch (e2) {
        // ignore: avoid_print
        print('Error with alternative extraction: $e2');
        return CardData();
      }
    }
  }

  /// Unload the SDK when done (optional, for cleanup)
  Future<void> unloadSdk({bool deleteCachedResources = false}) async {
    if (_isSdkLoaded) {
      try {
        // ignore: undefined_identifier
        final blinkidPlugin = BlinkidFlutter();
        // ignore: undefined_identifier
        await blinkidPlugin.unloadBlinkIdSdk(deleteCachedResources: deleteCachedResources);
        _isSdkLoaded = false;
      } catch (e) {
        // ignore: avoid_print
        print('Error unloading BlinkID SDK: $e');
      }
    }
  }
}
