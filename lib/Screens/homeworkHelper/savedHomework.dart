// lib/screens/homework/saved_homework_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/homeworkProvider.dart';
import 'homeworkDetailScreen.dart';

class SavedHomeworkScreen extends StatefulWidget {
  const SavedHomeworkScreen({super.key});

  @override
  State<SavedHomeworkScreen> createState() => _SavedHomeworkScreenState();
}

class _SavedHomeworkScreenState extends State<SavedHomeworkScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // 🔹 Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeworkProvider>().fetchHomeworks(reset: true);
    });

    // 🔹 Infinite scroll
    _scrollController.addListener(() {
      final provider = context.read<HomeworkProvider>();
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !provider.loadingMore &&
          provider.hasMore) {
        provider.fetchHomeworks();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    context.read<HomeworkProvider>().fetchHomeworks(reset: true, searchQuery: query);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeworkProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "My Saved Solutions",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
            onPressed: () =>
                context.read<HomeworkProvider>().fetchHomeworks(reset: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          _buildSearchBar(isDark),

          Expanded(
            child: provider.loadingList
                ? _buildLoadingState(isDark)
                : provider.homeworks.isEmpty
                ? _buildEmptyState(isDark)
                : _buildHomeworkList(provider, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: "Search solutions...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch("");
                    },
                  )
                      : null,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          isDark ? Colors.purple.shade300 : Colors.purple.shade600,
        ),
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
            "No Saved Solutions Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Solve homework problems to see them here",
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkList(HomeworkProvider provider, bool isDark) {
    return RefreshIndicator(
      onRefresh: () => provider.fetchHomeworks(reset: true),
      color: isDark ? Colors.purple.shade300 : Colors.purple.shade600,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: provider.homeworks.length + (provider.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.homeworks.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final hw = provider.homeworks[index];
          return _buildHomeworkCard(context, hw, isDark);
        },
      ),
    );
  }

  Widget _buildHomeworkCard(BuildContext context, Map<String, dynamic> hw, bool isDark) {
    final timestamp = DateTime.tryParse(hw["timestamp"] ?? "");
    final formattedDate = _formatDate(timestamp);
    final content = hw["content"] ?? "";
    final title = hw["title"] ?? "Untitled Solution";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HomeworkDetailScreen(homework: hw),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 24,
                        color: Colors.purple.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    content.length > 150 ? "${content.substring(0, 150)}..." : content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "View Solution",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.purple.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown date";
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    if (diff.inDays < 7) return "${diff.inDays} days ago";
    return "${date.day}/${date.month}/${date.year}";
  }
}
