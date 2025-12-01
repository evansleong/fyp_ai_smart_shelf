import 'package:flutter/material.dart';
import '../core/services/checkout_service.dart';
import 'success_screen.dart';
import '../core/services/api_service.dart';

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
    _fetchPoints();
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessScreen(
            shelfId: widget.shelfId,
            userName: widget.userName,
            shelfName: widget.shelfName,
            shopId: widget.shopId,
            customerId: widget.customerId,
          ),
        ),
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
    if ((_nameCtrl.text.isEmpty) && (widget.prefillName?.isNotEmpty ?? false)) {
      _nameCtrl.text = widget.prefillName!;
    }
    if ((_phoneCtrl.text.isEmpty) &&
        (widget.prefillPhone?.isNotEmpty ?? false)) {
      _phoneCtrl.text = widget.prefillPhone!;
    }
    if ((_emailCtrl.text.isEmpty) &&
        (widget.prefillEmail?.isNotEmpty ?? false)) {
      _emailCtrl.text = widget.prefillEmail!;
    }

    // --- Calculate Display Total ---
    double totalToPay = widget.cartTotal - _discountAmount;
    if (totalToPay < 0) totalToPay = 0;

    int pointsNeeded = (widget.cartTotal / 0.10).ceil();
    int potentialPoints = pointsNeeded < _availablePoints ? pointsNeeded : _availablePoints;
    int displayPoints = _usePoints ? _pointsToRedeem : potentialPoints;
    double displaySavings = displayPoints * 0.10;

    return WillPopScope(
      onWillPop: () async {
        try {
          await ApiService()
              .resumeSession(shopId: widget.shopId, shelfId: widget.shelfId);
        } catch (_) {}
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront, size: 16),
                            const SizedBox(width: 6),
                            Text(widget.shelfName),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: const [
                          Icon(Icons.lock, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text('Secure payment'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_availablePoints > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: Colors.deepOrange,
                        title: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              "Redeem $_pointsToRedeem Points",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "You have RM ${(_availablePoints * 0.10).toStringAsFixed(2)} of points to be redeemed",
                          style: TextStyle(
                              color: Colors.orange.shade800, fontSize: 12),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Subtotal',
                                style: TextStyle(color: Colors.grey)),
                            const Spacer(),
                            Text('RM ${widget.cartTotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        if (_usePoints) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Points Discount',
                                  style: TextStyle(color: Colors.green)),
                              const Spacer(),
                              Text('- RM ${_discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Text('Total to Pay',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Text('RM ${totalToPay.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.blue)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    readOnly: widget.prefillName != null &&
                        widget.prefillName!.isNotEmpty,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    readOnly: widget.prefillPhone != null &&
                        widget.prefillPhone!.isNotEmpty,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                    readOnly: widget.prefillEmail != null &&
                        widget.prefillEmail!.isNotEmpty,
                  ),
                  const SizedBox(height: 8),
                  if ((widget.prefillEmail?.isNotEmpty ?? false))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Receipt will be sent to ${widget.prefillEmail}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _pay,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              'Pay RM ${widget.cartTotal.toStringAsFixed(2)}'),
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
}
