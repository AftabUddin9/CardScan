# BlinkID Flutter Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Core Concepts](#core-concepts)
4. [Implementation Methods](#implementation-methods)
5. [Parsing Results](#parsing-results)
6. [Code Examples](#code-examples)
7. [Best Practices](#best-practices)

---

## Overview

BlinkID Flutter is a powerful SDK for scanning and extracting text from identity documents (IDs, passports, driver licenses, etc.). It can extract data from:
- **MRZ (Machine Readable Zone)** - The bottom section of passports and IDs
- **VIZ (Visual Inspection Zone)** - The visible text on documents
- **Barcodes** - PDF417, QR codes, and other barcode formats

### Key Features
- Real-time camera scanning with default UX
- Direct API scanning from static images
- Multi-side document support
- Automatic document detection
- Support for 100+ countries and document types

---

## Setup and Configuration

### 1. Add Dependencies

In your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # BlinkID Flutter package (use path if local, or version if from pub.dev)
  blinkid_flutter:
    path: ../BlinkID  # For local package
    # OR
    # blinkid_flutter: ^7.6.0  # If published to pub.dev
  
  # Image picker for selecting images from gallery (for DirectAPI)
  image_picker: ^1.0.7
```

### 2. Get License Key

1. Visit [Microblink Developer Hub](https://developer.microblink.com/)
2. Create an account and generate a license key
3. License keys are platform-specific (Android and iOS have different keys)

### 3. Platform Configuration

#### Android
- Minimum SDK: 21+
- Add camera permissions in `AndroidManifest.xml`

#### iOS
- Minimum iOS: 12.0+
- Add camera usage description in `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan documents</string>
```

---

## Core Concepts

### Main Components

1. **BlinkidFlutter** - Main plugin class
2. **BlinkIdSdkSettings** - SDK initialization settings (license key, resource download)
3. **BlinkIdSessionSettings** - Session configuration (scanning mode, quality settings)
4. **BlinkIdScanningSettings** - Detailed scanning parameters
5. **BlinkIdScanningUxSettings** - UI/UX customization
6. **BlinkIdScanningResult** - Contains all extracted data

### Scanning Modes

- **`ScanningMode.automatic`** - Automatically detects if document needs one or two sides
- **`ScanningMode.single`** - Scan only one side of the document

### Recognition Modes

The SDK can extract data from:
- **MRZ ID** - Machine readable zone on IDs
- **MRZ Passport** - Machine readable zone on passports
- **MRZ Visa** - Machine readable zone on visas
- **Photo ID** - Documents with face photos
- **Barcode ID** - Documents with barcodes
- **Full Recognition** - Complete document recognition

---

## Implementation Methods

### Method 1: Camera Scanning (Default UX)

This method launches the built-in camera interface with BlinkID's default UX.

**When to use:**
- Real-time document scanning
- Best user experience with guided scanning
- Automatic document detection

**Implementation:**

```dart
import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'dart:io';

class DocumentScanner {
  final blinkIdPlugin = BlinkidFlutter();
  String sdkLicenseKey = "";

  // Initialize license key based on platform
  void initLicense() {
    if (Platform.isAndroid) {
      sdkLicenseKey = "YOUR_ANDROID_LICENSE_KEY";
    } else if (Platform.isIOS) {
      sdkLicenseKey = "YOUR_IOS_LICENSE_KEY";
    }
  }

  Future<BlinkIdScanningResult?> scanWithCamera() async {
    try {
      // 1. Configure SDK Settings
      final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
      sdkSettings.downloadResources = true; // Download models on first use

      // 2. Configure Session Settings
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // 3. Configure Scanning Settings
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
      scanningSettings.glareDetectionLevel = DetectionLevel.mid;
      scanningSettings.blurDetectionLevel = DetectionLevel.mid;

      // 4. Configure Image Settings (optional - to get cropped images)
      final imageSettings = CroppedImageSettings();
      imageSettings.returnDocumentImage = true;
      imageSettings.returnFaceImage = true;
      imageSettings.returnSignatureImage = true;
      scanningSettings.croppedImageSettings = imageSettings;

      // 5. Configure UX Settings (optional)
      final uiSettings = BlinkIdScanningUxSettings();
      uiSettings.showHelpButton = true;
      uiSettings.showOnboardingDialog = false;
      uiSettings.allowHapticFeedback = true;
      uiSettings.preferredCamera = PreferredCamera.back;

      // 6. Optional: Filter documents by country/type
      final classFilter = ClassFilter.withIncludedDocumentClasses([
        DocumentFilter(Country.usa),
        DocumentFilter(Country.canada),
      ]);

      // 7. Perform scan
      final result = await blinkIdPlugin.performScan(
        sdkSettings,
        sessionSettings,
        uiSettings,
        // classFilter, // Optional
      );

      return result;
    } catch (error) {
      print("Scanning error: $error");
      return null;
    }
  }
}
```

### Method 2: Direct API Scanning (Static Images)

This method processes static images without opening the camera.

**When to use:**
- Processing images from gallery
- Batch processing multiple documents
- Custom camera implementation
- Server-side processing

**Implementation for Single Side:**

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

Future<BlinkIdScanningResult?> scanSingleImage() async {
  try {
    // 1. Pick image from gallery
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    // 2. Convert to Base64
    String imageBase64 = base64Encode(await image.readAsBytes());

    // 3. Configure SDK Settings
    final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
    sdkSettings.downloadResources = true;

    // 4. Configure Session Settings
    final sessionSettings = BlinkIdSessionSettings();
    sessionSettings.scanningMode = ScanningMode.single; // Single side

    // 5. Configure Scanning Settings
    final scanningSettings = BlinkIdScanningSettings();
    scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
    scanningSettings.glareDetectionLevel = DetectionLevel.mid;
    
    // If image is already cropped (document only, no background)
    // scanningSettings.scanCroppedDocumentImage = true;

    sessionSettings.scanningSettings = scanningSettings;

    // 6. Perform Direct API scan
    final result = await blinkIdPlugin.performDirectApiScan(
      sdkSettings,
      sessionSettings,
      imageBase64, // First image (front or back)
    );

    return result;
  } catch (error) {
    print("Scanning error: $error");
    return null;
  }
}
```

**Implementation for Multi-Side (Front + Back):**

```dart
Future<BlinkIdScanningResult?> scanMultiSideImage() async {
  try {
    // 1. Pick multiple images
    final images = await ImagePicker().pickMultiImage();
    if (images.length < 2) return null;

    // 2. Convert to Base64
    String frontImageBase64 = base64Encode(await images[0].readAsBytes());
    String backImageBase64 = base64Encode(await images[1].readAsBytes());

    // 3. Configure SDK Settings
    final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
    sdkSettings.downloadResources = true;

    // 4. Configure Session Settings
    final sessionSettings = BlinkIdSessionSettings();
    sessionSettings.scanningMode = ScanningMode.automatic; // Auto-detect sides

    // 5. Configure Scanning Settings
    final scanningSettings = BlinkIdScanningSettings();
    scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
    sessionSettings.scanningSettings = scanningSettings;

    // 6. Perform Direct API scan with both images
    final result = await blinkIdPlugin.performDirectApiScan(
      sdkSettings,
      sessionSettings,
      frontImageBase64, // First side (front)
      backImageBase64,  // Second side (back)
    );

    return result;
  } catch (error) {
    print("Scanning error: $error");
    return null;
  }
}
```

### Method 3: Preloading SDK

To reduce initial scan time, you can preload the SDK:

```dart
Future<void> preloadSDK() async {
  final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
  sdkSettings.downloadResources = true;
  
  await blinkIdPlugin.loadBlinkIdSdk(sdkSettings);
  // SDK is now loaded and ready for faster scanning
}
```

---

## Parsing Results

The `BlinkIdScanningResult` object contains all extracted data. Here's how to parse it:

### Basic Information Extraction

```dart
void parseBasicInfo(BlinkIdScanningResult? result) {
  if (result == null) return;

  // Personal Information
  String? firstName = result.firstName?.value ?? result.firstName?.latin;
  String? lastName = result.lastName?.value ?? result.lastName?.latin;
  String? fullName = result.fullName?.value ?? result.fullName?.latin;
  String? dateOfBirth = result.dateOfBirth?.date != null
      ? "${result.dateOfBirth!.date!.year}-${result.dateOfBirth!.date!.month}-${result.dateOfBirth!.date!.day}"
      : null;
  
  // Document Information
  String? documentNumber = result.documentNumber?.value ?? result.documentNumber?.latin;
  String? personalIdNumber = result.personalIdNumber?.value ?? result.personalIdNumber?.latin;
  String? issuingAuthority = result.issuingAuthority?.value ?? result.issuingAuthority?.latin;
  
  // Address
  String? address = result.address?.value ?? result.address?.latin;
  
  // Dates
  String? dateOfIssue = result.dateOfIssue?.date != null
      ? "${result.dateOfIssue!.date!.year}-${result.dateOfIssue!.date!.month}-${result.dateOfIssue!.date!.day}"
      : null;
  String? dateOfExpiry = result.dateOfExpiry?.date != null
      ? "${result.dateOfExpiry!.date!.year}-${result.dateOfExpiry!.date!.month}-${result.dateOfExpiry!.date!.day}"
      : null;
  
  // Document Class Info
  String? country = result.documentClassInfo?.countryName;
  String? documentType = result.documentClassInfo?.documentType?.name;
  
  // Recognition Mode
  String? recognitionMode = result.recognitionMode?.name;
}
```

### Multi-Alphabet Support

BlinkID extracts text in multiple alphabets. Always check multiple sources:

```dart
String? getName(BlinkIdScanningResult? result) {
  if (result?.fullName == null) return null;
  
  // Priority: value > latin > arabic > cyrillic > greek
  return result!.fullName!.value ?? 
         result.fullName!.latin ?? 
         result.fullName!.arabic ?? 
         result.fullName!.cyrillic ?? 
         result.fullName!.greek;
}
```

### MRZ Results (Machine Readable Zone)

```dart
void parseMRZResults(BlinkIdScanningResult? result) {
  if (result?.subResults == null) return;
  
  for (var subResult in result!.subResults!) {
    if (subResult.mrz != null) {
      final mrz = subResult.mrz!;
      
      print("Document Code: ${mrz.documentCode}");
      print("Document Number: ${mrz.documentNumber}");
      print("Issuer: ${mrz.issuer}");
      print("Nationality: ${mrz.nationality}");
      print("Date of Birth: ${mrz.dateOfBirth?.date}");
      print("Date of Expiry: ${mrz.dateOfExpiry?.date}");
      print("Gender: ${mrz.gender}");
      print("Primary ID: ${mrz.primaryID}");
      print("Secondary ID: ${mrz.secondaryID}");
      print("MRZ Verified: ${mrz.verified}"); // Check digit validation
      print("Raw MRZ: ${mrz.rawMRZString}");
    }
  }
}
```

### Barcode Results

```dart
void parseBarcodeResults(BlinkIdScanningResult? result) {
  if (result?.subResults == null) return;
  
  for (var subResult in result!.subResults!) {
    if (subResult.barcode != null) {
      final barcode = subResult.barcode!;
      
      print("Barcode Type: ${barcode.barcodeData?.barcodeType}");
      print("Barcode Data: ${barcode.barcodeData?.stringData}");
      print("First Name: ${barcode.firstName}");
      print("Last Name: ${barcode.lastName}");
      print("Address: ${barcode.address}");
      print("Date of Birth: ${barcode.dateOfBirth?.date}");
      
      // Driver License specific
      if (barcode.driverLicenseDetailedInfo != null) {
        print("Vehicle Class: ${barcode.driverLicenseDetailedInfo!.vehicleClass}");
        print("Restrictions: ${barcode.driverLicenseDetailedInfo!.restrictions}");
        print("Endorsements: ${barcode.driverLicenseDetailedInfo!.endorsements}");
      }
    }
  }
}
```

### VIZ Results (Visual Inspection Zone)

```dart
void parseVIZResults(BlinkIdScanningResult? result) {
  if (result?.subResults == null) return;
  
  for (var subResult in result!.subResults!) {
    if (subResult.viz != null) {
      final viz = subResult.viz!;
      
      print("First Name: ${viz.firstName?.latin}");
      print("Last Name: ${viz.lastName?.latin}");
      print("Full Name: ${viz.fullName?.latin}");
      print("Address: ${viz.address?.latin}");
      print("Place of Birth: ${viz.placeOfBirth?.latin}");
      print("Nationality: ${viz.nationality?.latin}");
      print("Date of Birth: ${viz.dateOfBirth?.date}");
      print("Document Number: ${viz.documentNumber?.latin}");
    }
  }
}
```

### Extracted Images

```dart
void extractImages(BlinkIdScanningResult? result) {
  if (result == null) return;
  
  // Document images (Base64 encoded)
  String? firstDocumentImage = result.firstDocumentImage;
  String? secondDocumentImage = result.secondDocumentImage;
  
  // Face image
  String? faceImageBase64 = result.faceImage?.image;
  
  // Signature image
  String? signatureImageBase64 = result.signatureImage?.image;
  
  // Input images (original captured images)
  String? firstInputImage = result.firstInputImage;
  String? secondInputImage = result.secondInputImage;
  
  // Convert Base64 to Image widget
  if (firstDocumentImage != null) {
    Uint8List imageBytes = base64Decode(firstDocumentImage);
    Image image = Image.memory(imageBytes);
  }
}
```

### Data Match Results

Check if data from front and back sides match:

```dart
void checkDataMatch(BlinkIdScanningResult? result) {
  if (result?.dataMatchResult == null) return;
  
  final dataMatch = result!.dataMatchResult!;
  
  print("Overall Match State: ${dataMatch.overallState?.name}");
  // States: notPerformed, failed, success
  
  if (dataMatch.states != null) {
    for (var field in dataMatch.states!) {
      print("${field.field?.name}: ${field.state?.name}");
      // Fields: dateOfBirth, dateOfExpiry, documentNumber, etc.
    }
  }
}
```

---

## Code Examples

### Complete Example: Camera Scanning with Result Display

```dart
import 'package:flutter/material.dart';
import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'dart:io';
import 'dart:convert';

class DocumentScanScreen extends StatefulWidget {
  @override
  _DocumentScanScreenState createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  final blinkIdPlugin = BlinkidFlutter();
  String sdkLicenseKey = "";
  BlinkIdScanningResult? scanResult;
  String resultText = "";

  @override
  void initState() {
    super.initState();
    _initLicense();
  }

  void _initLicense() {
    if (Platform.isAndroid) {
      sdkLicenseKey = "YOUR_ANDROID_LICENSE_KEY";
    } else if (Platform.isIOS) {
      sdkLicenseKey = "YOUR_IOS_LICENSE_KEY";
    }
  }

  Future<void> _scanDocument() async {
    try {
      // Configure SDK
      final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
      sdkSettings.downloadResources = true;

      // Configure Session
      final sessionSettings = BlinkIdSessionSettings();
      sessionSettings.scanningMode = ScanningMode.automatic;

      // Configure Scanning
      final scanningSettings = BlinkIdScanningSettings();
      scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
      
      final imageSettings = CroppedImageSettings();
      imageSettings.returnDocumentImage = true;
      imageSettings.returnFaceImage = true;
      scanningSettings.croppedImageSettings = imageSettings;
      
      sessionSettings.scanningSettings = scanningSettings;

      // Configure UX
      final uiSettings = BlinkIdScanningUxSettings();
      uiSettings.showHelpButton = true;
      uiSettings.preferredCamera = PreferredCamera.back;

      // Perform scan
      final result = await blinkIdPlugin.performScan(
        sdkSettings,
        sessionSettings,
        uiSettings,
      );

      setState(() {
        scanResult = result;
        resultText = _formatResult(result);
      });
    } catch (error) {
      setState(() {
        resultText = "Error: $error";
      });
    }
  }

  String _formatResult(BlinkIdScanningResult? result) {
    if (result == null) return "No result";
    
    StringBuffer buffer = StringBuffer();
    
    buffer.writeln("=== Document Information ===");
    buffer.writeln("Recognition Mode: ${result.recognitionMode?.name}");
    buffer.writeln("Country: ${result.documentClassInfo?.countryName}");
    buffer.writeln("Document Type: ${result.documentClassInfo?.documentType?.name}");
    
    buffer.writeln("\n=== Personal Information ===");
    buffer.writeln("Full Name: ${result.fullName?.latin ?? result.fullName?.value}");
    buffer.writeln("First Name: ${result.firstName?.latin ?? result.firstName?.value}");
    buffer.writeln("Last Name: ${result.lastName?.latin ?? result.lastName?.value}");
    
    if (result.dateOfBirth?.date != null) {
      final dob = result.dateOfBirth!.date!;
      buffer.writeln("Date of Birth: ${dob.year}-${dob.month}-${dob.day}");
    }
    
    buffer.writeln("\n=== Document Details ===");
    buffer.writeln("Document Number: ${result.documentNumber?.latin ?? result.documentNumber?.value}");
    buffer.writeln("Personal ID: ${result.personalIdNumber?.latin ?? result.personalIdNumber?.value}");
    buffer.writeln("Issuing Authority: ${result.issuingAuthority?.latin ?? result.issuingAuthority?.value}");
    
    if (result.dateOfExpiry?.date != null) {
      final expiry = result.dateOfExpiry!.date!;
      buffer.writeln("Date of Expiry: ${expiry.year}-${expiry.month}-${expiry.day}");
    }
    
    buffer.writeln("\n=== Address ===");
    buffer.writeln("Address: ${result.address?.latin ?? result.address?.value}");
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Document Scanner")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _scanDocument,
              child: Text("Scan Document"),
            ),
            SizedBox(height: 20),
            if (scanResult?.firstDocumentImage != null)
              Image.memory(
                base64Decode(scanResult!.firstDocumentImage!),
                height: 200,
              ),
            SizedBox(height: 20),
            Text(resultText),
          ],
        ),
      ),
    );
  }
}
```

### Example: Direct API with Image Picker

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

Future<Map<String, dynamic>?> scanFromGallery() async {
  try {
    // Pick image
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    // Convert to Base64
    String imageBase64 = base64Encode(await image.readAsBytes());

    // Configure and scan
    final sdkSettings = BlinkIdSdkSettings(sdkLicenseKey);
    sdkSettings.downloadResources = true;

    final sessionSettings = BlinkIdSessionSettings();
    sessionSettings.scanningMode = ScanningMode.single;

    final scanningSettings = BlinkIdScanningSettings();
    sessionSettings.scanningSettings = scanningSettings;

    final result = await blinkIdPlugin.performDirectApiScan(
      sdkSettings,
      sessionSettings,
      imageBase64,
    );

    // Extract data
    if (result == null) return null;

    return {
      'fullName': result.fullName?.latin ?? result.fullName?.value,
      'documentNumber': result.documentNumber?.latin ?? result.documentNumber?.value,
      'dateOfBirth': result.dateOfBirth?.date != null
          ? "${result.dateOfBirth!.date!.year}-${result.dateOfBirth!.date!.month}-${result.dateOfBirth!.date!.day}"
          : null,
      'dateOfExpiry': result.dateOfExpiry?.date != null
          ? "${result.dateOfExpiry!.date!.year}-${result.dateOfExpiry!.date!.month}-${result.dateOfExpiry!.date!.day}"
          : null,
      'address': result.address?.latin ?? result.address?.value,
      'country': result.documentClassInfo?.countryName,
    };
  } catch (error) {
    print("Error: $error");
    return null;
  }
}
```

---

## Best Practices

### 1. License Key Management
- Store license keys securely (use environment variables or secure storage)
- Never commit license keys to version control
- Use different keys for development and production

### 2. Error Handling
```dart
try {
  final result = await blinkIdPlugin.performScan(...);
  if (result == null) {
    // Handle null result (user cancelled)
  }
} on PlatformException catch (e) {
  // Handle platform-specific errors
  print("Platform error: ${e.message}");
} catch (e) {
  // Handle other errors
  print("Error: $e");
}
```

### 3. Resource Management
- Set `downloadResources = true` for first-time setup
- Preload SDK if scanning multiple documents
- Unload SDK when done (optional, SDK auto-unloads after scan)

### 4. Image Quality Settings
```dart
final scanningSettings = BlinkIdScanningSettings();

// Adjust detection levels based on your needs
scanningSettings.blurDetectionLevel = DetectionLevel.mid; // low, mid, high, off
scanningSettings.glareDetectionLevel = DetectionLevel.mid;
scanningSettings.tiltDetectionLevel = DetectionLevel.mid;

// Skip low-quality images
scanningSettings.skipImagesWithBlur = true;
scanningSettings.skipImagesWithGlare = true;
scanningSettings.skipImagesWithInadequateLightingConditions = true;
```

### 5. Document Filtering
```dart
// Only accept specific countries
final classFilter = ClassFilter.withIncludedDocumentClasses([
  DocumentFilter(Country.usa),
  DocumentFilter(Country.canada),
]);

// Or exclude specific documents
final excludeFilter = ClassFilter.withExcludedDocumentClasses([
  DocumentFilter(Country.usa, Region.california, DocumentType.dl),
]);
```

### 6. Anonymization
```dart
// For privacy compliance
scanningSettings.anonymizationMode = AnonymizationMode.fullResult;
// Options: none, imageOnly, resultFieldsOnly, fullResult
```

### 7. Performance Optimization
- Preload SDK before user starts scanning
- Use `scanCroppedDocumentImage = true` if you're already cropping images
- Disable image return if not needed (saves memory)

### 8. Result Validation
```dart
bool isValidResult(BlinkIdScanningResult? result) {
  if (result == null) return false;
  
  // Check if essential fields are present
  bool hasName = result.fullName != null || 
                 (result.firstName != null && result.lastName != null);
  bool hasDocumentNumber = result.documentNumber != null;
  bool hasDateOfBirth = result.dateOfBirth != null;
  
  // For MRZ, check verification
  if (result.subResults != null) {
    for (var subResult in result.subResults!) {
      if (subResult.mrz?.verified == true) {
        return true; // MRZ verified is highly reliable
      }
    }
  }
  
  return hasName && hasDocumentNumber && hasDateOfBirth;
}
```

---

## Common Use Cases

### 1. ID Verification
```dart
Future<bool> verifyID(BlinkIdScanningResult result) {
  // Check if document is valid
  if (result.documentClassInfo?.documentType != DocumentType.id) {
    return false;
  }
  
  // Check expiry
  if (result.dateOfExpiry?.date != null) {
    final expiry = result.dateOfExpiry!.date!;
    final now = DateTime.now();
    if (DateTime(expiry.year, expiry.month, expiry.day).isBefore(now)) {
      return false; // Expired
    }
  }
  
  // Check data match (if multi-side)
  if (result.dataMatchResult?.overallState == DataMatchState.success) {
    return true; // Data matches between sides
  }
  
  return true;
}
```

### 2. Age Verification
```dart
bool isOver18(BlinkIdScanningResult result) {
  if (result.dateOfBirth?.date == null) return false;
  
  final dob = result.dateOfBirth!.date!;
  final birthDate = DateTime(dob.year, dob.month, dob.day);
  final age = DateTime.now().difference(birthDate).inDays ~/ 365;
  
  return age >= 18;
}
```

### 3. Extract Specific Fields
```dart
class ExtractedDocumentData {
  final String? fullName;
  final String? documentNumber;
  final DateTime? dateOfBirth;
  final DateTime? dateOfExpiry;
  final String? address;
  final String? country;
  
  ExtractedDocumentData.fromResult(BlinkIdScanningResult result)
      : fullName = result.fullName?.latin ?? result.fullName?.value,
        documentNumber = result.documentNumber?.latin ?? result.documentNumber?.value,
        dateOfBirth = result.dateOfBirth?.date != null
            ? DateTime(
                result.dateOfBirth!.date!.year,
                result.dateOfBirth!.date!.month,
                result.dateOfBirth!.date!.day,
              )
            : null,
        dateOfExpiry = result.dateOfExpiry?.date != null
            ? DateTime(
                result.dateOfExpiry!.date!.year,
                result.dateOfExpiry!.date!.month,
                result.dateOfExpiry!.date!.day,
              )
            : null,
        address = result.address?.latin ?? result.address?.value,
        country = result.documentClassInfo?.countryName;
}
```

---

## Troubleshooting

### Common Issues

1. **License Key Error**
   - Ensure license key is correct for the platform
   - Check if license has expired
   - Verify license is for the correct package name

2. **No Results Returned**
   - Check image quality (lighting, focus, angle)
   - Ensure document is supported
   - Try adjusting detection levels

3. **Slow Performance**
   - Preload SDK before scanning
   - Reduce image quality settings if not needed
   - Disable unnecessary image returns

4. **Memory Issues**
   - Don't return images unless needed
   - Process results immediately and dispose
   - Unload SDK when done

---

## Additional Resources

- [Microblink Developer Hub](https://developer.microblink.com/)
- [BlinkID Documentation](https://github.com/BlinkID/blinkid-flutter)
- [Supported Documents](https://microblink.com/supported-documents/)

---

## Summary

BlinkID Flutter provides powerful document scanning capabilities:

1. **Two main methods:**
   - `performScan()` - Camera with default UX
   - `performDirectApiScan()` - Process static images

2. **Key settings:**
   - SDK Settings: License key, resource download
   - Session Settings: Scanning mode
   - Scanning Settings: Quality, anonymization, image return
   - UX Settings: UI customization

3. **Result parsing:**
   - Check multiple alphabet sources (latin, arabic, cyrillic, greek)
   - Access MRZ, VIZ, and Barcode results separately
   - Validate data match for multi-side documents
   - Extract images if needed

4. **Best practices:**
   - Secure license key storage
   - Preload SDK for better performance
   - Handle errors gracefully
   - Validate results before use

This guide should help you implement card scanning in your Flutter application. For specific document types or advanced features, refer to the official BlinkID documentation.

