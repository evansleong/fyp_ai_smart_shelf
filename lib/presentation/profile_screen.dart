import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- MODIFIED: Accept the user map ---
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  // --- MODIFIED: Declare controllers as 'late' ---
  // We will initialize them in initState()
  late final TextEditingController _nameController;
  late final TextEditingController _icController;
  late final TextEditingController _phoneController;
  late final TextEditingController _genderController;
  late final TextEditingController _religionController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _postcodeController;
  late final TextEditingController _stateController;

  // --- NEW: Initialize controllers with user data ---
  @override
  void initState() {
    super.initState();
    // Get the user map passed from the HomeScreen
    final user = widget.user;

    // Handle the "<empty>" string from DynamoDB
    String address2 = user['addressLine2'] ?? '';
    if (address2 == '<empty>') {
      address2 = '';
    }

    // Initialize all controllers with the user's data
    _nameController = TextEditingController(text: user['name'] ?? '');
    _icController = TextEditingController(text: user['icNumber'] ?? '');
    _phoneController = TextEditingController(text: user['phone'] ?? '');
    _genderController = TextEditingController(text: user['gender'] ?? '');
    _religionController = TextEditingController(text: user['religion'] ?? '');
    _addressLine1Controller =
        TextEditingController(text: user['addressLine1'] ?? '');
    _addressLine2Controller = TextEditingController(text: address2);
    _postcodeController = TextEditingController(text: user['postcode'] ?? '');
    _stateController = TextEditingController(text: user['state'] ?? '');
  }

  @override
  void dispose() {
    // Clean up all controllers
    _nameController.dispose();
    _icController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _religionController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  // --- MODIFIED: Add validation before saving ---
  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // --- User is trying to SAVE ---
        // First, validate the form
        if (_formKey.currentState!.validate()) {
          // If valid, stop editing and show success
          _isEditing = false;
          
          // TODO: In the future, you will call your API here
          // 1. Show a loading indicator
          // 2. final success = await _apiService.updateProfile({ ... });
          // 3. Only set _isEditing = false and show snackbar if success
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // If form is not valid, stay in editing mode
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fix the errors in the form.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // --- User is trying to EDIT ---
        _isEditing = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save_outlined : Icons.edit_outlined),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildPersonalDetailsCard(),
              const SizedBox(height: 16),
              _buildContactDetailsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI HELPER: Personal Details (Non-Editable) ---
  // (No changes needed in this function)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Details', style: titleStyle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: false, // Not editable
              decoration: inputDecoration.copyWith(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icController,
              enabled: false, // Not editable
              decoration: inputDecoration.copyWith(
                labelText: 'IC Number (NRIC)',
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _genderController,
              enabled: false, // Not editable
              decoration: inputDecoration.copyWith(
                labelText: 'Gender',
                prefixIcon: const Icon(Icons.wc_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _religionController,
              enabled: false, // Not editable
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

  // --- UI HELPER: Contact Details (Editable) ---
  // (No changes needed in this function)
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Information', style: titleStyle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing, // <-- Only editable when in edit mode
              decoration: inputDecoration.copyWith(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a phone number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine1Controller,
              enabled: _isEditing, // <-- Only editable when in edit mode
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
              enabled: _isEditing, // <-- Only editable when in edit mode
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
                    enabled: _isEditing, // <-- Only editable
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
                    enabled: _isEditing, // <-- Only editable
                    decoration: inputDecoration.copyWith(
                      labelText: 'State',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}