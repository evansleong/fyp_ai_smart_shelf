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

    // --- 1. Letterbox Resize (Maintain Aspect Ratio) ---
    // Create a black square canvas
    final img.Image inputImage =
        img.Image(width: _inputSize, height: _inputSize);
    img.fill(inputImage, color: img.ColorRgb8(0, 0, 0)); // Fill with black

    // Calculate scale to fit longest side
    double scale = _inputSize /
        (originalWidth > originalHeight ? originalWidth : originalHeight);
    int newWidth = (originalWidth * scale).round();
    int newHeight = (originalHeight * scale).round();

    // Resize original image
    final img.Image resizedPart = img.copyResize(
      originalImage,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Paste resized image into center of canvas
    int offsetX = (_inputSize - newWidth) ~/ 2;
    int offsetY = (_inputSize - newHeight) ~/ 2;

    img.compositeImage(inputImage, resizedPart, dstX: offsetX, dstY: offsetY);

    debugPrint(
        "Letterboxed image created. Scale: $scale, Offset: ($offsetX, $offsetY)");

    // --- 2. Preprocess Input ---
    // Convert to 4D list [1, 640, 640, 3], normalize 0-255 to 0.0-1.0
    var input = List.generate(
        1,
        (i) => List.generate(
            _inputSize,
            (j) => List.generate(_inputSize, (k) {
                  final pixel = inputImage.getPixel(k, j);
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

    debugPrint(
        "Detected format: ${isTransposed ? 'TRANSPOSED [1, $numProperties, $numBoxes]' : 'NORMAL [1, $numBoxes, $numProperties]'}");

    // Initialize output buffer
    var output = List.generate(
        1, (i) => List.generate(dim1, (j) => List.filled(dim2, 0.0)));

    try {
      _interpreter.run(input, output);
      debugPrint("Inference completed successfully");
    } catch (e) {
      debugPrint("Error running YOLO inference: $e");
      return null;
    }

    // --- 3. Parse Output with Correct Confidence ---
    List<BoundingBox> detections = [];
    final double confidenceThreshold =
        0.70; // Lowered to 70% based on user feedback

    double globalMaxConfidence = 0.0;
    String globalMaxLabel = "none";

    for (int i = 0; i < numBoxes; i++) {
      // Get the correct box data based on format
      List<double> box;
      if (isTransposed) {
        // Format: [1, numProperties, numBoxes] - need to extract column i
        box = List.generate(numProperties, (p) => output[0][p][i]);
      } else {
        // Format: [1, numBoxes, numProperties]
        box = output[0][i];
      }

      // YOLO Output Format:
      // [x_center, y_center, width, height, objectness, class0_score, class1_score...]
      // OR for YOLOv8 (no objectness):
      // [x_center, y_center, width, height, class0_score, class1_score...]

      final double xCenter = box[0];
      final double yCenter = box[1];
      final double w = box[2];
      final double h = box[3];

      double confidence = 0.0;
      int maxClassId = 0;

      // Determine if we have objectness score
      // If properties > classes + 4, then index 4 is likely objectness
      bool hasObjectness = numProperties > (_labels.length + 4);

      if (hasObjectness) {
        // YOLOv5 style: box[4] is objectness
        double objectness = box[4];

        // Find best class score
        double maxClassScore = 0.0;
        for (int c = 0; c < _labels.length; c++) {
          // Class scores start at index 5
          if (5 + c < box.length) {
            double score = box[5 + c];
            if (score > maxClassScore) {
              maxClassScore = score;
              maxClassId = c;
            }
          }
        }

        // Final confidence is objectness * class_score
        confidence = objectness * maxClassScore;
      } else {
        // YOLOv8 style: no objectness, classes start at index 4
        double maxClassScore = 0.0;
        for (int c = 0; c < _labels.length; c++) {
          if (4 + c < box.length) {
            double score = box[4 + c];
            if (score > maxClassScore) {
              maxClassScore = score;
              maxClassId = c;
            }
          }
        }
        confidence = maxClassScore;
      }

      // Track global max confidence for debugging
      if (confidence > globalMaxConfidence) {
        globalMaxConfidence = confidence;
        globalMaxLabel =
            maxClassId < _labels.length ? _labels[maxClassId] : 'unknown';
      }

      // Only process detections above threshold
      if (confidence > confidenceThreshold) {
        // Convert from normalized [0-1] to letterboxed coordinates [0-640]
        double lbX = xCenter * _inputSize;
        double lbY = yCenter * _inputSize;
        double lbW = w * _inputSize;
        double lbH = h * _inputSize;

        // Remove letterbox padding to get coordinates relative to resized image
        double rX = lbX - offsetX;
        double rY = lbY - offsetY;

        // Scale back to original image size
        // rX / scale = originalX
        double finalX = rX / scale;
        double finalY = rY / scale;
        double finalW = lbW / scale;
        double finalH = lbH / scale;

        // Convert from center format to corner format (top-left x, y)
        final double x1 = finalX - finalW / 2;
        final double y1 = finalY - finalH / 2;

        final String label =
            maxClassId < _labels.length ? _labels[maxClassId] : 'unknown';

        debugPrint(
            'Detection: $label ($maxClassId) | Conf: ${confidence.toStringAsFixed(3)} | Obj: ${hasObjectness ? box[4].toStringAsFixed(3) : "N/A"} | ClassScore: ${hasObjectness ? (confidence / box[4]).toStringAsFixed(3) : confidence.toStringAsFixed(3)} | Box: $x1, $y1, $finalW, $finalH');

        detections.add(BoundingBox(x1, y1, finalW, finalH, confidence, label));
      }
    }

    debugPrint("Total detections above threshold: ${detections.length}");

    if (detections.isEmpty) {
      debugPrint(
          "No detections found above confidence threshold ($confidenceThreshold)");
      debugPrint(
          "Max confidence found: ${(globalMaxConfidence * 100).toStringAsFixed(2)}% (Label: $globalMaxLabel)");
      return null;
    }

    // Return the detection with highest confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestBox = detections.first;

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

    debugPrint(
        "Original image size: ${originalImage.width}x${originalImage.height}");
    debugPrint(
        "Bounding box: x=${box.x}, y=${box.y}, w=${box.width}, h=${box.height}");

    // Ensure coordinates are within image bounds
    int x = box.x.clamp(0, originalImage.width - 1).toInt();
    int y = box.y.clamp(0, originalImage.height - 1).toInt();
    int width = box.width.clamp(1, originalImage.width - x).toInt();
    int height = box.height.clamp(1, originalImage.height - y).toInt();

    // ML Kit requires minimum 32x32 pixels
    const int minSize = 32;
    if (width < minSize || height < minSize) {
      debugPrint(
          "❌ ERROR: Cropped region too small! Size: ${width}x$height (minimum: ${minSize}x$minSize)");
      debugPrint(
          "This usually means the model detected something incorrectly.");
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

      debugPrint(
          "✅ Cropped image size: ${croppedImage.width}x${croppedImage.height}");

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
