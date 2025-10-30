import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/ocr_service.dart';
import '../core/widgets/camera_screen.dart';
import '../core/services/api_service.dart'; // 👈 IMPORT
import 'dart:io';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Services ---
  final OcrService _ocrService = OcrService();
  final ApiService _apiService = ApiService(); // 👈 USE

  // --- State ---
  bool _isScanning = false;
  bool _isRegistering = false;
  String? _faceImagePath;
  String? _faceImageKey;
  bool _isUploadingFace = false;

  // --- Controllers ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    _genderController.dispose();
    _religionController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const CameraScreen(
                scanMode: CameraScanMode.ocr,
              )),
    );

    if (imagePath == null || !mounted) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final data = await _ocrService.scanIcCard(imagePath);
      if (!mounted) return;

      if (data != null && data.isNotEmpty) {
        _parseAndPopulateData(data);
        _showSuccessSnackBar('Details extracted successfully!');
      } else {
        _showErrorSnackBar('Could not extract details. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('An error occurred during scanning: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _parseAndPopulateData(Map<String, dynamic> data) {
    setState(() {
      _nameController.text = data['name'] ?? '';
      _icController.text = data['nric'] ?? '';
      _genderController.text = data['gender'] ?? '';
      _religionController.text = data['religion'] ?? '';
    });
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _captureFace() async {
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          scanMode: CameraScanMode.face,
        ),
      ),
    );

    if (imagePath == null || !mounted) return;

    setState(() {
      _faceImagePath = imagePath;
      _isUploadingFace = true;
      _faceImageKey = null;
    });

    try {
      // 1. Call the service
      final String objectKey = await _apiService.uploadFaceToS3(imagePath);

      // 2. Set state
      if (!mounted) return;
      setState(() {
        _faceImageKey = objectKey;
      });

      _showSuccessSnackBar('Face captured and uploaded!');
    } catch (e) {
      // 3. Handle errors from the service
      _showErrorSnackBar('Face Upload Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFace = false;
        });
      }
    }
  }

  // --- REFACTORED: Uses ApiService ---
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_faceImageKey == null) {
      _showErrorSnackBar('Please capture your face to register.');
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      // 1. Create the request body
      final body = {
        'name': _nameController.text,
        'icNumber': _icController.text,
        'gender': _genderController.text,
        'religion': _religionController.text,
        'phone': _phoneController.text,
        'addressLine1': _addressLine1Controller.text,
        'addressLine2': _addressLine2Controller.text,
        'postcode': _postcodeController.text,
        'state': _stateController.text,
        'faceImageKey': _faceImageKey,
      };

      // 2. Call the service
      await _apiService.registerUser(body);

      // 3. Handle success
      if (!mounted) return;
      _showSuccessSnackBar('Registration Successful!');
      // Optionally pop screen
      // Navigator.of(context).pop();
    } catch (e) {
      // 4. Handle errors from the service
      _showErrorSnackBar('Registration Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  // --- Helper snackbar methods ---
  void _showErrorSnackBar(String content) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String content) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _nameController.clear();
      _icController.clear();
      _genderController.clear();
      _religionController.clear();
      _addressLine1Controller.clear();
      _addressLine2Controller.clear();
      _postcodeController.clear();
      _stateController.clear();
      _phoneController.clear();
    });
  }

  // --- UI HELPER METHODS ---

  Widget _buildPersonalDetailsCard() {
    final disabledFillColor = Colors.grey.shade200;
    final inputDecoration = InputDecoration(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        filled: true,
        fillColor: disabledFillColor,
        prefixIconColor: Colors.grey.shade600);

    final titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.bold);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- MODIFIED: Added icon and subtitle for clarity ---
            Row(
              children: [
                Icon(Icons.document_scanner_outlined,
                    color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text('Personal Details', style: titleStyle),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
              child: Text(
                'These details are filled automatically by scanning your IC.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextFormField(
              controller: _nameController,
              enabled: false,
              decoration: inputDecoration.copyWith(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icController,
              enabled: false,
              decoration: inputDecoration.copyWith(
                labelText: 'IC Number (NRIC)',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genderController,
              enabled: false,
              decoration: inputDecoration.copyWith(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _religionController,
              enabled: false,
              decoration: inputDecoration.copyWith(
                labelText: 'Religion',
                prefixIcon: const Icon(Icons.mosque_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactDetailsCard() {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
    final titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.bold);

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- MODIFIED: Added icon and subtitle for clarity ---
            Row(
              children: [
                Icon(Icons.edit_note_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Contact Information', style: titleStyle),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
              child: Text(
                'Please fill in your contact details manually.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextFormField(
              controller: _addressLine1Controller,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 1',
                prefixIcon: const Icon(Icons.home_work_outlined),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter Address Line 1' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine2Controller,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 2 (Optional)',
                prefixIcon: const Icon(Icons.add_road_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _postcodeController,
                    decoration: inputDecoration.copyWith(
                      labelText: 'Postcode',
                      prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: inputDecoration.copyWith(
                      labelText: 'State',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: inputDecoration.copyWith(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a phone number' : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Let's Get You Started",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan your IC to fill your details automatically.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // --- 'Scan IC' Button ---
                  FilledButton.tonalIcon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.scanner_outlined),
                    label: Text(
                        _isScanning ? 'Scanning...' : 'Scan IC to Autofill'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  // --- NEW: 'Capture Face' Button ---
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _isUploadingFace ? null : _captureFace,
                    icon: _isUploadingFace
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _faceImageKey != null // Show checkmark on success
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : const Icon(Icons.camera_front_outlined),
                    label: Text(_isUploadingFace
                        ? 'Uploading Face...'
                        : _faceImageKey != null
                            ? 'Face Captured!'
                            : 'Capture Face for Login'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // --- END NEW ---

                  const SizedBox(height: 24),

                  _buildPersonalDetailsCard(),
                  const SizedBox(height: 16),
                  _buildContactDetailsCard(),
                  const SizedBox(height: 32),

                  // --- MODIFIED BUTTON ROW ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          // Disable button while registering
                          onPressed: _isRegistering ? null : _resetForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reset Fields'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          // Disable button while registering OR if face is not yet captured
                          onPressed: (_isRegistering || _faceImageKey == null)
                              ? null
                              : _submitRegistration,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            // Make button gray if disabled
                            backgroundColor: (_faceImageKey == null)
                                ? Colors.grey.shade400
                                : null,
                          ),
                          // Show loading indicator when registering
                          child: _isRegistering
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'Register Account',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
