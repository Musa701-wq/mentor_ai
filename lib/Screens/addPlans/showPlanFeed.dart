// lib/screens/plan_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/studyPlannerProvider.dart';
import '../../services/Firestore_service.dart';
import '../../widgets/studyPlan/studyPlanCard.dart';

class PlanFeedScreen extends StatefulWidget {
  const PlanFeedScreen({super.key});

  @override
  State<PlanFeedScreen> createState() => _PlanFeedScreenState();
}

class _PlanFeedScreenState extends State<PlanFeedScreen> {
  final FirestoreService firestoreService = FirestoreService();
  bool loading = true;
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> filteredPlans = [];

  // Filter state: 0 = incomplete, 1 = complete, 2 = all
  int filterState = 2;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => loading = true);
    plans = await firestoreService.fetchUserPlans();
    _applyFilter();
    setState(() => loading = false);
  }

  void _applyFilter() {
    switch (filterState) {
      case 0:
        filteredPlans = plans
            .where((plan) => !(plan["completed"] ?? false))
            .toList();
        break;
      case 1:
        filteredPlans = plans
            .where((plan) => plan["completed"] ?? false)
            .toList();
        break;
      case 2:
        filteredPlans = List.from(plans);
        break;
    }
  }

  void _toggleFilter() {
    setState(() {
      filterState = (filterState + 1) % 3;
      _applyFilter();
    });
  }

  String _getFilterTooltip() {
    switch (filterState) {
      case 0:
        return "Showing incomplete plans";
      case 1:
        return "Showing complete plans";
      case 2:
      default:
        return "Showing all plans";
    }
  }

  IconData _getFilterIcon() {
    switch (filterState) {
      case 0:
        return Icons.filter_list_off; // Incomplete
      case 1:
        return Icons.task_alt; // Complete
      case 2:
      default:
        return Icons.filter_list; // All
    }
  }

  @override
  Widget build(BuildContext context) {
    final plannerProvider = Provider.of<StudyPlannerProvider>(
      context,
      listen: false,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "My Study Plans",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        actions: [
          IconButton(
            icon: Icon(
              _getFilterIcon(),
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
            onPressed: _toggleFilter,
            tooltip: _getFilterTooltip(),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
            onPressed: _loadPlans,
            tooltip: 'Refresh plans',
          ),
        ],
      ),
      body: loading
          ? _buildLoading(isDark)
          : RefreshIndicator(
              onRefresh: _loadPlans,
              color: isDark ? Colors.purple.shade300 : Colors.purple.shade600,
              child: filteredPlans.isEmpty
                  ? _buildEmptyState(isDark)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: ListView.builder(
                        key: ValueKey(
                          filterState,
                        ), // 🔑 forces rebuild on filter change
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredPlans.length,
                        itemBuilder: (context, index) {
                          final planData = filteredPlans[index];
                          final parsed = plannerProvider.parsePlan(
                            planData["plan"],
                          );

                          return StudyPlanCard(
                            key: ValueKey(
                              planData["id"],
                            ), // 🔑 keeps per-card state
                            goal: planData["goal"],
                            examDate: planData["examDate"],
                            startDate: planData["startDate"],
                            parsedPlan: parsed,
                            planId: planData["id"] ?? '0',
                            initialCompleted: planData["completed"] ?? false,
                            // 🔑 whenever completion is toggled inside the card,
                            // update local plans list too
                            onStatusChanged: (completed) {
                              setState(() {
                                final idx = plans.indexWhere(
                                  (p) => p["id"] == planData["id"],
                                );
                                if (idx != -1)
                                  plans[idx]["completed"] = completed;
                                _applyFilter(); // re-apply filter
                              });
                            },
                            // 🔑 when plan is dismissed, remove from local list
                            onDismissed: () {
                              setState(() {
                                plans.removeWhere(
                                  (p) => p["id"] == planData["id"],
                                );
                                _applyFilter(); // re-apply filter
                              });
                            },
                          );
                        },
                      ),
                    ),
            ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.purple.shade300 : Colors.purple.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Loading your study plans...",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateText(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateSubtext(),
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (filterState != 2)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  filterState = 2;
                  _applyFilter();
                });
              },
              icon: const Icon(Icons.list_rounded),
              label: const Text("View All Plans"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getEmptyStateText() {
    switch (filterState) {
      case 0:
        return "No incomplete plans";
      case 1:
        return "No complete plans";
      case 2:
      default:
        return "No study plans yet";
    }
  }

  String _getEmptyStateSubtext() {
    switch (filterState) {
      case 0:
        return "All your study plans are completed!";
      case 1:
        return "You haven't completed any study plans yet";
      case 2:
      default:
        return "Create your first study plan to get started";
    }
  }
}
