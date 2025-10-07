// lib/screens/plan_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Providers/studyPlannerProvider.dart';
import '../../services/Firestore_service.dart';
import '../../widgets/studyPlan/studyPlanCard.dart';
import '../authwrapper.dart';

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
  User? _currentUser;

  // Filter state: 0 = incomplete, 1 = complete, 2 = all
  int filterState = 2;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadPlans();
    } else {
      loading = false;
    }
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

  Widget _buildLoggedOutScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Study Plan Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  size: 60,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                "Plan Your Success",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                "Create personalized study plans, track your progress, and achieve your academic goals. Login to access all planning features.",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Features Grid
              _buildPlanFeaturesGrid(isDark),
              const SizedBox(height: 40),

              // Action Buttons
              Column(
                children: [
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthWrapper(isHome: true),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: Colors.deepPurple.withOpacity(0.4),
                      ),
                      child: const Text(
                        'Login to Access Plans',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthWrapper(isHome: true),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Additional Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Track your study progress with detailed timelines and completion analytics.",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
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
    );
  }

  Widget _buildPlanFeaturesGrid(bool isDark) {
    final features = [
      {
        'icon': Icons.schedule_rounded,
        'title': 'Smart Scheduling',
        'description': 'AI-powered study schedules tailored to your goals',
        'color': Colors.purple,
      },
      {
        'icon': Icons.track_changes_rounded,
        'title': 'Progress Tracking',
        'description': 'Monitor your completion and stay on track',
        'color': Colors.blue,
      },
      {
        'icon': Icons.flag_rounded,
        'title': 'Goal Setting',
        'description': 'Set clear academic goals and deadlines',
        'color': Colors.green,
      },
      {
        'icon': Icons.analytics_rounded,
        'title': 'Performance Analytics',
        'description': 'Get insights into your study patterns',
        'color': Colors.orange,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: feature['color'] as Color? ?? Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feature['icon'] as IconData? ?? Icons.star_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature['title'] as String? ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature['description'] as String? ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.3,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    // Check if user is logged in
    if (_currentUser == null) {
      return _buildLoggedOutScreen(isDark);
    }

    final plannerProvider = Provider.of<StudyPlannerProvider>(
      context,
      listen: false,
    );

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