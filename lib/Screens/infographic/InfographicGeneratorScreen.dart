import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/geminiService.dart';
import '../../services/ocrService.dart';
import '../../services/Firestore_service.dart';
import '../../widgets/FullScreenImageViewer.dart';

enum GeneratorState { input, processing, result }

class InfographicGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  const InfographicGeneratorScreen({super.key, this.existingData});

  @override
  State<InfographicGeneratorScreen> createState() => _InfographicGeneratorScreenState();
}

class _InfographicGeneratorScreenState extends State<InfographicGeneratorScreen> {
  final TextEditingController _notesController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final OcrService _ocrService = OcrService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  GeneratorState _state = GeneratorState.input;
  String _statusMsg = 'Analyzing notes...';
  Uint8List? _generatedImage;
  String? _docId;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _notesController.text = widget.existingData!['notes'] ?? '';
      _docId = widget.existingData!['id'];
      final base64Image = widget.existingData!['imageData'];
      if (base64Image != null) {
        _generatedImage = base64.decode(base64Image);
        _state = GeneratorState.result;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ------------------- OCR & Input Logic -------------------

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _processFile(File(image.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      _processFile(File(result.files.single.path!));
    }
  }

  Future<void> _processFile(File file) async {
    setState(() {
      _isExtracting = true;
      _statusMsg = 'Extracting text...';
    });
    try {
      String text = '';
      final path = file.path.toLowerCase();
      if (path.endsWith('.pdf')) {
        text = await _ocrService.extractTextFromPdf(file);
      } else if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
        text = await _ocrService.extractTextFromImage(file);
      } else {
        text = await file.readAsString();
      }

      if (mounted) {
        setState(() {
          _notesController.text += '\n$text';
        });
      }
    } catch (e) {
      _showSnackBar('Extraction failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  // ------------------- Generation Logic -------------------

  Future<void> _generateInfographic() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      _showSnackBar('Please enter or upload some notes first!', Colors.orange);
      return;
    }

    setState(() {
      _state = GeneratorState.processing;
      _statusMsg = 'Drafting visual structure...';
    });

    try {
      // Stage 1: Text to Visual Prompt
      final analysisPrompt = """
Analyze these study notes and create a detailed VISUAL PROMPT for an image generation model.
Your goal is to describe a high-quality, professional educational infographic.

NOTES:
$notes

INSTRUCTIONS:
1. Identify 3-4 key points.
2. Describe a layout with vibrant colors, icons, and clear sections.
3. Use a "Modern Premium" style featuring:
   - 3D extruded elements with soft shadows and глубинные эффекты (Depth effects).
   - A central hub layout (Hexagonal, circular, or semi-circle) as seen in high-end business infographics.
   - Vibrant, professional color palettes (e.g., Deep Purples, Emerald Greens, Vibrant Oranges).
   - Glassmorphism effects and clean typography placeholders.
4. DO NOT include person names or specific UI text, just the visual description.
5. Provide a description of around 50-80 words.
""";
      
      final visualPrompt = await _geminiService.summarize(analysisPrompt);
      
      // Save Record (Text-First)
      _docId = await _firestoreService.saveInfographic(
        userId: FirebaseAuth.instance.currentUser!.uid,
        notes: notes,
        prompt: visualPrompt,
      );

      setState(() => _statusMsg = 'Rendering infographic...');

      // Stage 2: Prompt to Image
      final base64Image = await _geminiService.generateImage("Infographic layout for: $visualPrompt");
      
      if (base64Image != null) {
        final bytes = base64.decode(base64Image);
        setState(() {
          _generatedImage = bytes;
          _state = GeneratorState.result;
        });

        // Async Background Tasks
        _saveImageLocally(_docId!, bytes);
        _firestoreService.updateInfographicImage(
          FirebaseAuth.instance.currentUser!.uid, 
          _docId!, 
          base64Image
        );
      } else {
        throw Exception('Image generation returned empty.');
      }
    } catch (e) {
      _showSnackBar('Generation failed: $e', Colors.red);
      setState(() => _state = GeneratorState.input);
    }
  }

  Future<void> _saveImageLocally(String id, Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/infographic_$id.png');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Local save error: $e');
    }
  }

  Future<void> _downloadImage() async {
    if (_generatedImage == null) return;
    try {
      Directory saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) saveDir = (await getExternalStorageDirectory())!;
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }
      
      final fileName = 'Infographic_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(_generatedImage!);
      _showSnackBar('✅ Saved to ${Platform.isAndroid ? 'Downloads' : 'Photos'}!', Colors.green);
    } catch (e) {
      _showSnackBar('Save failed: $e', Colors.red);
    }
  }

  void _shareImage() async {
    if (_generatedImage == null || _docId == null) return;
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/infographic.png').writeAsBytes(_generatedImage!);
    await Share.shareXFiles([XFile(file.path)], text: 'Check out this infographic I generated with Mentor AI!');
  }

  void _showFullScreenImage() {
    if (_generatedImage == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenImageViewer(
          imageBytes: _generatedImage,
          title: 'Infographic Full View',
          onDownload: _downloadImage,
          onShare: _shareImage,
        ),
      ),
    );
  }

  // ------------------- UI Builders -------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(_state == GeneratorState.result ? 'Visual Summary' : 'Infographic Creator'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D2B4E),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildCurrentState(),
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case GeneratorState.input:
        return _buildInputView();
      case GeneratorState.processing:
        return _buildProcessingView();
      case GeneratorState.result:
        return _buildResultView();
    }
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildActionChips(),
          const SizedBox(height: 20),
          _buildNotesInput(),
          const SizedBox(height: 40),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Visualize your knowledge",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2B4E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Paste your notes or upload a document to create a professional infographic.",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionChips() {
    return Row(
      children: [
        _buildChip(Icons.image_rounded, "Photo", _pickImage, Colors.blue),
        const SizedBox(width: 12),
        _buildChip(Icons.picture_as_pdf_rounded, "Document", _pickFile, Colors.red),
        const Spacer(),
        if (_notesController.text.isNotEmpty)
          IconButton(
            onPressed: () => setState(() => _notesController.clear()),
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          TextField(
            controller: _notesController,
            maxLines: 8,
            style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: "Enter your study notes here...",
              hintStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.all(24),
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
                      const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      Text(_statusMsg, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _generateAndSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: Text(
          "GENERATE INFOGRAPHIC",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
        ),
      ),
    );
  }

  void _generateAndSave() {
     _generateInfographic();
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/success.json', width: 250),
          const SizedBox(height: 24),
          Text(
            _statusMsg,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D2B4E)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Our AI is distilling your notes into a beautiful visual report.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showFullScreenImage,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _generatedImage != null ? Image.memory(_generatedImage!) : const SizedBox(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildQuickButton(Icons.download_rounded, "SAVE TO DEVICE", _downloadImage, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickButton(Icons.share_rounded, "SHARE", _shareImage, Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() => _state = GeneratorState.input),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("CREATE ANOTHER"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}
