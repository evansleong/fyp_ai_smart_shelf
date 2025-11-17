import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/yolo_detector_services.dart';
import 'dart:io';

// --- MODIFIED ENUM ---
enum CameraScanMode {
  qrCode, // For scanning QR codes
  ocr, // For taking a picture for Text Recognition (IC)
  faceRegister, // For capturing a user's face (no time limit)
  faceVerify, // For capturing a user's face (20s time limit)
}
// --- END MODIFIED ENUM ---

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
  YoloDetectorService? _detector;
  CameraDescription? _selectedCamera;
  bool _isManualCameraInitialized = false;
  bool _isPermissionGranted = false;
  bool _isDetecting = false;
  bool _isModelLoaded = false;

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

  // --- NEW: Timer state for verification mode ---
  Timer? _livenessTimer;
  int _countdownSeconds = 10;
  // --- END NEW ---

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
        // --- MODIFIED: Check for both face modes ---
        if (widget.scanMode == CameraScanMode.ocr ||
            widget.scanMode == CameraScanMode.faceRegister ||
            widget.scanMode == CameraScanMode.faceVerify) {
          _initializeManualCamera();
        }
      }
    });
  }

  // Helper to generate a random challenge list
  void _generateChallenges() {
    // ... (This function remains unchanged)
    _challenges.clear();
    _currentChallengeIndex = 0;
    _livenessInstruction = 'Position your face in the oval';
    _challenges.add(LivenessChallenge(
      LivenessChallengeType.lookStraight,
      'Please look straight',
    ));
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

    // --- MODIFIED: Use front camera for both face modes ---
    if (widget.scanMode == CameraScanMode.faceRegister ||
        widget.scanMode == CameraScanMode.faceVerify) {
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
    // --- END MODIFIED ---

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

    if (widget.scanMode == CameraScanMode.faceRegister ||
        widget.scanMode == CameraScanMode.faceVerify) {
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

      // --- NEW: Start timer ONLY for verification mode ---
      if (widget.scanMode == CameraScanMode.faceVerify) {
        _startLivenessTimer();
      }
    } else if (widget.scanMode == CameraScanMode.ocr) {
      // --- NEW: Load the YOLO model for OCR mode ---
      debugPrint("OCR Mode: Initializing YOLO detector...");
      _detector = YoloDetectorService();

      final bool modelLoadedSuccessfully = await _detector!.loadModel();

      if (mounted) {
        setState(() {
          // Only set _isModelLoaded if it was a success
          _isModelLoaded = modelLoadedSuccessfully;
        });

        if (!modelLoadedSuccessfully) {
          _showOcrError('Failed to load IC detector. Please restart the app.');
        }
      }

      await _detector!.loadModel();
      debugPrint("YOLO model initialized.");

      if (mounted) {
        setState(() {
          _isModelLoaded = true; // Tell the UI the model is ready!
        });
      }
    }
  }

  // --- NEW: Timer logic ---
  void _startLivenessTimer() {
    _livenessTimer?.cancel(); // Cancel any old timers
    _livenessTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 0) {
        timer.cancel();
        // Time's up!
        if (!mounted) return;

        debugPrint("--- Liveness Timer Expired ---");

        // Stop all processing
        _manualCameraController?.stopImageStream();
        _faceDetector?.close();
        _faceDetector = null;

        // Show a snackbar error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification timed out. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        // Pop the screen (returning null)
        Navigator.of(context).pop();
      } else {
        // Update UI with countdown
        if (mounted) {
          setState(() {
            _countdownSeconds--;
          });
        }
      }
    });
  }
  // --- END NEW ---

  // Process camera stream for liveness
  Future<void> _processCameraImage(CameraImage image) async {
    // ... (This entire function remains unchanged)
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
    // ... (This function remains unchanged)
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
    // --- NEW: Cancel timer on success ---
    _livenessTimer?.cancel();
    // --- END NEW ---

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
  // This is now ONLY for OCR mode
  // This is now ONLY for OCR mode
  Future<void> _onCapturePressed() async {
    if (widget.scanMode != CameraScanMode.ocr) return;

    // Guard clause (check if model is loaded)
    if (_manualCameraController == null ||
        !_manualCameraController!.value.isInitialized ||
        _detector == null ||
        !_isModelLoaded ||
        _isDetecting) {
      if (!_isModelLoaded) {
        debugPrint("Model is not loaded yet, please wait.");
      }
      return;
    }

    setState(() {
      _isDetecting = true; // Show loading spinner
    });

    try {
      // 1. Take the picture
      final image = await _manualCameraController!.takePicture();
      debugPrint("Picture taken: ${image.path}");

      // 2. Run YOLO detection
      debugPrint("Running YOLO detection...");
      final BoundingBox? detectedBox = await _detector!.detectCard(image.path);

      if (!mounted) return;

      // 3. Check if a card was found
      if (detectedBox != null) {
        debugPrint(
            "Card detected! Label: ${detectedBox.label}, Confidence: ${detectedBox.confidence}");
        debugPrint(
            "Bounding box: (${detectedBox.x}, ${detectedBox.y}, ${detectedBox.width}, ${detectedBox.height})");

        // 4. Crop the image
        final String? croppedImagePath =
            await _detector!.cropImage(image.path, detectedBox);

        if (croppedImagePath != null) {
          debugPrint("Image cropped successfully: $croppedImagePath");
          // SUCCESS - Pop with the cropped image path
          Navigator.of(context).pop(croppedImagePath);
        } else {
          debugPrint("ERROR: Cropping failed");
          _showOcrError(
              'The detected card region is too small. Please move closer or ensure better lighting.');
        }
      } else {
        debugPrint("No card detected in the image.");
        _showOcrError(
            'No IC card detected. Please:\n• Ensure the card is well-lit\n• Position it fully within the frame\n• Hold the camera steady');
      }
    } catch (e) {
      debugPrint("ERROR during YOLO capture/crop: $e");
      if (mounted) {
        _showOcrError('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false; // Hide loading spinner
        });
      }
    }
  }

  // --- 👇 ADD THIS NEW HELPER FUNCTION ---
  void _showOcrError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    // --- NEW: Cancel timer on dispose ---
    _livenessTimer?.cancel();
    // --- END NEW ---

    // Stop stream and close detector
    _manualCameraController?.stopImageStream();
    _faceDetector?.close();
    _detector?.dispose();
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

    // --- MODIFIED: Show for both face modes ---
    if (widget.scanMode == CameraScanMode.faceRegister ||
        widget.scanMode == CameraScanMode.faceVerify) {
      // ... (Oval size logic is the same)
      final double ovalWidth = MediaQuery.of(context).size.width * 0.8;
      final double ovalHeight = ovalWidth * 1.25;
      final Size ovalSize = Size(ovalWidth, ovalHeight);
      final double progress = _challenges.isEmpty
          ? 0.0
          : _currentChallengeIndex / _challenges.length;
      final Color borderColor = progress > 0.01 ? Colors.green : Colors.white;
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
          // --- NEW: Countdown Timer UI ---
          if (widget.scanMode == CameraScanMode.faceVerify)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_countdownSeconds s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // --- END NEW ---

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
    // --- END MODIFIED ---

    // UI elements for OCR mode
    Widget ocrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.ocr) {
      // ... (This UI logic remains unchanged)
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
              // Disable the button if the model isn't loaded
              onPressed: _isModelLoaded ? _onCapturePressed : null,
              backgroundColor: _isModelLoaded ? null : Colors.grey[700],
              child: _isDetecting
                  ? const CircularProgressIndicator(
                      color: Colors.white) // Shows spinner AFTER clicking
                  : (!_isModelLoaded
                      ? const CircularProgressIndicator(
                          color: Colors.white) // Shows spinner WHILE loading
                      : const Icon(Icons
                          .camera_alt)), // Only shows camera icon when ready
            ),
          ),
        ],
      );
    }

    // UI elements for QR mode
    Widget qrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.qrCode) {
      // ... (This UI logic remains unchanged)
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
          // --- MODIFIED: Check for both face modes ---
          if (widget.scanMode == CameraScanMode.faceRegister ||
              widget.scanMode == CameraScanMode.faceVerify)
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
            // ... (QR detect logic is unchanged)
            if (_isProcessing) return;
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

      // --- MODIFIED: Stack all manual camera cases ---
      case CameraScanMode.ocr:
      case CameraScanMode.faceRegister:
      case CameraScanMode.faceVerify:
        if (!_isManualCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- (Scaling logic is unchanged) ---
        final size = MediaQuery.of(context).size;
        var scale =
            size.aspectRatio * _manualCameraController!.value.aspectRatio;
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
  // ... (This class remains unchanged)
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
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.7);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    final progressPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 2 // Make it slightly thicker
      ..strokeCap = StrokeCap.round; // Rounded ends
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addOval(ovalRect),
    );
    canvas.drawPath(overlayPath, overlayPaint);
    canvas.drawOval(ovalRect, borderPaint);
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
