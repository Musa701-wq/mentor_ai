import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/SyllabusProvider.dart';
import 'SyllabusStudyScreen.dart';

class SyllabusDetailScreen extends StatefulWidget {
  final Map<String, dynamic> syllabus;

  const SyllabusDetailScreen({super.key, required this.syllabus});

  @override
  State<SyllabusDetailScreen> createState() => _SyllabusDetailScreenState();
}

class _SyllabusDetailScreenState extends State<SyllabusDetailScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<SyllabusProvider>();
    
    final roadmapData = widget.syllabus['roadmap'] as Map<String, dynamic>? ?? {};
    final title = widget.syllabus['title'] ?? 'Untitled Roadmap';
    final desc = roadmapData['description'] ?? 'Study session details.';
    final roadmap = roadmapData['roadmap'] as List? ?? [];
    final difficulty = roadmapData['difficulty'] ?? 'N/A';
    final prerequisites = roadmapData['prerequisites'] as List? ?? [];
    final studyTip = roadmapData['studyTip'] ?? '';
    final syllabusId = widget.syllabus['id'] ?? widget.syllabus['title'] ?? 'saved_roadmap';

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Roadmap Details', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // 💎 Premium Minimalist Header (Same as Breakdown)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF918BFF)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        difficulty.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.auto_awesome_rounded, color: Colors.orangeAccent, size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF2D2D5E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (prerequisites.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'PREREQUISITES',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prerequisites.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

          if (studyTip.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRO STUDY TIP',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.amber),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          studyTip,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          
          const Row(
            children: [
              Icon(Icons.route_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 12),
              Text(
                'CURRICULUM FLOW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // Timeline List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: roadmap.length,
            itemBuilder: (context, index) {
              final item = roadmap[index];
              return _buildTimelineItem(item, index, index == roadmap.length - 1, isDark, syllabusId, provider);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, int index, bool isLast, bool isDark, String syllabusId, SyllabusProvider provider) {
    final topic = item['topic'] ?? '';
    final detailedTopics = item['detailedTopics'] as List? ?? [];
    final subtopics = detailedTopics.isNotEmpty 
        ? detailedTopics.map((dt) => dt['topicTitle']).toList()
        : (item['subtopics'] as List? ?? []);
    final hours = item['estimatedHours'] ?? 0;
    final goal = item['learningGoal'] ?? '';
    final terms = item['keyTerms'] as List? ?? [];
    final isCompleted = provider.isMilestoneCompleted(syllabusId, index);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator with Checkmark Support
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : (isDark ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? Colors.green : const Color(0xFF6C63FF), width: 2),
                boxShadow: [
                  BoxShadow(color: (isCompleted ? Colors.green : const Color(0xFF6C63FF)).withOpacity(0.2), blurRadius: 10),
                ],
              ),
              child: Center(
                child: isCompleted 
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 120, 
                color: const Color(0xFF6C63FF).withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Content Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey('saved_chapter_$index'),
                initiallyExpanded: _expandedIndex == index,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedIndex = expanded ? index : null;
                  });
                },
                title: Text(
                  topic,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '$hours h',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${subtopics.length} Sections',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[50],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (goal.isNotEmpty) ...[
                          const Text(
                            'OBJECTIVE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            goal,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'KEY SUBTOPICS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6C63FF), letterSpacing: 1),
                        ),
                        const SizedBox(height: 12),
                        ...subtopics.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF6C63FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s.toString(),
                                  style: const TextStyle(fontSize: 13, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        if (terms.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'VOCABULARY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.orange, letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: terms.map((t) => Chip(
                              label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SyllabusStudyScreen(
                                    chapter: item,
                                    index: index,
                                    syllabusId: syllabusId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                            label: Text(
                              isCompleted ? "REVIEW CONTENT" : "START LEARNING",
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted ? Colors.green : const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
