// lib/services/ocr_service.dart
import 'dart:io';
import 'package:doc_text/doc_text.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_text/pdf_text.dart';   // for PDF

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from image file (JPG/PNG)
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return _collectText(result);
  }

  /// Extract text from a PDF file
  Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      final pdfDoc = await PDFDoc.fromFile(pdfFile);
      final text = await pdfDoc.text;
      return text;
    } catch (e) {
      debugPrint('PDF extraction failed: $e');
      return '';
    }
  }

  /// Extract text from a DOCX file
  Future<String> extractTextFromDocx(String filePath) async {
    try {
      // Create an instance of DocText
      final docText = DocText();

      // Call the instance method
      final String? extractedText = await docText.extractTextFromDoc(filePath);

      if (extractedText != null) {
        print('Extracted Text: $extractedText');
        return extractedText;
      } else {
        print('Failed to extract text.');
        return '';
      }
    } catch (e) {
      print('Error extracting text: $e');
      return'';
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
