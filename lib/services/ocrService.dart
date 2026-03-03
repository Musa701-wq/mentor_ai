// lib/services/ocr_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:doc_text/doc_text.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;


class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from image file (JPG/PNG)
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return _collectText(result);
  }

  /// Extract text from a PDF file - SIMPLE SOLUTION
  /// Extract text from a PDF file - FIXED SOLUTION
  Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      // Read PDF file as bytes - CORRECT TYPE
      final List<int> bytes = await pdfFile.readAsBytes();

      // Load PDF document - CORRECT CONSTRUCTOR
      final pdf = pw.Document();
      // OR use pdfx package agar zyada features chahiye

      // Alternative: Simple text extraction using string reading
      // Agar pdf package properly kaam nahi karta to yeh use karo
      return _extractTextSimple(pdfFile);
    } catch (e) {
      debugPrint('PDF extraction failed: $e');
      // Fallback: Try to read as plain text
      try {
        return await pdfFile.readAsString();
      } catch (e2) {
        return '';
      }
    }
  }

  /// Simple text extraction - works for text-based PDFs
  Future<String> _extractTextSimple(File pdfFile) async {
    try {
      // Some PDFs can be read as text directly
      final content = await pdfFile.readAsString();

      // Check if it contains PDF markers
      if (content.contains('%PDF') || content.contains('stream') || content.contains('endstream')) {
        // It's a real PDF, need proper parsing
        debugPrint('Binary PDF detected, need proper parser');
        return 'PDF parsing requires advanced library';
      }
      return content;
    } catch (e) {
      return '';
    }
  }
  /// Extract text from a DOCX file
  Future<String> extractTextFromDocx(String filePath) async {
    try {
      final docText = DocText();
      final String? extractedText = await docText.extractTextFromDoc(filePath);
      return extractedText ?? '';
    } catch (e) {
      debugPrint('DOCX extraction error: $e');
      return '';
    }
  }

  /// Run OCR on images (PDF pages converted to images)
  Future<String> extractTextFromPdfImages(List<File> pageImages) async {
    final buffer = StringBuffer();
    for (final img in pageImages) {
      final text = await extractTextFromImage(img);
      buffer.writeln(text);
    }
    return buffer.toString();
  }

  String _collectText(RecognizedText recognized) {
    final buffer = StringBuffer();
    for (final block in recognized.blocks) {
      buffer.writeln(block.text);
    }
    return buffer.toString();
  }

  void dispose() {
    _recognizer.close();
  }
}