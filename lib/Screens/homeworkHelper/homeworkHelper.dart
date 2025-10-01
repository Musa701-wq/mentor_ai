import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  bool _showSolution = false; // State for dropdown expansion

  Future<void> _pickFile(HomeworkProvider provider) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "png", "jpeg", "pdf", "docx"],
    );
    if (result != null) {
      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase();

      // ✅ Wrap in credit confirmation
      await CreditsService.confirmAndDeductCredits(
        context: context,
        cost: CreditsConfig.aiHomeworkHelper,
        actionName: "Homework Solving",
        onConfirmedAction: () async {
          if (ext == "pdf") {
            await provider.extractAndSolveFromPdf(file);
          } else if (ext == "docx") {
            await provider.extractAndSolveFromDocx(file.path);
          } else {
            await provider.extractAndSolveFromImage(file);
          }
          setState(() => _showSolution = true);
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
        await provider.solveFromText(_textController.text.trim());
        _textFocusNode.unfocus();
        setState(() => _showSolution = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HomeworkProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Homework Helper",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: isDark ? Colors.grey[300] : Colors.grey[600]),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _buildHowItWorksSheet(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Main Input Card
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Solve Any Homework",
                        style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upload or type your homework question",
                        style:
                        TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Input Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: "Type your homework question...",
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  hintStyle:
                                  TextStyle(color: Colors.grey[500]),
                                ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Send Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.purple.shade600,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  Colors.purple.shade600.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white),
                              onPressed: () => _solveFromText(provider),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Upload Options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildUploadOption(
                            icon: Icons.image_rounded,
                            label: "Image",
                            color: Colors.blue.shade600,
                            onTap: () => _pickFile(provider),
                          ),
                          _buildUploadOption(
                            icon: Icons.picture_as_pdf_rounded,
                            label: "PDF",
                            color: Colors.red.shade600,
                            onTap: () => _pickFile(provider),
                          ),
                          _buildUploadOption(
                            icon: Icons.description_rounded,
                            label: "Document",
                            color: Colors.green.shade600,
                            onTap: () => _pickFile(provider),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Loading
              if (provider.loading) _buildLoadingCard(cardColor!),

              // Results
              if (provider.steps != null && !provider.loading)
                _buildSolutionCard(provider, cardColor!, isDark),

              // Save Section
              if (provider.steps != null && !provider.loading)
                _buildSaveSection(provider, cardColor!, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('How It Works',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text(
            '1. Upload an image, PDF, or document of your homework\n\n'
                '2. Or type your homework question directly\n\n'
                '3. Get step-by-step solutions instantly\n\n'
                '4. Save your solutions for future reference',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
          ),
          const SizedBox(height: 16),
          const Text(
            "Solving your homework...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "This may take a few moments",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(HomeworkProvider provider, Color cardColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showSolution = !_showSolution),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.purple.shade600),
                    const SizedBox(width: 12),
                    const Text("Step-by-Step Solution",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  Icon(
                    _showSolution
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.purple.shade600,
                  )
                ],
              ),
            ),
          ),
          if (_showSolution)
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(provider.steps!,
                  style: const TextStyle(fontSize: 16, height: 1.6)),
            )
        ],
      ),
    );
  }

  Widget _buildSaveSection(HomeworkProvider provider, Color cardColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text("Save Your Solution",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: InputDecoration(
                hintText: "Enter a title for your homework...",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text("Save Homework",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_titleController.text.trim().isNotEmpty) {
                  await provider.saveHomework(_titleController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                      const Text("Homework saved successfully! 🎉"),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  _titleFocusNode.unfocus();
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
