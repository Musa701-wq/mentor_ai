import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/flashcardProvider.dart';
import '../../models/flashcardModel.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final dynamic deck;
  const FlashcardStudyScreen({super.key, required this.deck});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  List<FlashcardModel> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final provider = Provider.of<FlashcardProvider>(context, listen: false);
    final cards = await provider.loadCardsForDeck(widget.deck.id);
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  void _nextCard() {
    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E26) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF6C63FF),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Deck Complete!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF2D2D3A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Great job! You have successfully reviewed all the cards in this deck.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Back to Hub',
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentIndex = 0;
                          _isFlipped = false;
                        });
                      },
                      child: const Text(
                        'Restart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            Colors.purple.shade100,
            Colors.deepPurple.shade100,
            const Color(0xFF6C63FF).withOpacity(0.2),
          ],
          stops: const [0.1, 0.5, 0.9],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Stack(
        children: [
          _buildGradientBackground(isDark),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
          ),
        ],
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deck.title)),
        body: const Center(child: Text('No cards found in this deck.')),
      );
    }

    final currentCard = _cards[_currentIndex];
    
    // Define stunning, premium color palettes
    final palettes = [
      // Signature Purple
      {
        'dark_q': const [Color(0xFF1E1E26), Color(0xFF2D2B4E)],
        'light_q': [Colors.white, const Color(0xFFF3F4FE)],
        'a': const [Color(0xFF6C63FF), Color(0xFF4A47A3)],
        'primary': const Color(0xFF6C63FF),
      },
      // Vibrant Rose/Pink
      {
        'dark_q': const [Color(0xFF1E1E26), Color(0xFF4A1C40)],
        'light_q': [Colors.white, const Color(0xFFFEF3FA)],
        'a': const [Color(0xFFFF6384), Color(0xFFA3476E)],
        'primary': const Color(0xFFFF6384),
      },
      // Brilliant Teal
      {
        'dark_q': const [Color(0xFF1E1E26), Color(0xFF1D3B43)],
        'light_q': [Colors.white, const Color(0xFFF0FAFA)],
        'a': const [Color(0xFF20C997), Color(0xFF178A6B)],
        'primary': const Color(0xFF20C997),
      },
      // Deep Azure
      {
        'dark_q': const [Color(0xFF1E1E26), Color(0xFF1B2E4B)],
        'light_q': [Colors.white, const Color(0xFFF0F5FE)],
        'a': const [Color(0xFF339AF0), Color(0xFF1C5F9C)],
        'primary': const Color(0xFF339AF0),
      },
      // Sunset Orange
      {
        'dark_q': const [Color(0xFF1E1E26), Color(0xFF4B2A1B)],
        'light_q': [Colors.white, const Color(0xFFFEF5F0)],
        'a': const [Color(0xFFFF922B), Color(0xFFB55D11)],
        'primary': const Color(0xFFFF922B),
      },
    ];

    final currentPalette = palettes[_currentIndex % palettes.length];

    return Stack(
      children: [
        _buildGradientBackground(isDark),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.deck.title, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 22, 
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.black,
            centerTitle: true,
          ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar and Counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Card ${_currentIndex + 1}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Text(
                        '${_cards.length} Total',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                       duration: const Duration(milliseconds: 300),
                       child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _cards.length,
                        backgroundColor: (currentPalette['primary'] as Color).withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(currentPalette['primary'] as Color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 3D Flipping Card
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
                    builder: (context, double value, child) {
                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(value * pi / 180),
                        alignment: Alignment.center,
                        child: value < 90
                            ? _buildCardSide(currentCard.question, 'Q', isDark, currentPalette, isQuestion: true)
                            : Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardSide(currentCard.answer, 'A', isDark, currentPalette, isQuestion: false),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Tap hint
            Text(
              'Tap card to flip',
              style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5),
            ),
            
            const SizedBox(height: 20),
            _buildControls(isDark, currentPalette['primary'] as Color),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ],
);
}

  Widget _buildCardSide(String text, String label, bool isDark, Map<String, dynamic> palette, {required bool isQuestion}) {
    // Premium Gradients
    final gradient = isQuestion
        ? LinearGradient(
            colors: isDark ? palette['dark_q'] : palette['light_q'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: palette['a'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final textColor = isQuestion 
        ? (isDark ? Colors.white : const Color(0xFF2D2D3A))
        : Colors.white;

    final primaryColor = palette['primary'] as Color;

    final labelColor = isQuestion 
        ? primaryColor 
        : Colors.white.withOpacity(0.8);

    final labelBg = isQuestion
        ? primaryColor.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isQuestion ? Colors.black : primaryColor).withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: isQuestion ? primaryColor.withOpacity(0.1) : Colors.transparent, 
          width: 2
        ),
      ),
      child: Stack(
        children: [
          // Decorative Background Element
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              isQuestion ? Icons.psychology_rounded : Icons.lightbulb_rounded,
              size: 150,
              color: isQuestion ? primaryColor.withOpacity(0.03) : Colors.white.withOpacity(0.05),
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isQuestion)
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white70),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          height: 1.4,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: (isQuestion ? Colors.black : Colors.white).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(1, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(Icons.keyboard_arrow_left_rounded, _previousCard, _currentIndex > 0, isDark, primaryColor),
          _buildFlashActionButton(primaryColor),
          _buildNavButton(Icons.keyboard_arrow_right_rounded, _nextCard, true, isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, bool enabled, bool isDark, Color primaryColor) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: enabled 
            ? (isDark ? Colors.grey[850] : Colors.white)
            : (isDark ? Colors.grey[900] : Colors.grey[200]),
        shape: BoxShape.circle,
        boxShadow: enabled ? [
          BoxShadow(
            color: (isDark ? Colors.black : primaryColor).withOpacity(isDark ? 0.4 : 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 25,
              spreadRadius: 2,
            ),
        ] : [],
      ),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 28, color: enabled ? primaryColor : Colors.grey[400]),
      ),
    );
  }

  Widget _buildFlashActionButton(Color primaryColor) {
    // Generate a slightly darker shade for the gradient bottom
    final darkenColor = HSLColor.fromColor(primaryColor).withLightness(
        (HSLColor.fromColor(primaryColor).lightness - 0.15).clamp(0.0, 1.0)
    ).toColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      transform: Matrix4.identity()..scale(_isFlipped ? 1.05 : 1.0),
      child: GestureDetector(
        onTap: () => setState(() => _isFlipped = !_isFlipped),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, darkenColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            _isFlipped ? Icons.autorenew_rounded : Icons.remove_red_eye_rounded,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
