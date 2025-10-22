import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/post.dart';
import 'comments_page.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = Get.find<FeedController>();
    final auth = Get.find<AuthController>();

    return Obx(() {
      final items = feed.posts;
      if (items.isEmpty) {
        return const Center(child: Text('Chưa có bài nào. Chụp phát đi!'));
        }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final Post p = items[i];
          final meLiked = p.likedBy.contains(auth.uid);
          return Card(
            margin: const EdgeInsets.all(12),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CachedNetworkImage(imageUrl: p.imageUrl, fit: BoxFit.cover),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((p.caption ?? '').isNotEmpty)
                        Text(p.caption ?? '', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => feed.toggleLike(p, auth.uid!),
                            icon: Icon(meLiked ? Icons.favorite : Icons.favorite_border),
                          ),
                          Text('${p.likeCount}'),
                          const SizedBox(width: 12),
                          Text(timeago.format(p.createdAt)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => Get.to(() => CommentsPage(postId: p.id)),
                            icon: const Icon(Icons.mode_comment_outlined, size: 18),
                            label: const Text('Bình luận'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
