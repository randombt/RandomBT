import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirestoreService firestoreService = FirestoreService();
  final Set<String> _removingMissingPostIds = {};

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>? _savedPostsFuture;
  String _savedPostsKey = '';

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _loadSavedPosts(
    List<String> postIds,
  ) {
    final key = postIds.join(',');
    if (_savedPostsFuture == null || _savedPostsKey != key) {
      _savedPostsKey = key;
      _savedPostsFuture = firestoreService.getSavedPostDocuments(postIds);
    }
    return _savedPostsFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,
        title: const Text("Saved Posts"),
      ),
      body: user == null
          ? const Center(
              child: Text(
                "No Saved Posts",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : ValueListenableBuilder<SavedPostsState>(
              valueListenable: firestoreService.watchSavedPosts(user.uid),
              builder: (context, savedPosts, child) {
                if (savedPosts.isLoading && savedPosts.postIds.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (savedPosts.hasError && savedPosts.postIds.isEmpty) {
                  return const Center(
                    child: Text(
                      'Unable to load saved posts',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                if (savedPosts.postIds.isEmpty) {
                  return const Center(
                    child: Text(
                      "No Saved Posts",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                return FutureBuilder<
                  List<DocumentSnapshot<Map<String, dynamic>>>
                >(
                  future: _loadSavedPosts(savedPosts.postIds),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load saved posts',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final posts = snapshot.data!;
                    final loadedPostIds = posts.map((post) => post.id).toSet();
                    final missingPostIds = savedPosts.postIds
                        .where((id) => !loadedPostIds.contains(id))
                        .where(_removingMissingPostIds.add)
                        .toList();

                    if (missingPostIds.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        for (final postId in missingPostIds) {
                          firestoreService
                              .removeSavedPost(uid: user.uid, postId: postId)
                              .whenComplete(
                                () => _removingMissingPostIds.remove(postId),
                              );
                        }
                      });
                    }

                    if (posts.isEmpty) {
                      return const Center(
                        child: Text(
                          "No Saved Posts",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(4),
                      itemCount: posts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemBuilder: (context, index) {
                        final post = posts[index].data()!;
                        final postId = posts[index].id;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  backgroundColor: Colors.black,
                                  appBar: AppBar(backgroundColor: Colors.black),
                                  body: Center(
                                    child: InteractiveViewer(
                                      child: Image.network(post["imageUrl"]),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: postId,
                            child: Image.network(
                              post["imageUrl"],
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
