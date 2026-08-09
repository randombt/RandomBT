import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String uid;

  const UserProfileScreen({super.key, required this.uid});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final firestoreService = FirestoreService();
  final auth = FirebaseAuth.instance;

  late final Stream<QuerySnapshot> _followersStream = firestoreService.getFollowers(widget.uid);
  late final Stream<QuerySnapshot> _followingStream = firestoreService.getFollowing(widget.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text("Profile"),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!.data() as Map<String, dynamic>?;

          return Column(
            children: [
              const SizedBox(height: 20),

              CircleAvatar(
                radius: 45,
                backgroundImage:
                    (user?["profileUrl"] ?? "").toString().isNotEmpty
                    ? NetworkImage(user!["profileUrl"])
                    : null,
                child: (user?["profileUrl"] ?? "").toString().isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),

              const SizedBox(height: 15),

              Text(
                user?["username"] ?? "User",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                user?["bio"] ?? "",
                style: const TextStyle(color: Colors.white70),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _followersStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            "${snapshot.data?.docs.length ?? 0}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Followers",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      );
                    },
                  ),

                  StreamBuilder<QuerySnapshot>(
                    stream: _followingStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            "${snapshot.data?.docs.length ?? 0}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Following",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (widget.uid != auth.currentUser!.uid)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(auth.currentUser!.uid)
                      .collection("following")
                      .doc(widget.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final following = snapshot.data?.exists ?? false;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final currentUser = auth.currentUser;
                            if (currentUser == null) return;
                            final currentUserData =
                                (await firestoreService.getUserOnce(
                                  currentUser.uid,
                                )).data();
                            if (currentUserData == null) return;
                            await firestoreService.followUser(
                              currentUid: currentUser.uid,
                              targetUid: widget.uid,
                              username:
                                  currentUserData['username']?.toString() ?? '',
                              profileUrl:
                                  currentUserData['profileUrl']?.toString() ?? '',
                            );
                          },
                          child: Text(following ? "Following" : "Follow"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final currentUser = auth.currentUser;
                            if (currentUser == null) return;
                            final currentUserData =
                                (await firestoreService.getUserOnce(currentUser.uid)).data();
                            final targetUserData =
                                (await firestoreService.getUserOnce(widget.uid)).data();
                            if (currentUserData == null || targetUserData == null) return;

                            final chatService = ChatService();
                            final chatId = await chatService.createOrGetChat(
                              currentUid: currentUser.uid,
                              currentUsername: currentUserData['username']?.toString() ?? '',
                              currentProfileUrl: currentUserData['profileUrl']?.toString() ?? '',
                              targetUid: widget.uid,
                              targetUsername: targetUserData['username']?.toString() ?? '',
                              targetProfileUrl: targetUserData['profileUrl']?.toString() ?? '',
                            );

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  targetUid: widget.uid,
                                  targetUsername: targetUserData['username']?.toString() ?? '',
                                  targetProfileUrl: targetUserData['profileUrl']?.toString() ?? '',
                                ),
                              ),
                            );
                          },
                          child: const Text("Message"),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
