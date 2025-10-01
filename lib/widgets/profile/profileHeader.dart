import 'package:flutter/material.dart';

import '../../models/usermodel.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel profile;
  const ProfileHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Picture
          CircleAvatar(
            radius: screenWidth * 0.12,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: profile.profilePic.isNotEmpty
                ? NetworkImage(profile.profilePic)
                : const AssetImage('assets/images/fallback.png') as ImageProvider,
          ),
          const SizedBox(width: 16),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        Text('Grade: ${profile.grade}',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag, color: Colors.white70, size: 18),
                        const SizedBox(width: 4),
                        Text('Goal: ${profile.goal}',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (profile.subjects.isNotEmpty)
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: profile.subjects
                          .map((sub) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: Chip(
                          label: Text(sub, style: TextStyle(fontSize: screenWidth * 0.033, color: Colors.black)),
                          backgroundColor: Colors.white24.withOpacity(0.3),
                        ),
                      ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
