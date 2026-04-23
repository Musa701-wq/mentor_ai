import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_ai/utils/app_navigator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_ai/config/app_links.dart';
import 'package:student_ai/Screens/addQuiz/quizSolveScreen.dart';
import 'package:student_ai/Screens/addQuiz/quizAnalysisScreen.dart';
import 'package:student_ai/services/adService.dart';
import '../../routes.dart';

import '../../Providers/quizProvider.dart';
import '../../config/creditConfig.dart';
import '../../models/quizModel.dart';
import '../../services/creditService.dart';
import '../sharedItems/quizSharedStatsScreen.dart';
import 'addQuiz.dart';
import '../authwrapper.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> with RouteAware {
  QuizFilter _selectedFilter = QuizFilter.all;
  Set<String> _attemptedQuizIds = {};
  bool _isLoadingAttempts = true;

  Future<void> _loadAttemptedQuizIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _attemptedQuizIds = {};
          _isLoadingAttempts = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection("quizAttempts")
          .where("userId", isEqualTo: user.uid)
          .get();

      setState(() {
        _attemptedQuizIds = snapshot.docs
            .map((doc) => doc["quizId"] as String)
            .toSet();
        _isLoadingAttempts = false;
      });
    } catch (e, stack) {
      debugPrint("❌ Error fetching attempted quiz IDs: $e");
      debugPrint(stack.toString());
      setState(() {
        _attemptedQuizIds = {};
        _isLoadingAttempts = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAttemptedQuizIds();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadAttemptedQuizIds();
  }

  void _fullResetAndReload() {
    setState(() {
      _selectedFilter = QuizFilter.all;
      _attemptedQuizIds = {};
      _isLoadingAttempts = true;
    });
    _loadAttemptedQuizIds();
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
              // Quiz Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  size: 60,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                "Test Your Knowledge",
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
                "Create custom quizzes, track your progress, and challenge yourself. Login to access all quiz features.",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Features Grid
              _buildQuizFeaturesGrid(isDark),
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
                        'Login to Access Quizzes',
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
                      Icons.analytics_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Track your quiz performance and progress over time with detailed analytics.",
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

  Widget _buildQuizFeaturesGrid(bool isDark) {
    final features = [
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'AI Generated',
        'description': 'Smart quizzes created by AI based on your subjects',
        'color': Colors.purple,
      },
      {
        'icon': Icons.create_rounded,
        'title': 'Custom Quizzes',
        'description': 'Create your own quizzes with custom questions',
        'color': Colors.blue,
      },
      {
        'icon': Icons.track_changes_rounded,
        'title': 'Progress Tracking',
        'description': 'Monitor your scores and improvement over time',
        'color': Colors.green,
      },
      {
        'icon': Icons.share_rounded,
        'title': 'Share & Compete',
        'description': 'Share quizzes with friends and compare scores',
        'color': Colors.orange,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
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
                maxLines: 2,
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
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    // Check if user is logged in
    if (user == null) {
      return _buildLoggedOutScreen(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7FF),
      appBar: AppBar(
        title: const Text(
          "My Quizzes",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D2B4E),
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF2D2B4E),
        elevation: 0,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<QuizFilter>(
              icon: Icon(
                Icons.filter_list_rounded,
                color: isDark ? Colors.white : const Color(0xFF6C63FF),
              ),
              onSelected: (QuizFilter filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<QuizFilter>>[
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.all,
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: _selectedFilter == QuizFilter.all
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('All Quizzes'),
                    ],
                  ),
                ),
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.completed,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: _selectedFilter == QuizFilter.completed
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Completed'),
                    ],
                  ),
                ),
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.incomplete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: _selectedFilter == QuizFilter.incomplete
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Incomplete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.black, Colors.black]
                : [const Color(0xFFF7F7FF), const Color(0xFFEDEBFF)],
          ),
        ),
        child: _isLoadingAttempts
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        )
            : StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("quizzes")
              .where("userId", isEqualTo: user.uid)
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF6C63FF),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
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
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load quizzes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2B4E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please try again later",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
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
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.quiz_rounded,
                        size: 64,
                        color: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No quizzes yet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D2B4E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Create your first quiz to get started",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to quiz creation
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return AddQuizScreen();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text("Create Quiz"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
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
                ),
              );
            }

            final allQuizzes = snapshot.data!.docs;

            // Filter quizzes based on selection
            final filteredQuizzes = allQuizzes.where((quiz) {
              final quizId = quiz.id;
              final attempted = _attemptedQuizIds.contains(quizId);

              switch (_selectedFilter) {
                case QuizFilter.all:
                  return true;
                case QuizFilter.completed:
                  return attempted;
                case QuizFilter.incomplete:
                  return !attempted;
              }
            }).toList();

            return CustomScrollView(
              slivers: [
                // Filter chip bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'All',
                                isSelected:
                                _selectedFilter == QuizFilter.all,
                                onTap: () => setState(
                                      () => _selectedFilter = QuizFilter.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Completed',
                                isSelected:
                                _selectedFilter ==
                                    QuizFilter.completed,
                                onTap: () => setState(
                                      () => _selectedFilter =
                                      QuizFilter.completed,
                                ),
                                icon: Icons.check_circle_rounded,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                label: 'Incomplete',
                                isSelected:
                                _selectedFilter ==
                                    QuizFilter.incomplete,
                                onTap: () => setState(
                                      () => _selectedFilter =
                                      QuizFilter.incomplete,
                                ),
                                icon:
                                Icons.radio_button_unchecked_rounded,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${_getFilterTitle(_selectedFilter)} (${filteredQuizzes.length})",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Quiz list
                if (filteredQuizzes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
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
                              _selectedFilter == QuizFilter.completed
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.quiz_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _getEmptyStateMessage(_selectedFilter),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getEmptyStateSubtitle(_selectedFilter),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((
                          context,
                          index,
                          ) {
                        final quiz = filteredQuizzes[index];
                        final quizId = quiz.id;
                        final attempted = _attemptedQuizIds.contains(
                          quizId,
                        );

                        return QuizCard(
                          quizId: quizId,
                          totalQuestions: quiz["totalQuestions"] ?? 0,
                          source: quiz["source"] ?? "manual",
                          createdAt:
                          (quiz["createdAt"] as Timestamp?)
                              ?.toDate() ??
                              DateTime.now(),
                          attempted: attempted,
                          title: quiz["title"] ?? "Untitled Quiz",
                          onShare: () {
                            final quizModel = QuizModel.fromMap({
                              ...quiz.data() as Map<String, dynamic>,
                              'id': quizId,
                            });

                            _openShareDialog(quizModel, context);
                          },
                        );
                      }, childCount: filteredQuizzes.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          if (icon != null) const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: isSelected ? null : Colors.transparent,
      selectedColor: color ?? const Color(0xFF6C63FF),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
      ),
    );
  }

  String _getFilterTitle(QuizFilter filter) {
    switch (filter) {
      case QuizFilter.all:
        return "Your Quizzes";
      case QuizFilter.completed:
        return "Completed Quizzes";
      case QuizFilter.incomplete:
        return "Incomplete Quizzes";
    }
  }

  String _getEmptyStateMessage(QuizFilter filter) {
    switch (filter) {
      case QuizFilter.all:
        return "No quizzes yet";
      case QuizFilter.completed:
        return "No completed quizzes";
      case QuizFilter.incomplete:
        return "No incomplete quizzes";
    }
  }

  String _getEmptyStateSubtitle(QuizFilter filter) {
    switch (filter) {
      case QuizFilter.all:
        return "Create your first quiz to get started";
      case QuizFilter.completed:
        return "Complete some quizzes to see them here";
      case QuizFilter.incomplete:
        return "All your quizzes are completed!";
    }
  }

  void _openShareDialog(QuizModel quiz, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String q = '';
        Timer? _debounce;
        bool isLoading = false;
        List<Map<String, dynamic>> results = [];
        final provider = Provider.of<QuizProvider>(ctx, listen: false);
        final already = quiz.withShared.toSet();
        final selected = <String>{};

        return StatefulBuilder(
          builder: (context, setStateSB) {
            Future<void> runSearch(String query) async {
              setStateSB(() {
                isLoading = true;
              });

              final res = await provider.searchUsers(query);

              setStateSB(() {
                results = res;
                isLoading = false;
              });
            }

            void onChanged(String v) {
              q = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () async {
                await runSearch(q);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Share quiz',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    if (!isLoading)
                      Flexible(
                        child: results.isEmpty && q.isNotEmpty
                            ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No users found for "$q"',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Share App'),
                                  onPressed: () {
                                    Share.share(
                                      'Check out Mentor AI: ' +
                                          appStoreUrl,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final u = results[i];
                            final uid = u['uid'] as String;
                            final disabled = already.contains(uid);
                            final checked = selected.contains(uid);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                (u['profilePic'] != null &&
                                    (u['profilePic'] as String)
                                        .isNotEmpty)
                                    ? NetworkImage(u['profilePic'])
                                    : null,
                                child:
                                (u['profilePic'] == null ||
                                    (u['profilePic'] as String)
                                        .isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(u['name'] ?? 'User'),
                              subtitle:
                              (u['email'] != null &&
                                  (u['email'] as String).isNotEmpty)
                                  ? Text(u['email'])
                                  : null,
                              trailing: disabled
                                  ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(
                                    .15,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Shared',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                                  : Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  if (disabled) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Quiz already shared with this user',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (v == true) {
                                    selected.add(uid);
                                  } else {
                                    selected.remove(uid);
                                  }
                                  setStateSB(() {});
                                },
                              ),
                              onTap: () {
                                if (disabled) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Quiz already shared with this user',
                                      ),
                                    ),
                                  );
                                } else {
                                  if (checked) {
                                    selected.remove(uid);
                                  } else {
                                    selected.add(uid);
                                  }
                                  setStateSB(() {});
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Share'),
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                            await CreditsService.confirmAndDeductCredits(
                              context: context,
                              cost: CreditsConfig.shareQuiz,
                              actionName: "Share Quiz",
                              onConfirmedAction: () async {
                                final (added, alreadyDup) = await provider
                                    .shareQuizWithUsers(
                                  quiz: quiz,
                                  targetUids: selected.toList(),
                                );

                                if (alreadyDup.isNotEmpty) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Already shared with: ${alreadyDup.length} user(s)',
                                      ),
                                    ),
                                  );
                                }
                                if (added.isNotEmpty) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Shared with ${added.length} user(s) 🎉 -${CreditsConfig.shareQuiz} credits',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                if (context.mounted)
                                  Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum QuizFilter { all, completed, incomplete }

class QuizCard extends StatelessWidget {
  final String quizId;
  final int totalQuestions;
  final String source;
  final DateTime createdAt;
  final bool attempted;
  final String title;
  final VoidCallback onShare;

  const QuizCard({
    super.key,
    required this.quizId,
    required this.totalQuestions,
    required this.source,
    required this.createdAt,
    required this.attempted,
    required this.title,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAi = source == "ai";
    final colors = _QuizCardColors(isAi: isAi, isDark: isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: colors.boxShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleQuizTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.gradientColors,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with quiz type and top-right Share button
                _QuizHeader(isAi: isAi, onShare: onShare),
                const SizedBox(height: 12),

                // Quiz title
                _QuizTitle(title: title),
                const SizedBox(height: 12),

                // Metadata row
                _QuizMetadata(
                  totalQuestions: totalQuestions,
                  createdAt: createdAt,
                ),

                // Completion badge
                if (attempted) ...[
                  const SizedBox(height: 12),
                  const _CompletionBadge(),
                ],

                const SizedBox(height: 16),

                // Action buttons (Share moved to header)
                _QuizActions(
                  onViewStats: () => _handleViewStats(context),
                  mainColor: colors.mainColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleQuizTap(BuildContext context) async {
    if (attempted) {
      // ✅ Deduct credits before opening completed quiz
      await CreditsService.confirmAndDeductCredits(
        context: context,
        cost: CreditsConfig.openCompletedQuiz,
        actionName: "Open Completed Quiz",
        onConfirmedAction: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          // 🔍 Fetch the last attempt to show results
          final attemptSnap = await FirebaseFirestore.instance
              .collection("quizAttempts")
              .where("quizId", isEqualTo: quizId)
              .where("userId", isEqualTo: user.uid)
              .orderBy("createdAt", descending: true)
              .limit(1)
              .get();

          if (attemptSnap.docs.isNotEmpty) {
            final attemptDoc = attemptSnap.docs.first;
            final attemptId = attemptDoc.id;
            final attemptData = attemptDoc.data();
            
            final questions = List<Map<String, dynamic>>.from(attemptData['questions'] ?? []);
            final answers = List<String>.from(attemptData['answers'] ?? []);
            final initialAnalysis = attemptData['analysis'] as Map<String, dynamic>?;

            AppNavigator.key.currentState?.push(
              MaterialPageRoute(
                builder: (_) => QuizSolveScreen(
                  quizId: quizId,
                  isReadOnly: true,
                  initialAnswers: answers,
                  savedAnalysis: initialAnalysis,
                  attemptId: attemptId,
                ),
              ),
            );
          } else {
            // Fallback to solve if no attempt found
            AppNavigator.key.currentState?.push(
              MaterialPageRoute(builder: (_) => QuizSolveScreen(quizId: quizId)),
            );
          }
        },
      );
    } else {
      // 🚀 Free if not attempted yet
      AdService.showInterstitialAndNavigate(
        context,
        QuizSolveScreen(quizId: quizId),
      );
    }
  }

  void _handleViewStats(BuildContext context) async {
    await CreditsService.confirmAndDeductCredits(
      context: context,
      cost: CreditsConfig.viewStats,
      actionName: "View Quiz Stats",
      onConfirmedAction: () async {
        AppNavigator.key.currentState?.push(
          MaterialPageRoute(
            builder: (_) => QuizSharedStatsScreen(quizId: quizId),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Color management helper class
class _QuizCardColors {
  final bool isAi;
  final bool isDark;

  _QuizCardColors({required this.isAi, required this.isDark});

  Color get mainColor =>
      isAi ? const Color(0xFF7E57C2) : const Color(0xFF42A5F5);
  Color get secondaryColor =>
      isAi ? const Color(0xFF9575CD) : const Color(0xFF64B5F6);

  List<Color> get gradientColors => [mainColor, secondaryColor];

  List<BoxShadow>? get boxShadow => isDark
      ? null
      : [
    BoxShadow(
      color: mainColor.withOpacity(0.2),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
}

// Quiz type header component
class _QuizHeader extends StatelessWidget {
  final bool isAi;
  final VoidCallback onShare;

  const _QuizHeader({required this.isAi, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAi ? Icons.auto_awesome_rounded : Icons.edit_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isAi ? "AI Generated" : "Manual Quiz",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          tooltip: "Share Quiz",
          onPressed: onShare,
        ),
      ],
    );
  }
}

// Quiz title component
class _QuizTitle extends StatelessWidget {
  final String title;

  const _QuizTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// Quiz metadata component
class _QuizMetadata extends StatelessWidget {
  final int totalQuestions;
  final DateTime createdAt;

  const _QuizMetadata({required this.totalQuestions, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.quiz_rounded, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          "$totalQuestions ${totalQuestions == 1 ? 'question' : 'questions'}",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 16),
        const Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: Colors.white70,
        ),
        const SizedBox(width: 6),
        Text(
          _formatDate(createdAt),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Completion badge component
class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "✅ Completed",
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Action buttons component
class _QuizActions extends StatelessWidget {
  final VoidCallback onViewStats;
  final Color mainColor;

  const _QuizActions({
    required this.onViewStats,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: mainColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: onViewStats,
          icon: const Icon(Icons.bar_chart_rounded, size: 18),
          label: const Text("View Stats"),
        ),
      ],
    );
  }
}