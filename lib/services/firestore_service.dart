import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SavedPostsState {
  const SavedPostsState({
    this.postIds = const [],
    this.isLoading = true,
    this.hasError = false,
  });

  final List<String> postIds;
  final bool isLoading;
  final bool hasError;
}

class UsernameAlreadyInUseException implements Exception {}

class FirestoreService {
  static final Map<String, ValueNotifier<SavedPostsState>> _savedPostsStates =
      {};
  static final Map<
    String,
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  >
  _savedPostsSubscriptions = {};
  static final Map<String, DocumentSnapshot<Map<String, dynamic>>>
  _savedPostDocumentCache = {};
  static final Set<String> _missingSavedPostIds = {};

  static final Map<String, DocumentSnapshot<Map<String, dynamic>>> _userCache =
      {};
  static final Map<String, bool> _likeStatusCache = {};
  static final Map<String, Stream<QuerySnapshot>> _userPostsStreamCache = {};
  static final Map<String, Stream<QuerySnapshot>> _followersStreamCache = {};
  static final Map<String, Stream<QuerySnapshot>> _followingStreamCache = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> userReference(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return userReference(uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserOnce(
    String uid, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _userCache.containsKey(uid)) {
      return _userCache[uid]!;
    }
    final doc = await userReference(uid).get();
    if (doc.exists) {
      _userCache[uid] = doc;
    }
    return doc;
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
    _userCache.remove(uid);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String bio,
    required String profileUrl,
  }) async {
    await userReference(uid).set({
      'fullName': fullName,
      'bio': bio,
      'profileUrl': profileUrl,
    }, SetOptions(merge: true));
    _userCache.remove(uid);
  }

  Future<void> updateProfileWithUsername({
    required String uid,
    required String fullName,
    required String username,
    required String previousUsername,
    required String bio,
    required String profileUrl,
  }) async {
    final normalized = username.trim().toLowerCase();
    final previousNormalized = previousUsername.trim().toLowerCase();
    if (normalized.isEmpty) throw ArgumentError('Username is required.');
    final userRef = userReference(uid);
    final reservationRef = _firestore.collection('usernames').doc(normalized);
    final previousReservationRef = _firestore
        .collection('usernames')
        .doc(previousNormalized);

    await _firestore.runTransaction((transaction) async {

  final reservation = await transaction.get(reservationRef);

  DocumentSnapshot<Map<String, dynamic>>? previous;

  if (previousNormalized.isNotEmpty &&
      previousNormalized != normalized) {
    previous = await transaction.get(previousReservationRef);
  }

  if (reservation.exists &&
      reservation.data()?['uid'] != uid) {
    throw UsernameAlreadyInUseException();
  }

  transaction.set(
    reservationRef,
    {
      'uid': uid,
      'username': username.trim(),
      'reservedAt': FieldValue.serverTimestamp(),
    },
  );

  if (previous != null &&
      previous.exists &&
      previous.data()?['uid'] == uid) {
    transaction.delete(previousReservationRef);
  }

  transaction.set(
    userRef,
    {
      'fullName': fullName.trim(),
      'username': username.trim(),
      'usernameLowercase': normalized,
      'bio': bio.trim(),
      'profileUrl': profileUrl,
    },
    SetOptions(merge: true),
  );
 });
}
 Future<void> synchronizeProfileReferences({
    required String uid,
    required String username,
    required String profileUrl,
  }) async {
    final results = await Future.wait([
      _firestore.collection('posts').where('uid', isEqualTo: uid).get(),
      _firestore
          .collection('notifications')
          .where('fromUid', isEqualTo: uid)
          .get(),
      _firestore
          .collectionGroup('comments')
          .where('username', isEqualTo: username)
          .get(),
    ]);
    final batch = _firestore.batch();
    for (final doc in results[0].docs) {
      batch.update(doc.reference, {
        'username': username,
        'profileUrl': profileUrl,
      });
    }
    for (final doc in results[1].docs) {
      batch.update(doc.reference, {
        'username': username,
        'profileUrl': profileUrl,
      });
    }
    for (final doc in results[2].docs) {
      batch.update(doc.reference, {
        'username': username,
        'profileUrl': profileUrl,
      });
    }
    await batch.commit();
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
  Stream<QuerySnapshot<Map<String, dynamic>>> getNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({
      'seen': true,
    });
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

  /// Gets one newest-first page of posts for the Feed.
  Future<QuerySnapshot<Map<String, dynamic>>> getPostsPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection("posts")
        .orderBy("createdAt", descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.get();
  }

  /// Get Current User Posts
  Stream<QuerySnapshot> getUserPosts(String uid) {
    return _userPostsStreamCache.putIfAbsent(
      uid,
      () => _firestore
          .collection("posts")
          .where("uid", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .snapshots()
          .asBroadcastStream(),
    );
  }

  /// Delete Post
  Future<void> deletePost(String postId) async {
    const pageSize = 499;
    final postRef = _firestore.collection('posts').doc(postId);

    QueryDocumentSnapshot<Map<String, dynamic>>? lastUser;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);
      if (lastUser != null) {
        query = query.startAfterDocument(lastUser);
      }

      final users = await query.get();
      if (users.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final user in users.docs) {
        batch.delete(user.reference.collection('savedPosts').doc(postId));
      }
      await batch.commit();

      if (users.docs.length < pageSize) break;
      lastUser = users.docs.last;
    }

    await postRef.delete();
  }

  /// Update Likes
  Future<void> updateLikes(String postId, int likes) async {
    await _firestore.collection("posts").doc(postId).update({"likes": likes});
  }

  /// Checks whether a post is liked by the current user, utilizing memory cache.
  Future<bool> isPostLiked({
    required String postId,
    required String uid,
  }) async {
    final cacheKey = '${postId}_$uid';
    if (_likeStatusCache.containsKey(cacheKey)) {
      return _likeStatusCache[cacheKey]!;
    }
    final doc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .get();
    final liked = doc.exists;
    _likeStatusCache[cacheKey] = liked;
    return liked;
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

    final liked = await _firestore.runTransaction((transaction) async {
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

    _likeStatusCache['${postId}_$uid'] = liked;
    return liked;
  }

  /// Shares one saved-post listener per user for the current app session.
  /// Firestore's local cache supplies the latest available state offline, then
  /// synchronizes it when the device reconnects.
  ValueListenable<SavedPostsState> watchSavedPosts(String uid) {
    final state = _savedPostsStates.putIfAbsent(
      uid,
      () => ValueNotifier(const SavedPostsState()),
    );

    _savedPostsSubscriptions.putIfAbsent(uid, () {
      return userReference(uid)
          .collection('savedPosts')
          .orderBy('savedAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              state.value = SavedPostsState(
                postIds: snapshot.docs.map((post) => post.id).toList(),
                isLoading: false,
              );
            },
            onError: (_) {
              state.value = SavedPostsState(
                postIds: state.value.postIds,
                isLoading: false,
                hasError: true,
              );
            },
          );
    });

    return state;
  }

  /// Loads only saved posts that are not already cached for this session.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getSavedPostDocuments(
    Iterable<String> postIds,
  ) async {
    final ids = postIds.toList(growable: false);
    final missingIds = ids
        .where(
          (id) =>
              !_savedPostDocumentCache.containsKey(id) &&
              !_missingSavedPostIds.contains(id),
        )
        .toList();

    final futures = <Future<void>>[];
    for (var start = 0; start < missingIds.length; start += 10) {
      final end = start + 10 > missingIds.length
          ? missingIds.length
          : start + 10;
      final pageIds = missingIds.sublist(start, end);
      futures.add(() async {
        final posts = await _firestore
            .collection('posts')
            .where(FieldPath.documentId, whereIn: pageIds)
            .get();
        final foundIds = <String>{};
        for (final post in posts.docs) {
          _savedPostDocumentCache[post.id] = post;
          foundIds.add(post.id);
        }
        _missingSavedPostIds.addAll(
          pageIds.where((id) => !foundIds.contains(id)),
        );
      }());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    return [for (final id in ids) ?_savedPostDocumentCache[id]];
  }

  /// Toggles a saved post. A post ID is the document ID, so duplicates are
  /// structurally impossible.
  Future<bool> toggleSavedPost({
    required String uid,
    required String postId,
  }) async {
    final saveRef = userReference(uid).collection('savedPosts').doc(postId);
    final isSaved = await _firestore.runTransaction((transaction) async {
      final savedPost = await transaction.get(saveRef);
      if (savedPost.exists) {
        transaction.delete(saveRef);
        return false;
      }
      transaction.set(saveRef, {'savedAt': FieldValue.serverTimestamp()});
      return true;
    });
    _updateSavedPostsState(uid: uid, postId: postId, isSaved: isSaved);
    return isSaved;
  }

  Future<void> removeSavedPost({
    required String uid,
    required String postId,
  }) async {
    await userReference(uid).collection('savedPosts').doc(postId).delete();
    _updateSavedPostsState(uid: uid, postId: postId, isSaved: false);
  }

  void _updateSavedPostsState({
    required String uid,
    required String postId,
    required bool isSaved,
  }) {
    final state = _savedPostsStates[uid];
    if (state == null) return;

    final postIds = List<String>.of(state.value.postIds)..remove(postId);
    if (isSaved) postIds.insert(0, postId);
    state.value = SavedPostsState(postIds: postIds, isLoading: false);
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
        "likes": [],
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

  Future<void> likeComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> unlikeComment({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayRemove([userId]),
    });
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
    return _followersStreamCache.putIfAbsent(
      uid,
      () => _firestore
          .collection("users")
          .doc(uid)
          .collection("followers")
          .snapshots()
          .asBroadcastStream(),
    );
  }

  Stream<QuerySnapshot> getFollowing(String uid) {
    return _followingStreamCache.putIfAbsent(
      uid,
      () => _firestore
          .collection("users")
          .doc(uid)
          .collection("following")
          .snapshots()
          .asBroadcastStream(),
    );
  }
}
