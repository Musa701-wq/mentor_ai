import 'package:flutter/material.dart';
import '../../models/notesModel.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final bool isFavorite;
  final VoidCallback onFavToggle;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const NoteCard({
    Key? key,
    required this.note,
    required this.isFavorite,
    required this.onFavToggle,
    required this.onShare,
    required this.onEdit,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[800] : Colors.white;
    final textColor = isDark ? Colors.grey[100] : Colors.grey[800];
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Generate a color based on note content for visual variety
    final colorSeed = note.title.hashCode + note.content.hashCode;
    final cardColor = _generateColorFromSeed(colorSeed, isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isSmallScreen = screenWidth < 360;
        final bool isTablet = screenWidth > 600;
        final bool isLargeTablet = screenWidth > 900;

        // Responsive sizing
        final double titleSize = isSmallScreen ? 14 : (isTablet ? 17 : 16);
        final double contentSize = isSmallScreen ? 12 : (isTablet ? 14 : 13);
        final double tagSize = isSmallScreen ? 10 : (isTablet ? 12 : 11);
        final double dateSize = isSmallScreen ? 10 : (isTablet ? 12 : 11);
        final double iconSize = isSmallScreen ? 14 : (isTablet ? 18 : 16);

        // Responsive padding
        final double horizontalPadding = isSmallScreen ? 16 : (isTablet ? 24 : 20);
        final double verticalPadding = isSmallScreen ? 12 : (isTablet ? 20 : 16);
        final double spacing = isSmallScreen ? 6 : (isTablet ? 12 : 8);
        final double smallSpacing = isSmallScreen ? 4 : (isTablet ? 8 : 6);

        // Responsive dimensions
        final double accentBarWidth = isSmallScreen ? 4 : (isTablet ? 8 : 6);
        final double tagPadding = isSmallScreen ? 6 : (isTablet ? 10 : 8);
        final double tagVerticalPadding = isSmallScreen ? 3 : (isTablet ? 5 : 4);
        final double tagRadius = isSmallScreen ? 8 : (isTablet ? 12 : 10);
        final double cardRadius = isSmallScreen ? 16 : (isTablet ? 24 : 20);

        return Container(
          constraints: BoxConstraints(
            minHeight: isSmallScreen ? 140 : (isTablet ? 180 : 160),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            color: backgroundColor,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(cardRadius),
                child: Stack(
                  children: [
                    // Color accent bar
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: accentBarWidth,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(cardRadius),
                            bottomLeft: Radius.circular(cardRadius),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding + accentBarWidth,
                          verticalPadding,
                          horizontalPadding,
                          verticalPadding
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with title and favorite button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    decoration: TextDecoration.none,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: smallSpacing),
                              GestureDetector(
                                onTap: onFavToggle,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: EdgeInsets.all(isSmallScreen ? 3 : 4),
                                  decoration: BoxDecoration(
                                    color: isFavorite
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: iconSize,
                                    color: isFavorite
                                        ? Colors.redAccent
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: spacing),

                          // Content preview
                          if (note.content.isNotEmpty) ...[
                            Text(
                              note.content,
                              style: TextStyle(
                                fontSize: contentSize,
                                color: secondaryTextColor,
                                decoration: TextDecoration.none,
                                height: 1.4,
                              ),
                              maxLines: isSmallScreen ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: spacing),
                          ],

                          // Tags - Only show if there's space
                          if (note.tags.isNotEmpty) ...[
                            Wrap(
                              spacing: smallSpacing,
                              runSpacing: smallSpacing,
                              children: note.tags.take(isSmallScreen ? 2 : 3).map((tag) => Container(
                                decoration: BoxDecoration(
                                  color: cardColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(tagRadius),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: tagPadding,
                                    vertical: tagVerticalPadding
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: tagSize,
                                    fontWeight: FontWeight.w500,
                                    color: cardColor,
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )).toList(),
                            ),
                            SizedBox(height: spacing),
                          ],

                          // Footer with date and actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _formatDate(note.createdAt),
                                  style: TextStyle(
                                    fontSize: dateSize,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              Row(
                                children: [
                                  // Share button
                                  IconButton(
                                    onPressed: onShare,
                                    icon: Icon(
                                      Icons.share_rounded,
                                      size: iconSize,
                                      color: Colors.grey[500],
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Share note',
                                  ),
                                  SizedBox(width: smallSpacing),

                                  // Edit button
                                  IconButton(
                                    onPressed: onEdit,
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      size: iconSize,
                                      color: Colors.grey[500],
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Edit note',
                                  ),
                                  
                                  // Delete button (only show if onDelete is provided)
                                  if (onDelete != null) ...[
                                    SizedBox(width: smallSpacing),
                                    IconButton(
                                      onPressed: () => _showDeleteConfirmation(context),
                                      icon: Icon(
                                        Icons.delete_rounded,
                                        size: iconSize,
                                        color: Colors.red[400],
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Delete note',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          title: Text(
            'Delete Note',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${note.title}"? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDelete?.call();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}