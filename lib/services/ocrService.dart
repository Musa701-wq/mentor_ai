// lib/services/ocr_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:doc_text/doc_text.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from image file (JPG/PNG)
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return _collectText(result);
  }

  /// Extract text from a PDF file using syncfusion_flutter_pdf and OCR
  Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      final List<int> bytes = await pdfFile.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();

      // 1. Extract standard text layer
      final String textLayer = PdfTextExtractor(document).extractText();
      buffer.writeln(textLayer);

      document.dispose();
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('PDF extraction failed: $e');
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

  /// Unified method for Syllabus text extraction
  Future<String> extractTextFromSyllabus(File file) async {
    final path = file.path.toLowerCase();
    if (path.endsWith('.pdf')) {
      final text = await extractTextFromPdf(file);
      return text;
    } else if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
      return await extractTextFromImage(file);
    }
    return '';
  }
}