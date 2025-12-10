import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_button.dart';
import '../services/api_service.dart';

class CheckOutScreen extends StatefulWidget {
  const CheckOutScreen({super.key});

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  MobileScannerController? _scannerController;
  String? _scannedCode;
  bool _isScanning = false;
  bool _isCheckingOut = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _startScanning() async {
    if (!await Permission.camera.isGranted) {
      _showError('Camera permission is required');
      return;
    }

    setState(() {
      _isScanning = true;
      _hasScanned = false;
      _scannedCode = null;
    });

    // Initialize scanner controller
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_hasScanned && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _scannedCode = barcode.rawValue;
          _hasScanned = true;
          _isScanning = false;
        });

        // Stop scanner
        _scannerController?.stop();
      }
    }
  }

  Future<void> _checkOut() async {
    if (_scannedCode == null || _scannedCode!.isEmpty) {
      _showError('Please scan a QR code first');
      return;
    }

    setState(() {
      _isCheckingOut = true;
    });

    try {
      final response = await ApiService.checkout(visitNumber: _scannedCode!);

      setState(() {
        _isCheckingOut = false;
      });

      if (mounted) {
        if (response != null) {
          // Print response for debugging
          print('=== Checkout Response Data ===');
          print(response);
          print('=============================');

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-out successful!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate back to home screen
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-out failed. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isCheckingOut = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  void _resetScan() {
    setState(() {
      _scannedCode = null;
      _hasScanned = false;
      _isScanning = false;
    });
    _scannerController?.dispose();
    _scannerController = null;
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: const CustomAppBar(
        title: 'Check Out',
        showBackButton: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scan QR Code Button
                if (!_isScanning && !_hasScanned)
                  CustomButton(
                    text: 'Scan QR Code',
                    icon: Icons.qr_code_scanner,
                    backgroundColor: const Color(0xFF10B981),
                    onPressed: _startScanning,
                    isLoading: false,
                  ),

                // QR Scanner View
                if (_isScanning && !_hasScanned) ...[
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                          // Scanning overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF10B981),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          // Instructions
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Position QR code within the frame',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cancel button
                  CustomButton(
                    text: 'Cancel',
                    icon: Icons.close,
                    backgroundColor: Colors.grey,
                    onPressed: _resetScan,
                    isLoading: false,
                  ),
                ],

                // Success Message and Checkout Button
                if (_hasScanned && _scannedCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'QR Code Scanned Successfully!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Visit Number: $_scannedCode',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Checkout Button
                  CustomButton(
                    text: 'Check Out',
                    icon: Icons.logout,
                    backgroundColor: const Color(0xFFEF4444),
                    onPressed: _isCheckingOut ? () {} : _checkOut,
                    isLoading: _isCheckingOut,
                  ),
                  const SizedBox(height: 16),
                  // Rescan Button
                  CustomButton(
                    text: 'Scan Again',
                    icon: Icons.refresh,
                    backgroundColor: Colors.grey,
                    onPressed: _resetScan,
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
}
