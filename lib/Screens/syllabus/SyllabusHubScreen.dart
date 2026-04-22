import 'package:flutter/material.dart';
import 'package:student_ai/Screens/syllabus/SavedSyllabusScreen.dart';
import 'package:student_ai/services/adService.dart';
import 'SyllabusBreakdownScreen.dart';

class SyllabusHubScreen extends StatelessWidget {
  const SyllabusHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Syllabus Hub",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => Container(
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
                        'Syllabus Hub Features',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '• Turn any syllabus into a structured roadmap\n\n'
                            '• Upload images or PDFs of your syllabus\n\n'
                            '• Auto-saves your generated roadmaps in the background\n\n'
                            '• Access your saved roadmaps anytime',
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Got It!', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.map_outlined,
                      size: 32,
                      color: isDark ? Colors.white : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Roadmaps Made Easy",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Convert your syllabus into actionable plans",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Options Title
            Text(
              "What would you like to do?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),

            // New Breakdown Card
            _buildOptionCard(
              context,
              title: "New Syllabus Breakdown",
              subtitle: "Upload text, image, or PDF and get roadmaps",
              icon: Icons.add_road_rounded,
              color: Colors.blue.shade600,
              gradientColors: isDark
                  ? [Colors.blue.shade800, Colors.lightBlue.shade700]
                  : [Colors.blue.shade100, Colors.blue.shade50],
              destination: const SyllabusBreakdownScreen(),
            ),

            const SizedBox(height: 20),

            // Saved Breakdowns Card
            _buildOptionCard(
              context,
              title: "Saved Roadmaps",
              subtitle: "View and manage your generated roadmaps",
              icon: Icons.bookmark_rounded,
              color: Colors.orange.shade600,
              gradientColors: isDark
                  ? [Colors.orange.shade800, Colors.deepOrange.shade700]
                  : [Colors.orange.shade100, Colors.orange.shade50],
              destination: const SavedSyllabusScreen(),
            ),

            const SizedBox(height: 32),

            // Stats Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.checklist_rtl_rounded,
                    value: "Detailed",
                    label: "Agendas",
                    color: Colors.green.shade600,
                    isDark: isDark,
                  ),
                  _buildStatItem(
                    icon: Icons.timer_rounded,
                    value: "Instant",
                    label: "Processing",
                    color: Colors.orange.shade600,
                    isDark: isDark,
                  ),
                  _buildStatItem(
                    icon: Icons.auto_awesome_rounded,
                    value: "Smart",
                    label: "Structuring",
                    color: Colors.purple.shade600,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required List<Color> gradientColors,
        required Widget destination,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AdService.showInterstitialAndNavigate(context, destination);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(isDark ? 0.15 : 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: isDark ? Colors.white.withOpacity(0.7) : color.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
