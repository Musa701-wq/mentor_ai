import 'package:flutter/material.dart';
import 'package:student_ai/Screens/home.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/animation.dart';
import 'package:confetti/confetti.dart';

import '../../Providers/quizProvider.dart';

class ManualQuizScreen extends StatefulWidget {
  const ManualQuizScreen({super.key});

  @override
  State<ManualQuizScreen> createState() => _ManualQuizScreenState();
}

class _ManualQuizScreenState extends State<ManualQuizScreen>
    with SingleTickerProviderStateMixin {
  int? _totalQuestions;
  int _currentIndex = 0;
  late AnimationController _animationController;
  late ConfettiController _confettiController;
  bool _showConfetti = false;

  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _questionControllers = [];
  final List<List<TextEditingController>> _optionControllers = [];
  final List<int> _correctOptions = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  void _initializeControllers(int count) {
    _questionControllers.clear();
    _optionControllers.clear();
    _correctOptions.clear();

    for (int i = 0; i < count; i++) {
      _questionControllers.add(TextEditingController());
      _optionControllers.add(List.generate(4, (_) => TextEditingController()));
      _correctOptions.add(-1);
    }
  }

  bool _isCurrentQuestionValid() {
    final question = _questionControllers[_currentIndex].text.trim();
    final options = _optionControllers[_currentIndex]
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    final correctIndex = _correctOptions[_currentIndex];
    return question.isNotEmpty && options.length >= 2 && correctIndex != -1;
  }

  Future<void> _saveQuiz(BuildContext context) async {
    final provider = Provider.of<QuizProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    final quizTitle = _titleController.text.trim();
    if (quizTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a quiz title")),
      );
      return;
    }

    // Set title in provider
    provider.setQuizTitle(quizTitle);

    for (int i = 0; i < _totalQuestions!; i++) {
      final question = _questionControllers[i].text.trim();
      final options = _optionControllers[i]
          .map((c) => c.text.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      final correctIndex = _correctOptions[i];

      if (question.isEmpty || options.length < 2 || correctIndex == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fill all fields for Question ${i + 1}")),
        );
        return;
      }

      provider.addLocalQuestion(
        question,
        options,
        correctOption: correctIndex,
      );
    }

    await provider.saveQuizToDb(user.uid, isAiGenerated: false);

    // Show confetti on successful save
    setState(() {
      _showConfetti = true;
    });
    _confettiController.play();

    // Delay navigation to show confetti
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _showConfetti = false;
      });
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 2)),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    _titleController.dispose();
    for (var c in _questionControllers) {
      c.dispose();
    }
    for (var optionList in _optionControllers) {
      for (var c in optionList) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    bool isPrimary = true,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: isPrimary ? 4 : 0,
        backgroundColor: isPrimary
            ? const Color(0xFF6C63FF)
            : Colors.grey.shade100,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF6C63FF),
        shadowColor: isPrimary ? const Color(0xFF6C63FF).withOpacity(0.3) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(icon, size: 18),
            ),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNumberSelector() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Create Your Quiz",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2B4E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "How many questions do you want?",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              dropdownColor: const Color(0xFFF5F5FF),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6C63FF)),
              hint: const Text("Select number of questions"),
              items: List.generate(
                20,
                    (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    "${i + 1}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _totalQuestions = val;
                  _initializeControllers(val!);
                });
                _animationController.forward();
              },
            ),
          ),
          const SizedBox(height: 16),
          Image.asset(
            'assets/quiz.png', // Add your own image asset
            height: 150,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _totalQuestions!,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          "${((_currentIndex + 1) / _totalQuestions! * 100).round()}% Complete",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionField(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _correctOptions[_currentIndex] == index
              ? const Color(0xFF6C63FF).withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _correctOptions[_currentIndex] == index
                ? const Color(0xFF6C63FF)
                : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _optionControllers[_currentIndex][index],
                  decoration: InputDecoration(
                    labelText: "Option ${index + 1}",
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _correctOptions[_currentIndex] == index
                      ? const Color(0xFF6C63FF)
                      : Colors.grey[300],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.check,
                    color: _correctOptions[_currentIndex] == index
                        ? Colors.white
                        : Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _correctOptions[_currentIndex] = index;
                    });
                  },
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
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text(
              "Create Quiz",
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
            onTap: () {
              // Dismiss keyboard when tapping anywhere on the screen
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                Container(
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
                      child: _totalQuestions == null
                          ? Center(child: _buildQuestionNumberSelector())
                          : SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quiz Title
                        const Text(
                          "Quiz Title:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2B4E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: "Enter an engaging quiz title",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Progress indicator
                        _buildProgressIndicator(),
                        const SizedBox(height: 20),

                        // Question number
                        Text(
                          "Question ${_currentIndex + 1}/$_totalQuestions",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Question field
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _questionControllers[_currentIndex],
                            decoration: InputDecoration(
                              labelText: "Enter Question",
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Options
                        const Text(
                          "Options:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2B4E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: List.generate(4, (i) => _buildOptionField(i)),
                        ),
                        const SizedBox(height: 20),

                        // Navigation buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentIndex > 0)
                              _buildActionButton(
                                text: "Previous",
                                icon: Icons.arrow_back,
                                onPressed: () {
                                  setState(() {
                                    _currentIndex--;
                                  });
                                },
                                isPrimary: false,
                              ),
                            if (_currentIndex < _totalQuestions! - 1)
                              _buildActionButton(
                                text: "Next",
                                icon: Icons.arrow_forward,
                                onPressed: _isCurrentQuestionValid()
                                    ? () {
                                  setState(() {
                                    _currentIndex++;
                                  });
                                }
                                    : null,
                                isPrimary: true,
                              ),
                            if (_currentIndex == _totalQuestions! - 1)
                              quizProvider.isLoading
                                  ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                              )
                                  : _buildActionButton(
                                text: "Save Quiz",
                                icon: Icons.check_circle,
                                onPressed: _isCurrentQuestionValid()
                                    ? () => _saveQuiz(context)
                                    : null,
                                isPrimary: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Confetti animation
                ),if (_showConfetti)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFF6C63FF),
                      Color(0xFFFF6584),
                      Color(0xFFFFCE5C),
                      Color(0xFF4CAF50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}