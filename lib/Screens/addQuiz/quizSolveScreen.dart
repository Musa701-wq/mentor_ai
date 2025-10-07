import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Providers/quizProvider.dart';
import 'quizSuccessScreen.dart';

class QuizSolveScreen extends StatefulWidget {
  final String quizId;
  const QuizSolveScreen({super.key, required this.quizId});

  @override
  State<QuizSolveScreen> createState() => _QuizSolveScreenState();
}

class _QuizSolveScreenState extends State<QuizSolveScreen> {
  bool _loadingQuestions = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final provider = Provider.of<QuizProvider>(context, listen: false);

    final snapshot = await FirebaseFirestore.instance
        .collection("quizzes")
        .doc(widget.quizId)
        .collection("questions")
        .get();

    final questions = snapshot.docs.map((doc) {
      return QuizQuestion(
        question: doc["question"],
        options: List<String>.from(doc["options"]),
        correctAnswer: doc["correctAnswer"],
      );
    }).toList();

    provider
      ..resetQuiz()
      ..questions.clear()
      ..questions.addAll(questions);

    setState(() {
      _loadingQuestions = false;
    });
  }

  void _submitQuiz(BuildContext context) async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    
    // Check for unanswered questions
    List<int> unansweredQuestions = [];
    for (int i = 0; i < provider.questions.length; i++) {
      if (!provider.selectedAnswers.containsKey(i) || 
          provider.selectedAnswers[i] == null || 
          provider.selectedAnswers[i]!.isEmpty) {
        unansweredQuestions.add(i + 1); // Adding 1 for human-readable numbering
      }
    }
    
    // Show warning if there are unanswered questions
    if (unansweredQuestions.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
              SizedBox(width: 10),
              Text(
                "Incomplete Quiz",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                "You have ${unansweredQuestions.length} unanswered question(s).",
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Question(s): ${unansweredQuestions.join(', ')}",
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text(
                "Do you want to submit anyway?",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Review"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedWithSubmission(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: const Text("Submit Anyway"),
            ),
          ],
        ),
      );
      return;
    }
    
    // If all questions are answered, proceed with submission
    _proceedWithSubmission(context);
  }
  
  void _proceedWithSubmission(BuildContext context) async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "guest";

    final score = await provider.submitQuiz(userId, widget.quizId);
    // Navigate to a themed success screen, wait 5s there, then return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSuccessScreen(
          score: score,
          total: provider.questions.length,
        ),
      ),
    );

    if (!mounted) return;
    // After success screen auto-closes, move back to previous screen
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, provider, _) {
        if (_loadingQuestions) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Count answered questions
        final answered = provider.selectedAnswers.values
            .where((v) => v != null && v!.isNotEmpty)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Solve Quiz",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2B4E),
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6C63FF),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Color(0xFF6C63FF)),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F5FF),
                    Color(0xFFE6E6FF),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: provider.questions.isEmpty
                                  ? 0
                                  : (answered / provider.questions.length),
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${((provider.questions.isEmpty ? 0 : (answered / provider.questions.length)) * 100).round()}% Answered",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current question card (single-question view)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (provider.questions.isEmpty) {
                              return const Center(child: Text("No questions available"));
                            }
                            final q = provider.questions[_currentIndex];
                            final selected = provider.selectedAnswers[_currentIndex];
                            return StyledQuestionTile(
                              question: q.question,
                              options: q.options,
                              selectedAnswer: selected,
                              correctAnswer: provider.isSubmitted ? q.correctAnswer : null,
                              onSelect: (val) {
                                if (!provider.isSubmitted) {
                                  provider.selectAnswer(_currentIndex, val);
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Navigation buttons: Previous / Next / Submit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentIndex > 0)
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _currentIndex--;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: const Color(0xFF6C63FF),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, size: 18),
                                    SizedBox(width: 6),
                                    Text("Previous"),
                                  ],
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 140),

                          Text(
                            "Question ${_currentIndex + 1}/${provider.questions.length}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C63FF),
                            ),
                          ),

                          if (_currentIndex < provider.questions.length - 1)
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _currentIndex++;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Next"),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                              ),
                            )
                          else if (!provider.isSubmitted)
                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => _submitQuiz(context),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 18),
                                    SizedBox(width: 6),
                                    Text("Submit"),
                                  ],
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 140),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StyledQuestionTile extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedAnswer;
  final String? correctAnswer;
  final Function(String) onSelect;

  const StyledQuestionTile({
    super.key,
    required this.question,
    required this.options,
    required this.onSelect,
    this.selectedAnswer,
    this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2B4E),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: options.map((option) {
                final isCorrect = correctAnswer == option;
                final isSelected = selectedAnswer == option;

                Color borderColor = Colors.grey[200]!;
                Color fillColor = Colors.grey[50]!;
                IconData? trailingIcon;
                Color? trailingColor;

                if (correctAnswer != null) {
                  if (isCorrect) {
                    borderColor = Colors.green;
                    fillColor = Colors.green.withOpacity(0.1);
                    trailingIcon = Icons.check_circle;
                    trailingColor = Colors.green;
                  } else if (isSelected && !isCorrect) {
                    borderColor = Colors.red;
                    fillColor = Colors.red.withOpacity(0.1);
                    trailingIcon = Icons.cancel;
                    trailingColor = Colors.red;
                  }
                } else if (isSelected) {
                  borderColor = const Color(0xFF6C63FF);
                  fillColor = const Color(0xFF6C63FF).withOpacity(0.08);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: correctAnswer != null ? null : () => onSelect(option),
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          if (trailingIcon != null)
                            Icon(trailingIcon, color: trailingColor),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
