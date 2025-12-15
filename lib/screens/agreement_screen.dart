import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import '../models/workflow_data.dart';
import '../services/api_service.dart';

class AgreementScreen extends StatefulWidget {
  final CardData? parsedData;
  final String name;
  final String idNumber;
  final File? userPhoto;
  final String idImageReference; // File ID from step 1 (ID card)
  final String profilePictureFileId; // File ID from step 2 (selfie)
  final String email;
  final String? phone;
  final String? company;
  final String purposeOfVisit;
  final ApprovalSequence? selectedEscort;

  const AgreementScreen({
    super.key,
    this.parsedData,
    required this.name,
    required this.idNumber,
    this.userPhoto,
    required this.idImageReference,
    required this.profilePictureFileId,
    required this.email,
    this.phone,
    this.company,
    required this.purposeOfVisit,
    this.selectedEscort,
  });

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _isAgreed = false;
  bool _isSubmitting = false;
  String? _pdfPath;
  bool _isLoadingPdf = true;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _hasReachedLastPage = false;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Load PDF from assets
      final ByteData data = await rootBundle.load('assets/files/pdfFile.pdf');
      final bytes = data.buffer.asUint8List();
      
      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pdfFile.pdf');
      await file.writeAsBytes(bytes);
      
      setState(() {
        _pdfPath = file.path;
        _isLoadingPdf = false;
      });
    } catch (e) {
      print('Error loading PDF: $e');
      setState(() {
        _isLoadingPdf = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitCheckIn() async {
    // Validate agreement checkbox
    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions to proceed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare files array
      final files = [
        {'fileType': 'NID', 'fileId': widget.idImageReference},
      ];

      // Prepare dynamic data
      final dynamicData = {
        'IdNumber': widget.idNumber,
        'phone': widget.phone ?? '',
        'company': widget.company ?? '',
      };

      // Prepare visit schedule automatically
      // Set recurring visit to false, use current date/time, and end time 24h from now
      final now = DateTime.now();
      final endTime = now.add(const Duration(hours: 24));
      
      final visitSchedule = <String, dynamic>{
        'isRecurringVisit': false,
        'visitStartDate': DateFormat('yyyy-MM-dd').format(now),
        'visitStartTime': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'visitEndTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'visitEndDate': null, // Not needed for non-recurring visits
      };

      // Use selected escort's approverId as hostEmployeeId
      final hostEmployeeId = widget.selectedEscort?.approverId;

      // Call complete check-in API
      final response = await ApiService.completeCheckIn(
        name: widget.name,
        email: widget.email,
        profilePictureFileId: widget.profilePictureFileId,
        purposeOfVisit: widget.purposeOfVisit,
        files: files,
        dynamicData: dynamicData,
        hostEmployeeId: hostEmployeeId,
        visitSchedule: visitSchedule,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        if (response != null) {
          // Print response for debugging
          print('=== Check-In Response Data ===');
          print(response);
          print('=============================');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-in successful!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate back to home or initial screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-in failed. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: const CustomAppBar(
        title: 'Step 4: Agreement',
        showBackButton: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // PDF Viewer Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: _isLoadingPdf
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _pdfPath == null
                          ? Center(
                              child: Text(
                                'PDF not available',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                // PDF Page Info
                                if (_totalPages > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Page ${_currentPage + 1} of $_totalPages',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_left,
                                                color: Colors.white,
                                              ),
                                              onPressed: _currentPage > 0
                                                  ? () {
                                                      _pdfViewController
                                                          ?.setPage(_currentPage - 1);
                                                    }
                                                  : null,
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white,
                                              ),
                                              onPressed:
                                                  _currentPage < _totalPages - 1
                                                      ? () {
                                                          _pdfViewController
                                                              ?.setPage(_currentPage + 1);
                                                        }
                                                      : null,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                // PDF View
                                Expanded(
                                  child: PDFView(
                                    filePath: _pdfPath!,
                                    enableSwipe: true,
                                    swipeHorizontal: false,
                                    autoSpacing: true,
                                    pageFling: true,
                                    onRender: (pages) {
                                      setState(() {
                                        _totalPages = pages ?? 0;
                                        // If it's a single page PDF, user is already on last page
                                        if (_totalPages == 1) {
                                          _hasReachedLastPage = true;
                                        }
                                      });
                                    },
                                    onError: (error) {
                                      print('PDF Error: $error');
                                    },
                                    onPageError: (page, error) {
                                      print('PDF Page Error: $error');
                                    },
                                    onViewCreated: (PDFViewController controller) {
                                      _pdfViewController = controller;
                                    },
                                    onPageChanged: (int? page, int? total) {
                                      setState(() {
                                        _currentPage = page ?? 0;
                                        _totalPages = total ?? 0;
                                        // Check if user has reached the last page
                                        _hasReachedLastPage = 
                                            _totalPages > 0 && 
                                            _currentPage == _totalPages - 1;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
              ),

              // Agreement Checkbox and Submit Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Agreement Checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isAgreed,
                            onChanged: _hasReachedLastPage
                                ? (value) {
                                    setState(() {
                                      _isAgreed = value ?? false;
                                    });
                                  }
                                : null,
                            activeColor: const Color(0xFF10B981),
                            checkColor: Colors.white,
                          ),
                          Expanded(
                            child: Text(
                              _hasReachedLastPage
                                  ? 'I agree to the terms and conditions'
                                  : 'Please read through all pages to continue',
                              style: TextStyle(
                                color: _hasReachedLastPage
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    CustomButton(
                      text: 'Complete Check In',
                      icon: Icons.check_circle,
                      backgroundColor: const Color(0xFF10B981),
                      onPressed: _isSubmitting ? () {} : _submitCheckIn,
                      isLoading: _isSubmitting,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

