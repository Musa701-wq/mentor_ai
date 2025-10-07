// lib/widgets/studyPlan/studyPlanCard.dart
import 'package:flutter/material.dart';
import '../../services/Firestore_service.dart';

class StudyPlanCard extends StatefulWidget {
  final String goal;
  final String examDate;
  final String startDate;
  final Map<String, dynamic>? parsedPlan;
  final String planId; // Firestore doc ID
  final bool initialCompleted; // Firestore completed status
  final void Function(bool completed)? onStatusChanged; // ✅ callback
  final void Function()? onDismissed; // ✅ dismiss callback

  const StudyPlanCard({
    super.key,
    required this.goal,
    required this.examDate,
    required this.startDate,
    required this.parsedPlan,
    required this.planId,
    required this.initialCompleted,
    this.onStatusChanged,
    this.onDismissed,
  });

  @override
  State<StudyPlanCard> createState() => _StudyPlanCardState();
}

class _StudyPlanCardState extends State<StudyPlanCard> {
  bool showTopics = false;
  bool showSchedule = false;
  bool showReminders = false;
  late bool isCompleted;

  final FirestoreService firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    isCompleted = widget.initialCompleted;
  }

  Future<void> _markComplete() async {
    setState(() => isCompleted = true);
    await firestoreService.updatePlanCompletion(widget.planId, true);
    widget.onStatusChanged?.call(true); // ✅ notify parent
  }

  Future<void> _dismissPlan() async {
    try {
      await firestoreService.deletePlan(widget.planId);
      widget.onDismissed?.call(); // ✅ notify parent
    } catch (e) {
      // Show error message if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isStartDateInFuture() {
    try {
      final startDate = DateTime.parse(widget.startDate);
      final today = DateTime.now();
      return startDate.isAfter(DateTime(today.year, today.month, today.day));
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.parsedPlan;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[800];
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.05;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
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
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header with completion state ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.assignment_rounded,
                      size: 24,
                      color: isCompleted
                          ? Colors.green.shade600
                          : Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.goal,
                                style: TextStyle(
                                  fontSize:
                                      16 *
                                      MediaQuery.textScaleFactorOf(context),
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Completed",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Start: ${_formatDate(widget.startDate)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.event_available_rounded,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Exam: ${_formatDate(widget.examDate)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ✅ Only show "Mark as Complete" if not completed and start date is not in the future
              if (!isCompleted && !_isStartDateInFuture())
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        "Mark as Complete",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _markComplete,
                  ),
                ),

              // ✅ Show dismiss button if start date is in the future
              if (_isStartDateInFuture())
                Column(
                  children: [
                    if (!isCompleted) const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text(
                            "Dismiss Plan",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Dismiss Plan'),
                              content: const Text(
                                'Are you sure you want to dismiss this study plan? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _dismissPlan();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // --- Topics Section ---
              if (plan != null &&
                  plan["topics"] != null &&
                  (plan["topics"] as List).isNotEmpty)
                _buildTopicsSection(plan, textColor!, secondaryTextColor!),

              // --- Schedule Section ---
              if (plan != null &&
                  plan["studySchedule"] != null &&
                  (plan["studySchedule"] as List).isNotEmpty)
                _buildScheduleSection(plan, textColor!, secondaryTextColor!),

              // --- Reminders Section ---
              if (plan != null &&
                  plan["reminders"] != null &&
                  (plan["reminders"] as List).isNotEmpty)
                _buildRemindersSection(plan, textColor!),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Topics Section
  Widget _buildTopicsSection(
    Map<String, dynamic> plan,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionToggleButton(
          icon: Icons.menu_book_rounded,
          title: "Topics",
          isExpanded: showTopics,
          color: Colors.blue.shade600,
          onTap: () => setState(() => showTopics = !showTopics),
        ),
        if (showTopics) ...[
          const SizedBox(height: 12),
          ...((plan["topics"] as List).map((t) {
            final topicName = t["name"] ?? "Unnamed Topic";
            final estTime = t["estimatedTime"] ?? 1;
            final assignedDays = (t["assignedDays"] as List?) ?? [];
            return InkWell(
              onTap: () => _showTopicDialog(t),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.book_rounded,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            topicName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${estTime}h",
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (assignedDays.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: assignedDays
                            .map(
                              (day) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          })),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // 🔹 Schedule Section
  Widget _buildScheduleSection(
    Map<String, dynamic> plan,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionToggleButton(
          icon: Icons.schedule_rounded,
          title: "Study Schedule",
          isExpanded: showSchedule,
          color: Colors.green.shade600,
          onTap: () => setState(() => showSchedule = !showSchedule),
        ),
        if (showSchedule) ...[
          const SizedBox(height: 12),
          ...((plan["studySchedule"] as List).map((s) {
            final day = s["day"];
            final topics = (s["topics"] as List).join(', ');
            final hours = s["hours"];
            return InkWell(
              onTap: () => _showScheduleItemDialog(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topics,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "$hours h",
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // 🔹 Reminders Section
  Widget _buildRemindersSection(Map<String, dynamic> plan, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionToggleButton(
          icon: Icons.notifications_rounded,
          title: "Reminders",
          isExpanded: showReminders,
          color: Colors.orange.shade600,
          onTap: () => setState(() => showReminders = !showReminders),
        ),
        if (showReminders) ...[
          const SizedBox(height: 12),
          ...((plan["reminders"] as List).map(
            (r) => InkWell(
              onTap: () => _showReminderDialog(r),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notification_important_rounded,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ],
    );
  }

  // 🔹 Section Toggle Button
  Widget _buildSectionToggleButton({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            Icon(
              isExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString.split('T').first;
    }
  }

  void _showTopicDialog(Map<String, dynamic> t) {
    final topicName = t["name"] ?? "Unnamed Topic";
    final estTime = t["estimatedTime"] ?? 1;
    final assignedDays = (t["assignedDays"] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(topicName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Estimated time: ${estTime}h"),
              const SizedBox(height: 8),
              if (assignedDays.isNotEmpty) ...[
                const Text("Assigned days:"),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: assignedDays
                      .map(
                        (day) => Chip(
                          label: Text(day.toString()),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ] else ...[
                const Text("No assigned days"),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showScheduleItemDialog(Map<String, dynamic> s) {
    final day = s["day"]?.toString() ?? "Day";
    final topics = ((s["topics"] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final hours = s["hours"]?.toString() ?? "0";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Study Day: $day"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Hours: $hours h"),
              const SizedBox(height: 8),
              const Text("Topics:"),
              const SizedBox(height: 6),
              if (topics.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: topics.map((t) => Text("• $t")).toList(),
                )
              else
                const Text("No topics listed"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog(String r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reminder"),
        content: Text(r),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
