import 'package:flutter/material.dart';
import '../../../core/services/ocr_service.dart';
import 'camera_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final OcrService _ocrService = OcrService();
  bool _isScanning = false;
  Map<String, String>? _extractedData;

  Future<void> _startScan() async {
    // 1. Navigate to the CameraScreen and wait for a result
    final String? imagePath = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    // 2. Check if we got an image path back
    if (imagePath == null) return;

    setState(() {
      _isScanning = true;
      _extractedData = null;
    });

    try {
      // The service now returns a map, let's call it 'data'
      final data = await _ocrService.scanIcCard(imagePath);
      if (!mounted) return;

      if (data != null && data.isNotEmpty) {
        setState(() {
          _extractedData = data;
        });
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
      // Ensure the loading indicator is always turned off
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Scan IC Card'),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isScanning) const CircularProgressIndicator(),
                if (_extractedData != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExtractedInfo(
                          context,
                          icon: Icons.badge,
                          label: 'IC Number (NRIC)',
                          value: _extractedData!['nric'] ?? 'N/A',
                        ),
                        const SizedBox(height: 16),
                        _buildExtractedInfo(
                          context,
                          icon: Icons.person,
                          label: 'Extracted Name',
                          value: _extractedData!['name'] ?? 'N/A',
                        ),
                        const SizedBox(height: 16),
                        _buildExtractedInfo(
                          context,
                          icon: Icons.home,
                          label: 'Extracted Address',
                          value: _extractedData!['address'] ?? 'N/A',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedInfo(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}