// lib/providers/add_note_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/notesModel.dart';
import '../services/Firestore_service.dart';
import '../services/geminiService.dart';
import '../services/ocrService.dart';
import '../services/creditService.dart';


enum AddNoteState { idle, picking, ocrProcessing, confirming, saving, done, error }

class AddNoteProvider with ChangeNotifier {
  String title = '';
  String content = '';
  String? summary;
  List<File> files = [];
  AddNoteState state = AddNoteState.idle;
  String? errorMessage;
  List<String> tags = [];
  bool _summaryEnabled = false;

  bool get summaryEnabled => _summaryEnabled;



  final OcrService ocrService;
  final FirestoreService firestoreService;
  final GeminiService geminiService;

  AddNoteProvider({
    required this.ocrService,
    required this.firestoreService,
    required this.geminiService,
  });

  final _creditsService = CreditsService();




  void addTag(String tag) {
    if (tag.trim().isEmpty) return;
    if (tags.length >= 5) return; // max 5 tags
    if (!tags.contains(tag.trim())) {
      tags.add(tag.trim());
      notifyListeners();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    notifyListeners();
  }

  void setTitle(String t) {
    title = t;
    notifyListeners();
  }

  void setContent(String c) {
    content = c;
    notifyListeners();
  }

  void addFile(File file) {
    files.add(file);
    notifyListeners();
  }

  void clearFiles() {
    files.clear();
    notifyListeners();
  }

  void setState(AddNoteState s) {
    state = s;
    notifyListeners();
  }

  void setError(String msg) {
    errorMessage = msg;
    state = AddNoteState.error;
    notifyListeners();
  }

  Future<void> runOcrOnFiles() async {
    try {
      setState(AddNoteState.ocrProcessing);
      final buffer = StringBuffer();

      for (final file in files) {
        final ext = file.path.split('.').last.toLowerCase();

        if (['jpg', 'jpeg', 'png'].contains(ext)) {
          final text = await ocrService.extractTextFromImage(file);
          buffer.writeln(text);
        } else if (ext == 'pdf') {
          // Use PDF extraction only, don't try to display as image
          final text = await ocrService.extractTextFromPdf(file);
          buffer.writeln(text);
        } else if (ext == 'docx') {
          final text = await ocrService.extractTextFromDocx(file.path);
          buffer.writeln(text);
        } else {
          buffer.writeln('[Unsupported file type: $ext]');
        }
      }


      content = buffer.toString();
      setState(AddNoteState.confirming);
    } catch (e) {
      setError('Text extraction failed: $e');
    }
  }



  /// Optionally ask AI to summarize content
  Future<void> generateAiSummary() async {
    if (content.trim().isEmpty) return;
    try {
      setState(AddNoteState.ocrProcessing);
      final s = await geminiService.summarize(content);
      summary = s;
      // Dynamic credit deduction based on token usage
      final tokens = geminiService.lastEstimatedTokens;
      final cost = CreditsService.calcCreditsFromTokens(tokens);
      await _creditsService.deductCredits(cost);
      debugPrint('💳 Summary: deducted $cost credits ($tokens tokens)');
      setState(AddNoteState.confirming);
    } catch (e) {
      print(e);
      setError('AI summary failed: $e');
    }
  }

  /// Save to Firestore (and return the created id)
  Future<String> saveNoteToFirestore(String uid) async {
    try {
      setState(AddNoteState.saving);
      final id = const Uuid().v4();
      final note = NoteModel(
        id: id,
        uid: uid,
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
        summary: summary,
        tags: tags,
      );
      await firestoreService.saveNote(note);
      setState(AddNoteState.done);
      return id;
    } catch (e) {
      setError('Save failed: $e');
      rethrow;
    }
  }

  // Add this method to your AddNoteProvider class
  void removeFile(File file) {
    files.remove(file);
    notifyListeners();
  }


}
