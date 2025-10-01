// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Providers/quizProvider.dart';
import 'package:student_ai/SplashScreen.dart';
import 'package:student_ai/services/Firestore_service.dart';
import 'package:student_ai/services/IAPService.dart';
import 'package:student_ai/services/adService.dart';
import 'package:student_ai/services/geminiService.dart';
import 'package:student_ai/splashWrapper.dart';
import 'Providers/authProvider.dart';
import 'Providers/chatProvider.dart';
import 'Providers/homeStatsProvider.dart';
import 'Providers/homeworkProvider.dart';
import 'Providers/notesProvider.dart';
import 'Providers/profileProvider.dart';
import 'Providers/studyPlannerProvider.dart';
import 'Screens/authwrapper.dart';
import 'firebase_options.dart'; // Make sure you have this generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AdService.init();

  Future.microtask(() async {
    final iapService = IAPService();
    await iapService.init();
    await iapService.verifyMonthlySubscription(); // 🔹 verify subscription on app start

  });

  runApp(const MyApp());
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
        ChangeNotifierProvider(create: (_)=> NotesProvider(firestoreService:FirestoreService() )..loadNotes()),
        ChangeNotifierProvider(create: (_)=> ChatProvider(geminiService: GeminiService())),
        ChangeNotifierProvider(create: (_)=> QuizProvider(geminiService: GeminiService())),
        ChangeNotifierProvider(create: (_) => StudyPlannerProvider(geminiService: GeminiService(),)),
        ChangeNotifierProvider(create: (_) => HomeworkProvider()),
        ChangeNotifierProvider(create: (_) => HomeStatsProvider()..loadDashboard()),
        ChangeNotifierProvider(create: (_) => IAPService())
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Student AI App',
        theme: ThemeData.light(),         // Light theme
        themeMode: ThemeMode.light,
        home: const SplashWrapper(),
      ),
    );
  }
}
