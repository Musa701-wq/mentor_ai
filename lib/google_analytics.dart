import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Quiz Analytics
  static Future<void> logManualQuizClick() async {
    await _analytics.logEvent(
      name: 'manual_quiz_clicked',
      parameters: {
        'action': 'create_manual_quiz',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<void> logGenerateQuizClick() async {
    await _analytics.logEvent(
      name: 'generate_quiz_clicked',
      parameters: {
        'action': 'create_ai_quiz',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Notes Analytics
  static Future<void> logCreateNoteClick() async {
    await _analytics.logEvent(
      name: 'create_note_clicked',
      parameters: {
        'action': 'create_new_note',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Plan Analytics
  static Future<void> logCreatePlanClick() async {
    await _analytics.logEvent(
      name: 'create_plan_clicked',
      parameters: {
        'action': 'create_study_plan',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}