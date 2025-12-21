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
  bool _isLoadingProfile = true;
  bool _isSaving = false;
  Map<String, dynamic> _rewardsData = {
    'total_points': 0,
    'available_points': 0,
    'loyalty_tier': 'bronze',
    'lifetime_spend': 0.0,
  };
  final List<String> _malaysiaStates = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Kuala Lumpur',
    'Labuan',
    'Putrajaya',
  ];

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
    _initializeControllers(widget.user);
    _fetchLatestProfileData();
    _fetchRewardsData();
  }

  void _initializeControllers(Map<String, dynamic> user) {
    String address2 = user['addressLine2'] ?? '';
    if (address2 == '<empty>') address2 = '';

    String rawPhone = user['phone'] ?? '';
    if (rawPhone.startsWith('0')) {
      rawPhone = rawPhone.substring(1);
    }

    // Initialize controllers safely
    _nameController = TextEditingController(text: user['name'] ?? '');
    _icController = TextEditingController(text: user['icNumber'] ?? '');
    _phoneController = TextEditingController(text: rawPhone);
    _genderController = TextEditingController(text: user['gender'] ?? '');
    _religionController = TextEditingController(text: user['religion'] ?? '');
    _addressLine1Controller =
        TextEditingController(text: user['addressLine1'] ?? '');
    _addressLine2Controller = TextEditingController(text: address2);
    _postcodeController = TextEditingController(text: user['postcode'] ?? '');
    _stateController = TextEditingController(text: user['state'] ?? '');
  }

  Future<void> _fetchLatestProfileData() async {
    try {
      final api = ApiService();
      final shpUserId = widget.user['shp_user_id'] ?? widget.user['id'] ?? '';

      if (shpUserId.isNotEmpty) {
        final freshData = await api.getShopperInfo(shpUserId: shpUserId);

        if (freshData != null && mounted) {
          setState(() {
            String rawPhone = freshData['phone'] ?? '';
            if (rawPhone.startsWith('0')) {
              _phoneController.text = rawPhone.substring(1);
            } else {
              _phoneController.text = rawPhone;
            }
            _addressLine1Controller.text = freshData['addressLine1'] ?? '';

            String addr2 = freshData['addressLine2'] ?? '';
            _addressLine2Controller.text = (addr2 == '<empty>') ? '' : addr2;
            _postcodeController.text = freshData['postcode'] ?? '';
            _stateController.text = freshData['state'] ?? '';
            _nameController.text = freshData['name'] ?? '';
            _icController.text = freshData['icNumber'] ?? '';
          });
        }
      }
    } catch (e) {
      print("Error fetching latest profile: $e");
    }
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final api = ApiService();
      String rawPhone = _phoneController.text.trim();
      String formattedPhone = rawPhone.isNotEmpty ? '0$rawPhone' : '';
      final updatePayload = {
        'shp_user_id': widget.user['shp_user_id'] ?? widget.user['id'],
        'phone': formattedPhone,
        'addressLine1': _addressLine1Controller.text.trim(),
        'addressLine2': _addressLine2Controller.text.trim().isEmpty
            ? '<empty>'
            : _addressLine2Controller.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'state': _stateController.text.trim(),
      };

      await api.updateShopperProfile(updatePayload);
      await _fetchLatestProfileData();

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Update failed: ${e.toString().replaceAll('Exception:', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        _saveChanges();
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
                    fontWeight: FontWeight.w500,
                    color: value.isEmpty
                        ? Colors.grey.shade300
                        : const Color(0xFF1E293B)
                            .withOpacity(0.6), // Low opacity
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
    // Shared Input Decoration Style
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF6366F1), // Primary Color
          width: 1.5, // slightly thinner for elegance
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      filled: true,
      fillColor:
          _isEditing ? Colors.white : Colors.grey.shade50.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: TextStyle(
        color: _isEditing ? const Color(0xFF6366F1) : Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );

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
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                // Edit Button inside Contact Info
                _isEditing
                    ? InkWell(
                        onTap: () {
                          _formKey.currentState?.reset();
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: _toggleEdit,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Color(0xFF6366F1),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Phone Field (+60 Prefix) ---
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Phone Number',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "+60",
                        style: TextStyle(
                          color: _isEditing
                              ? Colors.grey.shade700
                              : Colors.grey.shade500,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade300,
                      )
                    ],
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value.startsWith('0')) return 'Do not include leading 0';
                if (value.length < 9) return 'Invalid length';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- Address Line 1 ---
            TextFormField(
              controller: _addressLine1Controller,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 1',
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter Address Line 1' : null,
            ),
            const SizedBox(height: 16),

            // --- Address Line 2 ---
            TextFormField(
              controller: _addressLine2Controller,
              enabled: _isEditing,
              decoration: inputDecoration.copyWith(
                labelText: 'Address Line 2 (Optional)',
              ),
            ),
            const SizedBox(height: 16),

            // --- Postcode & State Row ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Postcode
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _postcodeController,
                    enabled: _isEditing,
                    decoration: inputDecoration.copyWith(
                      labelText: 'Postcode',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (value.length != 5) return '5 digits';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // State Dropdown
                Expanded(
                  flex: 6,
                  child: IgnorePointer(
                    ignoring: !_isEditing, // Disable interaction if not editing
                    child: DropdownButtonFormField<String>(
                      // Use initialValue mechanism
                      value: _malaysiaStates.contains(_stateController.text)
                          ? _stateController.text
                          : null,

                      isExpanded: true,

                      // Style when disabled (not editing) vs enabled
                      decoration: inputDecoration.copyWith(
                        labelText: 'State',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        fillColor:
                            _isEditing ? Colors.white : Colors.grey.shade50,
                      ),

                      // Modern Styling
                      icon: _isEditing
                          ? const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF6366F1))
                          : const SizedBox(), // Hide arrow when read-only

                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 350,

                      items: _malaysiaStates.map((String state) {
                        return DropdownMenuItem<String>(
                          value: state,
                          child: Text(
                            state,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),

                      onChanged: _isEditing
                          ? (String? newValue) {
                              setState(() {
                                _stateController.text = newValue ?? '';
                              });
                            }
                          : null, // Disable logic

                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
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
                color:
                    isEditing ? const Color(0xFF6366F1) : Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isEditing ? const Color(0xFF6366F1) : Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isEditing ? Colors.white : Colors.grey.shade50,
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
              color: isEditing ? const Color(0xFF1E293B) : Colors.grey.shade600,
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
        gradient: LinearGradient(
          colors: _isSaving
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
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
          onTap: _isSaving ? null : _toggleEdit, // Disable tap while saving
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isSaving ? 'Saving...' : 'Save All Changes',
                  style: const TextStyle(
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
