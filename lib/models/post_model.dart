import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String uid;
  final String username;
  final String profileUrl;
  final String imageUrl;
  final String caption;
  final int likes;
  final int comments;
  final Timestamp? createdAt;

  PostModel({
    required this.id,
    required this.uid,
    required this.username,
    required this.profileUrl,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.createdAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PostModel(
      id: documentId,
      uid: map["uid"] ?? "",
      username: map["username"] ?? "",
      profileUrl: map["profileUrl"] ?? "",
      imageUrl: map["imageUrl"] ?? "",
      caption: map["caption"] ?? "",
      likes: map["likes"] ?? 0,
      comments: map["comments"] ?? 0,
      createdAt: map["createdAt"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "username": username,
      "profileUrl": profileUrl,
      "imageUrl": imageUrl,
      "caption": caption,
      "likes": likes,
      "comments": comments,
      "createdAt": createdAt,
    };
  }
}
