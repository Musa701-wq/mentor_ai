import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../Providers/flashcardProvider.dart';
import '../../services/geminiService.dart';
import '../../services/ocrService.dart';

class FlashcardGeneratorScreen extends StatefulWidget {
  const FlashcardGeneratorScreen({super.key});

  @override
  State<FlashcardGeneratorScreen> createState() => _FlashcardGeneratorScreenState();
}

class _FlashcardGeneratorScreenState extends State<FlashcardGeneratorScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();

  String _difficulty = 'medium';
  bool _isProcessing = false;
  bool _showSuccessAnimation = false;
  String _statusMsg = '';
  List<Map<String, String>> _generatedCards = [];
  int? _expandedCardIndex;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _isProcessing = true;
        _statusMsg = 'Extracting text from image...';
      });
      try {
        final text = await _ocrService.extractTextFromImage(File(image.path));
        setState(() {
          _contentController.text += '\n$text';
        });
      } catch (e) {
        _showSnackBar('OCR failed: $e');
      } finally {
        setState(() => _isProcessing = false);
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
      setState(() {
        _isProcessing = true;
        _statusMsg = 'Extracting text from file...';
      });
      try {
        String text = '';
        if (file.path.endsWith('.pdf')) {
          text = await _ocrService.extractTextFromPdf(file);
        } else {
          text = await file.readAsString();
        }
        setState(() {
          _contentController.text += '\n$text';
        });
      } catch (e) {
        _showSnackBar('File extraction failed: $e');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _generate() async {
    if (_contentController.text.trim().isEmpty) {
      _showSnackBar('Please provide some content first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMsg = 'AI is crafting your flashcards...';
    });

    try {
      final cards = await _geminiService.generateFlashcards(
        _contentController.text,
        _difficulty,
      );
      
      if (mounted) {
        setState(() {
          _generatedCards = cards;
          _isProcessing = false;
          _showSuccessAnimation = true;
        });

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() {
            _showSuccessAnimation = false;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Generation failed: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveDeck() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a deck title.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMsg = 'Saving your deck...';
    });

    try {
      await Provider.of<FlashcardProvider>(context, listen: false).createDeckWithCards(
        _titleController.text.trim(),
        'Generated from AI',
        _generatedCards,
      );
      if (mounted) {
        _showSnackBar('Deck saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Save failed: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _buildGradientBackground(bool isDark) {
    if (isDark) return Container(color: Colors.grey[900]);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        _buildGradientBackground(isDark),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'AI Flashcard Generator',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: isDark ? Colors.white : Colors.black),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.black,
            centerTitle: true,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle('Source Material', Icons.library_books_rounded, Colors.orangeAccent),
                    const SizedBox(height: 12),
                    _buildInputCard(isDark),
                    
                    const SizedBox(height: 32),
                    if (_generatedCards.isNotEmpty) ...[
                      _buildResultsSection(isDark),
                      const SizedBox(height: 100),
                    ] else if (!_isProcessing) ...[
                      _buildGenerateButton(),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
              if (_isProcessing) _buildLoadingOverlay(),
              if (_showSuccessAnimation) _buildSuccessOverlay(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
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
              "Flashcards Generated!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 32, color: Colors.deepOrange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create Your Deck",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    shadows: isDark ? [] : [
                      Shadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Paste text or upload files to generate Flashcards",
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : Colors.black.withOpacity(0.7)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, [Color iconColor = const Color(0xFF6C63FF)]) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentController,
            maxLines: 7,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Paste lecture notes, book snippets, or upload documents...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              contentPadding: const EdgeInsets.all(20),
              border: InputBorder.none,
            ),
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildActionChip(Icons.image_rounded, 'Image', _pickImage, Colors.blue),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Difficulty Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _difficulty,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6C63FF)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
                          items: ['easy', 'medium', 'hard'].map((val) {
                            return DropdownMenuItem(value: val, child: Text(val.toUpperCase(), style: const TextStyle(fontFamily: 'Roboto')));
                          }).toList(),
                          onChanged: (val) => setState(() => _difficulty = val!),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Save Your Deck', Icons.save_rounded, Colors.teal),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Deck Title',
              labelStyle: TextStyle(color: const Color(0xFF6C63FF).withOpacity(0.8)),
              hintText: 'e.g., Biology Chapter 1',
              contentPadding: const EdgeInsets.all(20),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.style_rounded, color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_generatedCards.length} Flashcards Generated',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.grey),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _generatedCards.length,
          itemBuilder: (context, index) {
            final card = _generatedCards[index];
            final isExpanded = _expandedCardIndex == index;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_expandedCardIndex == index) {
                    _expandedCardIndex = null;
                  } else {
                    _expandedCardIndex = index;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isExpanded 
                        ? Colors.deepOrange.withOpacity(0.5) 
                        : Colors.deepOrange.withOpacity(0.1)
                  ),
                  boxShadow: [
                    if (isExpanded)
                      BoxShadow(
                        color: Colors.deepOrange.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Q', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              card['question'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.4),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              setState(() {
                                _generatedCards.removeAt(index);
                                if (_expandedCardIndex == index) _expandedCardIndex = null;
                                else if (_expandedCardIndex != null && _expandedCardIndex! > index) _expandedCardIndex = _expandedCardIndex! - 1;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      
                      if (isExpanded) ...[
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('A', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                card['answer'] ?? '',
                                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 15, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _saveDeck,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text('Save Deck and Study', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.deepOrange, Colors.orange],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Generate Flashcards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.deepOrange),
              const SizedBox(height: 24),
              Text(
                _statusMsg,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
