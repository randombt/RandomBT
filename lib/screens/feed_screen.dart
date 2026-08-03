import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firestore_service.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

final FirebaseFirestore firestore = FirebaseFirestore.instance;

const _feedPageSize = 12;

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController heartController;
  String? animatedPostId;
  final ScrollController _scrollController = ScrollController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _posts = [];
  final Set<String> _postIds = {};
  DocumentSnapshot<Map<String, dynamic>>? _lastPostDocument;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasReachedEnd = false;
  String? _feedError;
  bool isLiking = false;
  bool isSaving = false;
  bool isCommenting = false;

  late Animation<double> heartAnimation;

  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController commentController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> toggleLike(String postId) async {
    if (isLiking) return;

    isLiking = true;

    try {
      final user = auth.currentUser;
      if (user == null) return;
      final userData = (await firestoreService.getUserOnce(user.uid)).data();
      if (userData == null) return;
      final liked = await firestoreService.toggleLike(
        postId: postId,
        uid: user.uid,
        username: userData['username']?.toString() ?? '',
        profileUrl: userData['profileUrl']?.toString() ?? '',
      );
      _updatePostLikes(postId, liked);
    } finally {
      isLiking = false;
    }
  }

  Future<void> toggleSave(String postId) async {
    if (isSaving) return;
    final user = auth.currentUser;
    if (user == null) return;
    isSaving = true;
    try {
      await firestoreService.toggleSavedPost(uid: user.uid, postId: postId);
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
      final userSnapshot = await firestoreService.getUserOnce(user.uid);
      final userData = userSnapshot.data();
      if (userData == null) return;

      final username = userData["username"]?.toString() ?? '';
      final profileUrl = userData["profileUrl"]?.toString() ?? '';
      final commentId = await firestoreService.addComment(
        postId: postId,
        username: username,
        profileUrl: profileUrl,
        comment: comment,
      );

      final postDoc = await firestore.collection("posts").doc(postId).get();
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
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data!.docs;

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          "No comments yet",
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final data =
                            comments[index].data() as Map<String, dynamic>;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (data["profileUrl"] ?? "").toString().isNotEmpty
                                ? NetworkImage(data["profileUrl"].toString())
                                : null,
                            child: (data["profileUrl"] ?? "").toString().isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            data["username"] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            data["comment"] ?? "",
                            style: const TextStyle(color: Colors.white70),
                          ),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        addCommentToFirestore(postId);
                      },
                      icon: const Icon(Icons.send, color: Colors.blue),
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

    heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    heartAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: heartController, curve: Curves.elasticOut),
    );

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
      final page = await firestoreService.getPostsPage(limit: _feedPageSize);
      if (!mounted) return;

      setState(() {
        _posts
          ..clear()
          ..addAll(page.docs);
        _postIds
          ..clear()
          ..addAll(page.docs.map((post) => post.id));
        _lastPostDocument = page.docs.isEmpty ? null : page.docs.last;
        _hasReachedEnd = page.docs.length < _feedPageSize;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _feedError = 'Unable to load posts. Please try again.';
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
        _hasReachedEnd = page.docs.length < _feedPageSize;
        _isLoadingMore = false;
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _feedError = 'Unable to load more posts. Please try again.';
        _isLoadingMore = false;
      });
    }
  }

  void _updatePostLikes(String postId, bool liked) {
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    final data = post.data();
    final likes = (data['likes'] as num?)?.toInt() ?? 0;
    data['likes'] = liked ? likes + 1 : (likes > 0 ? likes - 1 : 0);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    heartController.dispose();
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.chat_bubble_outline, color: Colors.white),
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
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        index == 0 ? "Your Story" : "User $index",
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

          const Divider(color: Colors.white24),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialPosts,
              child: Builder(
                builder: (context) {
                  if (_isInitialLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (_posts.isEmpty) {
                    final message = _feedError ?? 'No Posts Yet';
                    final color = _feedError == null
                        ? Colors.white
                        : Colors.redAccent;
                    return ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: Center(
                            child: Text(
                              message,
                              style: TextStyle(color: color),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final posts = _posts;

                  return ListView.builder(
                    key: const PageStorageKey("feed_list"),
                    controller: _scrollController,
                    itemCount:
                        posts.length +
                        (_isLoadingMore || _feedError != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == posts.length) {
                        if (_isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              _feedError!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      }

                      final doc = posts[index];
                      final post = doc.data();
                      final postId = doc.id;

                      return Card(
                        color: const Color(0xff1B1E24),
                        margin: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            uid: post["uid"],
                                          ),
                                        ),
                                      );
                                    },
                                    child: CircleAvatar(
                                      backgroundImage:
                                          (post["profileUrl"] ?? "").isNotEmpty
                                          ? NetworkImage(post["profileUrl"])
                                          : null,
                                      child: (post["profileUrl"] ?? "").isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            uid: post["uid"],
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      post["username"] ?? "",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              GestureDetector(
                                onDoubleTap: () async {
                                  heartController.forward(from: 0);
                                  setState(() {
                                    animatedPostId = postId;
                                  });

                                  await toggleLike(postId);

                                  await Future.delayed(
                                    const Duration(milliseconds: 700),
                                  );

                                  if (!mounted) return;

                                  setState(() {
                                    animatedPostId = null;
                                  });
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        post["imageUrl"],
                                        height: 220,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),

                                    if (animatedPostId == postId)
                                      ScaleTransition(
                                        scale: heartAnimation,
                                        child: const Icon(
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
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: firestore
                                        .collection("posts")
                                        .doc(postId)
                                        .collection("likes")
                                        .doc(auth.currentUser!.uid)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final liked =
                                          snapshot.data?.exists ?? false;

                                      return IconButton(
                                        onPressed: () {
                                          toggleLike(postId);
                                        },
                                        icon: Icon(
                                          liked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: liked
                                              ? Colors.red
                                              : Colors.white,
                                        ),
                                      );
                                    },
                                  ),

                                  Text(
                                    "${post["likes"]} Likes",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const Spacer(),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.comment_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      showComments(postId);
                                    },
                                  ),

                                  IconButton(
                                    icon: const Icon(
                                      Icons.send_outlined,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              "${post["caption"]}\n\n${post["imageUrl"]}",
                                        ),
                                      );
                                    },
                                  ),

                                  ValueListenableBuilder<SavedPostsState>(
                                    valueListenable: firestoreService
                                        .watchSavedPosts(auth.currentUser!.uid),
                                    builder: (context, savedPosts, child) {
                                      final saved = savedPosts.postIds.contains(
                                        postId,
                                      );

                                      return IconButton(
                                        onPressed: () {
                                          toggleSave(postId);
                                        },
                                        icon: Icon(
                                          saved
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 5),

                              Text(
                                post["caption"] ?? "",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
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
