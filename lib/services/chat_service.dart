import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<String> createOrGetChat({
    required String currentUid,
    required String currentUsername,
    required String currentProfileUrl,
    required String targetUid,
    required String targetUsername,
    required String targetProfileUrl,
  }) async {
    final chatId = getChatId(currentUid, targetUid);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [currentUid, targetUid],
        'participantData': {
          currentUid: {
            'username': currentUsername,
            'profileUrl': currentProfileUrl,
          },
          targetUid: {
            'username': targetUsername,
            'profileUrl': targetProfileUrl,
          },
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderUid': '',
      });
    }
    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String receiverUid,
    required String message,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final timestamp = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      transaction.set(messageRef, {
        'senderUid': senderUid,
        'receiverUid': receiverUid,
        'message': message,
        'createdAt': timestamp,
        'seen': false,
      });

      transaction.update(chatRef, {
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastSenderUid': senderUid,
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
