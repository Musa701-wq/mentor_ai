// lib/providers/quiz_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quizModel.dart';
import '../services/creditService.dart';
import '../services/geminiService.dart';

class QuizQuestion {
  String question;
  List<String> options;
  String correctAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}

class QuizProvider with ChangeNotifier {
  final GeminiService geminiService;
  final _creditsService = CreditsService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  QuizProvider({required this.geminiService});

  // ---------------- Quiz Creation ----------------
  List<QuizQuestion> _questions = [];
  bool _isLoading = false;
  bool _isSubmitted = false;
  Map<int, String> _selectedAnswers = {};
  String _quizTitle = "";

  // --- Getters ---
  List<QuizQuestion> get questions => _questions;
  bool get isLoading => _isLoading;
  bool get isSubmitted => _isSubmitted;
  Map<int, String> get selectedAnswers => _selectedAnswers;
  String get quizTitle => _quizTitle;

  // --- Setters ---
  void setQuizTitle(String title) {
    _quizTitle = title;
    notifyListeners();
  }

  // --- AI Generated Quiz ---
  Future<void> generateFromNotes(String notes, {String title = ""}) async {
    _isLoading = true;
    _isSubmitted = false;
    _selectedAnswers.clear();
    _quizTitle = title;
    notifyListeners();

    try {
      final data = await geminiService.generateQuizFromNotes(notes);
      _questions = data.map((q) {
        final options =
        (q["options"] as List).map((o) => o["text"] as String).toList();
        final correct = (q["options"] as List)
            .firstWhere((o) => o["correct"] == true,
            orElse: () => {"text": ""})["text"];

        return QuizQuestion(
          question: q["question"],
          options: options,
          correctAnswer: correct,
        );
      }).toList();

      // ─── Dynamic credit deduction based on token usage ───────────────
      // Temporarily bypassed for testing
      // final tokens = geminiService.lastEstimatedTokens;
      // final cost = CreditsService.calcCreditsFromTokens(tokens);
      // await _creditsService.deductCredits(cost);
      // debugPrint('💳 Quiz: deducted $cost credits ($tokens tokens)');

    } catch (e) {
      _questions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Manual Quiz ---
  void addLocalQuestion(String question, List<String> options,
      {required int correctOption}) {
    _questions.add(
      QuizQuestion(
        question: question,
        options: options,
        correctAnswer: options[correctOption],
      ),
    );
    notifyListeners();
  }

  // --- Select Answer ---
  void selectAnswer(int index, String answer) {
    _selectedAnswers[index] = answer;
    notifyListeners();
  }

  // --- Submit Quiz Attempt ---
  Future<Map<String, dynamic>> submitQuiz(String userId, String quizId) async {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswer) {
        score++;
      }
    }

    final answersAsList = List.generate(
      _questions.length,
          (i) => _selectedAnswers[i] ?? "",
    );

    final attemptRef = await firestore.collection("quizAttempts").add({
      "userId": userId,
      "quizId": quizId,
      "questions": _questions
          .map((q) => {
        "question": q.question,
        "options": q.options,
        "correctAnswer": q.correctAnswer,
      })
          .toList(),
      "answers": answersAsList,
      "score": score,
      "createdAt": DateTime.now(),
    });

    _isSubmitted = true;
    notifyListeners();
    return {
      "attemptId": attemptRef.id,
      "score": score,
    };
  }

  // --- Save Quiz to Firestore ---
  Future<void> saveQuizToDb(String userId,
      {bool isAiGenerated = false}) async {
    if (_questions.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final quizRef = await firestore.collection("quizzes").add({
        "userId": userId,
        "title": _quizTitle,
        "totalQuestions": _questions.length,
        "createdAt": DateTime.now(),
        "source": isAiGenerated ? "ai" : "manual",
        "withShared": [], // ✅ initialize empty
      });

      final batch = firestore.batch();
      for (var q in _questions) {
        final docRef = quizRef.collection("questions").doc();
        batch.set(docRef, {
          "question": q.question,
          "options": q.options,
          "correctAnswer": q.correctAnswer,
        });
      }
      await batch.commit();

      _questions.clear();
      _quizTitle = "";
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetQuiz() {
    _selectedAnswers.clear();
    _isSubmitted = false;
    _quizTitle = "";
    notifyListeners();
  }

  // ---------------- My Quizzes ----------------
  List<QuizModel> quizzes = [];
  bool isLoadingMy = false;
  bool hasMoreMy = true;
  DocumentSnapshot? lastMyDoc;

  // ---------------- Shared Quizzes ----------------
  List<QuizModel> sharedQuizzes = [];
  bool isLoadingShared = false;
  bool hasMoreShared = true;
  DocumentSnapshot? lastSharedDoc;

  // ---------------- Search Users ----------------
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final searchTerm = query.trim().toLowerCase();
    if (searchTerm.isEmpty) {
      debugPrint("[searchUsers] Query is empty → returning []");
      return [];
    }

    debugPrint("[searchUsers] Searching for: '$searchTerm'");

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('keywords', arrayContains: searchTerm)
          .limit(20)
          .get();

      debugPrint("[searchUsers] Firestore returned ${snap.docs.length} docs");

      final users = snap.docs.map((doc) {
        final data = doc.data();
        debugPrint(
            "[searchUsers] Candidate: ${data['name']} (${data['email']}) uid=${data['uid']}");
        if (data['uid'] == uid) {
          debugPrint("[searchUsers] Skipping self: ${data['uid']}");
          return null;
        }
        return {
          'uid': data['uid'] ?? doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'profilePic': data['profilePic'] ?? '',
        };
      }).whereType<Map<String, dynamic>>().toList();

      debugPrint("[searchUsers] Final filtered users = ${users.length}");
      return users;
    } catch (e) {
      debugPrint("[searchUsers] Error: $e");
      return [];
    }
  }

  // ---------------- Share Quizzes ----------------
  // ---------------- Share Quizzes ----------------
  Future<(List<String>, List<String>)> shareQuizWithUsers({
    required QuizModel quiz,
    required List<String> targetUids,
  }) async {
    final docRef = firestore.collection("quizzes").doc(quiz.id);

    final current = quiz.withShared.toSet();
    final toAdd = targetUids.where((u) => !current.contains(u)).toList();
    final already = targetUids.where((u) => current.contains(u)).toList();

    if (toAdd.isNotEmpty) {
      await docRef.update({
        'withShared': FieldValue.arrayUnion(toAdd),
      });

      // Update locally stored quizzes list if quiz exists there
      final idx = quizzes.indexWhere((q) => q.id == quiz.id);
      if (idx != -1) {
        quizzes[idx] = quizzes[idx]
            .copyWith(withShared: [...quizzes[idx].withShared, ...toAdd]);
        notifyListeners();
      }

      // Also update in sharedQuizzes if present
      final sIdx = sharedQuizzes.indexWhere((q) => q.id == quiz.id);
      if (sIdx != -1) {
        sharedQuizzes[sIdx] = sharedQuizzes[sIdx]
            .copyWith(withShared: [...sharedQuizzes[sIdx].withShared, ...toAdd]);
        notifyListeners();
      }
    }

    return (toAdd, already);
  }


  // ---------------- Load Shared Quizzes ----------------
  Future<void> loadSharedQuizzes({
    bool reset = false,
    String query = '',
  }) async {
    if (isLoadingShared) return;
    isLoadingShared = true;
    notifyListeners();

    if (reset) {
      sharedQuizzes.clear();
      lastSharedDoc = null;
      hasMoreShared = true;
    }

    try {
      // 🚀 SIMPLIFIED QUERY: Remove orderBy to avoid missing index errors during initial load
      Query baseQuery = firestore
          .collection("quizzes")
          .where('withShared', arrayContains: uid)
          .limit(10);

      if (lastSharedDoc != null) {
        baseQuery = baseQuery.startAfterDocument(lastSharedDoc!);
      }

      final snap = await baseQuery.get();
      debugPrint("📥 loadSharedQuizzes: found ${snap.docs.length} docs");

      if (snap.docs.length < 10) hasMoreShared = false;
      if (snap.docs.isNotEmpty) lastSharedDoc = snap.docs.last;

      List<QuizModel> fetched = [];
      for (final d in snap.docs) {
        try {
          final data = d.data() as Map<String, dynamic>;
          data['id'] = d.id;

          // get sharer details with safety check
          final sharerId = data['userId'];
          if (sharerId != null && sharerId is String && sharerId.isNotEmpty) {
            final userDoc = await firestore.collection('users').doc(sharerId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              data['ownerName'] = userData['name'] ?? 'Unknown User';
              data['ownerEmail'] = userData['email'] ?? '';
            }
          }

          fetched.add(QuizModel.fromMap(data));
        } catch (e) {
          debugPrint("⚠️ Error parsing individual quiz document ${d.id}: $e");
          // Continue with next documents instead of failing entire list
        }
      }

      // Sort locally if needed since we removed firestore orderBy
      fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (query.isNotEmpty) {
        fetched = fetched.where((q) {
          return q.title.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }

      sharedQuizzes.addAll(fetched);
      debugPrint("✅ loadSharedQuizzes: added ${fetched.length} quizzes");
    } catch (e, st) {
      print("❌ loadSharedQuizzes error: $e");
      print(st);
      rethrow; // so FutureBuilder sees the error
    } finally {
      isLoadingShared = false;
      notifyListeners();
    }
  }


}
