import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../Providers/notesProvider.dart';
import '../../services/geminiService.dart';
import '../../services/ocrService.dart';
import '../../models/notesModel.dart';

class NotesCleanerScreen extends StatefulWidget {
  const NotesCleanerScreen({super.key});

  @override
  State<NotesCleanerScreen> createState() => _NotesCleanerScreenState();
}

class _NotesCleanerScreenState extends State<NotesCleanerScreen> {
  final TextEditingController _messyController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();

  String _cleanedResult = '';
  bool _isProcessing = false;
  bool _showSuccessAnimation = false;
  String _statusMsg = '';
  bool _isHandwritten = false; // New state for handwriting mode

  @override
  void dispose() {
    _messyController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

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
          _messyController.text += '\n$text';
          _statusMsg = 'Text extracted successfully!';
        });
      } catch (e) {
        _showError('OCR failed: $e');
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
        } else if (file.path.endsWith('.docx')) {
          text = await _ocrService.extractTextFromDocx(file.path);
        } else {
          text = await file.readAsString();
        }
        setState(() {
          _messyController.text += '\n$text';
          _statusMsg = 'Text extracted successfully!';
        });
      } catch (e) {
        _showError('File extraction failed: $e');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cleanNotes() async {
    if (_messyController.text
        .trim()
        .isEmpty) {
      _showError('Please enter or upload some notes first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMsg = _isHandwritten
          ? 'AI is decoding your handwriting...'
          : 'AI is organizing your notes...';
    });

    try {
      final String cleaned;
      if (_isHandwritten) {
        cleaned =
        await _geminiService.polishHandwritingOCR(_messyController.text);
      } else {
        cleaned = await _geminiService.cleanNotes(_messyController.text);
      }

      if (mounted) {
        setState(() {
          _cleanedResult = cleaned;
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
      _showError('Cleaning failed: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToNotes() async {
    if (_cleanedResult.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMsg = 'Saving to your notes...';
    });

    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      // Extract title from the first line or use a default
      final lines = _cleanedResult.split('\n');
      String title = 'Cleaned Notes';
      for (var line in lines) {
        if (line
            .trim()
            .isNotEmpty) {
          title = line.replaceAll('#', '').trim();
          if (title.length > 30) title = '${title.substring(0, 27)}...';
          break;
        }
      }

      final newNote = NoteModel(
        id: const Uuid().v4(),
        uid: uid,
        title: title,
        content: _cleanedResult,
        createdAt: DateTime.now(),
        tags: ['Cleaned'],
      );

      await notesProvider.firestoreService.saveNote(newNote);
      await notesProvider.loadNotes(reset: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to My Notes!')),
        );
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _cleanedResult));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showHelpModal() {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Notes Cleaner Features',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '• Transform messy, unorganized notes into study guides\n\n'
                      '• Support for handwritten note optimization\n\n'
                      '• Extract text from Images, PDFs, and Word docs\n\n'
                      '• Save directly to your study notes collection',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Got It!',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildGradientBackground(bool isDark) {
    if (isDark) return Container(color: Colors.grey[900]);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade100,
            Colors.blue.shade100,
            Colors.purple.shade50,
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Stack(
      children: [
        _buildGradientBackground(isDark),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Notes Cleaner & Structurer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.black,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: _showHelpModal,
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cleaning_services_rounded,
                                size: 32, color: Colors.teal),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Study Notes Made Easy",
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
                                  "Convert messy scribbles into structured points",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.grey[300] : Colors
                                          .black.withOpacity(0.7)
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    _buildSectionHeader(
                        'Input Messy Notes', Icons.edit_note_rounded,
                        Colors.orangeAccent),
                    const SizedBox(height: 12),
                    _buildInputSection(isDark),
                    const SizedBox(height: 24),

                    if (_cleanedResult.isNotEmpty) ...[
                      _buildSectionHeader(
                          'Structured Study Notes', Icons.auto_awesome_rounded,
                          Colors.teal),
                      const SizedBox(height: 12),
                      _buildOutputSection(isDark),
                      const SizedBox(height: 30),
                    ] else
                      ...[
                        _buildCleanButton(),
                        const SizedBox(height: 100),
                      ],
                  ],
                ),
              ),
              if (_isProcessing) _buildLoadingOverlay(),
              if (_showSuccessAnimation) _buildSuccessOverlay(),
            ],
          ),
          floatingActionButton: _cleanedResult.isNotEmpty && !_isProcessing
              ? FloatingActionButton.extended(
            onPressed: () {
              setState(() => _cleanedResult = '');
              _messyController.clear();
            },
            backgroundColor: const Color(0xFF6C63FF),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Start New'),
          )
              : null,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon,
      [Color iconColor = const Color(0xFF6C63FF)]) {
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

  Widget _buildInputSection(bool isDark) {
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
        children: [
          TextField(
            controller: _messyController,
            maxLines: 8,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Paste messy notes or extract from files...',
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
                    _buildActionChip(
                        Icons.image_rounded, 'Image', _pickImage, Colors.blue),
                    const SizedBox(width: 8),
                    _buildActionChip(
                        Icons.picture_as_pdf_rounded, 'PDF/Doc', _pickFile,
                        Colors.redAccent),
                    const Spacer(),
                    if (_messyController.text.isNotEmpty)
                      IconButton(
                        onPressed: () =>
                            setState(() => _messyController.clear()),
                        icon: const Icon(
                            Icons.clear_all_rounded, color: Colors.redAccent),
                        tooltip: 'Clear All',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.history_edu_rounded, size: 18,
                        color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Optimize for Handwriting',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isHandwritten ? const Color(0xFF6C63FF) : Colors
                            .grey,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _isHandwritten,
                      activeColor: const Color(0xFF6C63FF),
                      onChanged: (val) => setState(() => _isHandwritten = val),
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

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap,
      Color color) {
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
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSection(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: SelectableText(
              _cleanedResult,
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                letterSpacing: 0.2,
                color: isDark ? Colors.grey[200] : const Color(0xFF2D2B4E),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveToNotes,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                    label: const Text('Save to Notes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: _copyToClipboard,
                    icon: const Icon(
                        Icons.copy_all_rounded, color: Color(0xFF6C63FF)),
                    tooltip: 'Copy all',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.teal, Colors.blue],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _cleanNotes,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Clean & Structure Notes',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
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
            color: Theme
                .of(context)
                .brightness == Brightness.dark ? Colors.grey[900] : Colors
                .white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                _statusMsg,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
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
              "Notes Organized!",
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
}