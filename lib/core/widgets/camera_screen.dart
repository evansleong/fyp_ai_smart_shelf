import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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

enum LivenessChallengeType {
  lookStraight,
  blink,
  turnLeft,
  turnRight,
}

class LivenessChallenge {
  final LivenessChallengeType type;
  final String instruction;
  int requiredCount; // e.g., for 2 blinks
  int currentCount = 0; // Tracks progress (e.g., 1 blink done)

  LivenessChallenge(
    this.type,
    this.instruction, {
    this.requiredCount = 1,
  });
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
  // Store selected camera for orientation
  CameraDescription? _selectedCamera;

  // Controller for QR code scanning
  final MobileScannerController _qrScannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // To prevent multiple pops when a QR code is detected
  bool _isProcessing = false;

  // Face Liveness State
  FaceDetector? _faceDetector;
  bool _isProcessingFrame = false;
  String _livenessInstruction = 'Position your face in the oval';

  // Dynamic Challenge State
  final List<LivenessChallenge> _challenges = [];
  int _currentChallengeIndex = 0;
  bool _isBlinking = false; // Helper to count discrete blinks

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
        if (widget.scanMode == CameraScanMode.ocr ||
            widget.scanMode == CameraScanMode.face) {
          _initializeManualCamera();
        }
      }
    });
  }

  // Helper to generate a random challenge list
  void _generateChallenges() {
    // Clear old challenges and reset index
    _challenges.clear();
    _currentChallengeIndex = 0;
    _livenessInstruction = 'Position your face in the oval';

    // 1. Always start with looking straight
    _challenges.add(LivenessChallenge(
      LivenessChallengeType.lookStraight,
      'Please look straight',
    ));

    // 2. Add the Head Tilt challenge FIRST.
    // The *direction* is still random.
    if (Random().nextBool()) {
      _challenges.add(LivenessChallenge(
        LivenessChallengeType.turnLeft,
        'Slowly turn your head left',
      ));
    } else {
      _challenges.add(LivenessChallenge(
        LivenessChallengeType.turnRight,
        'Slowly turn your head right',
      ));
    }

    // 3. Add the Blink challenge SECOND.
    // The *count* is still random.
    int blinkCount = Random().nextInt(2) + 2; // 2 or 3
    _challenges.add(LivenessChallenge(
      LivenessChallengeType.blink,
      'Please blink $blinkCount times',
      requiredCount: blinkCount,
    ));
  }

  Future<void> _initializeManualCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    if (widget.scanMode == CameraScanMode.face) {
      _selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
    } else {
      _selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    }

    _manualCameraController = CameraController(
      _selectedCamera!,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _manualCameraController!.initialize();
    if (!mounted) return;
    setState(() {
      _isManualCameraInitialized = true;
    });

    // Start image stream for face liveness
    if (widget.scanMode == CameraScanMode.face) {
      // 1. Generate the random challenge list
      _generateChallenges();

      // 2. Initialize the FaceDetector
      final options = FaceDetectorOptions(
        enableClassification: true, // Needed for blink detection
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      _faceDetector = FaceDetector(options: options);

      // 3. Start the stream
      _manualCameraController!.startImageStream(_processCameraImage);
    }
  }

  // Process camera stream for liveness
  Future<void> _processCameraImage(CameraImage image) async {
    if (_faceDetector == null || _isProcessingFrame) return;

    setState(() {
      _isProcessingFrame = true;
    });

    final inputImage = _inputImageFromCameraImage(image, _selectedCamera!);
    if (inputImage == null) {
      setState(() {
        _isProcessingFrame = false;
      });
      return;
    }

    final faces = await _faceDetector!.processImage(inputImage);
    String newInstruction = _livenessInstruction;

    if (faces.isEmpty) {
      // Face lost, reset all progress
      _generateChallenges(); // Create a new set of challenges
      newInstruction = _challenges.first.instruction;
    } else {
      final face = faces.first;
      final double headY = face.headEulerAngleY ?? 0;
      final double leftEye = face.leftEyeOpenProbability ?? 1.0;
      final double rightEye = face.rightEyeOpenProbability ?? 1.0;

      // Get the current challenge
      if (_currentChallengeIndex >= _challenges.length) {
        // This should be caught by the success state, but as a safeguard:
        await _onLivenessSuccess();
        return;
      }
      final challenge = _challenges[_currentChallengeIndex];
      newInstruction = challenge.instruction; // Show current instruction

      bool challengeMet = false;

      // --- New Dynamic State Machine ---
      switch (challenge.type) {
        case LivenessChallengeType.lookStraight:
          if (headY > -10 && headY < 10) {
            challengeMet = true;
          }
          break;

        case LivenessChallengeType.blink:
          // First, check if we are already in a "partially complete" state.
          int remaining = challenge.requiredCount - challenge.currentCount;

          if (remaining > 0 && remaining < challenge.requiredCount) {
            // If so, set the instruction to the partial progress
            // This prevents it from resetting to "Blink 3 times"
            newInstruction = 'Blink $remaining more time(s)';
          }

          // Now, process the blink detection
          if (leftEye < 0.2 && rightEye < 0.2) {
            _isBlinking = true; // Mark as "eyes closed"
          } else if (_isBlinking && leftEye > 0.8 && rightEye > 0.8) {
            // Eyes are open again after a blink
            challenge.currentCount++;
            _isBlinking = false; // Reset blink detector

            // Re-calculate remaining *after* incrementing
            remaining = challenge.requiredCount - challenge.currentCount;

            if (remaining > 0) {
              // Update instruction for the *next* frame
              newInstruction = 'Blink $remaining more time(s)';
            }

            if (challenge.currentCount >= challenge.requiredCount) {
              challengeMet = true;
            }
          }
          break;

        case LivenessChallengeType.turnLeft:
          if (headY > 30) {
            // Turned left (positive Y angle)
            challengeMet = true;
          }
          break;

        case LivenessChallengeType.turnRight:
          if (headY < -30) {
            // Turned right (negative Y angle)
            challengeMet = true;
          }
          break;
      }

      if (challengeMet) {
        _currentChallengeIndex++; // Move to next challenge
        if (_currentChallengeIndex >= _challenges.length) {
          // All challenges passed
          newInstruction = 'Success! Capturing...';
          await _onLivenessSuccess();
        } else {
          // Set instruction for the *next* challenge
          newInstruction = _challenges[_currentChallengeIndex].instruction;
        }
      }
    }

    // Update UI and unlock processing
    if (mounted) {
      setState(() {
        _livenessInstruction = newInstruction;
        _isProcessingFrame = false;
      });
    }
  }

  // Helper to convert CameraImage to InputImage
  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription cameraDescription) {
    try {
      final writeBuffer = WriteBuffer();
      for (final Plane plane in image.planes) {
        writeBuffer.putUint8List(plane.bytes);
      }
      final bytes = writeBuffer.done().buffer.asUint8List();

      final imageRotation = InputImageRotationValue.fromRawValue(
              cameraDescription.sensorOrientation) ??
          InputImageRotation.rotation90deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint("Error converting image: $e");
      return null;
    }
  }

  // Called when liveness succeeds
  Future<void> _onLivenessSuccess() async {
    // Stop all processing
    if (_manualCameraController == null) return;
    await _manualCameraController!.stopImageStream();
    await _faceDetector?.close();
    _faceDetector = null;

    try {
      // Take the picture
      final image = await _manualCameraController!.takePicture();
      if (!mounted) return;
      // Pop with the image path
      Navigator.of(context).pop(image.path);
    } catch (e) {
      debugPrint("Error taking picture after liveness: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Pop anyway to avoid getting stuck
      }
    }
  }

  // This is now ONLY for OCR mode
  Future<void> _onCapturePressed() async {
    if (widget.scanMode != CameraScanMode.ocr) return;

    if (_manualCameraController == null ||
        !_manualCameraController!.value.isInitialized) {
      return;
    }
    try {
      final image = await _manualCameraController!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image.path);
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  void dispose() {
    // Stop stream and close detector
    _manualCameraController?.stopImageStream();
    _faceDetector?.close();
    _manualCameraController?.dispose();
    _qrScannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return _buildPermissionDeniedScreen();
    }

    // This is the scanner or camera preview
    final scannerWidget = _buildScanner();

    // UI elements specifically for Face Liveness mode
    Widget faceLivenessUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.face) {
      // Calculate oval size
      final double ovalWidth = MediaQuery.of(context).size.width * 0.8;
      final double ovalHeight = ovalWidth * 1.25;
      final Size ovalSize = Size(ovalWidth, ovalHeight);

      // Calculate progress
      final double progress = _challenges.isEmpty
          ? 0.0
          : _currentChallengeIndex / _challenges.length;

      // Determine border color
      final Color borderColor = progress > 0.01 ? Colors.green : Colors.white;

      // Get screen center
      final screenCenterY = MediaQuery.of(context).size.height / 2;

      faceLivenessUI = Stack(
        alignment: Alignment.center,
        children: [
          // The overlay painter
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: OverlayPainter(
              cutoutSize: ovalSize,
              borderColor: borderColor,
              progress: progress,
            ),
          ),
          // "Liveness Check" Title (at top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            child: const Text(
              'Liveness Check',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Liveness Instruction (below oval)
          Positioned(
            // Position it below the oval
            top: screenCenterY + (ovalHeight / 2) + 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _livenessInstruction,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    // UI elements for OCR mode
    Widget ocrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.ocr) {
      // --- This is the old _buildGuideBox logic, just for OCR ---
      final double boxWidth = MediaQuery.of(context).size.width * 0.9;
      final double boxHeight = 220; // Rectangle for IC card
      ocrUI = Stack(
        alignment: Alignment.center,
        children: [
          // Guide box
          Container(
            width: boxWidth,
            height: boxHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Instruction text
          const Positioned(
            bottom: 140,
            child: Text(
              'Position your IC within the frame',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          // Capture button
          Positioned(
            bottom: 50,
            child: FloatingActionButton(
              onPressed: _onCapturePressed,
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      );
    }

    // UI elements for QR mode
    Widget qrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.qrCode) {
      // --- This is the old _buildGuideBox logic, just for QR ---
      final double boxWidth = MediaQuery.of(context).size.width * 0.8;
      qrUI = Stack(
        alignment: Alignment.center,
        children: [
          // Guide box
          Container(
            width: boxWidth,
            height: boxWidth, // Square
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Instruction text
          const Positioned(
            bottom: 140,
            child: Text(
              'Scan the shelf QR code',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The camera/scanner view (at the bottom)
          scannerWidget,

          // 2. The specific UI for the current mode
          if (widget.scanMode == CameraScanMode.face)
            faceLivenessUI
          else if (widget.scanMode == CameraScanMode.ocr)
            ocrUI
          else
            qrUI,

          // 3. Universal "Close" button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 --- UPDATED `_buildScanner` METHOD ---
  Widget _buildScanner() {
    switch (widget.scanMode) {
      case CameraScanMode.qrCode:
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
              Navigator.of(context).pop(code);
            }
          },
        );

      // Stack OCR and Face cases
      case CameraScanMode.ocr:
      case CameraScanMode.face:
        if (!_isManualCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- MODIFIED: This scaling logic ensures the preview covers the full screen ---
        final size = MediaQuery.of(context).size;
        // Calculate the scale to fill the screen (cover)
        var scale =
            size.aspectRatio * _manualCameraController!.value.aspectRatio;

        // Ensure it's always >= 1 (e.g., scale up, not down)
        if (scale < 1) scale = 1 / scale;

        return Transform.scale(
          scale: scale,
          child: Center(
            child: CameraPreview(_manualCameraController!),
          ),
        );
      // --- END MODIFIED ---
    }
  }

  // --- _buildGuideBox() is no longer needed ---

  Widget _buildPermissionDeniedScreen() {
    // ... (This function remains unchanged)
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

// 🎨 --- NEW WIDGET ---
// This class draws the semi-transparent overlay with an oval cutout
class OverlayPainter extends CustomPainter {
  final Size cutoutSize;
  final Color borderColor;
  final double borderWidth;
  final double progress; // 0.0 to 1.0

  OverlayPainter({
    required this.cutoutSize,
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: cutoutSize.width,
      height: cutoutSize.height,
    );

    // Paint for the semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.7);

    // Paint for the oval border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Paint for the progress ring
    final progressPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 2 // Make it slightly thicker
      ..strokeCap = StrokeCap.round; // Rounded ends

    // This path combines the full-screen rectangle and subtracts the oval
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addOval(ovalRect),
    );

    // Draw the overlay
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw the border
    canvas.drawOval(ovalRect, borderPaint);

    // Draw the progress arc
    if (progress > 0) {
      canvas.drawArc(
        ovalRect,
        -pi / 2, // Start at the top (12 o'clock)
        2 * pi * progress, // Sweep angle based on progress
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderColor != borderColor;
  }
}
