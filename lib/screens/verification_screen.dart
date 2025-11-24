import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import 'visitor_details_screen.dart';

class VerificationScreen extends StatefulWidget {
  final CardData? parsedData;
  final String name;
  final String idNumber;

  const VerificationScreen({
    super.key,
    this.parsedData,
    required this.name,
    required this.idNumber,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  File? _userPhoto;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _takeUserPhoto() async {
    await Permission.camera.request();

    if (!await Permission.camera.isGranted) {
      _showError('Camera permission is required');
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _userPhoto = File(photo.path);
        });
      }
    } catch (e) {
      _showError('Error taking photo: ${e.toString()}');
    }
  }

  void _goToStep3() {
    if (_userPhoto != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitorDetailsScreen(
            parsedData: widget.parsedData,
            name: widget.name,
            idNumber: widget.idNumber,
            userPhoto: _userPhoto,
          ),
        ),
      );
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
      appBar: const CustomAppBar(title: 'Step 2: Verification', showBackButton: true),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Summary
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
                        'Check-In Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Name:', widget.name),
                      _buildSummaryRow('ID:', widget.idNumber),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // User Photo Section
                Text(
                  'User Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please take a photo of the person for verification.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                if (_userPhoto != null)
                  Container(
                    height: 240,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _userPhoto!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // Camera Button
                CustomButton(
                  text: _userPhoto == null ? 'Take Verification Photo' : 'Retake Photo',
                  icon: Icons.camera_front,
                  backgroundColor: const Color(0xFF8B5CF6),
                  onPressed: _takeUserPhoto,
                  isLoading: false,
                ),

                // Next Step Button (Only visible if photo is taken)
                if (_userPhoto != null) ...[
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Step 3: Visitor Details',
                    icon: Icons.arrow_forward,
                    backgroundColor: const Color(0xFF3B82F6),
                    onPressed: _goToStep3,
                    isLoading: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

