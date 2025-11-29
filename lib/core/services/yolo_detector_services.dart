import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Helper class to hold our detection results
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final String label;

  BoundingBox(
      this.x, this.y, this.width, this.height, this.confidence, this.label);
}

class YoloDetectorService {
  late Interpreter _interpreter;
  late List<String> _labels;

  // This must match the size you trained with (640)
  final int _inputSize = 640;
  final String _modelPath = 'assets/models/mykad_detector.tflite';
  final String _labelPath = 'assets/models/labels.txt';

  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final labelsData = await rootBundle.loadString(_labelPath);
      _labels = labelsData.split('\n').map((e) => e.trim()).toList();
      
      // Print model info for debugging
      debugPrint('YOLO model loaded successfully');
      debugPrint('Input shape: ${_interpreter.getInputTensor(0).shape}');
      debugPrint('Output shape: ${_interpreter.getOutputTensor(0).shape}');
      debugPrint('Labels: $_labels');
      
      return true;
    } catch (e) {
      debugPrint('Error loading YOLO model: $e');
      return false;
    }
  }

  // 1. Detects the card in a full-size photo
  Future<BoundingBox?> detectCard(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      debugPrint("Failed to decode image");
      return null;
    }

    final originalHeight = originalImage.height;
    final originalWidth = originalImage.width;
    debugPrint("Original image size: $originalWidth x $originalHeight");

    // Resize image for the model (letterbox to maintain aspect ratio)
    final resizedImage = img.copyResize(
      originalImage, 
      width: _inputSize, 
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Convert to 4D list [1, 640, 640, 3], normalize 0-255 to 0.0-1.0
    var input = List.generate(
        1,
        (i) => List.generate(
            _inputSize,
            (j) => List.generate(_inputSize, (k) {
                  final pixel = resizedImage.getPixel(k, j);
                  return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
                })));

    // Get output shape from the model
    var outputShape = _interpreter.getOutputTensor(0).shape;
    debugPrint("Output shape: $outputShape");
    
    // Handle both [1, numBoxes, numProperties] and [1, numProperties, numBoxes]
    int dim1 = outputShape[1];
    int dim2 = outputShape[2];
    
    bool isTransposed = dim1 < dim2; // If [1, 5, 8400] instead of [1, 8400, 5]
    int numBoxes = isTransposed ? dim2 : dim1;
    int numProperties = isTransposed ? dim1 : dim2;
    
    debugPrint("Detected format: ${isTransposed ? 'TRANSPOSED [1, $numProperties, $numBoxes]' : 'NORMAL [1, $numBoxes, $numProperties]'}");

    // Initialize output buffer
    var output = List.generate(1,
        (i) => List.generate(dim1, (j) => List.filled(dim2, 0.0)));

    try {
      _interpreter.run(input, output);
      debugPrint("Inference completed successfully");
    } catch (e) {
      debugPrint("Error running YOLO inference: $e");
      return null;
    }

    // --- Parse the output ---
    List<BoundingBox> detections = [];
    final double confidenceThreshold = 0.7;

    for (int i = 0; i < numBoxes; i++) {
      // Get the correct box data based on format
      List<double> box;
      if (isTransposed) {
        // Format: [1, 5, 8400] - need to extract column i
        box = [
          output[0][0][i], // x_center
          output[0][1][i], // y_center
          output[0][2][i], // width
          output[0][3][i], // height
          output[0][4][i], // confidence (for single class) or first class score
        ];
      } else {
        // Format: [1, 8400, 5]
        box = output[0][i];
      }
      
      // YOLOv8 format: [x_center, y_center, width, height, ...class scores]
      final double xCenter = box[0];
      final double yCenter = box[1];
      final double w = box[2];
      final double h = box[3];
      
      // For models with multiple classes, find max confidence
      // For single class or binary, use box[4]
      double maxConfidence = box[4];
      int maxClassId = 0;
      
      // If there are more values, check for multiple classes
      if (box.length > 5) {
        for (int c = 0; c < (box.length - 4); c++) {
          double classConf = box[4 + c];
          if (classConf > maxConfidence) {
            maxConfidence = classConf;
            maxClassId = c;
          }
        }
      }

      // Only process detections above threshold
      if (maxConfidence > confidenceThreshold) {
        // YOLOv8 outputs normalized coordinates (0-1)
        // Scale directly to original image size
        final double scaledXCenter = xCenter * originalWidth;
        final double scaledYCenter = yCenter * originalHeight;
        final double scaledW = w * originalWidth;
        final double scaledH = h * originalHeight;
        
        // Convert from center format to corner format (top-left x, y)
        final double x1 = scaledXCenter - scaledW / 2;
        final double y1 = scaledYCenter - scaledH / 2;
        
        final String label = maxClassId < _labels.length 
            ? _labels[maxClassId] 
            : 'unknown';
        
        debugPrint(
            'Detection #${detections.length}: $label (class $maxClassId) conf: ${maxConfidence.toStringAsFixed(3)} at (${x1.toStringAsFixed(1)}, ${y1.toStringAsFixed(1)}, ${scaledW.toStringAsFixed(1)}, ${scaledH.toStringAsFixed(1)})');
        
        detections.add(BoundingBox(
            x1, y1, scaledW, scaledH, maxConfidence, label));
      }
    }

    debugPrint("Total detections above threshold: ${detections.length}");

    if (detections.isEmpty) {
      debugPrint("No detections found above confidence threshold");
      return null;
    }

    // Return the detection with highest confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestBox = detections.first;
    
    debugPrint(
        '✅ Best detection: ${bestBox.label} with confidence: ${bestBox.confidence.toStringAsFixed(3)}');
    debugPrint(
        '✅ Box in original image: (${bestBox.x.toStringAsFixed(1)}, ${bestBox.y.toStringAsFixed(1)}) ${bestBox.width.toStringAsFixed(1)}x${bestBox.height.toStringAsFixed(1)}');
    
    return bestBox;
  }

  // 2. Crops the image using the detected box
  Future<String?> cropImage(String imagePath, BoundingBox box) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint("ERROR: Failed to decode original image");
      return null;
    }

    debugPrint("Original image size: ${originalImage.width}x${originalImage.height}");
    debugPrint("Bounding box: x=${box.x}, y=${box.y}, w=${box.width}, h=${box.height}");

    // Ensure coordinates are within image bounds
    int x = box.x.clamp(0, originalImage.width - 1).toInt();
    int y = box.y.clamp(0, originalImage.height - 1).toInt();
    int width = box.width.clamp(1, originalImage.width - x).toInt();
    int height = box.height.clamp(1, originalImage.height - y).toInt();

    // ML Kit requires minimum 32x32 pixels
    const int minSize = 32;
    if (width < minSize || height < minSize) {
      debugPrint("❌ ERROR: Cropped region too small! Size: ${width}x$height (minimum: ${minSize}x$minSize)");
      debugPrint("This usually means the model detected something incorrectly.");
      return null;
    }

    debugPrint("Cropping at ($x, $y) with size ${width}x$height");

    try {
      // Crop the image using the bounding box
      final croppedImage = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      debugPrint("✅ Cropped image size: ${croppedImage.width}x${croppedImage.height}");

      // Save the cropped image to a temporary file
      final tempDir = await Directory.systemTemp.createTemp('mykad_app');
      final tempFile = File('${tempDir.path}/cropped_ic.png');
      await tempFile.writeAsBytes(img.encodePng(croppedImage));

      debugPrint("✅ Cropped image saved to: ${tempFile.path}");
      return tempFile.path;
    } catch (e) {
      debugPrint("❌ ERROR during cropping: $e");
      return null;
    }
  }

  void dispose() {
    _interpreter.close();
  }
}
