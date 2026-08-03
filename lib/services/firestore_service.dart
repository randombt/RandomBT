import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> userReference(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return userReference(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserOnce(String uid) {
    return userReference(uid).get();
  }

  Future<void> createUser({
    required String uid,
    required String email,
    required String username,
    required String fullName,
    required String phone,
    required String profileUrl,
  }) async {
    final reference = userReference(uid);
    final existingUser = await reference.get();

    await reference.set({
      'uid': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'phone': phone,
      'profileUrl': profileUrl,
      if (!existingUser.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String bio,
    required String profileUrl,
  }) {
    return userReference(uid).set({
      'fullName': fullName,
      'bio': bio,
      'profileUrl': profileUrl,
    }, SetOptions(merge: true));
  }

  /// Create Notification
  Future<void> createNotification({
    required String toUid,
    required String fromUid,
    required String username,
    required String profileUrl,
    required String type,
    String? postId,
    String? comment,
    String? actionId,
  }) async {
    if (toUid == fromUid) return;

    final notification = {
      "toUid": toUid,
      "fromUid": fromUid,
      "username": username,
      "profileUrl": profileUrl,
      "type": type,
      "postId": postId,
      "comment": comment,
      "seen": false,
      "createdAt": FieldValue.serverTimestamp(),
    };
    final id = actionId ?? '${type}_${postId ?? ''}_$fromUid';
    await _firestore
        .collection("notifications")
        .doc(id)
        .set(notification, SetOptions(merge: true));
  }

  /// Get Notifications
  Stream<QuerySnapshot> getNotifications(String uid) {
    return _firestore
        .collection("notifications")
        .where("toUid", isEqualTo: uid)
        .snapshots();
  }

  /// Upload Post
  Future<void> uploadPost({
    required String uid,
    required String username,
    required String profileUrl,
    required String imageUrl,
    required String caption,
  }) async {
    await _firestore.collection("posts").add({
      "uid": uid,
      "username": username,
      "profileUrl": profileUrl,
      "imageUrl": imageUrl,
      "caption": caption,
      "likes": 0,
      "comments": 0,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  /// Get All Posts
  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection("posts")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Get Current User Posts
  Stream<QuerySnapshot> getUserPosts(String uid) {
    return _firestore
        .collection("posts")
        .where("uid", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Delete Post
  Future<void> deletePost(String postId) async {
    final savedPosts = await _firestore
        .collectionGroup('savedPosts')
        .where(FieldPath.documentId, isEqualTo: postId)
        .get();
    final batch = _firestore.batch();
    for (final savedPost in savedPosts.docs) {
      batch.delete(savedPost.reference);
    }
    batch.delete(_firestore.collection("posts").doc(postId));
    await batch.commit();
  }

  /// Update Likes
  Future<void> updateLikes(String postId, int likes) async {
    await _firestore.collection("posts").doc(postId).update({"likes": likes});
  }

  /// Toggles the current user's like in one transaction. The like document ID
  /// enforces one like per user and keeps the counter in sync with it.
  Future<bool> toggleLike({
    required String postId,
    required String uid,
    required String username,
    required String profileUrl,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    return _firestore.runTransaction((transaction) async {
      final post = await transaction.get(postRef);
      if (!post.exists) return false;

      final like = await transaction.get(likeRef);
      final postData = post.data()!;
      final ownerUid = postData['uid']?.toString() ?? '';
      final notificationRef = _firestore
          .collection('notifications')
          .doc('like_${postId}_$uid');
      final currentLikes = (postData['likes'] as num?)?.toInt() ?? 0;

      if (like.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {
          'likes': currentLikes > 0 ? currentLikes - 1 : 0,
        });
        if (ownerUid != uid) transaction.delete(notificationRef);
        return false;
      }

      transaction.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
      transaction.update(postRef, {'likes': currentLikes + 1});
      if (ownerUid.isNotEmpty && ownerUid != uid) {
        transaction.set(notificationRef, {
          'toUid': ownerUid,
          'fromUid': uid,
          'username': username,
          'profileUrl': profileUrl,
          'type': 'like',
          'postId': postId,
          'comment': null,
          'seen': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    });
  }

  /// Toggles a saved post. A post ID is the document ID, so duplicates are
  /// structurally impossible.
  Future<bool> toggleSavedPost({required String uid, required String postId}) {
    final saveRef = userReference(uid).collection('savedPosts').doc(postId);
    return _firestore.runTransaction((transaction) async {
      final savedPost = await transaction.get(saveRef);
      if (savedPost.exists) {
        transaction.delete(saveRef);
        return false;
      }
      transaction.set(saveRef, {'savedAt': FieldValue.serverTimestamp()});
      return true;
    });
  }

  Future<void> removeSavedPost({required String uid, required String postId}) {
    return userReference(uid).collection('savedPosts').doc(postId).delete();
  }

  /// Add Comment
  Future<String> addComment({
    required String postId,
    required String username,
    required String profileUrl,
    required String comment,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();
    await _firestore.runTransaction((transaction) async {
      final post = await transaction.get(postRef);
      if (!post.exists) return;
      transaction.set(commentRef, {
        "username": username,
        "profileUrl": profileUrl,
        "comment": comment,
        "createdAt": FieldValue.serverTimestamp(),
      });
      final comments = (post.data()?['comments'] as num?)?.toInt() ?? 0;
      transaction.update(postRef, {'comments': comments + 1});
    });
    return commentRef.id;
  }

  /// Get Comments
  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection("posts")
        .doc(postId)
        .collection("comments")
        .orderBy("createdAt")
        .snapshots();
  }

  Future<bool> followUser({
    required String currentUid,
    required String targetUid,
    required String username,
    required String profileUrl,
  }) async {
    if (currentUid == targetUid) return false;
    final followingRef = _firestore
        .collection("users")
        .doc(currentUid)
        .collection("following")
        .doc(targetUid);

    final followerRef = _firestore
        .collection("users")
        .doc(targetUid)
        .collection("followers")
        .doc(currentUid);

    final notificationRef = _firestore
        .collection('notifications')
        .doc('follow_${targetUid}_$currentUid');

    return _firestore.runTransaction((transaction) async {
      final following = await transaction.get(followingRef);
      if (following.exists) {
        transaction.delete(followingRef);
        transaction.delete(followerRef);
        transaction.delete(notificationRef);
        return false;
      }

      final followedAt = FieldValue.serverTimestamp();
      transaction.set(followingRef, {'followedAt': followedAt});
      transaction.set(followerRef, {'followedAt': followedAt});
      transaction.set(notificationRef, {
        'toUid': targetUid,
        'fromUid': currentUid,
        'username': username,
        'profileUrl': profileUrl,
        'type': 'follow',
        'postId': null,
        'comment': null,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Stream<QuerySnapshot> getFollowers(String uid) {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("followers")
        .snapshots();
  }

  Stream<QuerySnapshot> getFollowing(String uid) {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("following")
        .snapshots();
  }
}
