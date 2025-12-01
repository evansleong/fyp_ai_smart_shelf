import 'package:flutter/material.dart';
import '../core/services/checkout_service.dart';
import 'success_screen.dart';
import '../core/services/api_service.dart';
import '../core/services/session_service.dart';
import '../core/model/cart_model.dart';

class CheckoutScreen extends StatefulWidget {
  final String shopId;
  final String customerId;
  final String shelfId;
  final String userName;
  final String shelfName;
  final String? prefillName;
  final String? prefillPhone;
  final String? prefillEmail;
  final double cartTotal;
  final List<CartItem> cartItems;

  const CheckoutScreen({
    super.key,
    required this.shopId,
    required this.customerId,
    required this.shelfId,
    required this.userName,
    required this.shelfName,
    this.prefillName,
    this.prefillPhone,
    this.prefillEmail,
    required this.cartTotal,
    required this.cartItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  int _availablePoints = 0;
  bool _usePoints = false;
  double _discountAmount = 0.0;
  int _pointsToRedeem = 0;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _fetchPoints();
  }

  void _initializeFields() {
    final session = SessionService();

    // 1. Try to load from session first
    if (session.name != null && session.name!.isNotEmpty) {
      _nameCtrl.text = session.name!;
    } else if (widget.prefillName != null) {
      _nameCtrl.text = widget.prefillName!;
      session.updateSession(name: widget.prefillName);
    }

    if (session.phone != null && session.phone!.isNotEmpty) {
      _phoneCtrl.text = session.phone!;
    } else if (widget.prefillPhone != null) {
      _phoneCtrl.text = widget.prefillPhone!;
      session.updateSession(phone: widget.prefillPhone);
    }

    if (session.email != null && session.email!.isNotEmpty) {
      _emailCtrl.text = session.email!;
    } else if (widget.prefillEmail != null) {
      _emailCtrl.text = widget.prefillEmail!;
      session.updateSession(email: widget.prefillEmail);
    }

    // 2. Listen for changes to update session
    _nameCtrl.addListener(() {
      session.updateSession(name: _nameCtrl.text);
    });
    _phoneCtrl.addListener(() {
      session.updateSession(phone: _phoneCtrl.text);
    });
    _emailCtrl.addListener(() {
      session.updateSession(email: _emailCtrl.text);
    });
  }

  Future<void> _fetchPoints() async {
    try {
      final data = await ApiService().getUserPoints(widget.customerId);
      if (mounted) {
        setState(() {
          final points = data['available_points'];
          if (points is int) {
            _availablePoints = points;
          } else if (points is double) {
            _availablePoints = points.toInt();
          } else {
            _availablePoints = 0;
          }
          _calculatePointsLogic();
        });
      }
    } catch (e) {
      print("Error fetching points: $e");
    }
  }

  void _calculatePointsLogic() {
    if (!_usePoints) {
      _discountAmount = 0.0;
      _pointsToRedeem = 0;
      return;
    }

    int pointsNeededForCart = (widget.cartTotal / 0.10).ceil();

    _pointsToRedeem = pointsNeededForCart < _availablePoints
        ? pointsNeededForCart
        : _availablePoints;

    _discountAmount = _pointsToRedeem * 0.10;

    if (_discountAmount > widget.cartTotal) {
      _discountAmount = widget.cartTotal;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final bool hasAllPrefill = (widget.prefillName?.isNotEmpty ?? false) &&
        (widget.prefillPhone?.isNotEmpty ?? false) &&
        (widget.prefillEmail?.isNotEmpty ?? false);
    if (!hasAllPrefill && !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      double finalAmount = widget.cartTotal - _discountAmount;
      if (finalAmount < 0) finalAmount = 0;

      await checkout(
        customerId: widget.customerId,
        shopId: widget.shopId,
        amount: finalAmount,
        pointsToRedeem: _pointsToRedeem,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      // Resume session after successful payment
      try {
        await ApiService()
            .resumeSession(shopId: widget.shopId, shelfId: widget.shelfId);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessScreen(
            shelfId: widget.shelfId,
            userName: widget.userName,
            shelfName: widget.shelfName,
            shopId: widget.shopId,
            customerId: widget.customerId,
            purchasedItems: widget.cartItems,
          ),
        ),
        (route) => route.settings.name == 'ShoppingScreen',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Payment failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Calculate Display Total ---
    double totalToPay = widget.cartTotal - _discountAmount;
    if (totalToPay < 0) totalToPay = 0;

    // Removed unused potentialPoints variable

    return WillPopScope(
      onWillPop: () async {
        try {
          await ApiService()
              .resumeSession(shopId: widget.shopId, shelfId: widget.shelfId);
        } catch (_) {}
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Checkout', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.storefront,
                                  size: 20, color: Colors.black87),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.shelfName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('Subtotal',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                            const Spacer(),
                            Text('RM ${widget.cartTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (_usePoints) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Points Discount',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 16)),
                              const Spacer(),
                              Text('- RM ${_discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('Total to Pay',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            const Spacer(),
                            Text('RM ${totalToPay.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: Colors.black)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_availablePoints > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        activeColor: Colors.deepPurple,
                        title: Row(
                          children: [
                            const Icon(Icons.stars_rounded,
                                color: Colors.orange, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Redeem $_pointsToRedeem Points",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                Text(
                                  "Available: RM ${(_availablePoints * 0.10).toStringAsFixed(2)}",
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        value: _usePoints,
                        onChanged: (val) {
                          setState(() {
                            _usePoints = val;
                            _calculatePointsLogic();
                          });
                        },
                      ),
                    ),

                  const Text("Contact Details",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    readOnly: widget.prefillName != null &&
                        widget.prefillName!.isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    readOnly: widget.prefillPhone != null &&
                        widget.prefillPhone!.isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                    readOnly: widget.prefillEmail != null &&
                        widget.prefillEmail!.isNotEmpty,
                  ),

                  if ((widget.prefillEmail?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        'Receipt will be sent to ${widget.prefillEmail}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white, // Fix text color
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _pay,
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Pay RM ${totalToPay.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Secure Payment by Stripe',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
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
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
      ),
    );
  }
}
