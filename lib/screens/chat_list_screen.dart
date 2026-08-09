import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  ChatListScreen({super.key});

  final ChatService chatService = ChatService();
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xff0F1115),
        body: Center(
          child: Text("Please login first", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        title: const Text("Messages"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatService.getChats(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Unable to load chats",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Text(
                "No Messages Yet",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chatData = chats[index].data();
              final chatId = chats[index].id;
              final participants = List<String>.from(chatData['participants'] ?? []);
              final participantData = chatData['participantData'] as Map<String, dynamic>? ?? {};

              final otherUid = participants.firstWhere(
                (uid) => uid != user.uid,
                orElse: () => '',
              );

              final otherData = participantData[otherUid] as Map<String, dynamic>? ?? {};
              final username = otherData['username'] ?? 'User';
              final profileUrl = otherData['profileUrl'] ?? '';
              final lastMessage = chatData['lastMessage'] ?? '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                  child: profileUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(
                  username,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMessage.isEmpty ? 'Tap to chat' : lastMessage,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        targetUid: otherUid,
                        targetUsername: username,
                        targetProfileUrl: profileUrl,
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
