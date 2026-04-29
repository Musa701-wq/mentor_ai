import 'dart:io';
import 'package:flutter/material.dart';
import 'package:student_ai/Screens/home.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../Providers/quizProvider.dart';
import '../../services/ocrService.dart';
import '../../config/creditConfig.dart';
import '../../services/creditService.dart';

class GenerateDocQuizScreen extends StatefulWidget {
  const GenerateDocQuizScreen({super.key});

  @override
  State<GenerateDocQuizScreen> createState() => _GenerateDocQuizScreenState();
}

class _GenerateDocQuizScreenState extends State<GenerateDocQuizScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isExtracting = false;
  String _statusMsg = '';
  bool _showSuccessAnimation = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        setState(() {
          _isExtracting = true;
          _statusMsg = 'Extracting text from image...';
        });
      }
      try {
        final text = await _ocrService.extractTextFromImage(File(image.path));
        if (mounted) {
          setState(() {
            _contentController.text += '\n$text';
          });
        }
      } catch (e) {
        _showSnackBar('OCR failed: $e');
      } finally {
        if (mounted) setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (mounted) {
        setState(() {
          _isExtracting = true;
          _statusMsg = 'Extracting text from document...';
        });
      }
      try {
        String text = '';
        if (file.path.endsWith('.pdf')) {
          text = await _ocrService.extractTextFromPdf(file);
        } else {
          text = await file.readAsString();
        }
        if (mounted) {
          setState(() {
            _contentController.text += '\n$text';
          });
        }
      } catch (e) {
        _showSnackBar('File extraction failed: $e');
      } finally {
        if (mounted) setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _generateAndSaveQuiz(BuildContext context) async {
    final extractedText = _contentController.text.trim();
    if (extractedText.isEmpty) {
      _showSnackBar("Please extract text from a document or image first.");
      return;
    }

    final quizTitle = _titleController.text.trim();
    if (quizTitle.isEmpty) {
      _showSnackBar("Please enter a quiz title.");
      return;
    }

    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar("User not logged in");
      return;
    }

    // ✅ Standardized Credit Deduction Flow
    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "Quiz Generation (Document)",
      onConfirmedAction: () async {
        try {
          quizProvider.setQuizTitle(quizTitle);
          final error = await quizProvider.generateFromNotes(extractedText, title: quizTitle);
          if (error != null) {
            if (error.contains("Insufficient")) return;
            throw Exception(error);
          }
          
          // Usage deduction
          await CreditsService().deductUsage(
            tokens: quizProvider.lastTokens, 
            actionName: "Quiz Generation (Document)"
          );

          await quizProvider.saveQuizToDb(user.uid, isAiGenerated: true);

          if (mounted) {
            setState(() {
              _showSuccessAnimation = true;
            });

            await Future.delayed(const Duration(seconds: 2));

            if (mounted) {
              setState(() {
                _showSuccessAnimation = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Quiz generated & saved! 🎉"),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 2)),
                (route) => false,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            _showSnackBar("Error generating quiz: $e");
          }
        }
      },
      onCancel: () {
        // Just return
      },
    );
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade100,
            Colors.deepOrange.shade100,
            Colors.redAccent.shade100,
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      title: Text(
        "Document to Quiz",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
    );
  }

  Widget _buildContent(QuizProvider quizProvider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 30),
            _buildQuizTitleInput(),
            const SizedBox(height: 25),
            _buildDocumentExtractor(),
            const SizedBox(height: 40),
            _buildGenerateButton(quizProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "AI Quiz Extractor",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Upload PDFs or Images and automatically turn them into interactive quizzes",
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
        const Text(
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
            decoration: const InputDecoration(
              hintText: "e.g., Biology Chapter 4",
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: Icon(Icons.title, color: Colors.deepOrange),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentExtractor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Upload Material:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildActionChip(Icons.image_rounded, 'Image', _pickImage, Colors.blue),
                    const SizedBox(width: 12),
                    _buildActionChip(Icons.picture_as_pdf_rounded, 'PDF/Doc', _pickFile, Colors.redAccent),
                    const Spacer(),
                    if (_contentController.text.isNotEmpty)
                      IconButton(
                        onPressed: () => setState(() => _contentController.clear()),
                        icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                        tooltip: 'Clear All',
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Stack(
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Extracted text will appear here. You can also paste manually...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      contentPadding: const EdgeInsets.all(20),
                      border: InputBorder.none,
                    ),
                  ),
                  if (_isExtracting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.8),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Colors.deepOrange),
                              const SizedBox(height: 12),
                              Text(_statusMsg, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
              color: Colors.deepOrange.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _generateAndSaveQuiz(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: quizProvider.isLoading || _isExtracting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, _) {
        return Stack(
          children: [
            _buildGradientBackground(),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(),
              body: _buildContent(quizProvider),
            ),
            if (_showSuccessAnimation)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/success.json',
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
