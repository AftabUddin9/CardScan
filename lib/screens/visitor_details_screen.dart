import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/gradient_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../models/card_data.dart';
import '../models/workflow_data.dart';
import '../services/api_service.dart';
import 'agreement_screen.dart';

class VisitorDetailsScreen extends StatefulWidget {
  final CardData? parsedData;
  final String name;
  final String idNumber;
  final File? userPhoto;
  final String idImageReference; // File ID from step 1 (ID card)
  final String profilePictureFileId; // File ID from step 2 (selfie)

  const VisitorDetailsScreen({
    super.key,
    this.parsedData,
    required this.name,
    required this.idNumber,
    this.userPhoto,
    required this.idImageReference,
    required this.profilePictureFileId,
  });

  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  String? _selectedVisitPurpose;
  bool _isRecurringVisit = true; // Set to true by default
  DateTime? _visitStartDate;
  DateTime? _visitEndDate;
  TimeOfDay? _visitStartTime;
  TimeOfDay? _visitEndTime;

  // Workflow data
  WorkflowData? _workflowData;
  bool _isLoadingWorkflow = false;
  ApprovalSequence? _selectedEscort; // Selected approval sequence (order 1)

  final List<String> _visitPurposes = ['Meeting', 'Site Survey', 'Activity'];

  @override
  void initState() {
    super.initState();
    // Set default dates and times
    final now = DateTime.now();
    _visitStartDate = now;
    _visitEndDate = now.add(const Duration(days: 7));
    _visitStartTime = TimeOfDay.fromDateTime(now);
    _visitEndTime = TimeOfDay.fromDateTime(now);
    // Fetch workflow data
    _fetchWorkflow();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorkflow() async {
    setState(() {
      _isLoadingWorkflow = true;
    });

    try {
      final response = await ApiService.fetchWorkflow();
      if (response != null) {
        final workflow = WorkflowData.fromJson(response);
        setState(() {
          _workflowData = workflow;
          // Set default escort (approval sequence with order 1)
          _selectedEscort = workflow.approvalSequences
              .where((seq) => seq.order == 1)
              .firstOrNull;
          _isLoadingWorkflow = false;
        });
      } else {
        setState(() {
          _isLoadingWorkflow = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load workflow data. Please try again.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingWorkflow = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workflow: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitCheckIn() async {
    if (_formKey.currentState!.validate()) {
      // Validate that file IDs are present and not the file type strings
      if (widget.idImageReference.isEmpty ||
          widget.idImageReference == 'idcard') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ID card image reference is missing or invalid. Please scan again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (widget.profilePictureFileId.isEmpty ||
          widget.profilePictureFileId == 'userselfie') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile picture file ID is missing or invalid. Please take a selfie again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Validate VMS Info
      if (_selectedEscort == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an escort.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Navigate to Step 4 (Agreement Screen)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgreementScreen(
            parsedData: widget.parsedData,
            name: widget.name,
            idNumber: widget.idNumber,
            userPhoto: widget.userPhoto,
            idImageReference: widget.idImageReference,
            profilePictureFileId: widget.profilePictureFileId,
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            company: _companyController.text.trim().isNotEmpty
                ? _companyController.text.trim()
                : null,
            purposeOfVisit: _selectedVisitPurpose!,
            selectedEscort: _selectedEscort,
            isRecurringVisit: _isRecurringVisit,
            visitStartDate: _visitStartDate!,
            visitEndDate: _visitEndDate,
            visitStartTime: _visitStartTime!,
            visitEndTime: _visitEndTime!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: const CustomAppBar(
        title: 'Step 3: Visitor Details',
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
                  // VMS Info Section
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
                          'VMS Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Location Dropdown
                        if (_isLoadingWorkflow)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_workflowData != null) ...[
                          _buildSummaryRow('Location:', _workflowData!.name),
                          _buildSummaryRow(
                            'Escort:',
                            _selectedEscort?.name ?? 'N/A',
                          ),
                        ] else
                          Text(
                            'No workflow data available',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Section
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
                          'Visitor Information',
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

                  // Phone Number Field
                  CustomTextField(
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      // Optional field, no validation needed
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field (Required)
                  CustomTextField(
                    label: 'Email *',
                    hint: 'Enter email address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      // Basic email validation
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Company Field
                  CustomTextField(
                    label: 'Company',
                    hint: 'Enter company name',
                    controller: _companyController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      // Optional field, no validation needed
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Visit Purpose Dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visit Purpose *',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedVisitPurpose,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          dropdownColor: const Color(0xFF1A1F3A),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          hint: Text(
                            'Select visit purpose',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                          items: _visitPurposes.map((String purpose) {
                            return DropdownMenuItem<String>(
                              value: purpose,
                              child: Text(purpose),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedVisitPurpose = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a visit purpose';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button (Navigate to Step 4)
                  CustomButton(
                    text: 'Continue to Agreement',
                    icon: Icons.arrow_forward,
                    backgroundColor: const Color(0xFF10B981),
                    onPressed: _submitCheckIn,
                    isLoading: false,
                  ),
                ],
              ),
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
            width: 80,
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
