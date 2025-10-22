import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class PostService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get posts =>
      _db.collection('posts');

  Future<String> createPost({
    required String userId,
    required String imageUrl,
    String? caption,
  }) async {
    final id = _uuid.v4();
    await posts.doc(id).set({
      'id': id,
      'userId': userId,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'likedBy': <String>[],
    });
    return id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> feedStream() =>
      posts.orderBy('createdAt', descending: true).limit(100).snapshots();

  Future<void> toggleLike(String postId, String uid, bool liked) async {
    final ref = posts.doc(postId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      if (liked) {
        if (!likedBy.contains(uid)) likedBy.add(uid);
      } else {
        likedBy.remove(uid);
      }
      tx.update(ref, {
        'likedBy': likedBy,
        'likeCount': likedBy.length,
      });
    });
  }

  CollectionReference<Map<String, dynamic>> commentsCol(String postId) =>
      posts.doc(postId).collection('comments');

  Future<void> addComment(String postId, String uid, String text) async {
    final id = _uuid.v4();
    await commentsCol(postId).doc(id).set({
      'id': id,
      'userId': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) =>
      commentsCol(postId).orderBy('createdAt', descending: true).snapshots();
}
