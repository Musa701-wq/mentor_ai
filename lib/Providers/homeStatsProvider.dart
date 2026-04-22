import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/notesModel.dart';

class HomeStatsProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Counts
  int totalPlans = 0;
  int completedPlans = 0;
  int totalQuizzes = 0;
  double avgQuizScore = 0.0;
  int get incompletePlans => totalPlans - completedPlans;

  Map<String, dynamic> sharedQuizStats = {};

  int totalHomeworks = 0;
  int totalNotes = 0;

  List<double> recentQuizScores = [];
  Map<String, double> topicAccuracy = {};
  List<String> weakTopics = [];

  int streakCount = 0; // 🔥 daily streak
  DateTime? lastOpenedDate;

  // Latest activity
  DateTime? latestExamDate;
  String? latestNoteTitle;

  // Recommended Notes
  List<NoteModel> recommendedNotes = [];

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool get loading => _isLoading;

  Future<void> loadDashboard() async {
    if (_uid == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      await fetchStats();
      await fetchRecommendedNotes();
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStats() async {
    if (_uid == null) return;

    try {
      // Study Plans
      final plansSnap = await _db
          .collection('users')
          .doc(_uid)
          .collection('studyPlans')
          .get();

      totalPlans = plansSnap.docs.length;
      completedPlans = plansSnap.docs.where((doc) {
        final data = doc.data();
        return (data['status'] == 'completed') || (data['progress'] == 1.0);
      }).length;

      // Latest Exam Date
      if (plansSnap.docs.isNotEmpty) {
        final dates = plansSnap.docs
            .map((doc) => doc.data()['examDate'] as String?)
            .where((date) => date != null)
            .map((date) => DateTime.tryParse(date!))
            .where((date) => date != null)
            .toList();

        if (dates.isNotEmpty) {
          dates.sort((a, b) => b!.compareTo(a!));
          latestExamDate = dates.first;
        } else {
          latestExamDate = null;
        }
      }

      // Notes
      final notesSnap = await _db
          .collection('notes')
          .where('uid', isEqualTo: _uid)
          .get();
      totalNotes = notesSnap.docs.length;

      // Homeworks
      final homeworksSnap = await _db
          .collection('users')
          .doc(_uid)
          .collection('homeworks')
          .get();
      totalHomeworks = homeworksSnap.docs.length;

      // Quiz Attempts
      final attemptsSnap = await _db
          .collection('quizAttempts')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .get();

      if (attemptsSnap.docs.isNotEmpty) {
        final percentages = <double>[];
        recentQuizScores.clear();
        Map<String, List<double>> topicScores = {};

        for (var doc in attemptsSnap.docs) {
          final data = doc.data();
          final score = (data['score'] as num?)?.toDouble() ?? 0.0;
          final questions = data['questions'] as List<dynamic>? ?? [];
          final totalQuestions = questions.length;

          if (totalQuestions > 0) {
            final percent = (score / totalQuestions) * 100;
            percentages.add(percent);
            
            if (recentQuizScores.length < 10) {
              recentQuizScores.add(percent);
            }

            final title = data['title'] ?? 'Other';
            if (!topicScores.containsKey(title)) {
              topicScores[title] = [];
            }
            topicScores[title]!.add(percent);
          }
        }

        totalQuizzes = attemptsSnap.docs.length;
        avgQuizScore = percentages.isNotEmpty
            ? percentages.reduce((a, b) => a + b) / percentages.length
            : 0.0;
            
        recentQuizScores = recentQuizScores.reversed.toList();

        topicAccuracy.clear();
        weakTopics.clear();
        topicScores.forEach((topic, scores) {
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          topicAccuracy[topic] = avg;
          if (avg < 60) {
            weakTopics.add(topic);
          }
        });
      }

      // Latest Activity (Check Streak logic)
      final userDoc = await _db.collection('users').doc(_uid).get();
      if (userDoc.exists) {
        streakCount = userDoc.data()?['streakCount'] ?? 0;
        final lastLoginTS = userDoc.data()?['lastLogin'] as Timestamp?;
        lastOpenedDate = lastLoginTS?.toDate();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> fetchRecommendedNotes() async {
    // Current logic: just fetch latest notes globally or curated
    try {
      final snap = await _db
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      recommendedNotes = snap.docs.map((doc) => NoteModel.fromMap(doc.data())).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching recommended notes: $e');
    }
  }

  Future<void> fetchSharedQuizStats() async {
    notifyListeners();
  }

  Future<void> checkStreak() async {
    if (_uid == null) return;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final Timestamp? lastTS = data['lastLogin'] as Timestamp?;
        final int currentStreak = data['streakCount'] ?? 0;
        
        final now = DateTime.now();
        if (lastTS != null) {
          final lastDate = lastTS.toDate();
          final diff = DateTime(now.year, now.month, now.day)
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;
          
          if (diff == 1) {
            await _db.collection('users').doc(_uid).update({
              'streakCount': currentStreak + 1,
              'lastLogin': FieldValue.serverTimestamp(),
            });
            streakCount = currentStreak + 1;
          } else if (diff > 1) {
            await _db.collection('users').doc(_uid).update({
              'streakCount': 1,
              'lastLogin': FieldValue.serverTimestamp(),
            });
            streakCount = 1;
          }
        } else {
          await _db.collection('users').doc(_uid).update({
            'streakCount': 1,
            'lastLogin': FieldValue.serverTimestamp(),
          });
          streakCount = 1;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking streak: $e');
    }
  }
}
