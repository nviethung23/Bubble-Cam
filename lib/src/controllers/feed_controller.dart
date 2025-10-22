import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/post.dart';
import '../services/post_service.dart';

class FeedController extends GetxController {
  final PostService _postService;
  FeedController(this._postService);

  RxList<Post> posts = <Post>[].obs;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void onInit() {
    super.onInit();
    _stream = _postService.feedStream();
    _stream.listen((snap) {
      posts.value = snap.docs.map((d) {
        final data = d.data();
        final ts = data['createdAt'] as Timestamp?;
        final ms = ts?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
        return Post.fromMap({...data, 'createdAt': ms});
      }).toList();
    });
  }

  Future<void> toggleLike(Post p, String uid) async {
    final liked = !p.likedBy.contains(uid);
    await _postService.toggleLike(p.id, uid, liked);
  }
}
