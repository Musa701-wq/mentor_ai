import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_ai/config/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Providers/homeStatsProvider.dart';
import '../../Providers/profileProvider.dart';
import '../../models/usermodel.dart';
import 'DetailedAnalyticsScreen.dart';
import '../purchaseScreen/creditPurchaseScreen.dart';
import 'editProfileScreen.dart';
import '../authwrapper.dart';
import 'OtherProductsScreen.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final void Function(int index)? onNavigateToIndex;
  const ProfileScreen({super.key, required this.uid, this.onNavigateToIndex});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;
  num _userCredits = 0; // Placeholder for user credits
  bool _isProUser = false;
  StreamSubscription? _proSubscription;
  User? _currentUser;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _currentUser = FirebaseAuth.instance.currentUser;

      if (_currentUser != null) {
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
        await profileProvider.fetchUser(widget.uid);

        final statProvider = Provider.of<HomeStatsProvider>(context, listen: false);
        await statProvider.checkStreak();

        // Set up listener for pro status
        _setupProStatusListener();
      }

      setState(() {
        _isLoading = false;
      });
      _controller.forward();
    });
  }

  void _setupProStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _proSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          setState(() {
            _isProUser = doc.data()?['isPro'] ?? false;
          });
        }
      }, onError: (error) {
        debugPrint('Error listening to pro status: $error');
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _proSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.deepPurple,
          ),
        ),
      );
    }

    // Check if user is logged in
    if (_currentUser == null) {
      return _buildLoggedOutScreen(isDark);
    }

    // User is logged in, show normal profile screen
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.user;
    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        body: Center(
          child: Text(
            'User not found',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
      );
    }

    return _buildLoggedInScreen(user, isDark);
  }

  Widget _buildLoggedOutScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Welcome Icon/Image
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome Text
                  Text(
                    "Welcome to Mentor AI!",
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
                    "Access personalized learning resources, track your progress, and unlock premium features by creating an account.",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Features Grid
                  _buildFeaturesGrid(isDark),
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
                            'Login to Continue',
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
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Login to access your personalized dashboard, save progress, and sync across devices.",
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
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isDark) {
    final features = [
      {
        'icon': Icons.quiz_rounded,
        'title': 'Smart Quizzes',
        'description': 'Personalized quizzes based on your learning needs',
        'color': Colors.orange,
      },
      {
        'icon': Icons.note_rounded,
        'title': 'Study Notes',
        'description': 'AI-generated notes tailored to your subjects',
        'color': Colors.purple,
      },
      {
        'icon': Icons.calendar_today_rounded,
        'title': 'Study Plans',
        'description': 'Customized study schedules and progress tracking',
        'color': Colors.green,
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Progress Analytics',
        'description': 'Track your learning journey with detailed insights',
        'color': Colors.blue,
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

  Widget _buildLoggedInScreen(UserModel user, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(context, isDark),
                  const SizedBox(height: 24),
                  _buildEnhancedProfileHeader(user, isDark, user.credits),
                  const SizedBox(height: 28),
                  _buildAnalyticsSection(isDark),
                  const SizedBox(height: 28),
                  _buildProfileInfoCard(user, isDark, context),
                  const SizedBox(height: 30),
                  _buildLegalSection(context, isDark),
                  _buildLogoutButton(context, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "My Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedProfileHeader(UserModel user, bool isDark, num credits) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
            const Color(0xFF7C4DFF), // Deep purple
            const Color(0xFF448AFF), // Bright blue
            const Color(0xFF00B0FF), // Light blue
          ]
              : [
            const Color(0xFF6A1B9A), // Rich purple
            const Color(0xFF8E24AA), // Vibrant purple
            const Color(0xFFAB47BC), // Soft purple
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row - Profile, User Info, and Edit Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Avatar
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.amber.shade200,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                          ? NetworkImage(user.profilePic!)
                          : null,
                      child: user.profilePic == null || user.profilePic!.isEmpty
                          ? Icon(
                        Icons.person,
                        size: 26,
                        color: const Color(0xFF6A1B9A),
                      )
                          : null,
                    ),
                  ),
                  if (_isProUser)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 1.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Colors.deepPurple,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // User Info and Premium Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "${user.name ?? 'User'} 👋",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isProUser) const SizedBox(width: 8),
                        if (_isProUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "PREMIUM",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isProUser
                          ? "Premium member enjoying exclusive benefits! ✨"
                          : "Ready to boost your learning experience? 🚀",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit Profile Button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: IconButton(
                  iconSize: 18,
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Credits and Stats Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Credits Icon
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),

                // Credits Info
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Available Credits",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "${credits.toStringAsFixed(1)} credits",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Get More Button and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Get More Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreditsStoreScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Get More",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      credits > 10 ? "Good balance" : "Consider topping up",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Stats Row
          const SizedBox(height: 12),
          Consumer<HomeStatsProvider>(
            builder: (context, stats, _) {
              return Row(
                children: [
                  Expanded(
                    child: _buildProfileMiniStat(
                      icon: Icons.quiz_rounded,
                      value: "Quizzes",
                      count: stats.totalQuizzes,
                      onTap: () {
                        widget.onNavigateToIndex?.call(2);
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildProfileMiniStat(
                      icon: Icons.notes_rounded,
                      value: "Notes",
                      count: stats.recommendedNotes.length,
                      onTap: () {
                        widget.onNavigateToIndex?.call(1);
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildProfileMiniStat(
                      icon: Icons.flag_rounded,
                      value: "Plans",
                      count: stats.totalPlans,
                      onTap: () {
                        widget.onNavigateToIndex?.call(3);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMiniStat({
    required IconData icon,
    required String value,
    required int count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection(bool isDark) {
    final stats = Provider.of<HomeStatsProvider>(context);
    final completionRate = stats.totalPlans > 0
        ? (stats.completedPlans / stats.totalPlans)
        : 0.0;

    final items = [
      {
        "title": "Notes",
        "value": stats.totalNotes.toString(),
        "icon": Icons.note_rounded,
        "color": Colors.purple,
        "subtitle": "Created",
      },
      {
        "title": "Homework",
        "value": stats.totalHomeworks.toString(),
        "icon": Icons.assignment_turned_in_rounded,
        "color": Colors.blue,
        "subtitle": "Solved",
      },
      {
        "title": "Quizzes",
        "value": stats.totalQuizzes.toString(),
        "icon": Icons.quiz_rounded,
        "color": Colors.orange,
        "subtitle": "${stats.avgQuizScore.toStringAsFixed(0)}% Avg",
      },
      {
        "title": "Streak",
        "value": stats.streakCount.toString(),
        "icon": Icons.local_fire_department_rounded,
        "color": Colors.red,
        "subtitle": "Days",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'Learning Analytics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            final int crossAxisCount = maxWidth < 600 ? 2 : 4;
            final double childAspectRatio = maxWidth < 600 ? 1.5 : 1.2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildAnalyticsCard(
                  title: item["title"] as String,
                  value: item["value"] as String,
                  subtitle: item["subtitle"] as String,
                  icon: item["icon"] as IconData,
                  color: item["color"] as Color,
                  isDark: isDark,
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        _buildStudyPlanProgress(completionRate, isDark),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetailedAnalyticsScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            foregroundColor: const Color(0xFF6C63FF),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.3)),
          ),
          child: const Text('View Detailed Analytics 📊', 
            style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPlanProgress(double rate, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Study Goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              Text(
                '${(rate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final stats = Provider.of<HomeStatsProvider>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isSmallScreen = screenWidth < 360;
        final bool isTablet = screenWidth > 600;
        final bool isLargeTablet = screenWidth > 900;

        // Responsive sizing
        final double valueSize = isSmallScreen ? 16 : (isTablet ? 20 : 18);
        final double titleSize = isSmallScreen ? 12 : (isTablet ? 14 : 13);
        final double iconSize = isSmallScreen ? 18 : (isTablet ? 22 : 20);
        final double iconPadding = isSmallScreen ? 6 : (isTablet ? 10 : 8);

        // Responsive padding
        final double containerPadding = isSmallScreen ? 12 : (isTablet ? 20 : 16);
        final double spacing = isSmallScreen ? 8 : (isTablet ? 16 : 12);
        final double borderRadius = isSmallScreen ? 16 : (isTablet ? 24 : 20);

        return GestureDetector(
          onTap: () => _showEnhancedStatDialog(context, title, stats),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
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
            padding: EdgeInsets.all(containerPadding),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: iconSize, color: color),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: valueSize,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEnhancedStatDialog(BuildContext context, String title, HomeStatsProvider stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String dialogTitle;
    List<Widget> content = [];

    switch (title) {
      case 'Notes':
        dialogTitle = 'Notes Statistics';
        content = [
          _buildEnhancedDialogRow(
            'Total Notes Created',
            '${stats.recommendedNotes.length}',
            Icons.note,
            context,
          ),
          if (stats.recommendedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recommended Notes:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...stats.recommendedNotes.take(3).map((note) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${note.title}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
            ),
          ],
        ];
        break;

      case 'Quizzes':
        dialogTitle = 'Quiz Statistics';
        content = [
          _buildEnhancedDialogRow(
            'Total Quizzes Taken',
            '${stats.totalQuizzes}',
            Icons.quiz,
            context,
          ),
          _buildEnhancedDialogRow(
            'Average Score',
            '${stats.avgQuizScore.toStringAsFixed(1)}%',
            Icons.grade,
            context,
          ),
          _buildEnhancedDialogRow(
            'Performance Level',
            stats.avgQuizScore >= 80 ? 'Excellent 🎉' :
            stats.avgQuizScore >= 60 ? 'Good 👍' : 'Needs Improvement 💪',
            Icons.trending_up,
            context,
          ),
        ];
        break;

      case 'Plans':
        dialogTitle = 'Study Plan Progress';
        content = [
          _buildEnhancedDialogRow(
            'Total Plans',
            '${stats.totalPlans}',
            Icons.assignment,
            context,
          ),
          _buildEnhancedDialogRow(
            'Completed Plans',
            '${stats.completedPlans}',
            Icons.check_circle,
            context,
          ),
          _buildEnhancedDialogRow(
            'In Progress',
            '${stats.incompletePlans}',
            Icons.pending,
            context,
          ),
          _buildEnhancedDialogRow(
            'Completion Rate',
            '${stats.totalPlans > 0 ? ((stats.completedPlans / stats.totalPlans) * 100).toStringAsFixed(1) : 0}%',
            Icons.trending_up,
            context,
          ),
          if (stats.latestExamDate != null)
            _buildEnhancedDialogRow(
              'Next Exam',
              stats.latestExamDate!.toLocal().toString().split(' ')[0],
              Icons.event,
              context,
            ),
        ];
        break;

      case 'Streak':
        dialogTitle = 'Learning Streak';
        content = [
          _buildEnhancedDialogRow(
            'Current Streak',
            '${stats.streakCount} days',
            Icons.local_fire_department,
            context,
          ),
          _buildEnhancedDialogRow(
            'Status',
            stats.streakCount >= 7 ? 'On Fire! 🔥' :
            stats.streakCount >= 3 ? 'Great Progress! 👍' : 'Keep Going! 💪',
            Icons.emoji_events,
            context,
          ),
          if (stats.streakCount > 0)
            _buildEnhancedDialogRow(
              'Motivation',
              'You\'re doing amazing! Keep up the great work!',
              Icons.celebration,
              context,
            ),
        ];
        break;

      default:
        dialogTitle = 'Statistics';
        content = [
          _buildEnhancedDialogRow('No data available', '', Icons.info, context),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getColorForTitle(title).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForTitle(title),
                  color: _getColorForTitle(title),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dialogTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildEnhancedDialogRow(
      String label,
      String value,
      IconData icon,
      BuildContext context,
      ) {
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

  // Rest of the existing methods remain the same...
  Widget _buildProfileInfoCard(UserModel user, bool isDark, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              if (_isProUser)
                const SizedBox(width: 12),
              if (_isProUser)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "PREMIUM MEMBER",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: user.email ?? 'Not provided',
            isDark: isDark,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.person_rounded,
            label: 'Full Name',
            value: user.name ?? 'Not provided',
            isDark: isDark,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.school_rounded,
            label: 'Grade',
            value: user.grade ?? 'Not provided',
            isDark: isDark,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.flag_rounded,
            label: 'Goal',
            value: user.goal ?? 'Not provided',
            isDark: isDark,
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Colors.deepPurple,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subjects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (user.subjects != null && user.subjects!.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: user.subjects!
                            .map((subject) => Chip(
                          label: Text(
                            subject,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                          backgroundColor: isDark
                              ? Colors.deepPurple.shade300
                              : Colors.deepPurple.shade500,
                        ))
                            .toList(),
                      )
                    else
                      Text(
                        'No subjects added',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.deepPurple,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      child: ElevatedButton(
        onPressed: () async {
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          profileProvider.setUser(UserModel(
            uid: '',
            email: '',
            name: '',
            grade: '',
            goal: '',
            subjects: [],
            profilePic: '',
          ));
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => AuthWrapper()),
                (route) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legal & Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Other Products
          _buildLegalItem(
            icon: Icons.apps_rounded,
            title: 'Other Products',
            subtitle: 'Discover more educational apps',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OtherProductsScreen()),
              );
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Privacy Policy
          _buildLegalItem(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'Learn how we protect your data',
            onTap: () {
              _launchUrl('https://vectorlabzlimited.com/privacy-policy/');
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Terms of Use
          _buildLegalItem(
            icon: Icons.description_rounded,
            title: 'Terms of Use',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              _launchUrl('https://vectorlabzlimited.com/terms-of-use/');
            },
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Delete Account
          _buildLegalItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account and data',
            onTap: () {
              _showDeleteAccountDialog(context);
            },
            isDark: isDark,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Colors.deepPurple.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.deepPurple,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : (isDark ? Colors.white : Colors.grey[800]),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      onTap: onTap,
    );
  }

  void _showDeleteAccountDialog(BuildContext parentContext) {
    debugPrint("🚨 [DELETE_DIALOG] Opening delete account confirmation dialog");

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint("❌ [DELETE_DIALOG] User cancelled account deletion");
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                debugPrint("✅ [DELETE_DIALOG] User confirmed account deletion");
                Navigator.of(dialogContext).pop();

                try {
                  debugPrint("🔄 [DELETE_DIALOG] Getting ProfileProvider instance from parent context");
                  final provider = Provider.of<ProfileProvider>(parentContext, listen: false);
                  debugPrint("✅ [DELETE_DIALOG] ProfileProvider instance obtained");

                  final bool? proceed = await showDialog<bool>(
                    context: parentContext,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Re-authentication Required'),
                      content: const Text(
                          'To delete your account, you will be asked to re-authenticate.\n\nPlease make sure to log in to the SAME account to continue.'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  );

                  if (proceed != true) {
                    debugPrint("❌ [DELETE_DIALOG] User cancelled at pre-auth step");
                    return;
                  }

                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (BuildContext loadingDialogContext) {
                      return const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 20),
                            Text("Deleting account..."),
                          ],
                        ),
                      );
                    },
                  );

                  debugPrint("🔥 [DELETE_DIALOG] Calling provider.deleteAccount()");
                  await provider.deleteAccount(parentContext);
                  debugPrint("✅ [DELETE_DIALOG] Account deletion completed successfully");

                  try {
                    Navigator.of(parentContext, rootNavigator: true).pop();
                  } catch (_) {}

                  if (!mounted) return;
                  Navigator.of(parentContext, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                        (route) => false,
                  );

                } catch (e) {
                  debugPrint("❌ [DELETE_DIALOG] Error during account deletion: $e");
                  debugPrint("📊 [DELETE_DIALOG] Error type: ${e.runtimeType}");
                  debugPrint("📝 [DELETE_DIALOG] Error details: ${e.toString()}");

                  try {
                    Navigator.of(parentContext, rootNavigator: true).pop();
                  } catch (_) {}

                  if (mounted) {
                    debugPrint("📢 [DELETE_DIALOG] Showing error SnackBar to user");
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Notes':
        return Icons.note_rounded;
      case 'Quizzes':
        return Icons.quiz_rounded;
      case 'Plans':
        return Icons.calendar_today_rounded;
      case 'Streak':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getColorForTitle(String title) {
    switch (title) {
      case 'Notes':
        return Colors.purple;
      case 'Quizzes':
        return Colors.orange;
      case 'Plans':
        return Colors.green;
      case 'Streak':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}