import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String uid;
  final String username;
  final String profileUrl;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String filterName;
  final String? musicId;
  final String? musicTitle;
  final String? artistName;
  final String? audioUrl;
  final int? startTime;
  final int? duration;
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
    this.musicId,
    this.musicTitle,
    this.artistName,
    this.audioUrl,
    this.startTime,
    this.duration,
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
      musicId: map['musicId'],
      musicTitle: map['musicTitle'],
      artistName: map['artistName'],
      audioUrl: map['audioUrl'],
      startTime: (map['startTime'] as num?)?.toInt(),
      duration: (map['duration'] as num?)?.toInt(),
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
      'musicId': musicId,
      'musicTitle': musicTitle,
      'artistName': artistName,
      'audioUrl': audioUrl,
      'startTime': startTime,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
