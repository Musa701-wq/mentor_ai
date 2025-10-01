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
  Future<void> extractAndSolveFromImage(File image) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromImage(image);
      steps = await _geminiService.chat(
        "Provide step-by-step guidance to solve this homework, do NOT provide the final solution, "
            "Also provide Detailed Guide assume your self as a tutor:\n$extractedText",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> extractAndSolveFromPdf(File pdf) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromPdf(pdf);
      steps = await _geminiService.chat(
        "Provide step-by-step guidance to solve this homework, do NOT provide the final solution, "
            "Also provide Detailed Guide assume your self as a tutor:\n$extractedText",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> extractAndSolveFromDocx(String filePath) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = await _ocrService.extractTextFromDocx(filePath);
      steps = await _geminiService.chat(
        "Provide step-by-step guidance to solve this homework, do NOT provide the final solution, "
            "Also provide Detailed Guide assume your self as a tutor:\n$extractedText",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> solveFromText(String text) async {
    loading = true;
    notifyListeners();
    try {
      extractedText = text;
      steps = await _geminiService.chat(
        "Provide step-by-step guidance to solve this homework, do NOT provide the final solution, "
            "Also provide Detailed Guide assume your self as a tutor:\n$text",
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveHomework(String title) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || steps == null) return;

    await _firestoreService.addHomework(uid, {
      "title": title,
      "content": steps,
      "timestamp": DateTime.now().toIso8601String(),
    });
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
