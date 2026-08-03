import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,
        title: const Text("Saved Posts"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: auth.currentUser == null
            ? null
            : firestore
                  .collection("users")
                  .doc(auth.currentUser!.uid)
                  .collection("savedPosts")
                  .orderBy("savedAt", descending: true)
                  .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedPosts = snapshot.data!.docs;

          if (savedPosts.isEmpty) {
            return const Center(
              child: Text(
                "No Saved Posts",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: savedPosts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final postId = savedPosts[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: firestore.collection("posts").doc(postId).get(),
                builder: (context, postSnapshot) {
                  if (postSnapshot.hasData && !postSnapshot.data!.exists) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final user = auth.currentUser;
                      if (user != null) {
                        firestoreService.removeSavedPost(
                          uid: user.uid,
                          postId: postId,
                        );
                      }
                    });
                    return const SizedBox.shrink();
                  }

                  if (!postSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final post =
                      postSnapshot.data!.data() as Map<String, dynamic>;

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
                      child: Image.network(post["imageUrl"], fit: BoxFit.cover),
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
