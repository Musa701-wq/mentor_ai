// lib/screens/notesFeed/sharedNotesScreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:student_ai/config/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Providers/notesProvider.dart';
import '../../models/notesModel.dart';
import '../../widgets/showNotes/noteCard.dart';
import '../notesFeed/showNotesDetail.dart';

class SharedNotesScreen extends StatefulWidget {
  const SharedNotesScreen({super.key});

  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool showFavOnly = false;
  String searchQuery = '';
  String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.loadSharedNotes(uid: uid);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        if (provider.hasMoreShared) {
          provider.loadSharedNotes(uid: uid, query: searchQuery);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    final provider = Provider.of<NotesProvider>(context, listen: false);
    provider.loadSharedNotes(uid: uid, reset: true, query: query);
  }






  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.grey[50];

    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final displayedNotes = showFavOnly
            ? provider.sharedNotes.where((n) => provider.isFavorite(n)).toList()
            : provider.sharedNotes;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.grey[800],
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  title: Text(
                    "Shared Notes",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.grey[800],
                      decoration: TextDecoration.none,
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? null
                            : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          showFavOnly ? Icons.favorite : Icons.favorite_border,
                          color: showFavOnly
                              ? Colors.redAccent
                              : Colors.grey[600],
                        ),
                        onPressed: () =>
                            setState(() => showFavOnly = !showFavOnly),
                        tooltip: showFavOnly
                            ? 'Show all shared notes'
                            : 'Show favorites only',
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(80),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search shared notes by title or tag...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              decoration: TextDecoration.none,
                            ),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Colors.grey[500]),
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  color: Colors.grey[500], size: 20),
                              onPressed: () {
                                onSearchChanged('');
                                FocusScope.of(context).unfocus();
                              },
                            )
                                : null,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                            decoration: TextDecoration.none,
                          ),
                          onChanged: onSearchChanged,
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: provider.isLoadingShared && provider.sharedNotes.isEmpty
                ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFF7E57C2)),
              ),
            )
                : displayedNotes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No shared notes found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When friends share notes with you, they will appear here.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () async => provider.loadSharedNotes(
                  uid: uid, reset: true, query: searchQuery),
              color: const Color(0xFF7E57C2),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            showFavOnly
                                ? 'Favorite Shared Notes'
                                : 'All Shared Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${displayedNotes.length} ${displayedNotes.length == 1 ? 'note' : 'notes'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          if (index >= displayedNotes.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 16),
                                child: CircularProgressIndicator(
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                      Color(0xFF7E57C2)),
                                ),
                              ),
                            );
                          }
                          final note = displayedNotes[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isDark
                                  ? null
                                  : [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: NoteCard(
                                      note: note,
                                      isFavorite:
                                      provider.isFavorite(note),
                                      onFavToggle: () => provider
                                          .toggleFavorite(note),
                                      onShare: () =>_openShareDialog(note), // no share here
                                      onEdit: () {}, // disabled
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                NoteDetailScreen(
                                                  note: note,
                                                  onShare: () {
                                                    _openShareDialog(note);
                                                  },
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (note.ownerName != null ||
                                      note.ownerEmail != null)
                                    Padding(
                                      padding:
                                      const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${note.ownerName ?? "Unknown"} • ${note.ownerEmail ?? ""}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                Colors.grey[600],
                                                decoration:
                                                TextDecoration
                                                    .none,
                                              ),
                                              overflow: TextOverflow
                                                  .ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: displayedNotes.length +
                            (provider.hasMoreShared ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  void _openShareDialog(NoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String q = '';
        Timer? _debounce;
        bool isLoading = false;
        List<Map<String, dynamic>> results = [];
        final provider = Provider.of<NotesProvider>(context, listen: false);
        final already = note.withShared.toSet();
        final selected = <String>{};

        return StatefulBuilder(
          builder: (context, setStateSB) {
            Future<void> runSearch(String query) async {
              setStateSB(() {
                isLoading = true;
              });

              final res = await provider.searchUsers(query);

              setStateSB(() {
                results = res;
                isLoading = false;
              });
            }

            void onChanged(String v) {
              q = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () async {
                await runSearch(q);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            'Share note',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: 'Search users by name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    if (!isLoading)
                      Flexible(
                        child: results.isEmpty && q.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No users found for "$q"',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.share_rounded),
                                        label: const Text('Share App'),
                                        onPressed: () {
                                          Share.share('Check out Mentor AI: ' + appStoreUrl);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final u = results[i];
                            final uid = u['uid'] as String;
                            final disabled = already.contains(uid);
                            final checked = selected.contains(uid);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (u['profilePic'] != null &&
                                    (u['profilePic'] as String).isNotEmpty)
                                    ? NetworkImage(u['profilePic'])
                                    : null,
                                child: (u['profilePic'] == null ||
                                    (u['profilePic'] as String).isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(u['name'] ?? 'User'),
                              subtitle: (u['email'] != null &&
                                  (u['email'] as String).isNotEmpty)
                                  ? Text(u['email'])
                                  : null,
                              trailing: disabled
                                  ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Shared',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                                  : Checkbox(
                                value: checked,
                                onChanged: (v) {
                                  if (disabled) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Note already shared with this user'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (v == true) {
                                    selected.add(uid);
                                  } else {
                                    selected.remove(uid);
                                  }
                                  setStateSB(() {});
                                },
                              ),
                              onTap: () {
                                if (disabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Note already shared with this user'),
                                    ),
                                  );
                                } else {
                                  if (checked) {
                                    selected.remove(uid);
                                  } else {
                                    selected.add(uid);
                                  }
                                  setStateSB(() {});
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Share'),
                          onPressed: selected.isEmpty
                              ? null
                              : () async {
                            final (added, alreadyDup) =
                            await provider.shareNoteWithUsers(
                              note: note,
                              targetUids: selected.toList(),
                            );

                            if (alreadyDup.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Already shared with: ${alreadyDup.length} user(s)',
                                  ),
                                ),
                              );
                            }
                            if (added.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Shared with ${added.length} user(s)',
                                  ),
                                ),
                              );
                            }
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
