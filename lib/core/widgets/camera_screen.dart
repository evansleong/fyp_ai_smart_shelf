import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

// Enum to define the purpose of the camera scanner
enum CameraScanMode {
  qrCode, // For scanning QR codes
  ocr, // For taking a picture for Text Recognition (IC)
  face, // For capturing a user's face 
}

class CameraScreen extends StatefulWidget {
  // The screen now requires a scanMode to know what to do
  final CameraScanMode scanMode;

  const CameraScreen({
    super.key,
    required this.scanMode,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Controller for manual camera operations (used for OCR and Face)
  CameraController? _manualCameraController;
  bool _isManualCameraInitialized = false;
  bool _isPermissionGranted = false;

  // Controller for QR code scanning
  final MobileScannerController _qrScannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // To prevent multiple pops when a QR code is detected
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isPermissionGranted = status.isGranted;
      if (_isPermissionGranted) {
        // --- MODIFIED: Initialize manual camera for OCR or Face mode ---
        if (widget.scanMode == CameraScanMode.ocr ||
            widget.scanMode == CameraScanMode.face) {
          _initializeManualCamera();
        }
      }
    });
  }

  // --- MODIFIED: OCR/Face Specific Methods ---
  Future<void> _initializeManualCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // --- NEW: Select FRONT camera for face, BACK camera for OCR ---
    CameraDescription selectedCamera;
    if (widget.scanMode == CameraScanMode.face) {
      // Find the front-facing camera
      selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, // Fallback to first camera
      );
    } else {
      // Find the back-facing camera
      selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first, // Fallback to first camera
      );
    }

    _manualCameraController = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false, // Audio is not needed
    );

    await _manualCameraController!.initialize();
    if (!mounted) return;
    setState(() {
      _isManualCameraInitialized = true;
    });
  }

  Future<void> _onCapturePressed() async {
    if (_manualCameraController == null ||
        !_manualCameraController!.value.isInitialized) {
      return;
    }
    try {
      // Take the picture
      final image = await _manualCameraController!.takePicture();
      if (!mounted) return;

      // Pop with the image path. This works for both OCR and Face mode.
      Navigator.of(context).pop(image.path);
    } catch (e) {
      // Handle error
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  void dispose() {
    _manualCameraController?.dispose();
    _qrScannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedScreen();
    }

    // --- NEW: Determine app bar title based on all 3 modes ---
    final String title = widget.scanMode == CameraScanMode.qrCode
        ? 'Scan Shelf QR Code'
        : (widget.scanMode == CameraScanMode.ocr
            ? 'Scan Your IC'
            : 'Capture Your Face');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Conditionally build the scanner based on the mode
          _buildScanner(),

          // Guide box overlay (useful for all modes)
          _buildGuideBox(),

          // --- MODIFIED: Show capture button for OCR *or* Face mode ---
          if (widget.scanMode == CameraScanMode.ocr ||
              widget.scanMode == CameraScanMode.face)
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

  Widget _buildScanner() {
    switch (widget.scanMode) {
      case CameraScanMode.qrCode:
        // Use MobileScanner for efficient and easy QR code detection
        return MobileScanner(
          controller: _qrScannerController,
          onDetect: (capture) {
            if (_isProcessing) return; // Don't process if already processing

            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              setState(() {
                _isProcessing = true;
              });
              final String code = barcodes.first.rawValue!;
              // Return the scanned code to the previous screen
              Navigator.of(context).pop(code);
            }
          },
        );

      // --- MODIFIED: Stack OCR and Face cases, as they do the same thing ---
      case CameraScanMode.ocr:
      case CameraScanMode.face:
        // Use the manual CameraController for taking a picture
        if (!_isManualCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: CameraPreview(_manualCameraController!),
        );
    }
  }

  Widget _buildGuideBox() {
    final double boxWidth = MediaQuery.of(context).size.width * 0.8;
    double boxHeight;
    BorderRadius borderRadius;

    // --- NEW: Custom guide boxes for all 3 modes ---
    if (widget.scanMode == CameraScanMode.qrCode) {
      boxHeight = boxWidth; // Square for QR
      borderRadius = BorderRadius.circular(12);
    } else if (widget.scanMode == CameraScanMode.ocr) {
      boxHeight = 220; // Rectangle for IC card
      borderRadius = BorderRadius.circular(12);
    } else {
      // Face mode
      boxHeight = boxWidth * 1.25; // Portrait oval shape
      borderRadius = BorderRadius.circular(boxWidth / 1.5); // Make it rounded
    }

    return Container(
      width: boxWidth,
      height: boxHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 3),
        borderRadius: borderRadius,
      ),
    );
  }

  Widget _buildPermissionDeniedScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Camera Permission Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please grant camera permission in your device settings to use this feature.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              )
            ],
          ),
        ),
      ),
    );
  }
}