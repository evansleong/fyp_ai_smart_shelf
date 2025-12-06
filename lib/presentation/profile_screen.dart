import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/api_service.dart';

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

  bool _isLoadingPoints = true;
  Map<String, dynamic> _rewardsData = {
    'total_points': 0,
    'available_points': 0,
    'loyalty_tier': 'bronze',
    'lifetime_spend': 0.0,
  };

  late final TextEditingController _nameController;
  late final TextEditingController _icController;
  late final TextEditingController _phoneController;
  late final TextEditingController _genderController;
  late final TextEditingController _religionController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _postcodeController;
  late final TextEditingController _stateController;


  @override
  void initState() {
    super.initState();
    final user = widget.user;
    String address2 = user['addressLine2'] ?? '';
    if (address2 == '<empty>') {
      address2 = '';
    }

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

    _fetchRewardsData();
  }

  Future<void> _fetchRewardsData() async {
    try {
      final api = ApiService(); 
      final shpUserId = widget.user['shp_user_id'] ?? widget.user['id'] ?? '';

      if (shpUserId.isNotEmpty) {
        final data = await api.getUserPoints(shpUserId);
        if (mounted) {
          setState(() {
            _rewardsData = data;
            _isLoadingPoints = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching points: $e");
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  @override
  void dispose() {
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

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        if (_formKey.currentState!.validate()) {
          _isEditing = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fix the errors in the form.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
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
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isEditing
                ? Container(
                    key: const ValueKey('cancel'),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _formKey.currentState?.reset();
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('edit'),
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleEdit,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                                color: Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  if (_isEditing) _buildEditModeBanner(),
                  const SizedBox(height: 16),
                  if (_isLoadingPoints)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _buildRewardsCard(),
                  const SizedBox(height: 16),
                  _buildPersonalDetailsCard(),
                  const SizedBox(height: 16),
                  _buildContactDetailsCard(),
                  SizedBox(height: _isEditing ? 100 : 24), 
                ],
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: _buildFloatingSaveButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'This information cannot be changed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModernInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Full Name',
              value: _nameController.text,
            ),
            const SizedBox(height: 16),
            _buildModernInfoRow(
              icon: Icons.badge_outlined,
              label: 'IC Number (NRIC)',
              value: _icController.text,
            ),
            const SizedBox(height: 16),
            _buildModernInfoRow(
              icon: Icons.wc_outlined,
              label: 'Gender',
              value: _genderController.text,
            ),
            const SizedBox(height: 16),
            _buildModernInfoRow(
              icon: Icons.mosque_outlined,
              label: 'Religion',
              value: _religionController.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsCard() {
    final tier =
        (_rewardsData['loyalty_tier'] ?? 'bronze').toString().toLowerCase();

    Color startColor;
    Color endColor;
    Color iconColor;

    switch (tier) {
      case 'platinum':
        startColor = const Color(0xFFE5E4E2);
        endColor = const Color(0xFF607D8B);
        iconColor = Colors.black45;
        break;
      case 'gold':
        startColor = const Color(0xFFFFD700);
        endColor = const Color(0xFFFFA000);
        iconColor = Colors.white;
        break;
      case 'silver':
        startColor = const Color(0xFFC0C0C0);
        endColor = const Color(0xFF9E9E9E);
        iconColor = Colors.white;
        break;
      default: // bronze
        startColor = const Color(0xFFCD7F32);
        endColor = const Color(0xFFA0522D);
        iconColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: endColor.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.star_rounded,
              size: 180,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tier.toUpperCase(),
                              style: TextStyle(
                                color: iconColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(_rewardsData['available_points'] ?? 0).toInt()}',
                            style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 48,
                              letterSpacing: -2,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'POINTS',
                            style: TextStyle(
                              color: iconColor.withOpacity(0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: iconColor,
                        size: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: iconColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lifetime Spend',
                          style: TextStyle(
                            color: iconColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Text(
                        'RM ${(_rewardsData['lifetime_spend'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 22,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF1E293B),
                    letterSpacing: -0.3,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phone_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Phone Number
            _buildModernTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a phone number' : null,
              isEditing: _isEditing,
            ),
            const SizedBox(height: 20),
            // Address Line 1
            _buildModernTextField(
              controller: _addressLine1Controller,
              label: 'Address Line 1',
              icon: Icons.home_work_outlined,
              validator: (value) =>
                  value!.isEmpty ? 'Please enter Address Line 1' : null,
              isEditing: _isEditing,
            ),
            const SizedBox(height: 20),
            // Address Line 2 (Optional)
            _buildModernTextField(
              controller: _addressLine2Controller,
              label: 'Address Line 2 (Optional)',
              icon: Icons.add_road_outlined,
              isEditing: _isEditing,
            ),
            const SizedBox(height: 20),
            // Postcode and State Row
            Row(
              children: [
                Expanded(
                  child: _buildModernTextField(
                    controller: _postcodeController,
                    label: 'Postcode',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    isEditing: _isEditing,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernTextField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.location_city_outlined,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                    isEditing: _isEditing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isEditing,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isEditing
                    ? const Color(0xFF6366F1).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isEditing
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isEditing 
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isEditing 
                ? Colors.white 
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEditing
                  ? const Color(0xFF6366F1).withOpacity(0.5)
                  : Colors.grey.shade200,
              width: isEditing ? 2 : 1,
            ),
            boxShadow: isEditing
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            enabled: isEditing,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isEditing
                  ? const Color(0xFF1E293B)
                  : Colors.grey.shade600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'Enter ${label.toLowerCase()}',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditModeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap fields below to edit your information',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleEdit,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Save All Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.3,
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
