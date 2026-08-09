import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_service.dart';
import 'user_profile_screen.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

final FirebaseFirestore firestore = FirebaseFirestore.instance;

const _feedPageSize = 12;

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _posts = [];
  final Set<String> _postIds = {};

  DocumentSnapshot<Map<String, dynamic>>? _lastPostDocument;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;

  String? _feedError;

  bool isSaving = false;
  bool isCommenting = false;

  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController commentController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> toggleSave(String postId) async {
    if (isSaving) return;

    final user = auth.currentUser;
    if (user == null) return;

    isSaving = true;

    try {
      await firestoreService.toggleSavedPost(
        uid: user.uid,
        postId: postId,
      );
    } finally {
      isSaving = false;
    }
  }

  Future<void> addCommentToFirestore(String postId) async {
    if (isCommenting) return;

    final comment = commentController.text.trim();
    final user = auth.currentUser;

    if (comment.isEmpty || user == null) return;

    isCommenting = true;

    try {
      final userSnapshot =
          await firestoreService.getUserOnce(user.uid);

      final userData = userSnapshot.data();

      if (userData == null) return;

      final username =
          userData["username"]?.toString() ?? '';

      final profileUrl =
          userData["profileUrl"]?.toString() ?? '';

      final commentId = await firestoreService.addComment(
        postId: postId,
        username: username,
        profileUrl: profileUrl,
        comment: comment,
      );

      final postDoc =
          await firestore.collection("posts").doc(postId).get();

      final post = postDoc.data();

      if (post != null && post["uid"] != user.uid) {
        await firestoreService.createNotification(
          toUid: post["uid"].toString(),
          fromUid: user.uid,
          username: username,
          profileUrl: profileUrl,
          type: "comment",
          postId: postId,
          comment: comment,
          actionId: 'comment_${postId}_$commentId',
        );
      }

      commentController.clear();
    } finally {
      isCommenting = false;
    }
  }

  void showComments(String postId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1B1E24),
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 15),

              const Text(
                "Comments",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Divider(),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestoreService.getComments(postId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final comments = snapshot.data!.docs;

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          "No comments yet",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final data = comments[index].data()
                            as Map<String, dynamic>;

                        final commentId =
                            comments[index].id;

                        final rawLikes = data["likes"];

                        final List<String> commentLikes =
                            rawLikes is List
                                ? rawLikes
                                    .map(
                                      (e) => e.toString(),
                                    )
                                    .toList()
                                : [];

                        return _CommentTile(
                          postId: postId,
                          commentId: commentId,
                          username:
                              data["username"] ?? "",
                          profileUrl:
                              data["profileUrl"] ?? "",
                          commentText:
                              data["comment"] ?? "",
                          initialLikes: commentLikes,
                          firestoreService:
                              firestoreService,
                        );
                      },
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        addCommentToFirestore(postId);
                      },
                      icon: const Icon(
                        Icons.send,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _loadInitialPosts();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 300) {
      return;
    }

    _loadMorePosts();
  }

  Future<void> _loadInitialPosts() async {
    if (_isRefreshing || _isLoadingMore) return;

    setState(() {
      _isRefreshing = true;
      _isInitialLoading = _posts.isEmpty;
      _isLoadingMore = false;
      _hasReachedEnd = false;
      _feedError = null;
      _lastPostDocument = null;
    });

    try {
      final page = await firestoreService.getPostsPage(
        limit: _feedPageSize,
      );

      if (!mounted) return;

      setState(() {
        _posts
          ..clear()
          ..addAll(page.docs);

        _postIds
          ..clear()
          ..addAll(
            page.docs.map(
              (post) => post.id,
            ),
          );

        _lastPostDocument =
            page.docs.isEmpty ? null : page.docs.last;

        _hasReachedEnd =
            page.docs.length < _feedPageSize;

        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } on FirebaseException {
      if (!mounted) return;

      setState(() {
        _feedError =
            'Unable to load posts. Please try again.';

        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isInitialLoading ||
        _isLoadingMore ||
        _hasReachedEnd ||
        _feedError != null ||
        _lastPostDocument == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _feedError = null;
    });

    try {
      final page = await firestoreService.getPostsPage(
        limit: _feedPageSize,
        startAfter: _lastPostDocument,
      );

      if (!mounted) return;

      setState(() {
        for (final post in page.docs) {
          if (_postIds.add(post.id)) {
            _posts.add(post);
          }
        }

        if (page.docs.isNotEmpty) {
          _lastPostDocument = page.docs.last;
        }

        _hasReachedEnd =
            page.docs.length < _feedPageSize;

        _isLoadingMore = false;
      });
    } on FirebaseException {
      if (!mounted) return;

      setState(() {
        _feedError =
            'Unable to load more posts. Please try again.';

        _isLoadingMore = false;
      });
    }
  }

  void _removePostFromFeed(String postId) {
    setState(() {
      _posts.removeWhere(
        (doc) => doc.id == postId,
      );

      _postIds.remove(postId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    commentController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,

        title: const Text(
          "RandomBT",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatListScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          SizedBox(
            height: 100,

            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,

              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8),

                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            Colors.deepPurple,

                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        index == 0
                            ? "Your Story"
                            : "User $index",

                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(
            color: Colors.white24,
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialPosts,

              child: Builder(
                builder: (context) {
                  if (_isInitialLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (_posts.isEmpty) {
                    final message =
                        _feedError ?? 'No Posts Yet';

                    final color =
                        _feedError == null
                            ? Colors.white
                            : Colors.redAccent;

                    return ListView(
                      controller: _scrollController,

                      physics:
                          const AlwaysScrollableScrollPhysics(),

                      children: [
                        SizedBox(
                          height:
                              MediaQuery.sizeOf(context)
                                      .height *
                                  0.6,

                          child: Center(
                            child: Text(
                              message,

                              style: TextStyle(
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final posts = _posts;

                  return ListView.builder(
                    key: const PageStorageKey(
                      "feed_list",
                    ),

                    controller: _scrollController,

                    itemCount:
                        posts.length +
                        (_isLoadingMore ||
                                _feedError != null
                            ? 1
                            : 0),

                    itemBuilder: (context, index) {
                      if (index == posts.length) {
                        if (_isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),

                            child: Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          );
                        }

                        return Padding(
                          padding:
                              const EdgeInsets.all(16),

                          child: Center(
                            child: Text(
                              _feedError!,

                              style:
                                  const TextStyle(
                                color:
                                    Colors.redAccent,
                              ),
                            ),
                          ),
                        );
                      }

                      final doc = posts[index];

                      final post = doc.data();

                      final postId = doc.id;

                      final currentUid =
                          auth.currentUser?.uid ?? '';

                      return _FeedPostCard(
                        key: ValueKey(postId),

                        postId: postId,

                        post: post,

                        currentUid: currentUid,

                        firestoreService:
                            firestoreService,

                        onCommentPressed: () =>
                            showComments(postId),

                        onToggleSave: toggleSave,

                        onPostDeleted:
                            _removePostFromFeed,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// COMMENT TILE
// ============================================================

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.postId,
    required this.commentId,
    required this.username,
    required this.profileUrl,
    required this.commentText,
    required this.initialLikes,
    required this.firestoreService,
  });

  final String postId;
  final String commentId;
  final String username;
  final String profileUrl;
  final String commentText;
  final List<String> initialLikes;
  final FirestoreService firestoreService;

  @override
  State<_CommentTile> createState() =>
      _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late List<String> _likes;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _likes = List<String>.from(
      widget.initialLikes,
    );
  }

  Future<void> _toggleLike() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null || _isProcessing) return;

    final uid = user.uid;

    final wasLiked = _likes.contains(uid);

    setState(() {
      if (wasLiked) {
        _likes.remove(uid);
      } else {
        _likes.add(uid);
      }

      _isProcessing = true;
    });

    try {
      if (wasLiked) {
        await widget.firestoreService.unlikeComment(
          postId: widget.postId,
          commentId: widget.commentId,
          userId: uid,
        );
      } else {
        await widget.firestoreService.likeComment(
          postId: widget.postId,
          commentId: widget.commentId,
          userId: uid,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          _likes.add(uid);
        } else {
          _likes.remove(uid);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth.instance.currentUser?.uid;

    final isLiked =
        currentUid != null &&
        _likes.contains(currentUid);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            widget.profileUrl.isNotEmpty
                ? NetworkImage(widget.profileUrl)
                : null,

        child: widget.profileUrl.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),

      title: Text(
        widget.username,

        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),

      subtitle: Text(
        widget.commentText,

        style: const TextStyle(
          color: Colors.white70,
        ),
      ),

     trailing: Column(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
          maxWidth: 28,
          maxHeight: 28,
        ),
        onPressed: _isProcessing ? null : _toggleLike,
        icon: Icon(
          isLiked
              ? Icons.favorite
              : Icons.favorite_border,
          color: isLiked
              ? Colors.red
              : Colors.white,
          size: 20,
        ),
      ),
    ),

    Text(
      '${_likes.length}',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
    ),
  ],
),
    );
  }
}


// ============================================================
// FEED POST CARD
// ============================================================

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({
    super.key,
    required this.postId,
    required this.post,
    required this.currentUid,
    required this.firestoreService,
    required this.onCommentPressed,
    required this.onToggleSave,
    required this.onPostDeleted,
  });

  final String postId;
  final Map<String, dynamic> post;
  final String currentUid;
  final FirestoreService firestoreService;
  final VoidCallback onCommentPressed;
  final ValueChanged<String> onToggleSave;
  final ValueChanged<String> onPostDeleted;

  @override
  State<_FeedPostCard> createState() =>
      _FeedPostCardState();
}

class _FeedPostCardState
    extends State<_FeedPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;

  late Animation<double> _heartAnimation;

  bool _showHeartAnimation = false;

  bool _isLiked = false;

  late int _likesCount;

  bool _isLiking = false;

  @override
  void initState() {
    super.initState();

    _likesCount =
        (widget.post["likes"] as num?)
                ?.toInt() ??
            0;

    _heartController =
        AnimationController(
      vsync: this,

      duration:
          const Duration(milliseconds: 300),
    );

    _heartAnimation =
        Tween<double>(
          begin: 0.5,
          end: 1.2,
        ).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.elasticOut,
      ),
    );

    _checkInitialLikeStatus();
  }

  @override
  void didUpdateWidget(
    covariant _FeedPostCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post["likes"] !=
        widget.post["likes"]) {
      _likesCount =
          (widget.post["likes"] as num?)
                  ?.toInt() ??
              0;
    }
  }

  Future<void> _checkInitialLikeStatus() async {
    if (widget.currentUid.isEmpty) return;

    final liked =
        await widget.firestoreService
            .isPostLiked(
      postId: widget.postId,
      uid: widget.currentUid,
    );

    if (mounted) {
      setState(() {
        _isLiked = liked;
      });
    }
  }

  Future<void> _handleToggleLike() async {
    if (_isLiking ||
        widget.currentUid.isEmpty) {
      return;
    }

    _isLiking = true;

    final previousLiked = _isLiked;

    final previousLikesCount =
        _likesCount;

    setState(() {
      _isLiked = !previousLiked;

      _likesCount = _isLiked
          ? previousLikesCount + 1
          : (previousLikesCount > 0
              ? previousLikesCount - 1
              : 0);
    });

    try {
      final userData =
          (await widget.firestoreService
                  .getUserOnce(
                    widget.currentUid,
                  ))
              .data();

      if (userData == null) return;

      final liked =
          await widget.firestoreService
              .toggleLike(
        postId: widget.postId,
        uid: widget.currentUid,
        username:
            userData['username']
                    ?.toString() ??
                '',
        profileUrl:
            userData['profileUrl']
                    ?.toString() ??
                '',
      );

      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;

          _likesCount =
              previousLikesCount;
        });
      }
    } finally {
      _isLiking = false;
    }
  }

  Future<void> _handleDoubleTap() async {
    _heartController.forward(from: 0);

    if (mounted) {
      setState(() {
        _showHeartAnimation = true;
      });
    }

    await _handleToggleLike();

    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (mounted) {
      setState(() {
        _showHeartAnimation = false;
      });
    }
  }

  Future<void> _confirmDeletePost() async {
    final confirmed =
        await showDialog<bool>(
      context: context,

      builder: (context) =>
          AlertDialog(
        backgroundColor:
            const Color(0xff1B1F2A),

        title: const Text(
          'Delete Post?',
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(
            color: Colors.white70,
          ),
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),

            child: const Text(
              'Cancel',
            ),
          ),

          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),

            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    try {
      await widget.firestoreService
          .deletePost(
        widget.postId,
      );

      if (!mounted) return;

      widget.onPostDeleted(
        widget.postId,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Post deleted successfully.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete post. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _heartController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    final postId = widget.postId;

    return RepaintBoundary(
      child: Card(
        color: const Color(0xff1B1E24),

        margin: const EdgeInsets.all(10),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),

        child: Padding(
          padding:
              const EdgeInsets.all(12),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(
                            uid: post["uid"],
                          ),
                        ),
                      );
                    },

                    child: CircleAvatar(
                      backgroundImage:
                          (post["profileUrl"] ??
                                      "")
                                  .toString()
                                  .isNotEmpty
                              ? NetworkImage(
                                  post[
                                      "profileUrl"],
                                )
                              : null,

                      child:
                          (post["profileUrl"] ??
                                      "")
                                  .toString()
                                  .isEmpty
                              ? const Icon(
                                  Icons.person,
                                )
                              : null,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(
                            uid: post["uid"],
                          ),
                        ),
                      );
                    },

                    child: Text(
                      post["username"] ??
                          "",

                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  if (widget.currentUid
                          .isNotEmpty &&
                      post["uid"]
                              ?.toString() !=
                          widget.currentUid)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore
                          .instance
                          .collection("users")
                          .doc(
                              widget.currentUid)
                          .collection("following")
                          .doc(
                              post["uid"]
                                      ?.toString() ??
                                  '')
                          .snapshots(),
                      builder: (context,
                          snapshot) {
                        final isFollowing =
                            snapshot.data
                                    ?.exists ??
                                false;
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                                  left: 8),
                          child: SizedBox(
                            height: 28,
                            child: TextButton(
                              style: TextButton
                                  .styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                backgroundColor:
                                    isFollowing
                                        ? Colors
                                            .transparent
                                        : Colors
                                            .blue,
                                side: isFollowing
                                    ? const BorderSide(
                                        color: Colors
                                            .white24,
                                      )
                                    : BorderSide
                                        .none,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              6),
                                ),
                              ),
                              onPressed:
                                  () async {
                                final user =
                                    FirebaseAuth
                                        .instance
                                        .currentUser;
                                if (user ==
                                    null) {
                                  return;
                                }
                                final userSnapshot =
                                    await widget
                                        .firestoreService
                                        .getUserOnce(
                                  user.uid,
                                );
                                final userData =
                                    userSnapshot
                                        .data();
                                if (userData ==
                                    null) {
                                  return;
                                }

                                await widget
                                    .firestoreService
                                    .followUser(
                                  currentUid:
                                      user.uid,
                                  targetUid: post[
                                          "uid"]
                                      .toString(),
                                  username: userData[
                                              'username']
                                          ?.toString() ??
                                      '',
                                  profileUrl: userData[
                                              'profileUrl']
                                          ?.toString() ??
                                      '',
                                );
                              },
                              child: Text(
                                isFollowing
                                    ? "Following"
                                    : "Follow",
                                style:
                                    TextStyle(
                                  color: isFollowing
                                      ? Colors
                                          .white70
                                      : Colors
                                          .white,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const Spacer(),

                  if (widget.currentUid
                          .isNotEmpty &&
                      post["uid"]
                              ?.toString() ==
                          widget.currentUid)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                      ),

                      color:
                          const Color(
                        0xff1B1E24,
                      ),

                      onSelected: (value) {
                        if (value ==
                            'delete') {
                          _confirmDeletePost();
                        }
                      },

                      itemBuilder:
                          (context) =>
                              const [
                        PopupMenuItem(
                          value: 'delete',

                          child: Text(
                            'Delete Post',
                            style:
                                TextStyle(
                              color: Colors
                                  .redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              GestureDetector(
                onDoubleTap:
                    _handleDoubleTap,

                child: Stack(
                  alignment:
                      Alignment.center,

                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),

                      child:
                          Container(
                        constraints:
                            const BoxConstraints(
                          maxHeight: 450,
                          minHeight: 200,
                        ),
                        width:
                            double.infinity,
                        child:
                            Image.network(
                          post["imageUrl"] ??
                              "",

                          width:
                              double.infinity,

                          fit: BoxFit.contain,

                          cacheWidth: 800,
                        ),
                      ),
                    ),

                    if (_showHeartAnimation)
                      ScaleTransition(
                        scale:
                            _heartAnimation,

                        child:
                            const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 100,
                        ),
                      ),
                  ],
                ),
              ),

              Row(
                children: [
                  IconButton(
                    onPressed:
                        _handleToggleLike,

                    icon: Icon(
                      _isLiked
                          ? Icons.favorite
                          : Icons
                              .favorite_border,

                      color: _isLiked
                          ? Colors.red
                          : Colors.white,
                    ),
                  ),

                  Text(
                    "$_likesCount Likes",

                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    icon:
                        const Icon(
                      Icons
                          .comment_outlined,
                      color:
                          Colors.white,
                    ),

                    onPressed:
                        widget
                            .onCommentPressed,
                  ),

                  IconButton(
                    icon:
                        const Icon(
                      Icons.send_outlined,
                      color:
                          Colors.white,
                    ),

                    onPressed: () {
                      SharePlus
                          .instance
                          .share(
                        ShareParams(
                          text:
                              "${post["caption"]}\n\n${post["imageUrl"]}",
                        ),
                      );
                    },
                  ),

                  if (widget.currentUid
                      .isNotEmpty)
                    ValueListenableBuilder<
                        SavedPostsState>(
                      valueListenable:
                          widget
                              .firestoreService
                              .watchSavedPosts(
                        widget
                            .currentUid,
                      ),

                      builder: (
                        context,
                        savedPosts,
                        child,
                      ) {
                        final saved =
                            savedPosts
                                .postIds
                                .contains(
                          postId,
                        );

                        return IconButton(
                          onPressed: () =>
                              widget
                                  .onToggleSave(
                            postId,
                          ),

                          icon: Icon(
                            saved
                                ? Icons.bookmark
                                : Icons
                                    .bookmark_border,

                            color:
                                Colors.white,
                          ),
                        );
                      },
                    ),
                ],
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                post["caption"] ?? "",

                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}