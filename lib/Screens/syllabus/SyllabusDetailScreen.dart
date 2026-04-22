import 'package:flutter/material.dart';

class SyllabusDetailScreen extends StatelessWidget {
  final Map<String, dynamic> syllabus;

  const SyllabusDetailScreen({super.key, required this.syllabus});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roadmapData = syllabus['roadmap'] as Map<String, dynamic>?;
    final title = syllabus['title'] ?? 'Untitled Roadmap';
    final desc = roadmapData?['description'] ?? '';
    final roadmap = roadmapData?['roadmap'] as List? ?? [];

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Roadmap Details'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roadmap.length,
              itemBuilder: (context, index) {
                final item = roadmap[index];
                return _buildRoadmapItem(item, index + 1, isDark);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapItem(Map<String, dynamic> item, int index, bool isDark) {
    final topic = item['topic'] ?? '';
    final subtopics = item['subtopics'] as List? ?? [];
    final hours = item['estimatedHours'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
          child: Text('$index', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
        ),
        title: Text(
          topic,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Est: $hours Hours'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtopics.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.toString())),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
