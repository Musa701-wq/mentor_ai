import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notesModel.dart';
import '../../Providers/notesProvider.dart';

class NoteDetailScreen extends StatefulWidget {
  final NoteModel note;
  final VoidCallback onShare;

  const NoteDetailScreen({
    super.key,
    required this.note,
    required this.onShare,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _contentController;
  late TextEditingController _titleController;
  String? _editedSummary;
  bool _isEditing = false;
  bool _isSaving = false;
  late NoteModel _currentNote;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _contentController = TextEditingController(text: _currentNote.content);
    _titleController = TextEditingController(text: _currentNote.title);
    _editedSummary = _currentNote.summary;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[800];
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final isFavorite = provider.isFavorite(_currentNote);
        final colorSeed = _currentNote.title.hashCode + _currentNote.content.hashCode;
        final accentColor = _generateColorFromSeed(colorSeed, isDark);

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(
              'Note Details',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            elevation: 0,
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.grey[800],
            centerTitle: false,
            actions: [
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : Colors.grey[600],
                ),
                onPressed: () => provider.toggleFavorite(_currentNote),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: Colors.grey[600]),
                onPressed: widget.onShare,
                tooltip: 'Share note',
              ),
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  color: _isEditing ? Colors.green.shade600 : Colors.grey[600],
                ),
                onPressed: () async {
                  if (_isEditing) {
                    setState(() => _isSaving = true);
                    final updated = _currentNote.copyWith(
                      title: _titleController.text.trim(),
                      content: _contentController.text.trim(),
                      summary: _editedSummary,
                    );
                    await provider.editNote(updated);

                    setState(() {
                      _currentNote = updated;
                      _isEditing = false;
                      _isSaving = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Note updated successfully'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                tooltip: _isEditing ? 'Save changes' : 'Edit note',
              ),
            ],
          ),
          body: _isSaving
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
                const SizedBox(height: 16),
                Text(
                  'Saving changes...',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
              : CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      _isEditing
                          ? Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  controller: _titleController,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    height: 1.3,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter note title...',
                                    hintStyle: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  maxLines: null,
                                ),
                              ),
                            )
                          : Text(
                              _titleController.text,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.3,
                              ),
                            ),
                      const SizedBox(height: 16),

                      // Tags
                      if (_currentNote.tags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentNote.tags
                              .map((tag) => Container(
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ))
                              .toList(),
                        ),

                      if (_currentNote.tags.isNotEmpty) const SizedBox(height: 24),

                      // Content Card
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
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
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _isEditing
                              ? TextField(
                            controller: _contentController,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Write your note content here...',
                              hintStyle: TextStyle(color: secondaryTextColor),
                            ),
                          )
                              : Text(
                            _contentController.text,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // AI Summary Section
              if (_editedSummary != null && _editedSummary!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    color: Colors.amber.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _editedSummary!,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: isDark ? Colors.amber.shade100 : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Generate Summary Button
              if (_isEditing)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          elevation: 3,
                        ),
                        onPressed: () async {
                          setState(() => _isSaving = true);
                          final summary = await provider.generateSummaryForNote(
                            _currentNote,
                            _contentController.text,
                          );
                          if (summary != null) {
                            setState(() => _editedSummary = summary);
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                            );
                          }
                          setState(() => _isSaving = false);
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: const Text(
                          "Generate AI Summary",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _generateColorFromSeed(int seed, bool isDark) {
    final colors = [
      const Color(0xFF7E57C2), // Purple
      const Color(0xFF42A5F5), // Blue
      const Color(0xFF66BB6A), // Green
      const Color(0xFFFFA726), // Orange
      const Color(0xFFEC407A), // Pink
      const Color(0xFFAB47BC), // Deep Purple
    ];

    final index = seed % colors.length;
    return isDark ? colors[index].withOpacity(0.8) : colors[index];
  }
}