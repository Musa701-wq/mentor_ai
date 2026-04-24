// lib/main.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Providers/quizProvider.dart';
import 'package:student_ai/SplashScreen.dart';
import 'package:student_ai/services/Firestore_service.dart';
import 'package:student_ai/services/IAPService.dart';
import 'package:student_ai/services/adService.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:student_ai/services/geminiService.dart';
import 'package:student_ai/splashWrapper.dart';
import 'Providers/authProvider.dart';
import 'Providers/chatProvider.dart';
import 'Providers/homeStatsProvider.dart';
import 'Providers/homeworkProvider.dart';
import 'Providers/notesProvider.dart';
import 'Providers/profileProvider.dart';
import 'Providers/studyPlannerProvider.dart';
import 'Providers/mindmapProvider.dart';
import 'Providers/SyllabusProvider.dart';
import 'Providers/flashcardProvider.dart';
import 'Screens/authwrapper.dart';
import 'firebase_options.dart'; // Make sure you have this generated
import 'routes.dart';
import 'utils/app_navigator.dart';
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Request App Tracking Transparency authorization on iOS before initializing ads
  await _requestATTIfNeeded();
  await AdService.init();
  await analytics.logEvent(name: 'debug_view_test');
  print('📊 Logged debug_view_test event for DebugView');

  // Future.microtask(() async {
  //   final iapService = IAPService();
  //   await iapService.init();
  //   await iapService.verifyMonthlySubscription(); // 🔹 verify subscription on app start
  //
  // });

  runApp(const MyApp());
}

Future<void> _requestATTIfNeeded() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT request failed: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ProfileProvider first
        ChangeNotifierProvider(create: (_) => ProfileProvider()),

        // authProvider1 depends on ProfileProvider
        ChangeNotifierProxyProvider<ProfileProvider, authProvider1>(
          create: (context) => authProvider1(
            Provider.of<ProfileProvider>(context, listen: false),
          ),
          update: (context, profileProvider, previousAuthProvider) {
            // just return the existing instance
            return previousAuthProvider!..notifyListeners();
          },
        ),
        ChangeNotifierProvider(create: (_) => NotesProvider(firestoreService:FirestoreService() )..loadNotes()),
        ChangeNotifierProvider(create: (_) => ChatProvider(geminiService: GeminiService())),
        ChangeNotifierProvider(create: (_) => QuizProvider(geminiService: GeminiService())),
        ChangeNotifierProvider(create: (_) => StudyPlannerProvider(geminiService: GeminiService(),)),
        ChangeNotifierProvider(create: (_) => MindmapProvider(geminiService: GeminiService())),
        ChangeNotifierProvider(create: (_) => HomeworkProvider()),
        ChangeNotifierProvider(create: (_) => HomeStatsProvider()..loadDashboard()),
        ChangeNotifierProvider(create: (_) => SyllabusProvider()),
        ChangeNotifierProvider(create: (_) => IAPService()..init()),
        ChangeNotifierProvider(create: (_) => FlashcardProvider()..loadDecks()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mentor AI App',
        theme: ThemeData.light(),         // Light theme
        themeMode: ThemeMode.light,
        navigatorKey: AppNavigator.key,
        navigatorObservers:  [routeObserver],
        home: const SplashWrapper(),
      ),
    );
  }
}
