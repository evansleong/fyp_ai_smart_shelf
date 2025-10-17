// lib/features/registration/presentation/screens/camera_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. Request camera permissions
    if (await Permission.camera.request().isGranted) {
      // 2. Get available cameras
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // 3. Initialize the controller
        _controller = CameraController(cameras[0], ResolutionPreset.high);
        await _controller!.initialize();
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } else {
      // Handle permission denial
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      // Return the image path to the previous screen
      Navigator.of(context).pop(image.path);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // This will center the camera preview without any scaling
          Center(
            child: CameraPreview(_controller!),
          ),

          // Green guide box overlay
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          // Capture button at the bottom
          Positioned(
            bottom: 50,
            child: FloatingActionButton(
              onPressed: _onCapturePressed,
              child: const Icon(Icons.camera_alt),
            ),
          )
        ],
      ),
    );
  }
}
