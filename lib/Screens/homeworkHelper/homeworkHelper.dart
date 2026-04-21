import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/homeworkProvider.dart';
import '../../config/creditConfig.dart';
import '../../services/creditService.dart';

class HomeworkHelperScreen extends StatefulWidget {
  const HomeworkHelperScreen({super.key});

  @override
  State<HomeworkHelperScreen> createState() => _HomeworkHelperScreenState();
}

class _HomeworkHelperScreenState extends State<HomeworkHelperScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();

  Future<void> _pickImage(HomeworkProvider provider) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);

      await CreditsService.confirmAndDeductCredits(
        context: context,
        cost: CreditsConfig.aiHomeworkHelper,
        actionName: "Homework Solving",
        onConfirmedAction: () async {
          final error = await provider.extractAndSolveFromImage(file);
          _handleResult(error);
        },
      );
    }
  }

  Future<void> _pickFile(HomeworkProvider provider, List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result != null) {
      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase();

      await CreditsService.confirmAndDeductCredits(
        context: context,
        cost: CreditsConfig.aiHomeworkHelper,
        actionName: "Homework Solving",
        onConfirmedAction: () async {
          String? error;
          if (ext == "pdf") {
            error = await provider.extractAndSolveFromPdf(file);
          } else if (ext == "docx") {
            error = await provider.extractAndSolveFromDocx(file.path);
          }
          _handleResult(error);
        },
      );
    }
  }

  Future<void> _solveFromText(HomeworkProvider provider) async {
    if (_textController.text.trim().isEmpty) return;

    await CreditsService.confirmAndDeductCredits(
      context: context,
      cost: CreditsConfig.aiHomeworkHelper,
      actionName: "Homework Solving",
      onConfirmedAction: () async {
        final error = await provider.solveFromText(_textController.text.trim());
        _handleResult(error);
        _textFocusNode.unfocus();
      },
    );
  }

  List<Map<String, String>> _parseSolutions(String text) {
    final List<Map<String, String>> solutions = [];

    // Remove asterisks just in case the model ignored our prompt
    final cleanText = text.replaceAll('*', '');

    // Regex to find all Question-Answer-Explanation blocks
    final regex = RegExp(
      r'Question:\s*(.*?)\s*Answer:\s*(.*?)\s*Explanation:\s*(.*?)(?=Question:|$)',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = regex.allMatches(cleanText);

    for (final match in matches) {
      solutions.add({
        'question': match.group(1)?.trim() ?? "",
        'answer': match.group(2)?.trim() ?? "",
        'explanation': match.group(3)?.trim() ?? "",
      });
    }

    return solutions;
  }

  void _handleResult(String? error) {
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text("AI Solution Generated & Saved!"),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HomeworkProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 🎨 Premium Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Homework Helper",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.shade800,
                      Colors.purple.shade700,
                      Colors.pink.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(Icons.psychology_rounded,
                      size: 200, color: Colors.white),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    builder: (context) => _buildHowItWorksSheet(),
                  );
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 📝 Main Input Card
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.edit_note_rounded,
                                  color: Colors.purple.shade600),
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Ask Anything",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  "Type or upload your work",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Input Area
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText: "Enter your question here...",
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(20),
                                  hintStyle: TextStyle(
                                      color: Colors.grey[400], fontSize: 15),
                                ),
                                style: const TextStyle(
                                    fontSize: 16, height: 1.5),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Row(
                                  children: [
                                    _buildSmallIconBtn(
                                      icon: Icons.image_outlined,
                                      color: Colors.blue,
                                      onTap: () => _pickImage(provider),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildSmallIconBtn(
                                      icon: Icons.picture_as_pdf_outlined,
                                      color: Colors.red,
                                      onTap: () => _pickFile(provider, ["pdf"]),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.auto_awesome,
                                          size: 18),
                                      label: const Text("Solve"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple.shade600,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14)),
                                      ),
                                      onPressed: () => _solveFromText(provider),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ⚡ Results Section
                if (provider.loading) _buildLoadingCard(cardColor!),

                if (provider.steps != null && !provider.loading) ...[
                  ..._buildPremiumSolutionCards(provider, cardColor!, isDark),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildLoadingCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E57C2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Analyzing homework...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            "Our AI is finding the best explanation",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPremiumSolutionCards(
      HomeworkProvider provider, Color cardColor, bool isDark) {
    final solutions = _parseSolutions(provider.steps!);

    if (solutions.isEmpty) {
      // Fallback for unstructured responses
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(provider.steps!, style: const TextStyle(fontSize: 16, height: 1.6)),
        )
      ];
    }

    return solutions.map((sol) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purple.shade600, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    "AI Solution",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sol['question']!.isNotEmpty) ...[
                    _buildLabel("QUESTION"),
                    Text(sol['question']!,
                        style: const TextStyle(
                            fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                  ],

                  if (sol['answer']!.isNotEmpty) ...[
                    _buildLabel("CORRECT ANSWER"),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Text(sol['answer']!,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.green)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (sol['explanation']!.isNotEmpty) ...[
                    _buildLabel("STUDY GUIDE"),
                    Text(sol['explanation']!,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.7,
                            color: isDark ? Colors.grey[300] : Colors.grey[800])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    )).toList();
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.purple.shade400,
          letterSpacing: 1.5,
        ),
      ),
    );
  }


  Widget _buildHowItWorksSheet() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('How it Works',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
            ],
          ),
          const SizedBox(height: 24),
          _buildUsageStep(Icons.camera_alt_rounded, "Take a photo or upload a file of your homework."),
          _buildUsageStep(Icons.chat_bubble_outline_rounded, "Or just type the question directly."),
          _buildUsageStep(Icons.auto_awesome_rounded, "Our AI analyzes the problem and provides the answer with a full guide."),
        ],
      ),
    );
  }

  Widget _buildUsageStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.purple.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4))),
        ],
      ),
    );
  }
}

