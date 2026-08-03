import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        elevation: 0,
        title: const Text("Notifications"),
      ),
      body: user == null
          ? const Center(
              child: Text(
                "No Notifications",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestoreService.getNotifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Unable to load notifications",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                final notifications = snapshot.data?.docs ?? [];
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      "No Notifications",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final data = notification.data();
                    final isRead = data['seen'] == true;

                    var text = "";
                    if (data["type"] == "like") {
                      text = "liked your post â¤ï¸";
                    } else if (data["type"] == "comment") {
                      text = "commented: ${data["comment"]}";
                    } else if (data["type"] == "follow") {
                      text = "started following you";
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (data["profileUrl"] ?? "").isNotEmpty
                            ? NetworkImage(data["profileUrl"])
                            : null,
                        child: (data["profileUrl"] ?? "").isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        data["username"] ?? "",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        text,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () async {
                        if (isRead) return;

                        try {
                          await firestoreService.markNotificationAsRead(
                            notification.id,
                          );
                        } on FirebaseException {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to mark notification as read',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
