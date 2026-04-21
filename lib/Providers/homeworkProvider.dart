// lib/providers/homework_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/Firestore_service.dart';
import '../services/geminiService.dart';
import '../services/ocrService.dart';

class HomeworkProvider extends ChangeNotifier {
  final OcrService _ocrService = OcrService();
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  String? extractedText;
  String? steps;
  bool loading = false;

  // 🔹 For saved homeworks
  List<Map<String, dynamic>> _homeworks = [];
  List<Map<String, dynamic>> get homeworks => _filteredHomeworks;
  final List<Map<String, dynamic>> _filteredHomeworks = [];

  bool loadingList = false;
  bool loadingMore = false;
  bool hasMore = true;
  DocumentSnapshot? lastDoc;
  String? _searchQuery;

  // ========== AI Homework Solving ==========
  Future<String?> extractAndSolveFromImage(File image) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromImage(image);
      steps = await _geminiService.chat(
        "Solve this homework question from the extracted text:\n$extractedText",
      );
      
      // 🚀 Auto-save in background
      _autoSave();
      
      return null; // Success
    } catch (e) {
      debugPrint('❌ Homework solving error: $e');
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> extractAndSolveFromPdf(File pdf) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromPdf(pdf);
      steps = await _geminiService.chat(
        "Solve this homework question from the extracted PDF text:\n$extractedText",
      );
      
      // 🚀 Auto-save in background
      _autoSave();
      
      return null;
    } catch (e) {
      debugPrint('❌ Homework solving error: $e');
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> extractAndSolveFromDocx(String filePath) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromDocx(filePath);
      steps = await _geminiService.chat(
        "Solve this homework question from the extracted document text:\n$extractedText",
      );
      
      // 🚀 Auto-save in background
      _autoSave();
      
      return null;
    } catch (e) {
      debugPrint('❌ Homework solving error: $e');
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> solveFromText(String text) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = text;
      steps = await _geminiService.chat(
        "Solve this homework question:\n$text",
      );

      // 🚀 Auto-save in background
      _autoSave();

      return null;
    } catch (e) {
      debugPrint('❌ Homework solving error: $e');
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Background auto-save logic
  void _autoSave() {
    if (steps == null) return;
    
    // Generate a default title from extracted text
    String defaultTitle = "AI Solution";
    if (extractedText != null && extractedText!.trim().isNotEmpty) {
      final cleanText = extractedText!.trim().replaceAll("\n", " ");
      defaultTitle = cleanText.length > 40 
          ? "${cleanText.substring(0, 40)}..." 
          : cleanText;
    }

    saveHomework(defaultTitle);
  }

  Future<String?> saveHomework(String title) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "User not logged in.";
    if (steps == null) return "No solution to save.";

    try {
      await _firestoreService.addHomework(uid, {
        "title": title,
        "content": steps,
        "timestamp": DateTime.now().toIso8601String(),
      });
      return null; // Success
    } catch (e) {
      debugPrint('❌ Error saving homework: $e');
      return e.toString();
    }
  }

  // ========== Fetch Saved Homeworks ==========
  Future<void> fetchHomeworks({bool reset = false, String searchQuery = ""}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (reset) {
      _homeworks.clear();
      _filteredHomeworks.clear();
      lastDoc = null;
      hasMore = true;
      loadingList = true;
      notifyListeners();
    } else {
      loadingMore = true;
      notifyListeners();
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("homeworks")
          .orderBy("timestamp", descending: true)
          .limit(10);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        hasMore = false;
      } else {
        final newHomeworks = snapshot.docs
            .map((doc) => {...doc.data() as Map<String, dynamic>, "id": doc.id})
            .toList();
        _homeworks.addAll(newHomeworks);
        lastDoc = snapshot.docs.last;
      }

      // 🔍 Apply title filter locally
      if (searchQuery.isNotEmpty) {
        _filteredHomeworks
          ..clear()
          ..addAll(_homeworks.where((hw) {
            final title = (hw["title"] ?? "").toString().toLowerCase();
            return title.contains(searchQuery.toLowerCase());
          }));
      } else {
        _filteredHomeworks
          ..clear()
          ..addAll(_homeworks);
      }
    } catch (e) {
      debugPrint("❌ Error fetching homeworks: $e");
    } finally {
      loadingList = false;
      loadingMore = false;
      notifyListeners();
    }
  }
}
