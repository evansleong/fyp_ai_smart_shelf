import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart'; // Ensure this is in pubspec.yaml
import '../services/yolo_detector_services.dart'; // Ensure this path is correct

// --- ENUMS ---
enum CameraScanMode {
  qrCode,
  ocr,
  faceRegister,
  faceVerify,
}

enum LivenessChallengeType {
  lookStraight,
  blink,
  turnLeft,
  turnRight,
}

// --- HELPER CLASSES ---
class LivenessChallenge {
  final LivenessChallengeType type;
  final String instruction;
  int requiredCount; 
  int currentCount = 0;

  LivenessChallenge(
    this.type, 
    this.instruction, {
    this.requiredCount = 1,
  });
}

class CameraScreen extends StatefulWidget {
  final CameraScanMode scanMode;

  const CameraScreen({
    super.key,
    required this.scanMode,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // --- Controllers & Services ---
  CameraController? _manualCameraController;
  YoloDetectorService? _detector;
  CameraDescription? _selectedCamera;
  FaceDetector? _faceDetector;
  
  final MobileScannerController _qrScannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // --- State Variables ---
  bool _isManualCameraInitialized = false;
  bool _isPermissionGranted = false;
  bool _isDetecting = false;
  bool _isModelLoaded = false;
  bool _isProcessing = false; // For QR
  bool _isProcessingFrame = false; // For Face
  bool _isTorchOn = false;
  
  Future<void> _toggleTorch() async {
    try {
      if (widget.scanMode == CameraScanMode.qrCode) {
        // For QR code, use MobileScanner torch
        await _qrScannerController.toggleTorch();
      } else if (widget.scanMode == CameraScanMode.ocr) {
        // For OCR, use CameraController torch
        if (_manualCameraController != null && _manualCameraController!.value.isInitialized) {
          await _manualCameraController!.setFlashMode(
            _isTorchOn ? FlashMode.off : FlashMode.torch,
          );
        }
      }
      
      if (mounted) {
        setState(() {
          _isTorchOn = !_isTorchOn;
        });
      }
    } catch (e) {
      debugPrint('Torch toggle failed: $e');
    }
  }


  // --- Liveness State ---
  String _livenessInstruction = 'Position your face in the oval';
  final List<LivenessChallenge> _challenges = [];
  int _currentChallengeIndex = 0;
  bool _isBlinking = false;
  Timer? _livenessTimer;
  int _countdownSeconds = 10;

  // --- Brightness State ---
  double _originalBrightness = 0.5;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    
    // Maximize brightness only for face modes
    if (widget.scanMode == CameraScanMode.faceVerify || 
        widget.scanMode == CameraScanMode.faceRegister) {
      _maximizeBrightness();
    }
  }

  // --- Brightness Logic ---
  Future<void> _maximizeBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0); // 100% Brightness
    } catch (e) {
      debugPrint("Error setting brightness: $e");
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(_originalBrightness);
    } catch (e) {
      debugPrint("Error resetting brightness: $e");
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isPermissionGranted = status.isGranted;
      if (_isPermissionGranted) {
        if (widget.scanMode != CameraScanMode.qrCode) {
          _initializeManualCamera();
        }
      }
    });
  }

  // --- Initialization ---
  Future<void> _initializeManualCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Select Camera based on mode
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

    // Initialize Logic based on Mode
    if (widget.scanMode == CameraScanMode.faceRegister ||
        widget.scanMode == CameraScanMode.faceVerify) {
      
      _generateChallenges();
      
      final options = FaceDetectorOptions(
        enableClassification: true, 
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      _faceDetector = FaceDetector(options: options);
      
      _manualCameraController!.startImageStream(_processCameraImage);

      if (widget.scanMode == CameraScanMode.faceVerify) {
        _startLivenessTimer();
      }
    } else if (widget.scanMode == CameraScanMode.ocr) {
      debugPrint("OCR Mode: Initializing YOLO detector...");
      _detector = YoloDetectorService();
      final bool modelLoadedSuccessfully = await _detector!.loadModel();
      
      if (mounted) {
        setState(() {
          _isModelLoaded = modelLoadedSuccessfully;
        });
        if (!modelLoadedSuccessfully) {
          _showOcrError('Failed to load IC detector.');
        }
      }
    }
  }

  void _generateChallenges() {
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
    
    int blinkCount = Random().nextInt(2) + 2; // 2 or 3 blinks
    _challenges.add(LivenessChallenge(
      LivenessChallengeType.blink,
      'Please blink $blinkCount times',
      requiredCount: blinkCount,
    ));
  }

  void _startLivenessTimer() {
    _livenessTimer?.cancel();
    _livenessTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds <= 0) {
        timer.cancel();
        if (!mounted) return;
        
        // Stop everything
        _manualCameraController?.stopImageStream();
        _faceDetector?.close();
        _faceDetector = null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification timed out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      } else {
        if (mounted) {
          setState(() {
            _countdownSeconds--;
          });
        }
      }
    });
  }

  // --- Face Processing Logic ---
  Future<void> _processCameraImage(CameraImage image) async {
    if (_faceDetector == null || _isProcessingFrame) return;

    setState(() {
      _isProcessingFrame = true;
    });

    final inputImage = _inputImageFromCameraImage(image, _selectedCamera!);
    if (inputImage == null) {
      setState(() => _isProcessingFrame = false);
      return;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);
      String newInstruction = _livenessInstruction;

      if (faces.isEmpty) {
        _generateChallenges(); // Reset if face lost
        newInstruction = _challenges.first.instruction;
      } else {
        final face = faces.first;
        final double headY = face.headEulerAngleY ?? 0;
        final double leftEye = face.leftEyeOpenProbability ?? 1.0;
        final double rightEye = face.rightEyeOpenProbability ?? 1.0;

        if (_currentChallengeIndex >= _challenges.length) {
          await _onLivenessSuccess();
          return;
        }
        
        final challenge = _challenges[_currentChallengeIndex];
        newInstruction = challenge.instruction;
        bool challengeMet = false;

        switch (challenge.type) {
          case LivenessChallengeType.lookStraight:
            if (headY > -10 && headY < 10) challengeMet = true;
            break;

          case LivenessChallengeType.blink:
            int remaining = challenge.requiredCount - challenge.currentCount;
            if (remaining > 0 && remaining < challenge.requiredCount) {
              newInstruction = 'Blink $remaining more time(s)';
            }

            // Blink detection logic
            if (leftEye < 0.2 && rightEye < 0.2) {
              _isBlinking = true; // Eyes closed
            } else if (_isBlinking && leftEye > 0.8 && rightEye > 0.8) {
              // Eyes open again -> Blink complete
              challenge.currentCount++;
              _isBlinking = false;
              remaining = challenge.requiredCount - challenge.currentCount;
              if (remaining > 0) newInstruction = 'Blink $remaining more time(s)';
              if (challenge.currentCount >= challenge.requiredCount) challengeMet = true;
            }
            break;

          case LivenessChallengeType.turnLeft:
            if (headY > 30) challengeMet = true;
            break;

          case LivenessChallengeType.turnRight:
            if (headY < -30) challengeMet = true;
            break;
        }

        if (challengeMet) {
          _currentChallengeIndex++;
          if (_currentChallengeIndex >= _challenges.length) {
            newInstruction = 'Success! Capturing...';
            await _onLivenessSuccess();
          } else {
            newInstruction = _challenges[_currentChallengeIndex].instruction;
          }
        }
      }

      if (mounted) {
        setState(() {
          _livenessInstruction = newInstruction;
          _isProcessingFrame = false;
        });
      }
    } catch (e) {
      debugPrint("Error processing face: $e");
      setState(() => _isProcessingFrame = false);
    }
  }

  Future<void> _onLivenessSuccess() async {
    _livenessTimer?.cancel();
    if (_manualCameraController == null) return;
    
    await _manualCameraController!.stopImageStream();
    await _faceDetector?.close();
    _faceDetector = null;

    try {
      final image = await _manualCameraController!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image.path);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // --- OCR Processing Logic ---
  Future<void> _onCapturePressed() async {
    if (widget.scanMode != CameraScanMode.ocr) return;
    if (_manualCameraController == null || !_isModelLoaded || _isDetecting) return;

    setState(() => _isDetecting = true);

    try {
      final image = await _manualCameraController!.takePicture();
      final BoundingBox? detectedBox = await _detector!.detectCard(image.path);

      if (!mounted) return;

      if (detectedBox != null) {
        final String? croppedImagePath = await _detector!.cropImage(image.path, detectedBox);
        if (croppedImagePath != null) {
          Navigator.of(context).pop(croppedImagePath);
        } else {
          _showOcrError('Cropping failed. Try again.');
        }
      } else {
        _showOcrError('No IC detected. Adjust lighting and position.');
      }
    } catch (e) {
      if (mounted) _showOcrError('Error: $e');
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

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

  // --- Helper: Image Conversion ---
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
      return null;
    }
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _manualCameraController?.stopImageStream();
    _faceDetector?.close();
    _detector?.dispose();
    _manualCameraController?.dispose();
    _qrScannerController.dispose();

    // Reset brightness on exit if we changed it
    if (widget.scanMode == CameraScanMode.faceVerify || 
        widget.scanMode == CameraScanMode.faceRegister) {
      _resetBrightness();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) return _buildPermissionDeniedScreen();

    // The base camera view
    final scannerWidget = _buildScanner();

    // --- Face Liveness UI (White "Soft Box" Style) ---
    Widget faceLivenessUI = const SizedBox.shrink();

    if (widget.scanMode == CameraScanMode.faceRegister ||
        widget.scanMode == CameraScanMode.faceVerify) {
      
      final double ovalWidth = MediaQuery.of(context).size.width * 0.8;
      final double ovalHeight = ovalWidth * 1.25;
      final Size ovalSize = Size(ovalWidth, ovalHeight);
      final double progress = _challenges.isEmpty ? 0.0 : _currentChallengeIndex / _challenges.length;
      
      // Colors specifically for White Background
      final Color borderColor = progress > 0.01 ? Colors.green : Colors.grey.shade400;
      final screenCenterY = MediaQuery.of(context).size.height / 2;

      faceLivenessUI = Stack(
        alignment: Alignment.center,
        children: [
          // 1. The White Overlay Painter
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: OverlayPainter(
              cutoutSize: ovalSize,
              borderColor: borderColor,
              progress: progress,
            ),
          ),
          
          // 2. Title (Dark Text)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            child: const Text(
              'Liveness Check',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 3. Timer (Verification Only)
          if (widget.scanMode == CameraScanMode.faceVerify)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(
                  '$_countdownSeconds s',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 4. Instruction Box (White with Shadow)
          Positioned(
            top: screenCenterY + (ovalHeight / 2) + 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _livenessInstruction,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16, 
                    fontWeight: FontWeight.w600
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // 5. Close Button (Dark Icon for White BG)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      );
    }

    // --- OCR UI ---
    Widget ocrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.ocr) {
      final double boxWidth = MediaQuery.of(context).size.width * 0.9;
      final double boxHeight = 220;
      ocrUI = Stack(
        children: [
          // Dim background overlay (matching QR UI style)
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          // Frame border with enhanced styling
          Align(
            alignment: Alignment.center,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.06),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.credit_card,
                    size: 50,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
          // Close button (matching QR UI style)
          Positioned(
            top: MediaQuery.of(context).padding.top + 18,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Flashlight button (positioned above instructions)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 200,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _toggleTorch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: Icon(
                  _isTorchOn ? Icons.flash_off : Icons.flash_on,
                  color: Colors.white,
                ),
                label: Text(_isTorchOn ? 'Turn Off Flash' : 'Turn On Flash'),
              ),
            ),
          ),
          // Instructions text (matching QR UI style)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 140,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  'Position your IC within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Ensure good lighting and keep the IC flat',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Capture button (enhanced styling)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.large(
                onPressed: _isModelLoaded && !_isDetecting ? _onCapturePressed : null,
                backgroundColor: _isModelLoaded && !_isDetecting 
                    ? Colors.white 
                    : Colors.grey.shade700,
                child: _isDetecting
                    ? const CircularProgressIndicator(
                        color: Colors.black87,
                        strokeWidth: 3,
                      )
                    : (!_isModelLoaded
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.black87,
                            size: 32,
                          )),
              ),
            ),
          ),
        ],
      );
    }

    // --- QR UI ---
    Widget qrUI = const SizedBox.shrink();
    if (widget.scanMode == CameraScanMode.qrCode) {
      final double boxWidth = MediaQuery.of(context).size.width * 0.78;
      qrUI = Stack(
        children: [
          // Dim background overlay
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: boxWidth,
              height: boxWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              // Frame interior is transparent - no gradient overlay
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 60,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 18,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 140,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  'Align QR within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Stand about 20 cm away for best results',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 60,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _toggleTorch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: Icon(
                  _isTorchOn ? Icons.flash_off : Icons.flash_on,
                  color: Colors.white,
                ),
                label: Text(_isTorchOn ? 'Turn Off Flash' : 'Turn On Flash'),
              ),
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
          scannerWidget, // Layer 1: Camera Feed
          
          // Layer 2: Specific Overlays
          if (widget.scanMode == CameraScanMode.faceRegister ||
              widget.scanMode == CameraScanMode.faceVerify)
            faceLivenessUI
          else if (widget.scanMode == CameraScanMode.ocr)
            ocrUI
          else
            qrUI,
        ],
      ),
    );
  }

  Widget _buildScanner() {
    switch (widget.scanMode) {
      case CameraScanMode.qrCode:
        return MobileScanner(
          controller: _qrScannerController,
          onDetect: (capture) {
            if (_isProcessing) return;
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              setState(() => _isProcessing = true);
              Navigator.of(context).pop(barcodes.first.rawValue!);
            }
          },
        );

      case CameraScanMode.ocr:
      case CameraScanMode.faceRegister:
      case CameraScanMode.faceVerify:
        if (!_isManualCameraInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final size = MediaQuery.of(context).size;
        var scale = size.aspectRatio * _manualCameraController!.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;
        
        return Transform.scale(
          scale: scale,
          child: Center(
            child: CameraPreview(_manualCameraController!),
          ),
        );
    }
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

// 🎨 --- UPDATED OVERLAY PAINTER (Soft Box Effect) ---
class OverlayPainter extends CustomPainter {
  final Size cutoutSize;
  final Color borderColor;
  final double borderWidth;
  final double progress; // 0.0 to 1.0

  OverlayPainter({
    required this.cutoutSize,
    this.borderColor = Colors.grey,
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

    // 1. White Background (Soft Box Light Source)
    final overlayPaint = Paint()..color = Colors.white; 

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
      
    final progressPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 2
      ..strokeCap = StrokeCap.round;

    // Create the cutout mask
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
        -pi / 2,
        2 * pi * progress,
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