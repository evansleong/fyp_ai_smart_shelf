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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final bool hasAllPrefill =
        (widget.prefillName?.isNotEmpty ?? false) &&
        (widget.prefillPhone?.isNotEmpty ?? false) &&
        (widget.prefillEmail?.isNotEmpty ?? false);
    if (!hasAllPrefill && !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await checkout(
        customerId: widget.customerId,
        shopId: widget.shopId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      // Best-effort stop monitoring on checkout completion
      try {
        await ApiService().mobileStop(shopId: widget.shopId, shelfId: widget.shelfId);
      } catch (_) {}
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
        SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
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
    if ((_phoneCtrl.text.isEmpty) && (widget.prefillPhone?.isNotEmpty ?? false)) {
      _phoneCtrl.text = widget.prefillPhone!;
    }
    if ((_emailCtrl.text.isEmpty) && (widget.prefillEmail?.isNotEmpty ?? false)) {
      _emailCtrl.text = widget.prefillEmail!;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  readOnly: widget.prefillName != null && widget.prefillName!.isNotEmpty,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  readOnly: widget.prefillPhone != null && widget.prefillPhone!.isNotEmpty,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                  readOnly: widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _pay,
                    child: _loading ? const CircularProgressIndicator() : const Text('Pay Now'),
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
