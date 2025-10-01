import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Screens/addQuiz/quizSolveScreen.dart';
import 'package:student_ai/services/adService.dart';

import '../../Providers/quizProvider.dart';
import '../../config/creditConfig.dart';
import '../../models/quizModel.dart';
import '../../services/creditService.dart';
import '../sharedItems/quizSharedStatsScreen.dart';
import 'addQuiz.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text("My Quizzes"),
          centerTitle: true,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.grey[800],
        ),
        body: Center(
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
                  Icons.login_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Please log in to view your quizzes",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to access your created quizzes and track your progress",
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
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "My Quizzes",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        elevation: 0,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<QuizFilter>(
              icon: Icon(Icons.filter_list_rounded, color: isDark ? Colors.white : Colors.grey[800]),
              onSelected: (QuizFilter filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<QuizFilter>>[
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.all,
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded,
                          color: _selectedFilter == QuizFilter.all
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('All Quizzes'),
                    ],
                  ),
                ),
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.completed,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: _selectedFilter == QuizFilter.completed
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Completed'),
                    ],
                  ),
                ),
                PopupMenuItem<QuizFilter>(
                  value: QuizFilter.incomplete,
                  child: Row(
                    children: [
                      Icon(Icons.radio_button_unchecked_rounded,
                          color: _selectedFilter == QuizFilter.incomplete
                              ? Colors.orange
                              : Colors.grey),
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
      body: _isLoadingAttempts
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E57C2)),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E57C2)),
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
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please try again later",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
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
                      Icons.quiz_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No quizzes yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create your first quiz to get started",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to quiz creation
                        Navigator.push(context, MaterialPageRoute(builder: (context){
                          return AddQuizScreen();
                        }));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Create Quiz"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7E57C2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
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
                              isSelected: _selectedFilter == QuizFilter.all,
                              onTap: () => setState(() => _selectedFilter = QuizFilter.all),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Completed',
                              isSelected: _selectedFilter == QuizFilter.completed,
                              onTap: () => setState(() => _selectedFilter = QuizFilter.completed),
                              icon: Icons.check_circle_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Incomplete',
                              isSelected: _selectedFilter == QuizFilter.incomplete,
                              onTap: () => setState(() => _selectedFilter = QuizFilter.incomplete),
                              icon: Icons.radio_button_unchecked_rounded,
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
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                              color: isDark ? Colors.white : Colors.grey[800],
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final quiz = filteredQuizzes[index];
                        final quizId = quiz.id;
                        final attempted = _attemptedQuizIds.contains(quizId);

                        return QuizCard(
                          quizId: quizId,
                          totalQuestions: quiz["totalQuestions"] ?? 0,
                          source: quiz["source"] ?? "manual",
                          createdAt: (quiz["createdAt"] as Timestamp?)?.toDate() ??
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
                      },
                      childCount: filteredQuizzes.length,
                    ),
                  ),
                ),
            ],
          );
        },
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
      selectedColor: color ?? Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
        final provider = Provider.of<QuizProvider>(context, listen: false);
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
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
                          child: Text(
                            'No users found for "$q"',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
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
                                backgroundImage: (u['profilePic'] != null &&
                                    (u['profilePic'] as String).isNotEmpty)
                                    ? NetworkImage(u['profilePic'])
                                    : null,
                                child: (u['profilePic'] == null ||
                                    (u['profilePic'] as String).isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(u['name'] ?? 'User'),
                              subtitle: (u['email'] != null &&
                                  (u['email'] as String).isNotEmpty)
                                  ? Text(u['email'])
                                  : null,
                              trailing: disabled
                                  ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Quiz already shared with this user'),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Quiz already shared with this user'),
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
                                final (added, alreadyDup) =
                                await provider.shareQuizWithUsers(
                                  quiz: quiz,
                                  targetUids: selected.toList(),
                                );

                                if (alreadyDup.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Already shared with: ${alreadyDup.length} user(s)',
                                      ),
                                    ),
                                  );
                                }
                                if (added.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Shared with ${added.length} user(s) 🎉 -${CreditsConfig.shareQuiz} credits',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                if (context.mounted) Navigator.pop(context);
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

enum QuizFilter {
  all,
  completed,
  incomplete,
}

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
    final mainColor = isAi ? const Color(0xFF7E57C2) : const Color(0xFF42A5F5);
    final secondaryColor = isAi ? const Color(0xFF9575CD) : const Color(0xFF64B5F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: mainColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (attempted) {
              // ✅ Deduct credits before opening completed quiz
              await CreditsService.confirmAndDeductCredits(
                context: context,
                cost: CreditsConfig.openCompletedQuiz, // 👈 add this in creditConfig.dart
                actionName: "Open Completed Quiz",
                onConfirmedAction: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizSolveScreen(quizId: quizId),
                    ),
                  );
                },
              );
            } else {
              // 🚀 Free if not attempted yet
              AdService.showInterstitialAndNavigate(context, QuizSolveScreen(quizId: quizId));
            }
          },

          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [mainColor, secondaryColor],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quiz type + title
                Row(
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
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Details row
                Row(
                  children: [
                    const Icon(Icons.quiz_rounded,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      "$totalQuestions ${totalQuestions == 1 ? 'question' : 'questions'}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                if (attempted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  ),
                ],

                const SizedBox(height: 16),

                // 🔹 Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: "Share Quiz",
                      onPressed: onShare,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        await CreditsService.confirmAndDeductCredits(
                          context: context,
                          cost: CreditsConfig.viewStats, // define in creditConfig.dart
                          actionName: "View Quiz Stats",
                          onConfirmedAction: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>  QuizSharedStatsScreen(
                                  quizId: quizId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.bar_chart_rounded, size: 18),
                      label: const Text("View Stats"),
                    ),

                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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