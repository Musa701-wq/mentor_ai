import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/homeStatsProvider.dart';

class QuizSharedStatsScreen extends StatefulWidget {
  final String quizId;

  const QuizSharedStatsScreen({super.key, required this.quizId});

  @override
  State<QuizSharedStatsScreen> createState() => _QuizSharedStatsScreenState();
}

class _QuizSharedStatsScreenState extends State<QuizSharedStatsScreen> {
  @override
  void initState() {
    super.initState();
    // 🔹 Trigger stats fetching
    Future.microtask(() =>
        Provider.of<HomeStatsProvider>(context, listen: false)
            .fetchSharedQuizStats());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<HomeStatsProvider>(context);
    final quizData = provider.sharedQuizStats[widget.quizId];

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Quiz Analytics"),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.grey[800],
        ),
      ),
      body: provider.sharedQuizStats.isEmpty
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E57C2)),
        ),
      )
          : quizData == null
          ? Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                "No data available",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "No analytics data found for this quiz",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : _buildQuizDetails(quizData, isDark),
    );
  }

  Widget _buildQuizDetails(Map<String, dynamic> quizData, bool isDark) {
    final quizTitle = quizData["quizTitle"] ?? "Untitled Quiz";
    final participants = quizData["participants"] as List<Map<String, dynamic>>;
    final totalParticipants = participants.length;

    // Calculate stats based on hasAttempted flag
    int completedAttempts = 0;
    double totalScore = 0;
    int totalQuestions = 0;

    for (final user in participants) {
      final hasAttempted = user["hasAttempted"] ?? false;
      final bestScore = user["bestScore"] ?? 0;
      final userTotalQuestions = user["totalQuestions"] ?? 0;

      if (hasAttempted) {
        completedAttempts++;
        totalScore += bestScore;
        totalQuestions = userTotalQuestions; // Assuming all have same total
      }
    }

    final averageScore = completedAttempts > 0
        ? (totalScore / completedAttempts).round()
        : 0;
    final completionRate = totalParticipants > 0
        ? ((completedAttempts / totalParticipants) * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Quiz summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7E57C2), Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      Icons.people_alt_rounded,
                      "$totalParticipants",
                      "Participants",
                      Colors.white70,
                    ),
                    _buildStatItem(
                      Icons.quiz_rounded,
                      completedAttempts > 0
                          ? "$averageScore/${totalQuestions > 0 ? totalQuestions : '?'}"
                          : "N/A",
                      "Avg Score",
                      Colors.white70,
                    ),
                    _buildStatItem(
                      Icons.trending_up_rounded,
                      "$completionRate%",
                      "Completion",
                      Colors.white70,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Performance metrics
          Text(
            "Performance Overview",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  "Completed",
                  "$completedAttempts",
                  Icons.check_circle_rounded,
                  Colors.green,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  "Not Started",
                  "${totalParticipants - completedAttempts}",
                  Icons.pending_rounded,
                  Colors.orange,
                  isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🔹 Only show score distribution if there are attempts
          if (completedAttempts > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.deepPurple[300],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Score Distribution",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildScoreDistribution(participants, totalQuestions, isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 🔹 Participants section header
          Row(
            children: [
              Text(
                "Participants ($totalParticipants)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.people_alt_rounded,
                color: Colors.deepPurple[300],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 🔹 Participants list
          participants.isEmpty
              ? Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  "No participants yet",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: participants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = participants[index];
              final name = user["name"] ?? "Unknown";
              final email = user["email"] ?? "";
              final hasAttempted = user["hasAttempted"] ?? false;
              final bestScore = user["bestScore"] ?? 0;
              final total = user["totalQuestions"] ?? 0;

              // Determine display text based on attempt status
              String scoreText;
              Color statusColor;
              IconData statusIcon;

              if (hasAttempted) {
                final percentage = total > 0 ? (bestScore / total * 100).round() : 0;
                scoreText = "$bestScore/$total";
                statusColor = _getScoreColor(percentage);
                statusIcon = Icons.quiz_rounded;
              } else {
                scoreText = "Not started";
                statusColor = Colors.grey;
                statusIcon = Icons.pending_rounded;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasAttempted)
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 16,
                              color: statusColor,
                            ),
                          if (hasAttempted) const SizedBox(width: 4),
                          Text(
                            scoreText,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDistribution(List<Map<String, dynamic>> participants, int totalQuestions, bool isDark) {
    // Count scores in different ranges
    int excellent = 0; // 90-100%
    int good = 0;      // 70-89%
    int average = 0;   // 50-69%
    int poor = 0;      // 0-49%

    for (final user in participants) {
      final hasAttempted = user["hasAttempted"] ?? false;
      final bestScore = user["bestScore"] ?? 0;
      final userTotalQuestions = user["totalQuestions"] ?? 0;

      if (hasAttempted && userTotalQuestions > 0) {
        final percentage = (bestScore / userTotalQuestions * 100).round();

        if (percentage >= 90) {
          excellent++;
        } else if (percentage >= 70) {
          good++;
        } else if (percentage >= 50) {
          average++;
        } else {
          poor++;
        }
      }
    }

    final totalAttempted = excellent + good + average + poor;

    if (totalAttempted == 0) {
      return Text(
        "No attempts recorded yet",
        style: TextStyle(
          color: Colors.grey[500],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: [
        _buildDistributionBar("Excellent (90-100%)", excellent, totalAttempted, Colors.green, isDark),
        const SizedBox(height: 8),
        _buildDistributionBar("Good (70-89%)", good, totalAttempted, Colors.lightGreen, isDark),
        const SizedBox(height: 8),
        _buildDistributionBar("Average (50-69%)", average, totalAttempted, Colors.orange, isDark),
        const SizedBox(height: 8),
        _buildDistributionBar("Needs Improvement (0-49%)", poor, totalAttempted, Colors.red, isDark),
      ],
    );
  }

  Widget _buildDistributionBar(String label, int count, int total, Color color, bool isDark) {
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              "$count ($percentage%)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: total > 0 ? count / total : 0,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.lightGreen;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}