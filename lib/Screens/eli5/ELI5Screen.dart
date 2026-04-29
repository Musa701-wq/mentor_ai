import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/geminiService.dart';
import '../../services/Firestore_service.dart';
import '../../services/creditService.dart';

enum ELI5State { hub, generator, result, history }

class ELI5Screen extends StatefulWidget {
  const ELI5Screen({super.key});

  @override
  State<ELI5Screen> createState() => _ELI5ScreenState();
}

class _ELI5ScreenState extends State<ELI5Screen> with TickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController();
  String _selectedLevel = 'Beginner';
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  bool _isSaving = false;
  Uint8List? _imageBytes;
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  late AnimationController _dotController;
  ELI5State _state = ELI5State.hub;
  Map<String, dynamic>? _selectedHistoryItem;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }


  @override
  void dispose() {
    _dotController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateExplanation() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      _showSnackBar('Please enter a topic explored!', Colors.orange);
      return;
    }

    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "ELI5 Generation",
      onConfirmedAction: () async {
        setState(() {
          _isLoading = true;
          _result = null;
          _selectedHistoryItem = null;
          _imageBytes = null;
        });

        try {
          final result = await _geminiService.getELI5Explanation(topic, _selectedLevel);
          
          // Usage deduction
          await CreditsService().deductUsage(
            tokens: _geminiService.lastEstimatedTokens, 
            actionName: "ELI5 Generation"
          );

          Map<String, dynamic> finalSaveData = {
            'topic': topic,
            'level': _selectedLevel,
            ...result,
          };

          setState(() {
            _result = result;
            _state = ELI5State.result;
          });

          // Auto-save TEXT content first (immediately after generation)
          final uid = FirebaseAuth.instance.currentUser?.uid;
          String? savedDocId;
          if (uid != null) {
            try {
              savedDocId = await _firestoreService.saveELI5(uid, {
                'topic': topic,
                'level': _selectedLevel,
                ...result,
              });
            } catch (e) {
              debugPrint('Error saving initial history: $e');
            }
          }

          // Generate image if required
          if (result['imageRequired'] == true && result['imageSearchQuery'] != null) {
            debugPrint('🎨 Attempting to generate image for: ${result['imageSearchQuery']}');
            final base64String = await _geminiService.generateImage(result['imageSearchQuery']);
            if (base64String != null) {
              setState(() {
                _imageBytes = base64Decode(base64String);
              });
              
              // 🚀 [LOCAL SAVE] Save to device immediately for maximum reliability
              if (savedDocId != null) {
                await _saveImageLocally(savedDocId, _imageBytes!);
              }
              
              // Update Firestore record with image data if record was created
              if (uid != null && savedDocId != null) {
                try {
                  await _firestoreService.updateELI5Image(uid, savedDocId, base64String);
                } catch (e) {
                  debugPrint('⚠️ Error updating image in Firestore (likely too large): $e');
                  // No snackbar here to avoid annoying user, since local save already worked
                }
              }
            } else {
              debugPrint('⚠️ Image generation failed or returned null.');
              setState(() {
                _result!['imageRequired'] = false;
              });
            }
          }
        } catch (e) {
          _showSnackBar('Oops! Something went wrong: $e', Colors.red);
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
    );
  }

  Future<void> _showSmartActionDialog(String text, String action) async {
    debugPrint('🚀 _showSmartActionDialog triggered for action: $action with text: "$text"');
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      debugPrint('⚠️ Cleaned text is empty, returning.');
      return;
    }

    await CreditsService.confirmUsageAndCheckBalance(
      context: context,
      actionName: "Smart Action",
      minBalance: 0.1, // Small check for small action
      onConfirmedAction: () async {
        String title;
        IconData icon;
        Color iconColor;
        Future<String> aiFuture;

        switch (action) {
          case 'Summarize':
            title = 'Summary';
            icon = Icons.summarize_rounded;
            iconColor = Colors.teal;
            aiFuture = _geminiService.getExcerptSummary(cleanedText);
            break;
          case 'Describe':
            title = 'Quick Explanation';
            icon = Icons.psychology_alt_rounded;
            iconColor = Colors.orange;
            aiFuture = _geminiService.getExcerptExplanation(cleanedText);
            break;
          case 'Meaning':
          default:
            title = 'Meaning of "${cleanedText.split(' ').first}${cleanedText.split(' ').length > 1 ? '...' : ''}"';
            icon = Icons.translate_rounded;
            iconColor = Colors.indigo;
            aiFuture = _geminiService.getWordMeaning(cleanedText);
            break;
        }

        // Usage deduction after future completes (or inside the FutureBuilder)
        // Since it's a FutureBuilder, we should wrap the aiFuture to deduct after it finishes
        final wrappedFuture = aiFuture.then((res) async {
          await CreditsService().deductUsage(
            tokens: _geminiService.lastEstimatedTokens, 
            actionName: "Smart Action ($action)"
          );
          return res;
        });

        debugPrint('💬 Showing dialog for: $title');
        if (!mounted) {
          debugPrint('❌ Widget not mounted, cannot show dialog.');
          return;
        }

        // Use addPostFrameCallback to ensure the context menu is fully dismissed first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: this.context,
            barrierDismissible: true,
            builder: (context) {
              debugPrint('🎨 Building Professional Dialog');
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROFESSIONAL HEADER
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.03),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: iconColor,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2D2B4E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                              style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                            ),
                          ],
                        ),
                      ),

                      // CONTENT AREA
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                          child: FutureBuilder<String>(
                            future: wrappedFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Curating Explanation...',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                    child: Text(
                                      'Service temporarily unavailable. Please try again.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(color: Colors.red[400], fontSize: 14),
                                    ),
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  snapshot.data ?? 'No information found for this selection.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    height: 1.7,
                                    color: const Color(0xFF4A4972),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // FOOTER ACTIONS
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D2B4E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Acknowledged',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }

  Future<void> _showWordMeaningDialog(String word) async {
    await _showSmartActionDialog(word, 'Meaning');
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildVibrantBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildStateContent(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVibrantBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade100,   // Light lavender
            Colors.blue.shade100,     // Soft blue
            Colors.teal.shade100,     // Gentle teal
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_state == ELI5State.hub) {
                Navigator.pop(context);
              } else if (_state == ELI5State.result && _selectedHistoryItem != null) {
                 setState(() => _state = ELI5State.history);
              } else {
                setState(() => _state = ELI5State.hub);
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2B4E)),
          ),
          const SizedBox(width: 8),
          Text(
            _state == ELI5State.hub ? 'ELI5 Mentor' : 
            _state == ELI5State.generator ? 'New Topic' :
            _state == ELI5State.history ? 'Recent Activity' : 'Topic Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D2B4E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_state) {
      case ELI5State.hub:
        return _buildHub();
      case ELI5State.generator:
        return Column(
          children: [
            const SizedBox(height: 20),
            _buildInputSection(),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              _buildTypingState(),
            ],
          ],
        );
      case ELI5State.result:
        return _buildResultSection(
          _selectedHistoryItem ?? _result!, 
          _selectedHistoryItem != null ? (_selectedHistoryItem!['topic'] ?? 'Stored Topic') : _topicController.text, 
          true
        );
      case ELI5State.history:
        return _buildHistoryView();
    }
  }

  Widget _buildHub() {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildHubCard(
          title: "Describe a New Topic",
          subtitle: "Explain any complex concept in simple terms",
          icon: Icons.psychology_rounded,
          colors: [const Color(0xFF6C63FF), const Color(0xFF8A84FF)],
          onTap: () => setState(() => _state = ELI5State.generator),
        ),
        const SizedBox(height: 16), // Reduced from 20
        _buildHubCard(
          title: "Revisit Activity",
          subtitle: "Check your previously saved explanations",
          icon: Icons.history_rounded,
          colors: [const Color(0xFF00C853), const Color(0xFF2E7D32)], // Changed to a more vibrant green
          onTap: () => setState(() => _state = ELI5State.history),
        ),
      ],
    );
  }

  Widget _buildHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final historyColors = [
      Colors.indigo,
      Colors.deepPurple,
      Colors.teal,
      Colors.blueGrey,
      Colors.blue,
      Colors.purple,
    ];

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getELI5HistoryStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity found',
                    style: GoogleFonts.poppins(color: Colors.grey[500], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = history[index];
                final color = historyColors[index % historyColors.length];
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.85), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () async {
                        final docId = item['id'] ?? '';
                        final localImage = await _getLocalImage(docId);
                        
                        setState(() {
                          _selectedHistoryItem = item;
                          // Prefer local image (highest quality & reliability), fallback to Firestore sync
                          if (localImage != null) {
                            _imageBytes = localImage;
                          } else if (item['imageData'] != null) {
                            _imageBytes = base64Decode(item['imageData']);
                          } else {
                            _imageBytes = null;
                          }
                          _state = ELI5State.result;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['topic'] ?? 'Unknown Topic').toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item['level'] ?? 'Beginner',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }



  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topic Name',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Black Hole, Inflation, AI...',
              hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: Colors.black.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Category Level',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildLevelSelector(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    final levels = ['Beginner', 'Intermediate', 'Advanced'];
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
      children: levels.map((level) {
        final isSelected = _selectedLevel == level;
        return GestureDetector(
          onTap: () => setState(() => _selectedLevel = level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Text(
              level,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        );
      }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _generateExplanation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_rounded, size: 24),
            const SizedBox(width: 12),
            Text(
              'Simplify Instantly',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(Map<String, dynamic> data, String topic, bool isMain) {
    final bool hasImage = data['imageRequired'] == true && data['imageSearchQuery'] != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PDF-STYLE HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isMain ? Colors.grey.shade50 : Colors.indigo.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(
                  isMain ? Icons.description_outlined : Icons.bookmark_added_rounded,
                  color: Colors.indigo,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isMain ? "Topic Breakdown Report" : "Saved Generation",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (isMain) const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE
                Text(
                  topic.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: isMain ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D2B4E),
                    height: 1.2,
                  ),
                ),
                const Divider(height: 32, thickness: 1.5),
                
                // INTERACTIVE TIP
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.orangeAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Tip: Highlight any text to get instant explanations!",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DEFINITION SECTION
                _buildSectionTitle("DEFINITION"),
                SelectableText(
                  data['definition'] ?? 'No definition provided.',
                  contextMenuBuilder: (context, editableTextState) {
                    return _buildContextMenu(context, editableTextState);
                  },
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // IMAGE
                if (hasImage) ...[
                  _buildAIImage(data['imageSearchQuery']),
                  const SizedBox(height: 24),
                ],

                // EXPLANATION
                _buildSectionTitle("DETAILED EXPLANATION"),
                SelectableText(
                  (data['explanation'] ?? 'No explanation provided.').replaceAll('•', '\n•').trim(),
                  contextMenuBuilder: (context, editableTextState) {
                    return _buildContextMenu(context, editableTextState);
                  },
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),

                // ANALOGY
                _buildSectionTitle("ANALOGY / EXAMPLE"),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFCF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.15)),
                  ),
                  child: SelectableText(
                    data['example'] ?? 'No example provided.',
                    contextMenuBuilder: (context, editableTextState) {
                      return _buildContextMenu(context, editableTextState);
                    },
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // USE CASE
                _buildSectionTitle("REAL WORLD USE CASE"),
                SelectableText(
                  data['useCase'] ?? 'No use case provided.',
                  contextMenuBuilder: (context, editableTextState) {
                    return _buildContextMenu(context, editableTextState);
                  },
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAsPDF,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: Text(
                      _isSaving ? "GENERATING PDF..." : "SAVE AS PDF DOCUMENT",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
    final selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
    final bool isLongerText = selectedText.split(' ').length > 2;

    // Add custom "Summarize" button if text is long
    if (isLongerText) {
      buttonItems.insert(0, ContextMenuButtonItem(
        label: 'Summarize',
        onPressed: () {
          ContextMenuController.removeAny();
          _showSmartActionDialog(selectedText, 'Summarize');
        },
      ));
    }

    // Add custom "Describe" button
    buttonItems.insert(0, ContextMenuButtonItem(
      label: 'Describe',
      onPressed: () {
        ContextMenuController.removeAny();
        _showSmartActionDialog(selectedText, 'Describe');
      },
    ));

    // Add custom "Meaning" button for single words or short phrases
    if (!isLongerText) {
      buttonItems.insert(0, ContextMenuButtonItem(
        label: 'Meaning',
        onPressed: () {
          ContextMenuController.removeAny();
          _showSmartActionDialog(selectedText, 'Meaning');
        },
      ));
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey[400],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAIImage(String query) {
    if (!_isLoading && _imageBytes == null && _state == ELI5State.result) {
      // If we are in result mode and no image exists, don't show the empty loading box
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _imageBytes != null
            ? Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Container(
                color: Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Curating Illustration...",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTypingIndicator(),
          const SizedBox(height: 16),
          Text(
            "Simplifying complex concepts...",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final value = (_dotController.value - delay) % 1.0;
            final opacity = value < 0.5 ? value * 2 : (1 - value) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(opacity.clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required int index,
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    // Basic point formatting for better readability if AI returns bullets
    final formattedContent = content.replaceAll('•', '\n•').trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colorful Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              formattedContent,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.7,
                color: const Color(0xFF2D2B4E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- PDF Export Logic -------------------
  Future<void> _saveAsPDF() async {
    if (_result == null) return;
    
    setState(() => _isSaving = true);
    try {
      final topic = (_selectedHistoryItem?['topic'] ?? _result!['topic'] ?? 'Topic').toString();
      final level = (_selectedHistoryItem?['level'] ?? _selectedLevel).toString();
      final intro = _result!['introduction'] ?? '';
      final explanation = _result!['explanation'] ?? '';
      final summary = _result!['summary'] ?? '';

      // 1. Create PDF Document
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      
      // 2. Define Styles
      final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 28, style: PdfFontStyle.bold);
      final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
      final PdfFont subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
      final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      
      double yOffset = 0;

      // 3. Draw Premium Header Band
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(108, 99, 255)), // Brand Purple
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 100),
      );
      
      graphics.drawString(
        'ELI5 ACADEMIC REPORT',
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(20, 20, 0, 0),
      );
      
      graphics.drawString(
        topic.toUpperCase(),
        titleFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(20, 40, page.getClientSize().width - 40, 50),
      );

      yOffset = 120;

      // 4. Draw Level Badge and Date
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(45, 43, 78)),
        bounds: Rect.fromLTWH(20, yOffset, 120, 25),
      );
      graphics.drawString(
        'LEVEL: $level',
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(30, yOffset + 6, 0, 0),
      );
      
      final dateStr = DateFormat('MMM dd, yyyy').format(DateTime.now());
      graphics.drawString(
        'Generated on: $dateStr',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfBrushes.gray,
        bounds: Rect.fromLTWH(page.getClientSize().width - 150, yOffset + 6, 0, 0),
      );

      yOffset += 50;

      // 5. Draw Image (if available)
      if (_imageBytes != null) {
        try {
          final PdfBitmap bitmap = PdfBitmap(_imageBytes!);
          final double imgWidth = 300;
          final double imgHeight = 200;
          final double imgX = (page.getClientSize().width - imgWidth) / 2;
          
          graphics.drawImage(bitmap, Rect.fromLTWH(imgX, yOffset, imgWidth, imgHeight));
          yOffset += imgHeight + 30;
        } catch (e) {
          debugPrint('PDF Image Error: $e');
        }
      }

      // 6. Draw Content Sections
      void drawSection(String title, String content, PdfColor color) {
        // Draw Section Header (Light Background)
        graphics.save();
        graphics.setTransparency(0.08);
        graphics.drawRectangle(
          brush: PdfSolidBrush(color),
          bounds: Rect.fromLTWH(20, yOffset, page.getClientSize().width - 40, 30),
        );
        graphics.restore();
        graphics.drawString(
          title.toUpperCase(),
          subHeaderFont,
          brush: PdfSolidBrush(color),
          bounds: Rect.fromLTWH(30, yOffset + 6, 0, 0),
        );
        yOffset += 40;
        
        // Draw Section Content
        final PdfTextElement element = PdfTextElement(text: content, font: bodyFont);
        element.brush = PdfBrushes.black;
        final PdfLayoutResult result = element.draw(
          page: page,
          bounds: Rect.fromLTWH(25, yOffset, page.getClientSize().width - 50, 0),
        )!;
        yOffset = result.bounds.bottom + 30;
      }

      drawSection('Introduction', intro, PdfColor(108, 99, 255));
      drawSection('Deep Dive Explanation', explanation, PdfColor(0, 150, 136));
      drawSection('Quick Summary', summary, PdfColor(255, 152, 0));

      // 7. Save and Share
      final List<int> bytes = await document.save();
      document.dispose();

      Directory saveDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        saveDir = (await downloadDir.exists()) ? downloadDir : (await getExternalStorageDirectory())!;
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'ELI5_Report_${topic.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      _showSnackBar('✅ Report saved to ${Platform.isAndroid ? 'Downloads' : 'Documents'}!', Colors.green);
    } catch (e) {
      debugPrint('Export failed: $e');
      _showSnackBar('Failed to save PDF: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ------------------- Local Image Caching Logic -------------------
  Future<void> _saveImageLocally(String docId, Uint8List bytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/eli5_$docId.png';
      final file = File(imagePath);
      await file.writeAsBytes(bytes);
      debugPrint('💾 Local Hybrid Save: $imagePath');
    } catch (e) {
      debugPrint('⚠️ Error saving image locally: $e');
    }
  }

  Future<Uint8List?> _getLocalImage(String docId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/eli5_$docId.png';
      final file = File(imagePath);
      if (await file.exists()) {
        debugPrint('📦 Local Hybrid Load: $imagePath');
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading local image: $e');
    }
    return null;
  }
}
