import 'package:flutter/material.dart';

class OnboardingProfile extends StatefulWidget {
  final void Function(String name, String grade, List<String> subjects) onNext;
  const OnboardingProfile({super.key, required this.onNext});

  @override
  State<OnboardingProfile> createState() => _OnboardingProfileState();
}

class _OnboardingProfileState extends State<OnboardingProfile> {
  String? _selectedGrade;
  final List<String> _selectedSubjects = [];

  final grades = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12', 'University'];
  final subjects = ['Math', 'Physics', 'Chemistry', 'Biology', 'English'];

  @override
  void initState() {
    super.initState();
    // Set default values to prevent blocking
    _selectedGrade = grades.first;
    _selectedSubjects.addAll(['Math', 'English']); // Default subjects
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Create Your Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us about yourself to personalize your experience',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Name field removed – name comes from Google/Apple sign-in
                      const SizedBox(height: 0),

                      // Grade Selection
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Grade',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedGrade,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? Colors.grey[700] : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                              items: grades.map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedGrade = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Subjects Selection
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Subjects (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Choose the subjects you want to focus on',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: subjects.map((s) {
                                final isSelected = _selectedSubjects.contains(s);
                                return FilterChip(
                                  label: Text(s),
                                  selected: isSelected,
                                  onSelected: (sel) {
                                    setState(() {
                                      if (sel) {
                                        _selectedSubjects.add(s);
                                      } else {
                                        _selectedSubjects.remove(s);
                                      }
                                    });
                                  },
                                  selectedColor: const Color(0xFF7E57C2),
                                  checkmarkColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white :
                                    (isDark ? Colors.white : Colors.grey[800]),
                                  ),
                                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Next Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Pass blank name; actual name is sourced from sign-in
                            widget.onNext(
                              '',
                              _selectedGrade!,
                              _selectedSubjects,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E57C2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: Colors.purple.withOpacity(0.3),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}