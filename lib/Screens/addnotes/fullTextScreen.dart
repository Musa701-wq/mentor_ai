// lib/Screens/full_text_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullTextScreen extends StatelessWidget {
  final String title;
  final String text;

  const FullTextScreen({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[100] : Colors.grey[900];
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final readTime = (wordCount / 200).ceil();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.grey[900],
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.copy_rounded, color: Colors.purple.shade600),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Text copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            tooltip: 'Copy all text',
          ),

        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section with Stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade600,
                    Colors.purple.shade800,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStat(Icons.text_fields_rounded, '$wordCount words'),
                      const SizedBox(width: 20),
                      _buildStat(Icons.timer_rounded, '$readTime min read'),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isDark

                      ? null
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Divider
                        Container(
                          height: 2,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Content
                        SelectableText.rich(
                          TextSpan(
                            text: text,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: textColor,
                            ),
                          ),
                          textAlign: TextAlign.left,
                          selectionControls: MaterialTextSelectionControls(),
                          onSelectionChanged: (selection, cause) {
                            // Handle text selection if needed
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}