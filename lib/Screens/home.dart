import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_ai/Screens/sharedItems/sharedContentHub.dart';
import '../Providers/authProvider.dart';
import '../Providers/notesProvider.dart';
import '../Screens/profile/profileScreen.dart';
import '../config/creditConfig.dart';
import '../models/notesModel.dart';
import '../services/adService.dart';
import '../services/creditService.dart';
import 'addPlans/addPlan.dart';
import 'addPlans/showPlanFeed.dart';
import 'addQuiz/addQuiz.dart';
import 'addQuiz/quizListScreen.dart';
import 'addnotes/add_notes_screen.dart';
import 'chatBuddyScreen.dart';
import 'homeworkHelper/homeworkScreen.dart';
import 'notesFeed/notesFeedScreen.dart';
import '../../Providers/homeStatsProvider.dart';
import 'notesFeed/showNotesDetail.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _showTooltip = true;
  bool _isProUser = false;
  StreamSubscription? _proSubscription;
  int _notesKey = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showTooltip = false);
      }
    });

    Future.microtask(
      () => Provider.of<HomeStatsProvider>(
        context,
        listen: false,
      ).fetchRecommendedNotes(),
    );

    // Set up listener for pro status
    _setupProStatusListener();
  }

  void _setupProStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _proSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (doc) {
              if (doc.exists) {
                setState(() {
                  _isProUser = doc.data()?['isPro'] ?? false;
                });
              }
            },
            onError: (error) {
              debugPrint('Error listening to pro status: $error');
            },
          );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _proSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<authProvider1>(context);
    final profile = authProv.userModel;

    final List<Widget> _screens = [
      HomeBody(
        profile: profile,
        animation: _fadeAnimation,
        isProUser: _isProUser,
      ),
      NotesFeedScreen(key: ValueKey(_notesKey)),
      QuizListScreen(),
      PlanFeedScreen(),
      ProfileScreen(uid: FirebaseAuth.instance.currentUser!.uid),
    ];

    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: _buildResponsiveBottomNavBar(),
      floatingActionButton: _buildResponsiveFAB(),
    );
  }

  Widget _buildResponsiveBottomNavBar() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375; // iPhone SE, mini
    final double iconSize = isSmallScreen ? 22 : 28;
    final double fontSize = isSmallScreen ? 10 : 12;

    return Padding(
      padding: const EdgeInsets.all(12.0), // margin from edges
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBar(
            height: 70,
            backgroundColor: Colors.transparent, // glass effect
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(
                () => {
                  _selectedIndex = index,
                  if (index == 1)
                    {_notesKey = DateTime.now().millisecondsSinceEpoch},
                },
              );
            },
            indicatorColor: Colors.blueAccent.withOpacity(0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.home,
                  size: iconSize,
                  color: Colors.blueAccent,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.note_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.note,
                  size: iconSize,
                  color: Colors.blueAccent,
                ),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Icon(Icons.quiz_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.quiz,
                  size: iconSize,
                  color: Colors.blueAccent,
                ),
                label: 'Quiz',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_play_next_outlined, size: iconSize),
                selectedIcon: Icon(
                  Icons.queue_play_next,
                  size: iconSize,
                  color: Colors.blueAccent,
                ),
                label: 'Plans',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: iconSize),
                selectedIcon: Icon(
                  Icons.person,
                  size: iconSize,
                  color: Colors.blueAccent,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveFAB() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_showTooltip)
          Positioned(
            bottom: isSmallScreen ? 70 : 80,
            right: isSmallScreen ? 12 : 16,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10 : 12,
                vertical: isSmallScreen ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                "Hey buddy, how can I help you?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
          ),
        FloatingActionButton(
          backgroundColor: Colors.deepPurple,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return ChatBuddyScreen();
                },
              ),
            );
          },
          child: Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
      ],
    );
  }
}

class HomeBody extends StatelessWidget {
  final dynamic profile;
  final Animation<double> animation;
  final bool isProUser;

  const HomeBody({
    super.key,
    required this.profile,
    required this.animation,
    required this.isProUser,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final adWidget = AdService.bannerAd != null && !isProUser
        ? Container(
            alignment: Alignment.center,
            width: AdService.bannerAd!.size.width.toDouble(),
            height: AdService.bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: AdService.bannerAd!),
          )
        : const SizedBox();

    return FadeTransition(
      opacity: animation,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            "Home",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildWelcomeHeader(
                          context,
                          profile,
                          isDark,
                          isProUser,
                        ),
                        const SizedBox(height: 28),
                        _buildProgressOverview(
                          context,
                          screenWidth,
                          screenHeight,
                        ),
                        const SizedBox(height: 32),
                        _buildQuickActions(context),
                        const SizedBox(height: 32),
                        _buildRecommendedResources(
                          context,
                          screenWidth,
                          screenHeight,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          adWidget, // ✅ Banner at bottom
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    dynamic profile,
    bool isDark,
    bool isProUser,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Container(
      padding: EdgeInsets.all(screenWidth > 600 ? 28 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.deepPurple.shade700, Colors.purple.shade900]
              : [Colors.deepPurple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 28 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(isDark ? 0.4 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: screenWidth > 600 ? 36 : 32,
                  backgroundColor: Colors.white,
                  backgroundImage: profile?.profilePic != null
                      ? NetworkImage(profile.profilePic)
                      : null,
                  child: profile?.profilePic == null
                      ? Icon(
                          Icons.person,
                          size: screenWidth > 600 ? 32 : 30,
                          color: Colors.deepPurple.shade400,
                        )
                      : null,
                ),
              ),
              if (isProUser)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.star,
                      color: Colors.deepPurple,
                      size: screenWidth > 600 ? 16 : 14,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: screenWidth > 600 ? 24 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Hello, ${profile?.name?.split(' ').first ?? 'Student'}!",
                      style: TextStyle(
                        fontSize: screenWidth > 600 ? 24 : 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (isProUser) const SizedBox(width: 8),
                    if (isProUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Premium User",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isProUser
                      ? "Enjoy your premium ads free experience! 🎉"
                      : "Ready to boost your productivity today?",
                  style: TextStyle(
                    fontSize: screenWidth > 600 ? 16 : 15,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Consumer<HomeStatsProvider>(
                    builder: (context, stats, _) {
                      if (stats.loading) {
                        return const Text(
                          "Loading goals...",
                          style: TextStyle(color: Colors.white),
                        );
                      }
                      return Text(
                        "Tasks: ${stats.completedPlans}/${stats.completedPlans + stats.incompletePlans} completed",
                        style: TextStyle(
                          fontSize: screenWidth > 600 ? 14 : 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: isSmallScreen ? 140 : 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              const SizedBox(width: 4),
              _buildActionCard(
                title: 'Add Notes',
                icon: Icons.note_add_rounded,
                subtitle: 'Create new notes',
                colors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
                onTap: () {
                  print("Navigating to AddNotesScreen");
                  AdService.showInterstitialAndNavigate(
                    context,
                    AddNotesScreen(),
                  );
                },
                context: context,
              ),

              _buildActionCard(
                title: 'Study Plan',
                icon: Icons.auto_awesome_mosaic_rounded,
                subtitle: 'Plan your study',
                colors: const [Color(0xFF2196F3), Color(0xFF03A9F4)],
                onTap: () {
                  AdService.showInterstitialAndNavigate(
                    context,
                    AiPlannerScreen(),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Create Quiz',
                icon: Icons.quiz_rounded,
                subtitle: 'Test your knowledge',
                colors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                onTap: () {
                  AdService.showInterstitialAndNavigate(
                    context,
                    AddQuizScreen(),
                  );
                },
                context: context,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Popular Actions',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 24 : 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: isSmallScreen ? 140 : 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionCard(
                title: 'Homework Hub',
                icon: Icons.library_books_rounded,
                subtitle: 'Guide steps',
                colors: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                onTap: () {
                  AdService.showInterstitialAndNavigate(
                    context,
                    HomeworkHubScreen(),
                  );
                },
                context: context,
              ),
              _buildActionCard(
                title: 'Shared Items',
                icon: Icons.share_rounded,
                subtitle: 'Get help from your friends',
                colors: const [Color(0xFFFF9800), Color(0xFFFF5722)],
                onTap: () {
                  AdService.showInterstitialAndNavigate(
                    context,
                    SharedContentHub(),
                  );
                },
                context: context,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return Container(
      width: isSmallScreen ? 140 : 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 22 : 26,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverview(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeStatsProvider>(
      builder: (context, stats, _) {
        if (stats.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final statItems = [
          {
            'title': 'Completed Quizzes',
            'value': stats.totalQuizzes.toString(),
            'progress': stats.avgQuizScore / 100,
            'color': Colors.orange,
            'icon': Icons.quiz_rounded,
            'subtitle': 'Score Avg: ${stats.avgQuizScore.toStringAsFixed(1)}%',
          },
          {
            'title': 'Planner',
            'value': '${stats.totalPlans} Plans',
            'progress': stats.totalPlans > 0 ? 0.6 : 0.0,
            'color': Colors.green,
            'icon': Icons.calendar_today_rounded,
            'subtitle': stats.latestExamDate != null
                ? "Exam: ${stats.latestExamDate}"
                : "No exam set",
          },
          {
            'title': 'Goals',
            'value':
                "${stats.completedPlans}/${stats.completedPlans + stats.incompletePlans}",
            'progress': (stats.completedPlans + stats.incompletePlans) > 0
                ? stats.completedPlans /
                      (stats.completedPlans + stats.incompletePlans)
                : 0.0,
            'color': Colors.blue,
            'icon': Icons.flag_rounded,
            'subtitle': "Your goals",
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: screenWidth > 600 ? 24 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: screenHeight * 0.2,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: statItems.length,
                itemBuilder: (context, index) {
                  final stat = statItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildStatCard(
                      title: stat['title'] as String,
                      value: stat['value'] as String,
                      progress: stat['progress'] as double,
                      color: stat['color'] as Color,
                      icon: stat['icon'] as IconData,
                      subtitle: stat['subtitle'] as String,
                      context: context,
                      stats: stats,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
    required IconData icon,
    required String subtitle,
    required BuildContext context,
    required HomeStatsProvider stats,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    return GestureDetector(
      onTap: () => _showStatDialog(context, title, stats),
      child: Container(
        width: isSmallScreen ? 140 : 160,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: isSmallScreen ? 18 : 20, color: color),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: (isSmallScreen ? 100 : 120) * progress,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatDialog(BuildContext context, String title, HomeStatsProvider stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String dialogTitle;
    List<Widget> content = [];
    
    switch (title) {
      case 'Completed Quizzes':
         dialogTitle = 'Quiz Statistics';
         content = [
           _buildDialogRow('Total Quizzes Taken', '${stats.totalQuizzes}', Icons.quiz, context),
           _buildDialogRow('Average Score', '${stats.avgQuizScore.toStringAsFixed(1)}%', Icons.grade, context),
           _buildDialogRow('Current Streak', '${stats.streakCount} days', Icons.local_fire_department, context),
           if (stats.latestExamDate != null && stats.latestExamDate!.isNotEmpty)
              _buildDialogRow('Next Exam', stats.latestExamDate!, Icons.event, context),
         ];
         break;
         
       case 'Planner':
         dialogTitle = 'Study Plan Progress';
         content = [
           _buildDialogRow('Total Plans', '${stats.totalPlans}', Icons.assignment, context),
           _buildDialogRow('Completed Plans', '${stats.completedPlans}', Icons.check_circle, context),
           _buildDialogRow('Incomplete Plans', '${stats.incompletePlans}', Icons.pending, context),
           _buildDialogRow('Completion Rate', '${stats.totalPlans > 0 ? ((stats.completedPlans / stats.totalPlans) * 100).toStringAsFixed(1) : 0}%', Icons.trending_up, context),
         ];
         break;
         
       case 'Goals':
         dialogTitle = 'Goal Tracking';
         content = [
           _buildDialogRow('Study Streak', '${stats.streakCount} days', Icons.local_fire_department, context),
           _buildDialogRow('Quiz Average', '${stats.avgQuizScore.toStringAsFixed(1)}%', Icons.grade, context),
           _buildDialogRow('Plans Completed', '${stats.completedPlans}', Icons.check_circle, context),
           _buildDialogRow('Recommended Notes', '${stats.recommendedNotes.length}', Icons.lightbulb, context),
         ];
         break;
         
       default:
         dialogTitle = 'Statistics';
         content = [
           _buildDialogRow('No data available', '', Icons.info, context),
         ];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                _getIconForTitle(title),
                color: _getColorForTitle(title),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                dialogTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: content,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: _getColorForTitle(title),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(String label, String value, IconData icon, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Completed Quizzes':
        return Icons.quiz;
      case 'Planner':
        return Icons.assignment;
      case 'Goals':
        return Icons.flag;
      default:
        return Icons.info;
    }
  }

  Color _getColorForTitle(String title) {
    switch (title) {
      case 'Completed Quizzes':
        return Colors.blue;
      case 'Planner':
        return Colors.green;
      case 'Goals':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference > 1) {
      return 'In $difference days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildRecommendedResources(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeStatsProvider>(
      builder: (context, stats, _) {
        if (stats.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stats.recommendedNotes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, top: 16),
            child: Text(
              "No notes to recommend yet",
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Recommended For You',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 24 : 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: screenHeight * 0.35,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stats.recommendedNotes.length,
                itemBuilder: (context, index) => FadeTransition(
                  opacity: animation,
                  child: _buildResourceCard(
                    note: stats.recommendedNotes[index],
                    index: index,
                    isDark: isDark,
                    context: context,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResourceCard({
    required int index,
    required bool isDark,
    required NoteModel note,
    required BuildContext context,
  }) {
    final random = Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 375;

    final colors = [
      [const Color(0xFFFFA726), const Color(0xFFFF7043)],
      [const Color(0xFF42A5F5), const Color(0xFF4FC3F7)],
      [const Color(0xFF66BB6A), const Color(0xFF81C784)],
      [const Color(0xFFAB47BC), const Color(0xFFBA68C8)],
      [const Color(0xFFEF5350), const Color(0xFFE57373)],
    ];

    final icons = [
      Icons.school_rounded,
      Icons.timer_rounded,
      Icons.assignment_rounded,
      Icons.self_improvement_rounded,
      Icons.work_rounded,
    ];

    final times = [
      "5 min read",
      "7 min read",
      "10 min read",
      "12 min read",
      "15 min read",
      "20 min read",
    ];

    final tag = note.tags.isNotEmpty
        ? note.tags[random.nextInt(note.tags.length)]
        : ["Learning", "Productivity", "Academics", "Wellness", "Future"][random
              .nextInt(5)];

    return Container(
      width: isSmallScreen ? 180 : 220,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            AdService.showInterstitialAndNavigate(
              context,
              NoteDetailScreen(
                note: note,
                onShare: () {
                  _openShareDialog(note, context);
                },
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors[index % colors.length],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[index % colors.length][0].withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[index % icons.length],
                    size: isSmallScreen ? 20 : 24,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  note.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: isSmallScreen ? 12 : 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      times[random.nextInt(times.length)],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: isSmallScreen ? 12 : 16,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: isSmallScreen ? 12 : 16,
                        color: Colors.white,
                      ),
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

  void _openShareDialog(NoteModel note, BuildContext context) {
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
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final already = note.withShared.toSet();
        final selected = <String>{};

        return StatefulBuilder(
          builder: (context, setStateSB) {
            Future<void> runSearch(String query) async {
              setStateSB(() => isLoading = true);
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
                            'Share note',
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
                    // 🔍 search field
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
                                                      'Note already shared with this user',
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
                                              'Note already shared with this user',
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

                    // ✅ Share button with credit deduction
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
                                    cost: CreditsConfig.shareNote,
                                    actionName: "Share Notes",
                                    onConfirmedAction: () async {
                                      final (added, alreadyDup) = await provider
                                          .shareNoteWithUsers(
                                            note: note,
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
                                              'Shared with ${added.length} user(s) 🎉 -${CreditsConfig.shareNote} credits',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
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
