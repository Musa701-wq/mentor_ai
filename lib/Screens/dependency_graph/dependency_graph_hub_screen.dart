import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/Firestore_service.dart';
import '../../Providers/dependencyGraphProvider.dart';
import 'dependency_graph_screen.dart';

class DependencyGraphHubScreen extends StatefulWidget {
  const DependencyGraphHubScreen({super.key});

  @override
  State<DependencyGraphHubScreen> createState() => _DependencyGraphHubScreenState();
}

class _DependencyGraphHubScreenState extends State<DependencyGraphHubScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildGradientBackground(),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              _buildActionsSection(),
              _buildHistoryHeader(),
              _buildHistoryList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.lightBlue.shade100,
            Colors.cyan.shade50,
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          "Dependency Hub",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2D2B4E),
            fontSize: 20,
          ),
        ),
        background: const SizedBox(),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2B4E)),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildActionsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildActionCard(
              title: "New Topic Graph",
              subtitle: "Build chronological paths",
              icon: Icons.account_tree_rounded,
              gradient: [const Color(0xFF2196F3), const Color(0xFF03A9F4)],
              onTap: () {
                  final provider = Provider.of<DependencyGraphProvider>(context, listen: false);
                  provider.reset();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DependencyGraphScreen()),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Row(
          children: [
            Text(
              "Recent Graphs",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D2B4E),
              ),
            ),
            const Spacer(),
            Icon(Icons.history_rounded, color: Colors.blue.shade700, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_uid.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildGuestHistoryPlaceholder(),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getDependencyGraphHistoryStream(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildHistoryCard(data);
              },
              childCount: snapshot.data!.docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuestHistoryPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.lock_person_rounded, size: 60, color: Colors.blue.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              "Log in to save history",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your topic dependencies will be synced.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('MMM dd, hh:mm a').format(timestamp.toDate())
        : 'Recently';
    final topic = data['topic'] ?? 'Unknown Topic';
    final graphData = data['graphData'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (graphData != null) {
              final provider = Provider.of<DependencyGraphProvider>(context, listen: false);
              provider.loadGraphFromHistory(topic, graphData);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DependencyGraphScreen()),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_tree_outlined, color: Colors.blue.shade600),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D2B4E),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.blue.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_mosaic_rounded, size: 60, color: Colors.blue.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              "No topic graphs yet",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            Text(
              "Generate dependencies to see them here!",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
