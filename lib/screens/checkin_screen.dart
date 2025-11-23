import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import '../services/blinkid_service.dart';
// MLKitService is no longer used as fallback for gallery image since gallery is removed
// import '../services/mlkit_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _blinkIDService = BlinkIDService();

  CardData? _parsedData;
  bool _isScanning = false;
  bool _isSubmitting = false;

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
    });

    try {
      final result = await _blinkIDService.scanWithCamera();

      setState(() {
        _isScanning = false;
        if (result != null && !result.isEmpty) {
          _parsedData = result;
          
          // Populate Name (Native preferred, or Latin/Value)
          if (result.fullName != null) {
            _nameController.text = result.fullName!;
          } else if (result.firstName != null || result.lastName != null) {
            _nameController.text = "${result.firstName ?? ''} ${result.lastName ?? ''}".trim();
          } else if (result.fullNameEnglish != null) {
             // Fallback to English if native was empty but english existed (though logic usually ensures fullName covers it)
             _nameController.text = result.fullNameEnglish!;
          }

          // Populate ID (Native preferred)
          if (result.documentNumber != null) {
            _idController.text = result.documentNumber!;
          } else if (result.documentNumberEnglish != null) {
             _idController.text = result.documentNumberEnglish!;
          }
        }
      });

      if (result == null || result.isEmpty) {
        _showError(
          'BlinkID scan failed or cancelled. Please try again or enter manually.',
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      // ignore: avoid_print
      print('Camera scan error: $errorMessage');
      _showError(
        'Camera scanning failed. Please enter manually.',
      );
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
        _nameController.clear();
        _idController.clear();
        setState(() {
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
      appBar: const CustomAppBar(title: 'Check In', showBackButton: true),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
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

                  // Manual Input Fields
                  CustomTextField(
                    label: 'Name',
                    hint: 'Enter full name',
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'ID Number',
                    hint: 'Enter ID number',
                    controller: _idController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter ID number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                            _buildDataRow('Name (English)', _parsedData!.fullNameEnglish!),
                          if (_parsedData!.documentNumberEnglish != null)
                            _buildDataRow('ID (English)', _parsedData!.documentNumberEnglish!),
                          
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
