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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          TextButton.icon(
            onPressed: _toggleEdit,
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit_outlined,
              size: 20,
              color: _isEditing ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
            ),
            label: Text(
              _isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                color: _isEditing ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildPersonalDetailsCard(),
              const SizedBox(height: 16),
              _buildContactDetailsCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'This information cannot be changed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: _nameController.text,
            ),
            const Divider(height: 1, indent: 48),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'IC Number (NRIC)',
              value: _icController.text,
            ),
            const Divider(height: 1, indent: 48),
            _buildInfoRow(
              icon: Icons.wc_outlined,
              label: 'Gender',
              value: _genderController.text,
            ),
            const Divider(height: 1, indent: 48),
            _buildInfoRow(
              icon: Icons.mosque_outlined,
              label: 'Religion',
              value: _religionController.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: value.isEmpty ? Colors.grey.shade400 : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsCard() {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: _isEditing ? const Color(0xFF6366F1) : Colors.grey.shade600,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_outlined,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Phone Number',
                labelStyle: TextStyle(
                  color: _isEditing ? Colors.grey.shade700 : Colors.grey.shade500,
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: 'Enter phone number',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a phone number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine1Controller,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 1',
                labelStyle: TextStyle(
                  color: _isEditing ? Colors.grey.shade700 : Colors.grey.shade500,
                ),
                prefixIcon: const Icon(Icons.home_work_outlined),
                hintText: 'Enter address line 1',
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter Address Line 1' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressLine2Controller,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 2 (Optional)',
                labelStyle: TextStyle(
                  color: _isEditing ? Colors.grey.shade700 : Colors.grey.shade500,
                ),
                prefixIcon: const Icon(Icons.add_road_outlined),
                hintText: 'Enter address line 2 (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _postcodeController,
                    enabled: _isEditing,
                    decoration: inputDecoration.copyWith(
                      labelText: 'Postcode',
                      labelStyle: TextStyle(
                        color: _isEditing ? Colors.grey.shade700 : Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                      hintText: 'Postcode',
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
                    enabled: _isEditing,
                    decoration: inputDecoration.copyWith(
                      labelText: 'State',
                      labelStyle: TextStyle(
                        color: _isEditing ? Colors.grey.shade700 : Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      hintText: 'State',
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