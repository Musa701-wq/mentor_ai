import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/Firestore_service.dart';
import '../../widgets/FullScreenImageViewer.dart';
import 'InfographicGeneratorScreen.dart';

class InfographicHubScreen extends StatefulWidget {
  const InfographicHubScreen({super.key});

  @override
  State<InfographicHubScreen> createState() => _InfographicHubScreenState();
}

class _InfographicHubScreenState extends State<InfographicHubScreen> {
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
            Colors.amber.shade100,
            Colors.orange.shade100,
            Colors.purple.shade100,
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
          "Infographic Hub",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2D2B4E),
            fontSize: 20,
          ),
        ),
        background: const SizedBox(),
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
              title: "New Infographic",
              subtitle: "Convert messy notes into visuals",
              icon: Icons.add_photo_alternate_rounded,
              gradient: [const Color(0xFF6C63FF), const Color(0xFF8E24AA)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InfographicGeneratorScreen()),
              ),
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
              "Recent Activities",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D2B4E),
              ),
            ),
            const Spacer(),
            Icon(Icons.history_rounded, color: Colors.orange.shade700, size: 20),
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
      stream: _firestoreService.getInfographicHistoryStream(_uid),
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
            Icon(Icons.lock_person_rounded, size: 60, color: Colors.orange.withOpacity(0.3)),
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
              "Your infographics will be synced across devices.",
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
    final notes = data['notes'] ?? '';
    final docId = data['id'] ?? '';
    final base64Image = data['imageData'];

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
          onTap: () async {
            final localFile = await _getLocalImageFile(docId);
            if (!context.mounted) return;
            
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => FullScreenImageViewer(
                  imageBytes: (localFile == null && base64Image != null) ? base64.decode(base64Image) : null,
                  imageFile: localFile,
                  title: notes.split('\n').first,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildImagePreview(docId, base64Image),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notes.split('\n').first,
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
                Icon(Icons.chevron_right_rounded, color: Colors.orange.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String docId, String? base64String) {
    return FutureBuilder<File?>(
      future: _getLocalImageFile(docId),
      builder: (context, snapshot) {
        Widget image;
        if (snapshot.hasData && snapshot.data != null) {
          image = Image.file(snapshot.data!, fit: BoxFit.cover);
        } else if (base64String != null && base64String.isNotEmpty) {
          try {
            image = Image.memory(base64.decode(base64String), fit: BoxFit.cover);
          } catch (e) {
            image = Container(color: Colors.orange.shade100, child: const Icon(Icons.image_not_supported));
          }
        } else {
          image = Container(color: Colors.orange.shade100, child: const Icon(Icons.auto_awesome));
        }

        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: image,
          ),
        );
      },
    );
  }

  Future<File?> _getLocalImageFile(String docId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/infographic_$docId.png');
      if (await file.exists()) return file;
    } catch (e) {
      debugPrint('Local file error: $e');
    }
    return null;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_mosaic_rounded, size: 60, color: Colors.orange.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              "No infographics yet",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            Text(
              "Start converting your notes today!",
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
