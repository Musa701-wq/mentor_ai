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
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.grey[900],
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              TextField(
                                controller: _titleController,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter title...',
                                  hintStyle: TextStyle(color: Colors.white70),
                                ),
                                maxLines: null,
                              )
                            else
                              Text(
                                _titleController.text,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (_currentNote.tags.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _currentNote.tags
                                    .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sharer Profile (if shared)
                      if (_currentNote.ownerName != null && _currentNote.ownerName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  _currentNote.ownerName![0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shared by ${_currentNote.ownerName}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_currentNote.ownerEmail != null)
                                      Text(
                                        _currentNote.ownerEmail!,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      Text(
                        "CONTENT",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.purple.shade400,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: _isEditing
                            ? TextField(
                                controller: _contentController,
                                maxLines: null,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.7,
                                  color: textColor,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Write your note...',
                                ),
                              )
                            : Text(
                                _contentController.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.7,
                                  color: textColor,
                                ),
                              ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              if (_editedSummary != null && _editedSummary!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI SUMMARY",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber.shade700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.amber.shade400,
                                Colors.amber.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    "Smart Overview",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _editedSummary!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

              // Generate Summary Button
              if (_isEditing)
                // SliverToBoxAdapter(
                //   child: Padding(
                //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                //     child: Center(
                //       child: ElevatedButton.icon(
                //         style: ElevatedButton.styleFrom(
                //           backgroundColor: Colors.amber.shade600,
                //           foregroundColor: Colors.white,
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(16),
                //           ),
                //           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                //           elevation: 3,
                //         ),
                //         onPressed: () async {
                //           setState(() => _isSaving = true);
                //           final summary = await provider.generateSummaryForNote(
                //             _currentNote,
                //             _contentController.text,
                //           );
                //           if (summary != null) {
                //             setState(() => _editedSummary = summary);
                //             _scrollController.animateTo(
                //               _scrollController.position.maxScrollExtent,
                //               duration: const Duration(milliseconds: 500),
                //               curve: Curves.easeOut,
                //             );
                //           }
                //           setState(() => _isSaving = false);
                //         },
                //         icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                //         label: const Text(
                //           "Generate AI Summary",
                //           style: TextStyle(fontWeight: FontWeight.w600),
                //         ),
                //       ),
                //     ),
                //   ),
                // ),

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