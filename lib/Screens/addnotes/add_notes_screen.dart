import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Providers/addNoteProvider.dart';
import '../../config/creditConfig.dart';
import '../../google_analytics.dart';
import '../../services/Firestore_service.dart';
import '../../services/creditService.dart';
import '../../services/geminiService.dart';
import '../../services/ocrService.dart';
import '../../widgets/addNotes/add_note_widgets.dart';
import 'fullTextScreen.dart';

class AddNotesScreen extends StatefulWidget {
  const AddNotesScreen({super.key});

  @override
  State<AddNotesScreen> createState() => _AddNotesScreenState();
}

class _AddNotesScreenState extends State<AddNotesScreen> {
  late AddNoteProvider provider;
  final TextEditingController _tagController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  bool _generateSummary = false;

  @override
  void dispose() {
    _titleController.dispose();
    provider.ocrService.dispose();
    _tagController.dispose();
    _titleFocusNode.dispose();
    _tagFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

/*
  @override
  void initState() {
    super.initState();
    final ocr = OcrService();
    final fs = FirestoreService();
    final gemini = GeminiService();
    provider = AddNoteProvider(
        ocrService: ocr, firestoreService: fs, geminiService: gemini);
  }
*/
  @override
  void initState() {
    super.initState();
    // Log analytics when screen opens
    AnalyticsService.logCreateNoteClick();

    final ocr = OcrService();
    final fs = FirestoreService();
    final gemini = GeminiService();
    provider = AddNoteProvider(
        ocrService: ocr, firestoreService: fs, geminiService: gemini);
  }
  Future<void> _pickImageFromCamera() async {
    final XFile? picked =
    await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) provider.addFile(File(picked.path));
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? picked =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) provider.addFile(File(picked.path));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      provider.addFile(file);
    }
  }

  Future<void> _startOcrFlow() async {
    if (provider.files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please attach an image or PDF first.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    // Show confirmation dialog for OCR with optional summary generation
    final bool? confirm = true;

    if (confirm == true) {
      // Deduct credits and proceed with OCR
      final int totalCost =  (_generateSummary ? CreditsConfig.aiSummary : 0);

      await CreditsService.confirmUsageAndCheckBalance(
        context: context,
        actionName: "OCR & Summary Generation",
        onConfirmedAction: () async {
          await provider.runOcrOnFiles();

          if (_generateSummary && provider.content.isNotEmpty) {
            await provider.generateAiSummary();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Text extracted and summary generated!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Text extracted!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }

          // Reset summary option for next time
          setState(() {
            _generateSummary = false;
          });
        },
      );
    }
  }

  Future<void> _useCurrentTextFlow() async {
    if (provider.content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please add some content first'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    if (_generateSummary) {
      // If summary generation is enabled, ask for confirmation and deduct credits
      await CreditsService.confirmUsageAndCheckBalance(
        context: context,
        actionName: "AI Summary Generation",
        onConfirmedAction: () async {
          await provider.generateAiSummary();
          provider.setState(AddNoteState.confirming);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Summary generated!"),
                backgroundColor: Colors.green,
              ),
            );
          }

          // Reset summary option for next time
          setState(() {
            _generateSummary = false;
          });
        },
      );
    } else {
      // If no summary generation, just proceed to confirming state
      provider.setState(AddNoteState.confirming);
    }
  }

  Future<void> _askForSummary() async {
    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "AI Summary Generation",
      onConfirmedAction: () async {
        await provider.generateAiSummary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Summary generated!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  Future<void> _saveNote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    await provider.saveNoteToFirestore(uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Note saved successfully! 🎉'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.green.shade600,
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _editContentDialog() async {
    final controller = TextEditingController(text: provider.content);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Extracted Text',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Changes',style: TextStyle(color: Colors.white),),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      provider.setContent(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[800];

    // Responsive sizing values
    final double horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final double elementSpacing = isSmallScreen ? 12.0 : 16.0;
    final double smallElementSpacing = isSmallScreen ? 8.0 : 12.0;
    final double buttonHeight = isSmallScreen ? 48.0 : 52.0;
    final double inputOptionSize = isSmallScreen ? 90.0 : 100.0;
    final double inputOptionIconSize = isSmallScreen ? 28.0 : 32.0;
    final double inputOptionTextSize = isSmallScreen ? 12.0 : 14.0;
    final double titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final double tagChipFontSize = isSmallScreen ? 12.0 : 14.0;

    return ChangeNotifierProvider<AddNoteProvider>.value(
      value: provider,
      child: Consumer<AddNoteProvider>(builder: (context, p, _) {
        return GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping anywhere on the screen
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,

          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: Text('Create New Note',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isSmallScreen ? 18.0 : 20.0)),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              elevation: 0,
              centerTitle: false,
              actions: [
                IconButton(
                  icon: Icon(Icons.help_outline,
                      color: Colors.purple.shade600,
                      size: isSmallScreen ? 20.0 : 24.0),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final double screenWidth = MediaQuery.of(context).size.width;
                            final double screenHeight = MediaQuery.of(context).size.height;
                            final bool isSmallScreen = screenWidth < 360;
                            final bool isTablet = screenWidth > 600;
                            final bool isLargeTablet = screenWidth > 900;

                            // Responsive sizing
                            final double titleSize = isSmallScreen ? 18 : (isTablet ? 24 : 20);
                            final double textSize = isSmallScreen ? 14 : (isTablet ? 18 : 16);
                            final double buttonTextSize = isSmallScreen ? 14 : (isTablet ? 18 : 16);
                            final double handleWidth = isSmallScreen ? 30 : (isTablet ? 50 : 40);
                            final double handleHeight = isSmallScreen ? 4 : (isTablet ? 6 : 5);

                            // Responsive padding
                            final double horizontalPadding = isSmallScreen ? 16 : (isTablet ? 32 : 24);
                            final double verticalPadding = isSmallScreen ? 16 : (isTablet ? 28 : 24);
                            final double spacing = isSmallScreen ? 12 : (isTablet ? 20 : 16);
                            final double smallSpacing = isSmallScreen ? 8 : (isTablet ? 12 : 10);
                            final double buttonPadding = isSmallScreen ? 12 : (isTablet ? 18 : 16);
                            final double buttonRadius = isSmallScreen ? 10 : (isTablet ? 14 : 12);

                            return Container(
                              constraints: BoxConstraints(
                                maxHeight: screenHeight * 0.8,
                              ),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: verticalPadding,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: handleWidth,
                                          height: handleHeight,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: spacing),

                                      Text(
                                        'How It Works',
                                        style: TextStyle(
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: smallSpacing),

                                      Text(
                                        '1. Capture or select content using camera, gallery, or PDF\n\n'
                                            '2. Extract text using OCR or type manually\n\n'
                                            '3. Edit and organize with tags\n\n'
                                            '4. Optionally generate AI summary\n\n'
                                            '5. Save to your personal library',
                                        style: TextStyle(
                                          fontSize: textSize,
                                          height: isSmallScreen ? 1.4 : (isTablet ? 1.7 : 1.5),
                                        ),
                                      ),
                                      SizedBox(height: spacing),

                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple.shade600,
                                            padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(buttonRadius),
                                            ),
                                          ),
                                          child: Text(
                                            'Got It!',
                                            style: TextStyle(
                                              fontSize: buttonTextSize,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 10),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                )
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(horizontalPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title input
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child:Consumer<AddNoteProvider>(
                                        builder: (context, provider, child) {
                                          final isSmallScreen = MediaQuery.of(context).size.width < 360;

                                          // Keep controller in sync with provider
                                          if (_titleController.text != provider.title) {
                                            _titleController.text = provider.title;
                                            _titleController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: _titleController.text.length),
                                            );
                                          }

                                          return TextField(
                                            controller: _titleController,
                                            focusNode: _titleFocusNode,
                                            onChanged: provider.setTitle,
                                            style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                                            decoration: InputDecoration(
                                              hintText: 'Note title (e.g., Math Chapter 3 Notes)',
                                              border: InputBorder.none,
                                              hintStyle: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: isSmallScreen ? 14.0 : 16.0,
                                              ),
                                            ),
                                          );
                                        },
                                      ),


                                    ),
                                    if (p.title.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey.shade600,
                                            size: isSmallScreen ? 18.0 : 24.0),
                                        onPressed: () {
                                          provider.setTitle('');
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: elementSpacing),

                            // Tag input
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tags',
                                    style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: smallElementSpacing),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[800] : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: TextField(
                                            controller: _tagController,
                                            focusNode: _tagFocusNode,
                                            style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                                            decoration: InputDecoration(
                                              hintText: 'Add a tag (e.g., math, biology)',
                                              border: InputBorder.none,
                                              hintStyle: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: isSmallScreen ? 14.0 : 16.0),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: smallElementSpacing),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.add,
                                            color: Colors.white,
                                            size: isSmallScreen ? 18.0 : 24.0),
                                        onPressed: () {
                                          if (_tagController.text.trim().isNotEmpty) {
                                            p.addTag(_tagController.text.trim());
                                            _tagController.clear();
                                            _tagFocusNode.unfocus();
                                          }else{
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Write something to add tag ")));
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: smallElementSpacing),

                            // Tag chips
                            if (p.tags.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: p.tags
                                    .map((tag) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 8.0 : 12.0,
                                      vertical: isSmallScreen ? 6.0 : 8.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          color: Colors.purple.shade800,
                                          fontWeight: FontWeight.w500,
                                          fontSize: tagChipFontSize,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 4.0 : 6.0),
                                      GestureDetector(
                                        onTap: () {
                                          p.removeTag(tag);
                                        },
                                        child: Icon(
                                          Icons.close,
                                          size: isSmallScreen ? 14.0 : 16.0,
                                          color: Colors.purple.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                                    .toList(),
                              ),

                            SizedBox(height: elementSpacing),

                            // Input options header
                            Text('Add Content',
                                style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: smallElementSpacing),

                            // Input options
                            SizedBox(
                              height: inputOptionSize + 30,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildInputOption(
                                    icon: Icons.camera_alt_rounded,
                                    title: 'Camera',
                                    color: Colors.blue,
                                    onTap: _pickImageFromCamera,
                                    size: inputOptionSize,
                                    iconSize: inputOptionIconSize,
                                    textSize: inputOptionTextSize,
                                  ),
                                  SizedBox(width: smallElementSpacing),
                                  _buildInputOption(
                                    icon: Icons.photo_library_rounded,
                                    title: 'Gallery',
                                    color: Colors.green,
                                    onTap: _pickImageFromGallery,
                                    size: inputOptionSize,
                                    iconSize: inputOptionIconSize,
                                    textSize: inputOptionTextSize,
                                  ),

                                  SizedBox(width: smallElementSpacing),
                                  _buildInputOption(
                                    icon: Icons.keyboard_alt_rounded,
                                    title: 'Type Text',
                                    color: Colors.purple,
                                    onTap: () async {
                                      final result = await showDialog<Map<String, dynamic>?>(
                                          context: context,
                                          builder: (c) {
                                            final ctrl = TextEditingController();
                                            bool generateSummaryLocal = false;
                                            return StatefulBuilder(
                                              builder: (context, setDialogState) {
                                                return Dialog(
                                                  backgroundColor: Colors.transparent,
                                                  child: SingleChildScrollView(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).scaffoldBackgroundColor,
                                                        borderRadius: BorderRadius.circular(20),
                                                      ),
                                                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Type Your Note',
                                                            style: TextStyle(
                                                                fontSize: isSmallScreen ? 18.0 : 20.0,
                                                                fontWeight: FontWeight.bold),
                                                          ),
                                                          SizedBox(height: smallElementSpacing),
                                                          TextField(
                                                            controller: ctrl,
                                                            maxLines: 8,
                                                            decoration: InputDecoration(
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              filled: true,
                                                              hintText: 'Start typing your note here...',
                                                            ),
                                                          ),
                                                          SizedBox(height: elementSpacing),
                                                          
                                                          // AI Summary Toggle
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              color: isDark ? Colors.grey[800] : Colors.grey[50],
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            padding: EdgeInsets.all(12),
                                                            child: Row(
                                                              children: [
                                                                Icon(Icons.summarize_rounded,
                                                                    color: Colors.orange.shade600,
                                                                    size: isSmallScreen ? 18.0 : 20.0),
                                                                SizedBox(width: 8),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(
                                                                        'Generate AI Summary',
                                                                        style: TextStyle(
                                                                            fontSize: isSmallScreen ? 13.0 : 14.0,
                                                                            fontWeight: FontWeight.w600),
                                                                      ),
                                                                      SizedBox(height: 2),
                                                                      Text(
                                                                        'Costs ${CreditsConfig.aiSummary} credits',
                                                                        style: TextStyle(
                                                                          fontSize: isSmallScreen ? 11.0 : 12.0,
                                                                          color: Colors.grey.shade600,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Switch(
                                                                  value: generateSummaryLocal,
                                                                  onChanged: (val) {
                                                                    setDialogState(() {
                                                                      generateSummaryLocal = val;
                                                                    });
                                                                  },
                                                                  activeColor: Colors.orange.shade600,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          
                                                          SizedBox(height: elementSpacing),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.end,
                                                            children: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(c),
                                                                child: const Text('Cancel'),
                                                              ),
                                                              SizedBox(width: smallElementSpacing),
                                                              ElevatedButton(
                                                                onPressed: () => Navigator.pop(c, {
                                                                  'text': ctrl.text,
                                                                  'generateSummary': generateSummaryLocal,
                                                                }),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Colors.purple.shade600,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                ),
                                                                child: const Text('Add Text',style: TextStyle(color: Colors.white),),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          });
                                      if (result != null && result['text'] != null && result['text'].isNotEmpty) {
                                        provider.setContent(result['text']);
                                        
                                        // If summary generation is requested, handle it with credit deduction
                                        if (result['generateSummary'] == true) {
                                          await CreditsService.confirmUsageAndCheckBalance(
                                            context: context,
                                            actionName: "AI Summary Generation",
                                            onConfirmedAction: () async {
                                              await provider.generateAiSummary();
                                              provider.setState(AddNoteState.confirming);

                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text("Summary generated!"),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        } else {
                                          provider.setState(AddNoteState.confirming);
                                        }
                                      }
                                    },
                                    size: inputOptionSize,
                                    iconSize: inputOptionIconSize,
                                    textSize: inputOptionTextSize,
                                  ),
                                  SizedBox(width: smallElementSpacing),
                                  _buildInputOption(
                                    icon: Icons.picture_as_pdf_rounded,
                                    title: 'PDF',
                                    color: Colors.red,
                                    onTap: _pickPdf,
                                    size: inputOptionSize,
                                    iconSize: inputOptionIconSize,
                                    textSize: inputOptionTextSize,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: elementSpacing),

                            // Generate Summary Toggle (similar to the one below extracted text)
                            if (p.files.isNotEmpty || p.content.isNotEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.all(elementSpacing),
                                child: Row(
                                  children: [
                                    Icon(Icons.summarize_rounded,
                                        color: Colors.orange.shade600,
                                        size: isSmallScreen ? 18.0 : 24.0),
                                    SizedBox(width: smallElementSpacing),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Generate AI Summary',
                                            style: TextStyle(
                                                fontSize: isSmallScreen ? 14.0 : 16.0,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Extract text and generate summary : This action (Summary Generation) will deduct ${CreditsConfig.aiSummary} Credits',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12.0 : 13.0,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _generateSummary,
                                      onChanged: (val) {
                                        setState(() {
                                          _generateSummary = val;
                                        });
                                      },
                                      activeColor: Colors.orange.shade600,
                                    ),
                                  ],
                                ),
                              ),

                            if (p.files.isNotEmpty || p.content.isNotEmpty)
                              SizedBox(height: elementSpacing),

                            // Attached files
                            if (p.files.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Attached Files',
                                      style: TextStyle(
                                          fontSize: titleFontSize,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(height: smallElementSpacing),
                                  SizedBox(
                                    height: inputOptionSize,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: p.files.length,
                                      itemBuilder: (context, i) {
                                        final f = p.files[i];
                                        final ext = f.path.split('.').last.toLowerCase();
                                        final fileName = f.path.split('/').last;

                                        Widget preview;
                                        if (['jpg', 'jpeg', 'png'].contains(ext)) {
                                          preview = ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(f,
                                                width: inputOptionSize,
                                                height: inputOptionSize,
                                                fit: BoxFit.cover),
                                          );
                                        } else if (ext == 'pdf') {
                                          preview = Container(
                                            width: inputOptionSize,
                                            height: inputOptionSize,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.picture_as_pdf_rounded,
                                                    size: inputOptionIconSize,
                                                    color: Colors.red.shade600),
                                                SizedBox(height: 4),
                                                Text(
                                                  fileName.length > 12 ? '${fileName.substring(0, 10)}...' : fileName,
                                                  style: TextStyle(fontSize: inputOptionTextSize),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          preview = Container(
                                            width: inputOptionSize,
                                            height: inputOptionSize,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.insert_drive_file_rounded,
                                                    size: inputOptionIconSize),
                                                SizedBox(height: 4),
                                                Text(
                                                  fileName.length > 12 ? '${fileName.substring(0, 10)}...' : fileName,
                                                  style: TextStyle(fontSize: inputOptionTextSize),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        return Container(
                                          margin: EdgeInsets.only(right: smallElementSpacing),
                                          child: Stack(
                                            children: [
                                              preview,
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    p.removeFile(f);
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.6),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding: const EdgeInsets.all(4),
                                                    child: Icon(Icons.close,
                                                        size: isSmallScreen ? 14.0 : 16.0,
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),

                            SizedBox(height: elementSpacing),

                            // OCR / use current text buttons
                            if (p.state == AddNoteState.idle || p.state == AddNoteState.picking)
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.document_scanner_rounded,
                                          size: isSmallScreen ? 18.0 : 24.0),
                                      onPressed: _startOcrFlow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      label: Text('Extract Text (OCR)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 14.0 : 16.0)),
                                    ),
                                  ),
                                  SizedBox(height: smallElementSpacing),
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: OutlinedButton.icon(
                                      icon: Icon(Icons.text_fields_rounded,
                                          size: isSmallScreen ? 18.0 : 24.0),
                                      onPressed: _useCurrentTextFlow,
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      label: Text('Use Current Text',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 14.0 : 16.0)),
                                    ),
                                  ),
                                ],
                              ),

                            // Processing indicator
                            if (p.state == AddNoteState.ocrProcessing)
                              Padding(
                                padding: EdgeInsets.all(elementSpacing),
                                child: Column(
                                  children: [
                                    const CircularProgressIndicator(),
                                    SizedBox(height: elementSpacing),
                                    Text(
                                      'Extracting text...',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14.0 : 16.0,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Confirming content & AI summary
                            if (p.state == AddNoteState.confirming && p.content.isNotEmpty)
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      // Extracted Text Card
                                      Container(
                                        padding: EdgeInsets.all(elementSpacing),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'EXTRACTED TEXT',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.purple,
                                                      letterSpacing: 1.2),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.edit_note_rounded,
                                                      color: Colors.purple.shade600,
                                                      size: 24),
                                                  onPressed: _editContentDialog,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              p.content,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.5,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => FullTextScreen(
                                                          title: 'Extracted Text', text: p.content),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                                                label: const Text('View Full'),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.purple.shade600,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: elementSpacing),

                                      // AI Summary Card
                                      if (p.summary != null)
                                        Container(
                                          padding: EdgeInsets.all(elementSpacing),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.amber.shade400,
                                                Colors.amber.shade600,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withOpacity(0.3),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'AI SUMMARY',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 1.1),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                p.summary!,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  height: 1.5,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => FullTextScreen(
                                                            title: 'AI Summary', text: p.summary!),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                                                  label: const Text('View Full', style: TextStyle(color: Colors.white)),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      if (p.summary != null) SizedBox(height: elementSpacing),

                                      // Action buttons
                                      Column(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            height: buttonHeight,
                                            child: ElevatedButton.icon(
                                              icon: p.state == AddNoteState.saving
                                                  ? SizedBox(
                                                width: isSmallScreen ? 14.0 : 16.0,
                                                height: isSmallScreen ? 14.0 : 16.0,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2, color: Colors.white),
                                              )
                                                  : Icon(Icons.save_rounded,
                                                  size: isSmallScreen ? 18.0 : 24.0),
                                              onPressed: _saveNote,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.purple.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              label: Text(
                                                p.state == AddNoteState.saving ? 'Saving...' : 'Save to Library',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: isSmallScreen ? 14.0 : 16.0),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: smallElementSpacing),
                                          SizedBox(
                                            width: double.infinity,
                                            height: buttonHeight,
                                            child: OutlinedButton.icon(
                                              icon: Icon(Icons.clear_rounded,
                                                  size: isSmallScreen ? 18.0 : 24.0),
                                              onPressed: () {
                                                p.setState(AddNoteState.idle);
                                                p.clearFiles();
                                                p.setContent('');
                                                setState(() {
                                                  _generateSummary = false;
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              label: Text('Cancel',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: isSmallScreen ? 14.0 : 16.0)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Error
                            if (p.state == AddNoteState.error)
                              Container(
                                padding: EdgeInsets.all(elementSpacing),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded,
                                        color: Colors.red.shade600,
                                        size: isSmallScreen ? 18.0 : 24.0),
                                    SizedBox(width: smallElementSpacing),
                                    Expanded(
                                      child: Text(
                                        p.errorMessage ?? 'An unknown error occurred',
                                        style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: isSmallScreen ? 13.0 : 15.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInputOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required double size,
    required double iconSize,
    required double textSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: EdgeInsets.all(size * 0.16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: color),
            SizedBox(height: size * 0.08),
            Text(
              title,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}