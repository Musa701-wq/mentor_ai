import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/geminiService.dart';
import '../services/ocrService.dart';
import '../services/creditService.dart';
import '../services/Firestore_service.dart';

class SyllabusProvider with ChangeNotifier {
  final OcrService _ocrService = OcrService();
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  int get lastTokens => _geminiService.lastEstimatedTokens;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _status = '';
  String get status => _status;

  Map<String, dynamic>? _roadmap;
  Map<String, dynamic>? get roadmap => _roadmap;

  // 🔹 Track completion of milestones
  final Set<String> _completedMilestones = {};
  Set<String> get completedMilestones => _completedMilestones;

  bool isMilestoneCompleted(String syllabusId, int index) {
    return _completedMilestones.contains("${syllabusId}_$index");
  }

  void toggleMilestoneCompletion(String syllabusId, int index) {
    final key = "${syllabusId}_$index";
    if (_completedMilestones.contains(key)) {
      _completedMilestones.remove(key);
    } else {
      _completedMilestones.add(key);
    }
    notifyListeners();
  }

  // 🔹 For saved roadmaps
  final List<Map<String, dynamic>> _syllabuses = [];
  final List<Map<String, dynamic>> _filteredSyllabuses = [];
  List<Map<String, dynamic>> get syllabuses => _filteredSyllabuses;

  bool loadingList = false;
  bool loadingMore = false;
  bool hasMore = true;
  DocumentSnapshot? lastDoc;

  Future<void> processSyllabus(File file, BuildContext context) async {
    _isLoading = true;
    _status = 'Reading syllabus...';
    _roadmap = null;
    notifyListeners();

    try {
      // 1. Proactive Credit Deduction (Handled in UI via confirmAndDeductCredits)
      // We keep a safety check here but it should already be done.
      // Finalizing the security: The UI calls confirmAndDeductCredits.
      // To avoid double charging, we stop internal deduction if the UI handles it, 
      // but for robustness we previously had it here. 
      // I will remove it from here to avoid double charging.

      // 2. Extract Text
      final text = await _ocrService.extractTextFromSyllabus(file);
      if (text.isEmpty) {
        throw Exception('Could not extract text from the file.');
      }

      // 3. Generate Roadmap
      _status = 'AI is building your roadmap... This may take a moment.';
      notifyListeners();
      
      final result = await _geminiService.breakdownSyllabus(text);
      
      _status = 'Saving your roadmap...';
      notifyListeners();
      
      _roadmap = result;

      // 4. Auto save the result
      _autoSave(text);

    } catch (e) {
      _status = 'Error: $e';
      debugPrint('❌ Syllabus process error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _autoSave(String extractedText) {
    if (_roadmap == null) return;
    
    String defaultTitle = "Syllabus Breakdown";
    if (extractedText.trim().isNotEmpty) {
      final cleanText = extractedText.trim().replaceAll("\n", " ");
      defaultTitle = cleanText.length > 40 
          ? "${cleanText.substring(0, 40)}..." 
          : cleanText;
    }

    saveSyllabus(defaultTitle);
  }

  Future<String?> saveSyllabus(String title) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "User not logged in.";
    if (_roadmap == null) return "No roadmap to save.";

    try {
      await _firestoreService.addSyllabus(uid, {
        "title": title,
        "roadmap": _roadmap,
        "timestamp": DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      debugPrint('❌ Error saving syllabus: $e');
      return e.toString();
    }
  }

  // ========== Fetch Saved Syllabuses ==========
  Future<void> fetchSyllabuses({bool reset = false, String searchQuery = ""}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (reset) {
      _syllabuses.clear();
      _filteredSyllabuses.clear();
      lastDoc = null;
      hasMore = true;
      loadingList = true;
      notifyListeners();
    } else {
      loadingMore = true;
      notifyListeners();
    }

    try {
      final docs = await _firestoreService.fetchSyllabusesPaginated(
        uid,
        limit: 10,
        startAfterDoc: lastDoc,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      );

      if (docs.isEmpty) {
        hasMore = false;
      } else {
        _syllabuses.addAll(docs);
        lastDoc = docs.last["snapshot"] as DocumentSnapshot?;
      }

      // 🔍 Apply title filter locally
      if (searchQuery.isNotEmpty) {
        _filteredSyllabuses
          ..clear()
          ..addAll(_syllabuses.where((hw) {
            final title = (hw["title"] ?? "").toString().toLowerCase();
            return title.contains(searchQuery.toLowerCase());
          }));
      } else {
        _filteredSyllabuses
          ..clear()
          ..addAll(_syllabuses);
      }
    } catch (e) {
      debugPrint("❌ Error fetching syllabuses: $e");
    } finally {
      loadingList = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  void reset() {
    _roadmap = null;
    _status = '';
    _isLoading = false;
    notifyListeners();
  }
}
