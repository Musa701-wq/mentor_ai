import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/SyllabusProvider.dart';

class SyllabusStudyScreen extends StatefulWidget {
  final Map<String, dynamic> chapter;
  final int index;
  final String syllabusId;

  const SyllabusStudyScreen({
    super.key,
    required this.chapter,
    required this.index,
    required this.syllabusId,
  });

  @override
  State<SyllabusStudyScreen> createState() => _SyllabusStudyScreenState();
}

class _SyllabusStudyScreenState extends State<SyllabusStudyScreen> {
  int _currentTopicIndex = 0;
  late List _topics;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _topics = widget.chapter['detailedTopics'] as List? ?? [];
    // Fallback if detailedTopics is empty but studyContent exists (for old data)
    if (_topics.isEmpty && widget.chapter['studyContent'] != null) {
      _topics = [
        {
          "topicTitle": widget.chapter['topic'] ?? "Study Material",
          "explanation": widget.chapter['studyContent'],
          "example": "Review your syllabus for specific examples.",
          "formulaOrRule": ""
        }
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayTitle = widget.chapter['topic'] ?? 'Chapter Detail';
    final provider = context.watch<SyllabusProvider>();

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF0F2FF),
      appBar: AppBar(
        title: Text(dayTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 📊 Progress Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _topics.isEmpty ? 0 : (_currentTopicIndex + 1) / _topics.length,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "${_currentTopicIndex + 1}/${_topics.length}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentTopicIndex = idx),
              itemCount: _topics.length,
              itemBuilder: (context, idx) {
                final topic = _topics[idx];
                return _buildTopicCard(topic, isDark);
              },
            ),
          ),

          // 🎮 Navigation Controls
          _buildNavigationControls(provider, isDark),
        ],
      ),
    );
  }

  Widget _buildTopicCard(dynamic topicData, bool isDark) {
    final title = topicData['topicTitle'] ?? 'Untitled Topic';
    final explanation = topicData['explanation'] ?? '';
    final example = topicData['example'] ?? '';
    final rule = topicData['formulaOrRule'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ Topic Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF918BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 24),

          // 📖 Explanation Section
          _buildSection(
            title: "Concept Explained",
            content: explanation,
            icon: Icons.menu_book_rounded,
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 💡 Example Section
          if (example.isNotEmpty)
            _buildSection(
              title: "Real-Life Example",
              content: example,
              icon: Icons.lightbulb_rounded,
              color: Colors.orange,
              isDark: isDark,
              isExample: true,
            ),
          const SizedBox(height: 16),

          // ⚙️ Formula/Rule Section
          if (rule.isNotEmpty)
            _buildSection(
              title: "Key Rule / Formula",
              content: rule,
              icon: Icons.functions_rounded,
              color: Colors.pink,
              isDark: isDark,
              highlight: true,
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isExample = false,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: isExample || highlight ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(SyllabusProvider provider, bool isDark) {
    final isLastTopic = _currentTopicIndex == _topics.length - 1;
    final isCompleted = provider.isMilestoneCompleted(widget.syllabusId, widget.index);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Row(
        children: [
          if (_currentTopicIndex > 0)
            IconButton(
              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (isLastTopic) {
                    provider.toggleMilestoneCompletion(widget.syllabusId, widget.index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isCompleted ? "Day Marked Incomplete" : "Chapter Completed! 🎉"),
                        backgroundColor: isCompleted ? Colors.grey : Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    if (!isCompleted) Navigator.pop(context);
                  } else {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastTopic ? (isCompleted ? Colors.orange : Colors.green) : const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isLastTopic ? (isCompleted ? "RESET PROGRESS" : "COMPLETE DAY") : "NEXT TOPIC",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
