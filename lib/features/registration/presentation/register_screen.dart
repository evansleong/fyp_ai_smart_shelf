import 'package:flutter/material.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/widgets/camera_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // A key to identify and validate our form
  final _formKey = GlobalKey<FormState>();

  // Services and state management
  final OcrService _ocrService = OcrService();
  bool _isScanning = false;

  // Controllers to manage the text in each input field
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // State variables for the dropdown menus
  String? _selectedGender;
  String? _selectedReligion;

  @override
  void dispose() {
    // Clean up the controllers when the widget is removed from the tree
    _nameController.dispose();
    _icController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 1. Navigate to the CameraScreen and wait for an image path
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const CameraScreen(
                scanMode: CameraScanMode.ocr,
              )),
    );

    // 2. Return if no image was captured
    if (imagePath == null) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // 3. Call the OCR service to extract data
      final data = await _ocrService.scanIcCard(imagePath);
      if (!mounted) return;

      // 4. If data is extracted, populate the form fields
      if (data != null && data.isNotEmpty) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _icController.text = data['nric'] ?? '';
          _addressController.text = data['address'] ?? '';
          _selectedGender = data['gender'];
          _selectedReligion = data['religion'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details extracted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract details. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred during scanning.'),
        ),
      );
    } finally {
      // 5. Always stop the loading indicator
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _submitRegistration() {
    // Validate all form fields
    if (_formKey.currentState!.validate()) {
      // If the form is valid, you can proceed with the registration logic
      print('Form is valid!');
      print('Name: ${_nameController.text}');
      print('IC: ${_icController.text}');
      print('Gender: $_selectedGender');
      print('Address: ${_addressController.text}');
      print('Religion: $_selectedReligion');
      print('Phone: ${_phoneController.text}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing Registration...')),
      );
    }
  }

  // --- UI HELPER METHODS ---

  Widget _buildPersonalDetailsCard() {
    // Style for disabled fields to make them look locked
    final disabledFillColor = Colors.grey.shade200;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: disabledFillColor,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'IC Number (NRIC)',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: disabledFillColor,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc_outlined),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: disabledFillColor,
              ),
              items: ['Male', 'Female', 'Other']
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedReligion,
              decoration: InputDecoration(
                labelText: 'Religion',
                prefixIcon: const Icon(Icons.mosque_outlined),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: disabledFillColor,
              ),
              items: ['Muslim', 'Non-Muslim']
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Information',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter an address' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
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
      appBar: AppBar(title: const Text('Create Account')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Scan IC Button ---
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: const Icon(Icons.scanner),
                  label: const Text('Scan IC to Autofill'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_isScanning)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 16),

                // --- Form Sections ---
                _buildPersonalDetailsCard(),
                const SizedBox(height: 16),
                _buildContactDetailsCard(),
                const SizedBox(height: 32),

                // --- Register Button ---
                FilledButton(
                  onPressed: _submitRegistration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Register Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
