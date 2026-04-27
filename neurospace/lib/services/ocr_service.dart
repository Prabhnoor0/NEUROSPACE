/// NeuroSpace — OCR Service
/// Provides on-device text extraction from images using Google ML Kit.
/// Falls back to backend Groq Vision OCR for complex images.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from an image file using on-device ML Kit OCR.
  /// This runs entirely on-device — no network call needed.
  /// Returns the recognized text as a single string.
  static Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer.processImage(inputImage);

      if (recognized.text.isEmpty) {
        debugPrint('OCR: No text found in image');
        return '';
      }

      debugPrint('OCR: Extracted ${recognized.text.length} chars from image');

      // Build structured text preserving blocks and lines
      final buffer = StringBuffer();
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln(); // blank line between blocks
      }

      return buffer.toString().trim();
    } catch (e) {
      debugPrint('OCR error: $e');
      return '';
    }
  }

  /// Extract text with position data (useful for future overlay features).
  /// Returns a list of maps with text, bounding box, and confidence.
  static Future<List<Map<String, dynamic>>> extractTextWithPositions(
      String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer.processImage(inputImage);

      final results = <Map<String, dynamic>>[];

      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          results.add({
            'text': line.text,
            'boundingBox': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'width': line.boundingBox.width,
              'height': line.boundingBox.height,
            },
            'language': block.recognizedLanguages.isNotEmpty
                ? block.recognizedLanguages.first
                : 'en',
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('OCR positions error: $e');
      return [];
    }
  }

  /// Clean up resources when the service is no longer needed
  static void dispose() {
    _textRecognizer.close();
  }
}
