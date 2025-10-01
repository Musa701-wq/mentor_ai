import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Providers/homeStatsProvider.dart';
import '../../Providers/profileProvider.dart';
import '../../models/usermodel.dart';
import '../purchaseScreen/creditPurchaseScreen.dart';
import 'editProfileScreen.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;
  int _userCredits = 150; // Placeholder for user credits
  bool _isProUser = false;
  StreamSubscription? _proSubscription;

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
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      await profileProvider.fetchUser(widget.uid);

      final statProvider = Provider.of<HomeStatsProvider>(context, listen: false);
      await statProvider.checkStreak();

      // Set up listener for pro status
      _setupProStatusListener();

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
    final profileProvider = Provider.of<ProfileProvider>(context);
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
                  _buildProfileStats(isDark),
                  const SizedBox(height: 28),
                  _buildProfileInfoCard(user, isDark, context),
                  const SizedBox(height: 30),
                  _buildActionButtons(context, isDark),
                  const SizedBox(height: 30),
                  _buildLegalSection(context, isDark),
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

  Widget _buildEnhancedProfileHeader(UserModel user, bool isDark, int credits) {
    return Container(
      padding: EdgeInsets.all(16), // Reduced padding for smaller screens
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.deepPurple.shade700, Colors.purple.shade900]
              : [Colors.deepPurple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(isDark ? 0.4 : 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 400;

          return isSmallScreen
              ? _buildSmallScreenLayout(user, isDark, credits, constraints)
              : _buildRegularScreenLayout(user, isDark, credits);
        },
      ),
    );
  }

  Widget _buildRegularScreenLayout(UserModel user, bool isDark, int credits) {
    return Row(
      children: [
        // Avatar with Pro badge
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
                child: user.profilePic == null
                    ? Icon(Icons.person, size: 36, color: Colors.deepPurple.shade400)
                    : null,
              ),
            ),
            if (_isProUser)
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
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    user.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isProUser)
                    const SizedBox(width: 8),
                  if (_isProUser)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "PRO",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (user.email != null)
                Text(
                  user.email!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Credits + Buy Button Row (only show if not Pro user)
              if (!_isProUser) ...[
                Row(
                  children: [
                    // Credits Display
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.currency_exchange_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$credits Credits',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Buy Credits Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) {
                          return const CreditsStoreScreen();
                        }));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text(
                        "Buy",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Other tags (grade, goal etc.)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (user.grade != null && user.grade!.isNotEmpty)
                    _buildTag(Icons.school, user.grade!),
                  if (user.goal != null && user.goal!.isNotEmpty)
                    _buildTag(Icons.flag, user.goal!),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(UserModel user, bool isDark, int credits, BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar and name row
        Row(
          children: [
            // Avatar with Pro badge
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30, // Smaller avatar on small screens
                    backgroundColor: Colors.white,
                    backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
                    child: user.profilePic == null
                        ? Icon(Icons.person, size: 24, color: Colors.deepPurple.shade400)
                        : null,
                  ),
                ),
                if (_isProUser)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.deepPurple,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_isProUser)
                        const SizedBox(width: 6),
                      if (_isProUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "PRO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Credits + Buy Button Row - only show if not Pro user
        if (!_isProUser) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Credits Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      '$credits Credits',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Buy Credits Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return const CreditsStoreScreen();
                  }));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text(
                  "Buy Credits",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],


        // Other tags (grade, goal etc.)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (user.grade != null && user.grade!.isNotEmpty)
              _buildTag(Icons.school, user.grade!),
            if (user.goal != null && user.goal!.isNotEmpty)
              _buildTag(Icons.flag, user.goal!),
          ],
        ),
      ],
    );
  }

  // Small helper for tags
  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats(bool isDark) {
    final stats = Provider.of<HomeStatsProvider>(context);

    final items = [
      {
        "title": "Notes",
        "value": stats.recommendedNotes.length.toString(),
        "icon": Icons.note_rounded,
        "color": Colors.purple,
      },
      {
        "title": "Completed Quizzes",
        "value": stats.totalQuizzes.toString(),
        "icon": Icons.quiz_rounded,
        "color": Colors.orange,
      },
      {
        "title": "Plans",
        "value": stats.totalPlans.toString(),
        "icon": Icons.calendar_today_rounded,
        "color": Colors.green,
      },
      {
        "title": "Streak",
        "value": "${stats.streakCount} days",
        "icon": Icons.local_fire_department_rounded,
        "color": Colors.red,
      },
    ];

    return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 1.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildStatItem(
                  context: context,
                  title: item["title"] as String,
                  value: item["value"] as String,
                  icon: item["icon"] as IconData,
                  color: item["color"] as Color,
                  isDark: isDark,
                );
              },
            );
          },
        )
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
          onTap: () => _showStatDialog(context, title),
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

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
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
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              shadowColor: Colors.redAccent.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  void _showDeleteAccountDialog(BuildContext context) {
    debugPrint("🚨 [DELETE_DIALOG] Opening delete account confirmation dialog");
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint("❌ [DELETE_DIALOG] User cancelled account deletion");
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                debugPrint("✅ [DELETE_DIALOG] User confirmed account deletion");
                Navigator.of(context).pop(); // Close the dialog first
                
                try {
                  debugPrint("🔄 [DELETE_DIALOG] Getting ProfileProvider instance from context");
                  final provider = Provider.of<ProfileProvider>(context, listen: false);
                  debugPrint("✅ [DELETE_DIALOG] ProfileProvider instance obtained");
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
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
                  await provider.deleteAccount(context);
                  debugPrint("✅ [DELETE_DIALOG] Account deletion completed successfully");
                  
                  // Close loading dialog if still open
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  
                } catch (e) {
                  debugPrint("❌ [DELETE_DIALOG] Error during account deletion: $e");
                  debugPrint("📊 [DELETE_DIALOG] Error type: ${e.runtimeType}");
                  debugPrint("📝 [DELETE_DIALOG] Error details: ${e.toString()}");
                  
                  // Close loading dialog if still open
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  
                  // Show error message to user
                  if (mounted) {
                    debugPrint("📢 [DELETE_DIALOG] Showing error SnackBar to user");
                    ScaffoldMessenger.of(context).showSnackBar(
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

  void _showStatDialog(BuildContext context, String title) {
    final stats = Provider.of<HomeStatsProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
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
                  title,
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
              children: [
                const SizedBox(height: 8),
                ...switch (title) {
                  'Notes' => [
                    _buildDialogRow(context, 'Total Notes', stats.recommendedNotes.length.toString()),
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
                  ],
                  'Completed Quizzes' => [
                    _buildDialogRow(context, 'Total Quizzes', stats.totalQuizzes.toString()),
                    _buildDialogRow(context, 'Average Score', '${stats.avgQuizScore.toStringAsFixed(1)}%'),
                    if (stats.totalQuizzes > 0)
                      _buildDialogRow(context, 'Performance', stats.avgQuizScore >= 80 ? 'Excellent' : stats.avgQuizScore >= 60 ? 'Good' : 'Needs Improvement'),
                  ],
                  'Plans' => [
                    _buildDialogRow(context, 'Total Plans', stats.totalPlans.toString()),
                    _buildDialogRow(context, 'Completed', stats.completedPlans.toString()),
                    _buildDialogRow(context, 'In Progress', stats.incompletePlans.toString()),
                    if (stats.totalPlans > 0)
                      _buildDialogRow(context, 'Completion Rate', '${((stats.completedPlans / stats.totalPlans) * 100).toStringAsFixed(1)}%'),
                    if (stats.latestExamDate != null && stats.latestExamDate!.isNotEmpty)
                      _buildDialogRow(context, 'Next Exam', stats.latestExamDate!),
                  ],
                  'Streak' => [
                    _buildDialogRow(context, 'Current Streak', '${stats.streakCount} days'),
                    _buildDialogRow(context, 'Status', stats.streakCount >= 7 ? 'On Fire! 🔥' : stats.streakCount >= 3 ? 'Great Progress! 👍' : 'Keep Going! 💪'),
                    if (stats.streakCount > 0)
                      _buildDialogRow(context, 'Motivation', 'You\'re doing amazing! Keep up the great work!'),
                  ],
                  _ => [
                    Text(
                      'No additional information available.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                },
              ],
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

  Widget _buildDialogRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Notes':
        return Icons.note_rounded;
      case 'Completed Quizzes':
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
      case 'Completed Quizzes':
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