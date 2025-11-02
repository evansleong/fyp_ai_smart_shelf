import 'package:flutter/material.dart';
import '../core/widgets/camera_screen.dart';
import '../core/services/api_service.dart';
import 'dart:io';

class FaceCaptureScreen extends StatefulWidget {
  // This screen receives the user details from Step 1
  final Map<String, dynamic> userDetails;

  const FaceCaptureScreen({
    super.key,
    required this.userDetails,
  });

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  // --- Services ---
  final ApiService _apiService = ApiService();

  // --- State ---
  bool _isRegistering = false;
  String? _faceImagePath;
  String? _faceImageKey;
  bool _isUploadingFace = false;

  // --- (This screen has no text controllers) ---

  @override
  void dispose() {
    super.dispose();
  }

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

  Future<void> _submitRegistration() async {
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
        ...widget.userDetails, 
        'faceImageKey': _faceImageKey,
      };

      // 2. Call the *original* registerUser service
      await _apiService.registerUser(body);

      // 3. Handle success
      if (!mounted) return;
      _showSuccessSnackBar('Registration Successful!');
      
      // Pop ALL screens back to the first screen (e.g., login)
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      // 4. Handle errors from the service
      // This will catch the "IC already registered" error if it
      // happens again (e.g., in a race condition)
      _showErrorSnackBar('Registration Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  // --- (Helper snackbar methods) ---
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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account (Step 2 of 2)'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Final Step: Face Login",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture your face. This will be used to log you in.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),

              // --- Face Preview (Optional but nice) ---
              if (_faceImagePath != null)
                CircleAvatar(
                  radius: 80,
                  backgroundImage: FileImage(File(_faceImagePath!)),
                )
              else
                CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person_outline,
                      size: 80, color: Colors.grey.shade600),
                ),
              
              const SizedBox(height: 48),

              // --- 'Capture Face' Button ---
              FilledButton.tonalIcon(
                onPressed: _isUploadingFace ? null : _captureFace,
                icon: _isUploadingFace
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : _faceImageKey != null // Show checkmark on success
                        ? const Icon(Icons.check_circle, color: Colors.green)
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
              const SizedBox(height: 24),

              // --- 'Register' Button ---
              FilledButton(
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
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}