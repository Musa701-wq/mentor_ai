import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart'; // Add this to your pubspec.yaml

import '../../Providers/notesProvider.dart';
import '../../Providers/quizProvider.dart';
import '../../config/creditConfig.dart';
import '../../services/creditService.dart';

class GenerateQuizScreen extends StatefulWidget {
  const GenerateQuizScreen({super.key});

  @override
  State<GenerateQuizScreen> createState() => _GenerateQuizScreenState();
}

class _GenerateQuizScreenState extends State<GenerateQuizScreen> with SingleTickerProviderStateMixin {
  String? selectedNote;
  final TextEditingController _titleController = TextEditingController();
  late AnimationController _animationController;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateAndSaveQuiz(BuildContext context) async {
    if (selectedNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Select a note first"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final quizTitle = _titleController.text.trim();
    if (quizTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter a quiz title"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("User not logged in"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // ✅ Wrap with credit confirmation
    await CreditsService.confirmAndDeductCredits(
      context: context,
      cost: CreditsConfig.aiQuiz,
      actionName: "AI Quiz Generation",
      onConfirmedAction: () async {
        try {
          // Set title in provider
          quizProvider.setQuizTitle(quizTitle);

          // Generate quiz with selected note
          await quizProvider.generateFromNotes(selectedNote!, title: quizTitle);

          // Save to Firestore
          await quizProvider.saveQuizToDb(user.uid, isAiGenerated: true);

          if (mounted) {
            setState(() {
              _showSuccessAnimation = true;
            });

            await Future.delayed(const Duration(seconds: 2));

            setState(() {
              _showSuccessAnimation = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Quiz generated & saved! -${CreditsConfig.aiQuiz} credits 🎉",
                ),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
    );
  }


  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade100,   // Light lavender
            Colors.blue.shade100,     // Soft blue
            Colors.teal.shade100,     // Gentle teal
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Generate Quiz",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: Colors.black,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildContent(QuizProvider quizProvider, NotesProvider notesProvider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(),
            const SizedBox(height: 30),

            // Quiz Title Input
            _buildQuizTitleInput(),
            const SizedBox(height: 25),

            // Notes Selection
            _buildNotesSelection(notesProvider),
            const SizedBox(height: 40),

            // Generate Button
            _buildGenerateButton(quizProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "AI Quiz Generator",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Transform your notes into engaging quizzes with AI",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quiz Title:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: "Enter a catchy quiz title",
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: Icon(Icons.title, color: Colors.purple.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSelection(NotesProvider notesProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Notes:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),

        // Handle loading state
        if (notesProvider.isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
              ),
            ),
          )
        else if (notesProvider.notes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "No notes available. Please create one first.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<String>(
                value: notesProvider.notes.map((n) => n.content).contains(selectedNote)
                    ? selectedNote
                    : null, // ✅ Prevents mismatch crash
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                dropdownColor: Colors.white,
                icon: Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.purple.shade700, size: 28),
                hint: const Text(
                  "Choose a note to transform into quiz",
                  style: TextStyle(fontSize: 16),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                items: notesProvider.notes.map((n) {
                  return DropdownMenuItem(
                    value: n.content,
                    child: Text(
                      n.title,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedNote = val);
                },
              ),

            ),
          ),
      ],
    );
  }


  Widget _buildGenerateButton(QuizProvider quizProvider) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _generateAndSaveQuiz(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: quizProvider.isLoading
              ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2.5,
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                "Generate Quiz",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<QuizProvider, NotesProvider>(
      builder: (context, quizProvider, notesProvider, _) {
        return Stack(
          children: [
            // Background
            _buildGradientBackground(),

            // Content
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(),
              body: _buildContent(quizProvider, notesProvider),
            ),

            // Success Animation Overlay
            if (_showSuccessAnimation)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/success.json', // Add this animation file to your assets
                        width: 200,
                        height: 200,
                        repeat: false,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Quiz Created Successfully!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}