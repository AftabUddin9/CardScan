import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import '../services/blinkid_service.dart';
import '../services/api_service.dart';
import 'verification_screen.dart';
// MLKitService is no longer used as fallback for gallery image since gallery is removed
// import '../services/mlkit_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _blinkIDService = BlinkIDService();

  CardData? _parsedData;
  bool _isScanning = false;
  String? _idImageReference; // File ID from save-blob API
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _scanWithCamera() async {
    await _requestPermissions();

    if (!await Permission.camera.isGranted) {
      _showError('Camera permission is required');
      return;
    }

    setState(() {
      _isScanning = true;
      _parsedData = null;
      _idImageReference = null;
    });

    try {
      final result = await _blinkIDService.scanWithCamera();

      if (result != null && !result.isEmpty) {
        // Populate Name (Native preferred, or Latin/Value)
        String? name;
        if (result.fullName != null) {
          name = result.fullName!;
        } else if (result.firstName != null || result.lastName != null) {
          name = "${result.firstName ?? ''} ${result.lastName ?? ''}".trim();
        } else if (result.fullNameEnglish != null) {
          name = result.fullNameEnglish!;
        }

        // Populate ID (Native preferred)
        String? idNumber;
        if (result.documentNumber != null) {
          idNumber = result.documentNumber!;
        } else if (result.documentNumberEnglish != null) {
          idNumber = result.documentNumberEnglish!;
        }

        setState(() {
          _parsedData = result;
          if (name != null) _nameController.text = name;
          if (idNumber != null) _idController.text = idNumber;
          _isScanning = false;
        });

        // Upload document image to API
        if (result.documentImageBase64 != null &&
            result.documentImageBase64!.isNotEmpty) {
          setState(() {
            _isUploadingImage = true;
          });

          // Convert base64 to File
          final imageFile = await ApiService.base64ToFile(
            result.documentImageBase64!,
            extension: '.jpg',
          );

          if (imageFile != null) {
            final fileId = await ApiService.saveBlob(
              imageFile: imageFile,
            );

            setState(() {
              _isUploadingImage = false;
              _idImageReference = fileId;
            });

            if (fileId == null) {
              _showError('Failed to upload document image. Please try again.');
            }
          } else {
            setState(() {
              _isUploadingImage = false;
            });
            _showError('Failed to process document image. Please try again.');
          }
        } else {
          setState(() {
            _isScanning = false;
          });
          _showError('Document image not available. Please scan again.');
        }
      } else {
        setState(() {
          _isScanning = false;
        });
        _showError('BlinkID scan failed or cancelled. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _isUploadingImage = false;
      });
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('Camera scan error: $errorMessage');
      _showError('Camera scanning failed. Please try again.');
    }
  }

  void _goToVerification() {
    if (_parsedData == null || _parsedData!.isEmpty) {
      _showError('Please scan a card first');
      return;
    }

    if (_nameController.text.isEmpty || _idController.text.isEmpty) {
      _showError('Name and ID number are required. Please scan again.');
      return;
    }

    if (_idImageReference == null) {
      _showError('Document image is still uploading. Please wait...');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          parsedData: _parsedData,
          name: _nameController.text,
          idNumber: _idController.text,
          idImageReference: _idImageReference!,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: const CustomAppBar(
        title: 'Step 1: Card Scan',
        showBackButton: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scan Button Section
                CustomButton(
                  text: 'Scan Card',
                  icon: Icons.camera_alt,
                  backgroundColor: const Color(0xFF10B981),
                  onPressed: _isScanning ? () {} : _scanWithCamera,
                  isLoading: _isScanning,
                ),
                const SizedBox(height: 24),

                // Display Scanned Data (Read-only)
                if (_parsedData != null && !_parsedData!.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scanned Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDataRow(
                          'Name:',
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Not scanned',
                        ),
                        _buildDataRow(
                          'ID Number:',
                          _idController.text.isNotEmpty
                              ? _idController.text
                              : 'Not scanned',
                        ),
                        if (_isUploadingImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Uploading document...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_idImageReference != null && !_isUploadingImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Document uploaded',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Parsed Data Section
                if (_parsedData != null && !_parsedData!.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Preview Data',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Show English variants if available
                        if (_parsedData!.fullNameEnglish != null)
                          _buildDataRow(
                            'Name (English)',
                            _parsedData!.fullNameEnglish!,
                          ),
                        if (_parsedData!.documentNumberEnglish != null)
                          _buildDataRow(
                            'ID (English)',
                            _parsedData!.documentNumberEnglish!,
                          ),

                        // Other fields
                        if (_parsedData!.dateOfBirth != null)
                          _buildDataRow(
                            'Date of Birth',
                            _parsedData!.dateOfBirth!,
                          ),
                        if (_parsedData!.expiryDate != null)
                          _buildDataRow(
                            'Expiry Date',
                            _parsedData!.expiryDate!,
                          ),
                        if (_parsedData!.address != null)
                          _buildDataRow('Address', _parsedData!.address!),
                        if (_parsedData!.nationality != null)
                          _buildDataRow(
                            'Nationality',
                            _parsedData!.nationality!,
                          ),
                        if (_parsedData!.sex != null)
                          _buildDataRow('Sex', _parsedData!.sex!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scanned Image
                  if (_parsedData!.documentImageBase64 != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_parsedData!.documentImageBase64!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                'Image load failed',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],

                // Next Step Button (Go to Verification)
                CustomButton(
                  text: 'Step 2: Verification',
                  icon: Icons.arrow_forward,
                  backgroundColor: const Color(0xFF3B82F6),
                  onPressed: _goToVerification,
                  isLoading: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
