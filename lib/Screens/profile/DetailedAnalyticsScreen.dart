import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Providers/homeStatsProvider.dart';

class DetailedAnalyticsScreen extends StatelessWidget {
  const DetailedAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<HomeStatsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Performance Insights'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: stats.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader('Performance Trend', isDark),
                const SizedBox(height: 16),
                _buildTrendChart(stats.recentQuizScores, isDark),
                const SizedBox(height: 32),
                
                _buildHeader('Subject Mastery', isDark),
                const SizedBox(height: 16),
                _buildSubjectMastery(stats.topicAccuracy, isDark),
                const SizedBox(height: 32),

                if (stats.weakTopics.isNotEmpty) ...[
                  _buildHeader('Areas to Improve', isDark),
                  const SizedBox(height: 16),
                  _buildWeakAreas(stats.weakTopics, isDark),
                  const SizedBox(height: 32),
                ],

                _buildOverallSummary(stats, isDark),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.grey[800],
      ),
    );
  }

  Widget _buildTrendChart(List<double> scores, bool isDark) {
    if (scores.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text('No quiz data yet', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: LineChartPainter(scores: scores, isDark: isDark),
      ),
    );
  }

  Widget _buildSubjectMastery(Map<String, double> accuracy, bool isDark) {
    if (accuracy.isEmpty) return const Text('No subject data available');
    
    return Column(
      children: accuracy.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildMasteryBar(e.key, e.value, isDark),
      )).toList(),
    );
  }

  Widget _buildMasteryBar(String title, double percent, bool isDark) {
    final color = percent > 80 ? Colors.green : (percent > 60 ? Colors.orange : Colors.red);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${percent.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildWeakAreas(List<String> topics, bool isDark) {
    return Column(
      children: topics.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildOverallSummary(HomeStatsProvider stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4A47A3)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStat('Accuracy', '${stats.avgQuizScore.toStringAsFixed(0)}%'),
          _buildSummaryStat('Streak', '${stats.streakCount}d'),
          _buildSummaryStat('Quizzes', '${stats.totalQuizzes}'),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> scores;
  final bool isDark;

  LineChartPainter({required this.scores, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6C63FF).withOpacity(0.3),
          const Color(0xFF6C63FF).withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final double xStep = scores.length > 1 ? size.width / (scores.length - 1) : size.width;
    
    for (int i = 0; i < scores.length; i++) {
      final double x = i * xStep;
      final double y = size.height - (scores[i] / 100 * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      if (i == scores.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()..color = const Color(0xFF6C63FF);
    for (int i = 0; i < scores.length; i++) {
      final double x = i * xStep;
      final double y = size.height - (scores[i] / 100 * size.height);
      canvas.drawCircle(Offset(x, y), 5, pointPaint);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
