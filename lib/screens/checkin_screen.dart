import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import '../services/blinkid_service.dart';
import '../services/mlkit_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _manualInputController = TextEditingController();
  final _blinkIDService = BlinkIDService();
  final _mlKitService = MLKitService();
  final _imagePicker = ImagePicker();

  File? _selectedImage;
  CardData? _parsedData;
  bool _isScanning = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    _mlKitService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Request camera permission
    await Permission.camera.request();
    
    // Request storage permissions based on platform
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use READ_MEDIA_IMAGES
      // For Android 12 and below, use READ_EXTERNAL_STORAGE
      // Permission.photos handles this automatically
      await Permission.photos.request();
    } else {
      // For iOS, use photos permission
      await Permission.photos.request();
    }
  }

  Future<void> _scanWithCamera() async {
    await _requestPermissions();
    
    if (!await Permission.camera.isGranted) {
      _showError('Camera permission is required');
      return;
    }

    setState(() {
      _isScanning = true;
      _selectedImage = null;
      _parsedData = null;
    });

    try {
      final result = await _blinkIDService.scanWithCamera();
      
      setState(() {
        _isScanning = false;
        if (result != null && !result.isEmpty) {
          _parsedData = result;
          // Auto-fill manual input if data is parsed
          if (result.fullName != null) {
            _manualInputController.text = result.fullName!;
          } else if (result.documentNumber != null) {
            _manualInputController.text = result.documentNumber!;
          }
        }
      });

      if (result == null || result.isEmpty) {
        _showError('BlinkID is not available on this device/emulator. Please use "Upload Image" to scan from gallery, or enter manually.');
      }
    } catch (e) {
      setState(() => _isScanning = false);
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('Camera scan error: $errorMessage');
      _showError('Camera scanning is not available. Please use "Upload Image" to scan from gallery, or enter manually.');
    }
  }

  Future<void> _pickImageFromGallery() async {
    await _requestPermissions();
    
    if (!await Permission.photos.isGranted) {
      _showError('Photo library permission is required');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _parsedData = null;
          _isScanning = true;
        });

        // Try BlinkID first, then fallback to ML Kit
        CardData? result;
        
        try {
          // Try BlinkID first
          result = await _blinkIDService.scanFromImage(_selectedImage!);
          
          // If BlinkID fails, use ML Kit as fallback
          if (result == null || result.isEmpty) {
            // ignore: avoid_print
            print('BlinkID failed, trying ML Kit fallback...');
            result = await _mlKitService.recognizeTextFromImage(_selectedImage!);
          }
        } catch (e) {
          // ignore: avoid_print
          print('BlinkID error, trying ML Kit fallback: $e');
          // Try ML Kit as fallback
          try {
            result = await _mlKitService.recognizeTextFromImage(_selectedImage!);
          } catch (mlKitError) {
            // ignore: avoid_print
            print('ML Kit error: $mlKitError');
          }
        }
        
        setState(() {
          _isScanning = false;
          if (result != null && !result.isEmpty) {
            _parsedData = result;
            // Auto-fill manual input if data is parsed
            if (result.fullName != null) {
              _manualInputController.text = result.fullName!;
            } else if (result.documentNumber != null) {
              _manualInputController.text = result.documentNumber!;
            } else if (result.rawText != null && result.rawText!.isNotEmpty) {
              // Use raw text if available
              _manualInputController.text = result.rawText!.split('\n').first;
            }
          }
        });

        if (result == null || result.isEmpty) {
          _showError('Failed to parse card data. Please try again or enter manually.');
        }
      }
    } catch (e) {
      _showError('Error picking image: ${e.toString()}');
    }
  }

  Future<void> _submitCheckIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Check-in successful!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Clear form after successful submission
        _manualInputController.clear();
        setState(() {
          _selectedImage = null;
          _parsedData = null;
        });
      }
    }
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
        title: 'Check In',
        showBackButton: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Scan Buttons Section
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Scan Card',
                          icon: Icons.camera_alt,
                          backgroundColor: const Color(0xFF10B981),
                          onPressed: _isScanning ? () {} : _scanWithCamera,
                          isLoading: _isScanning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomButton(
                          text: 'Upload Image',
                          icon: Icons.photo_library,
                          backgroundColor: const Color(0xFF8B5CF6),
                          onPressed: _isScanning ? () {} : _pickImageFromGallery,
                          isLoading: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Image Preview Section
                  if (_selectedImage != null || _isScanning)
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _isScanning && _selectedImage == null
                            ? Container(
                                color: Colors.black.withOpacity(0.3),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox(),
                      ),
                    ),
                  if (_selectedImage != null || _isScanning)
                    const SizedBox(height: 16),

                  // Manual Input Field
                  CustomTextField(
                    label: 'Name / ID Number',
                    hint: 'Enter name or ID number manually',
                    controller: _manualInputController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter name or ID number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Parsed Data Section
                  if (_parsedData != null && !_parsedData!.isEmpty)
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
                                'Parsed Data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_parsedData!.fullName != null)
                            _buildDataRow('Full Name', _parsedData!.fullName!),
                          if (_parsedData!.firstName != null)
                            _buildDataRow('First Name', _parsedData!.firstName!),
                          if (_parsedData!.lastName != null)
                            _buildDataRow('Last Name', _parsedData!.lastName!),
                          if (_parsedData!.documentNumber != null)
                            _buildDataRow(
                              'Document Number',
                              _parsedData!.documentNumber!,
                            ),
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
                        ],
                      ),
                    ),
                  if (_parsedData != null && !_parsedData!.isEmpty)
                    const SizedBox(height: 24),

                  // Submit Button
                  CustomButton(
                    text: 'Submit Check In',
                    icon: Icons.check,
                    backgroundColor: const Color(0xFF3B82F6),
                    onPressed: _isSubmitting ? () {} : _submitCheckIn,
                    isLoading: _isSubmitting,
                  ),
                ],
              ),
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
            width: 100,
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
