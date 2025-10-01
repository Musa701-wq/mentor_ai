// lib/providers/home_stats_provider.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notesModel.dart';

class HomeStatsProvider with ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  int completedPlans = 0;
  int incompletePlans = 0;
  int totalPlans = 0;

  int totalQuizzes = 0;
  double avgQuizScore = 0.0;

  int streakCount = 0; // 🔥 daily streak
  DateTime? lastOpenedDate;

  List<NoteModel> recommendedNotes = [];
  String? latestExamDate;
  bool loading = true;

  Map<String, Map<String, dynamic>> sharedQuizStats = {};

  // -------------------------------------------------
  // 🔹 Fetch stats for quizzes you own
  // -------------------------------------------------
  Future<void> fetchSharedQuizStats() async {
    if (_uid == null) return;

    try {
      final quizSnap = await _db
          .collection("quizzes")
          .where("userId", isEqualTo: _uid)
          .get();

      Map<String, Map<String, dynamic>> result = {};

      for (final quizDoc in quizSnap.docs) {
        final quizData = quizDoc.data();
        final quizId = quizDoc.id;
        final quizTitle = quizData['title'] ?? 'Untitled Quiz';
        final totalQuestions = (quizData['totalQuestions'] as int?) ?? 0;
        final sharedUids = List<String>.from(quizData['withShared'] ?? []);

        List<Map<String, dynamic>> participants = [];

        for (final uid in sharedUids) {
          // Fetch user info
          final userDoc = await _db.collection("users").doc(uid).get();
          final userName = userDoc.data()?['name'] ?? "Unknown";
          final userEmail = userDoc.data()?['email'] ?? "";

          // Fetch quiz attempts
          final attemptsSnap = await _db
              .collection("quizAttempts")
              .where("userId", isEqualTo: uid)
              .where("quizId", isEqualTo: quizId)
              .orderBy("createdAt", descending: true)
              .get();

          final attemptsCount = attemptsSnap.docs.length;
          bool hasAttempted = attemptsCount > 0;

          int bestScore = 0;
          int lastScore = 0;

          if (hasAttempted) {
            for (final att in attemptsSnap.docs) {
              final data = att.data();
              final score = (data['score'] as num?)?.toInt() ?? 0;
              if (score > bestScore) bestScore = score;
              lastScore = score; // last doc → last attempt
            }
          }

          participants.add({
            "uid": uid,
            "name": userName,
            "email": userEmail,
            "attempts": attemptsCount,
            "bestScore": bestScore,
            "lastScore": lastScore,
            "totalQuestions": totalQuestions,
            "hasAttempted": hasAttempted, // Add flag for attempted status
          });
        }

        // 🔹 Include quiz even if no one attempted
        result[quizId] = {
          "quizTitle": quizTitle,
          "totalQuestions": totalQuestions,
          "participants": participants,
        };
      }

      sharedQuizStats = result;
      notifyListeners();
      debugPrint("✅ Shared quiz stats loaded for ${result.length} quizzes");
    } catch (e, st) {
      debugPrint("❌ Error fetching shared quiz stats: $e");
      debugPrint(st.toString());
    }
  }





  /// 🔹 Track streak when app opens
  Future<void> checkStreak() async {
    if (_uid == null) {
      debugPrint("[STREAK] No UID found → cannot check streak.");
      return;
    }

    try {
      final docRef =
      _db.collection('users').doc(_uid).collection('meta').doc('streak');
      final snap = await docRef.get();

      final today = DateTime.now();
      final todayStr = DateFormat("yyyy-MM-dd").format(today);

      debugPrint("[STREAK] Checking streak for user $_uid");
      debugPrint("[STREAK] Today: $todayStr");

      if (snap.exists) {
        final data = snap.data()!;
        final lastDateStr = data['lastOpened'] as String?;
        final lastDate =
        lastDateStr != null ? DateTime.tryParse(lastDateStr) : null;
        final streak = (data['count'] as int?) ?? 0;

        debugPrint("[STREAK] Existing streak data: $data");
        debugPrint("[STREAK] Last opened: $lastDateStr → $lastDate");
        debugPrint("[STREAK] Previous streak count: $streak");

        if (lastDate != null) {
          final diff = today.difference(lastDate).inDays;
          debugPrint("[STREAK] Days since last open: $diff");

          if (diff == 1) {
            streakCount = streak + 1;
            debugPrint("[STREAK] Consecutive login → incremented streak: $streakCount");
          } else if (diff == 0) {
            streakCount = streak;
            debugPrint("[STREAK] Already opened today → streak unchanged: $streakCount");
          } else {
            streakCount = 1;
            debugPrint("[STREAK] Missed $diff days → streak reset to 1");
          }
        } else {
          streakCount = 1;
          debugPrint("[STREAK] No last date stored → streak started at 1");
        }
      } else {
        streakCount = 1;
        debugPrint("[STREAK] No streak doc found → first time streak = 1");
      }

      lastOpenedDate = today;

      await docRef.set({
        'count': streakCount,
        'lastOpened': todayStr,
      });

      debugPrint("[STREAK] Updated Firestore with → count: $streakCount, lastOpened: $todayStr");
      notifyListeners();
    } catch (e) {
      debugPrint("[STREAK] Error tracking streak: $e");
    }
  }


  /// 🔹 Fetch recommended notes
  Future<void> fetchRecommendedNotes() async {
    if (_uid == null) return;

    try {
      final snap = await _db
          .collection('notes')
          .where('uid', isEqualTo: _uid)
          .get();

      final notes = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return NoteModel.fromMap(data);
      }).toList();

      if (notes.isNotEmpty) {
        notes.shuffle(Random());
        recommendedNotes = notes.take(5).toList();
      } else {
        recommendedNotes = [];
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching recommended notes: $e");
      recommendedNotes = [];
      notifyListeners();
    }
  }

  /// 🔹 Fetch dashboard stats
  Future<void> fetchStats() async {
    if (_uid == null) return;

    loading = true;
    notifyListeners();

    try {
      // Plans
      final plansSnap = await _db
          .collection('studyPlans')
          .where('uid', isEqualTo: _uid)
          .get();

      totalPlans = plansSnap.docs.length;

      completedPlans = plansSnap.docs.where((doc) {
        final data = doc.data();
        return (data['completed'] == true);
      }).length;
      incompletePlans = totalPlans - completedPlans;

      // Upcoming exam
      if (plansSnap.docs.isNotEmpty) {
        final now = DateTime.now();

        final upcomingPlans = plansSnap.docs.map((doc) {
          final data = doc.data();
          final dateStr = data['examDate']?.toString();
          return DateTime.tryParse(dateStr ?? "");
        }).where((date) => date != null && date.isAfter(now)).toList();

        if (upcomingPlans.isNotEmpty) {
          upcomingPlans.sort((a, b) => a!.compareTo(b!));
          final nextExam = upcomingPlans.first!;
          latestExamDate = DateFormat("d MMM yyyy").format(nextExam);
        } else {
          latestExamDate = null;
        }
      }

      // Quiz Attempts
      final attemptsSnap = await _db
          .collection('quizAttempts')
          .where('userId', isEqualTo: _uid)
          .get();

      if (attemptsSnap.docs.isNotEmpty) {
        final percentages = <double>[];

        for (var doc in attemptsSnap.docs) {
          final data = doc.data();

          final score = (data['score'] as num?)?.toDouble() ?? 0.0;
          final questions = data['questions'] as List<dynamic>? ?? [];
          final totalQuestions = questions.length;

          if (totalQuestions > 0) {
            final percent = (score / totalQuestions) * 100;
            percentages.add(percent);
          }
        }

        avgQuizScore = percentages.isNotEmpty
            ? percentages.reduce((a, b) => a + b) / percentages.length
            : 0.0;

        final quizIds = attemptsSnap.docs
            .map((doc) => doc['quizId'] as String?)
            .where((id) => id != null)
            .toSet();

        totalQuizzes = quizIds.length;
      } else {
        avgQuizScore = 0.0;
        totalQuizzes = 0;
      }

      loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      loading = false;
      notifyListeners();
    }
  }
  Future<void> loadDashboard() async {
    if (_uid == null) return;
    loading = true;
    notifyListeners();

    await Future.wait([
      fetchSharedQuizStats(),
      fetchRecommendedNotes(),
      fetchStats(),
      checkStreak(),
    ]);

    loading = false;
    notifyListeners();
  }
}
