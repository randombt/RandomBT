import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String uid;
  final String username;
  final String profileUrl;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String filterName;
  final DateTime createdAt;
  final DateTime expiresAt;

  StoryModel({
    required this.id,
    required this.uid,
    required this.username,
    required this.profileUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.filterName,
    required this.createdAt,
    required this.expiresAt,
  });

  factory StoryModel.fromMap(String id, Map<String, dynamic> map) {
    return StoryModel(
      id: id,
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      profileUrl: map['profileUrl'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: map['mediaType'] ?? 'image',
      filterName: map['filterName'] ?? 'Normal',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'profileUrl': profileUrl,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'filterName': filterName,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
