import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

// Enum to define the purpose of the camera scanner
enum CameraScanMode {
  qrCode, // For scanning QR codes
  ocr,    // For taking a picture for Text Recognition (IC)
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
  // Controller for manual camera operations (used for OCR)
  CameraController? _ocrCameraController;
  bool _isOcrCameraInitialized = false;
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
        // If mode is OCR, initialize the manual camera controller
        if (widget.scanMode == CameraScanMode.ocr) {
          _initializeOcrCamera();
        }
      }
    });
  }

  // --- OCR Specific Methods ---
  Future<void> _initializeOcrCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _ocrCameraController = CameraController(cameras[0], ResolutionPreset.high);
      await _ocrCameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isOcrCameraInitialized = true;
      });
    }
  }

  Future<void> _onCapturePressed() async {
    if (_ocrCameraController == null || !_ocrCameraController!.value.isInitialized) {
      return;
    }
    try {
      // Take the picture
      final image = await _ocrCameraController!.takePicture();
      if (!mounted) return;
      
      // For OCR, you would now process this image with ML Kit.
      // After processing, you pop with the extracted text.
      // For now, we just pop with the path.
      Navigator.of(context).pop(image.path);

    } catch (e) {
      // Handle error
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  void dispose() {
    _ocrCameraController?.dispose();
    _qrScannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.scanMode == CameraScanMode.qrCode
            ? 'Scan Shelf QR Code'
            : 'Scan Your IC'),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Conditionally build the scanner based on the mode
          _buildScanner(),

          // Guide box overlay (useful for both modes)
          _buildGuideBox(),
          
          // Show capture button only for OCR mode
          if (widget.scanMode == CameraScanMode.ocr)
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
              setState(() { _isProcessing = true; });
              final String code = barcodes.first.rawValue!;
              // Return the scanned code to the previous screen
              Navigator.of(context).pop(code);
            }
          },
        );

      case CameraScanMode.ocr:
        // Use the manual CameraController for taking a picture
        if (!_isOcrCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: CameraPreview(_ocrCameraController!),
        );
    }
  }

  Widget _buildGuideBox() {
    // Calculate the desired width for the guide box
    final double boxWidth = MediaQuery.of(context).size.width * 0.8;

    return Container(
      width: boxWidth,
      // Use a ternary operator to set the height
      height: widget.scanMode == CameraScanMode.qrCode
          ? boxWidth // Make it a SQUARE for QR codes
          : 220,     // Keep it a RECTANGLE for IC cards (OCR)
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 3),
        borderRadius: BorderRadius.circular(12),
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