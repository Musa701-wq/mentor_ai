import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/geminiService.dart';
import '../../services/creditService.dart';

class AITutorScreen extends StatefulWidget {
  const AITutorScreen({super.key});

  @override
  State<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends State<AITutorScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  
  String _documentContext = "";
  String _uploadedFileName = "";
  bool _isExtracting = false;

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    // Start fresh every time - user can load previous sessions via History button
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionToHistory() async {
    if (_messages.isEmpty || _documentContext.isEmpty) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ai_tutor_sessions.json');
      
      List<dynamic> sessions = [];
      if (await file.exists()) {
        final contents = await file.readAsString();
        sessions = jsonDecode(contents);
      }

      // Find and update existing session for this file, or add new
      final existingIndex = sessions.indexWhere((s) => s['fileName'] == _uploadedFileName);
      final sessionData = {
        "id": _uploadedFileName,
        "fileName": _uploadedFileName,
        "timestamp": DateTime.now().toIso8601String(),
        "context": _documentContext,
        "messages": _messages,
      };

      if (existingIndex >= 0) {
        sessions[existingIndex] = sessionData;
      } else {
        sessions.insert(0, sessionData);
        if (sessions.length > 10) sessions = sessions.sublist(0, 10); // Keep max 10
      }

      await file.writeAsString(jsonEncode(sessions));
    } catch (e) {
      debugPrint("Failed to save session: $e");
    }
  }

  Future<List<dynamic>> _loadSessions() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ai_tutor_sessions.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents);
      }
    } catch (e) {
      debugPrint("Failed to load sessions: $e");
    }
    return [];
  }

  void _restoreSession(Map<String, dynamic> session) {
    setState(() {
      _uploadedFileName = session['fileName'] ?? "";
      _documentContext = session['context'] ?? "";
      _messages = List<Map<String, String>>.from(
        (session['messages'] as List).map((i) => Map<String, String>.from(i))
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isExtracting = true;
          _uploadedFileName = result.files.single.name;
        });

        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();

        setState(() {
          _documentContext = text;
          _isExtracting = false;
          _messages.clear();
        });
        
        _saveSessionToHistory();
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      _showSnackBar("Failed to read PDF: $e", Colors.red);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _isExtracting = true;
          _uploadedFileName = image.name;
        });

        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        setState(() {
          _documentContext = recognizedText.text;
          _isExtracting = false;
          _messages.clear();
        });
        
        textRecognizer.close();
        _saveSessionToHistory();
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      _showSnackBar("Failed to process image: $e", Colors.red);
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Upload Study Material",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D2B4E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Upload a PDF or an Image to give the AI Context.",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildUploadOption(
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                    label: "PDF",
                    onTap: () {
                      Navigator.pop(context);
                      _pickPDF();
                    },
                  ),
                  _buildUploadOption(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.blueAccent,
                    label: "Camera",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildUploadOption(
                    icon: Icons.image_rounded,
                    color: Colors.purpleAccent,
                    label: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadOption({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2B4E),
            ),
          )
        ],
      ),
    );
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add({"role": "system", "text": text});
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final query = _messageController.text.trim();
    if (query.isEmpty) return;
    
    if (_documentContext.isEmpty) {
      _showSnackBar("Please upload a PDF or an Image first so the AI has context.", Colors.orange);
      return;
    }

    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "AI Tutoring",
      onConfirmedAction: () async {
        setState(() {
          _messages.add({"role": "user", "text": query});
          _messageController.clear();
          _isLoading = true;
        });
        
        _scrollToBottom();

        try {
          final response = await _geminiService.tutorChatWithContext(
            query, 
            _messages.where((m) => m['role'] != 'system').toList(), 
            _documentContext
          );
          
          // Usage deduction
          await CreditsService().deductUsage(
            tokens: _geminiService.lastEstimatedTokens, 
            actionName: "AI Tutoring"
          );

          setState(() {
            _messages.add({"role": "model", "text": response});
            _isLoading = false;
          });
          _scrollToBottom();
          _saveSessionToHistory();
          
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar("Oops! Something went wrong: $e", Colors.red);
        }
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _removeContext() {
    setState(() {
      _documentContext = "";
      _uploadedFileName = "";
      _messages.clear();
    });
    _showSnackBar("Context cleared.", Colors.green);
  }

  void _showHistoryOptions() async {
    final sessions = await _loadSessions();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8E24AA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        "Previous Sessions",
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      if (sessions.isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            Navigator.pop(context);
                            final directory = await getApplicationDocumentsDirectory();
                            final file = File('${directory.path}/ai_tutor_sessions.json');
                            if (await file.exists()) await file.delete();
                            _showSnackBar("All history cleared.", Colors.green);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text("Clear All", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_toggle_off_rounded, size: 64, color: Color(0xFFDDD8FF)),
                          const SizedBox(height: 12),
                          Text(
                            "No saved sessions yet.",
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final fileName = session['fileName'] ?? 'Unknown';
                        final ts = DateTime.tryParse(session['timestamp'] ?? '');
                        final msgCount = (session['messages'] as List?)?.length ?? 0;
                        final isPdf = fileName.toLowerCase().endsWith('pdf');
                        
                        // Cycle through tile accent colors
                        final List<Color> tileColors = [
                          const Color(0xFF6C63FF),
                          const Color(0xFFFF6B6B),
                          const Color(0xFF20BF6B),
                          const Color(0xFFF7B731),
                          const Color(0xFF0FB9B1),
                          const Color(0xFF8E24AA),
                        ];
                        final tileColor = tileColors[index % tileColors.length];
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: tileColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tileColor.withOpacity(0.25)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tileColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                color: tileColor, size: 22,
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF2D2B4E)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              ts != null 
                                ? "${ts.day}/${ts.month}/${ts.year} • $msgCount messages"
                                : "$msgCount messages",
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: tileColor),
                            onTap: () {
                              Navigator.pop(context);
                              _restoreSession(Map<String, dynamic>.from(session));
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF8E24AA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          "Context AI Tutor",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: "Chat History",
            onPressed: _showHistoryOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Premium Context Banner
          if (_isExtracting)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Extracting content...",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ],
              ),
            )
          else if (_documentContext.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2B4E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D2B4E).withOpacity(0.2),
                    blurRadius: 10, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _uploadedFileName.toLowerCase().endsWith('pdf') 
                          ? Icons.picture_as_pdf_rounded 
                          : Icons.image_rounded, 
                      color: Colors.white, size: 24
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Active Context",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                        ),
                        Text(
                          _uploadedFileName,
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: _removeContext,
                  )
                ],
              ),
            )
          else
            const SizedBox.shrink(),

          // Chat or Empty State
          Expanded(
            child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 80,
                        color: Color(0xFFDDD8FF),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Upload to Start",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB0AADD),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap + to upload a PDF or Image\nand chat with your notes",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFFCBC6E8),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final role = message["role"];
                    final text = message["text"] ?? "";
                    return _buildMessageBubble(role, text, index);
                  },
                ),
          ),
          
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.2), blurRadius: 6, offset: const Offset(0,2))],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/1.png', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF), size: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildTypingIndicator(),
                  ],
                ),
              ),
            ),

          _buildSuggestedQuestions(),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16).copyWith(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FE),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF6C63FF)),
                      tooltip: "Upload Material",
                      onPressed: _showUploadOptions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _documentContext.isEmpty ? "Context required..." : "Ask your Tutor...",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8E24AA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    if (_messages.isNotEmpty || _documentContext.isEmpty) return const SizedBox.shrink();

    final suggestions = [
      "Summarize this document",
      "Explain the main concepts",
      "Create a quick quiz",
      "Give me study tips"
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(suggestions[index], style: const TextStyle(fontSize: 13, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () {
              _messageController.text = suggestions[index];
              _sendMessage();
            },
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3.0;
              final value = (_dotController.value - delay) % 1.0;
              final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(opacity.clamp(0.2, 1.0)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(String? role, String text, int index) {
    if (role == "system") {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.deepPurple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF2D2B4E),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = role == "user";
    
    // Formatting text from model carefully to handle **bolding** natively or just using simple text
    final formattedText = text.replaceAll('•', '\n•').trim();

    // AI Colors to cycle through
    final List<Color> aiColors = [
      const Color(0xFF6C63FF), // Indigo
      const Color(0xFFFF6B6B), // Coral
      const Color(0xFF20BF6B), // Green
      const Color(0xFFF7B731), // Orange
      const Color(0xFF0FB9B1), // Teal
      const Color(0xFF8E24AA), // Purple
      const Color(0xFFEB3B5A), // Cherry
    ];
    
    Color aiBubbleColor = aiColors[index % aiColors.length];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: aiBubbleColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/1.png', 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF), size: 14),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2D2B4E) : aiBubbleColor.withOpacity(0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                border: isUser ? null : Border.all(color: aiBubbleColor.withOpacity(0.3)),
                boxShadow: isUser ? [
                  BoxShadow(color: const Color(0xFF2D2B4E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ] : [],
              ),
              child: Text(
                formattedText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: isUser ? Colors.white : const Color(0xFF2D2B4E),
                  fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
