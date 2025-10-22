import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../services/post_service.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final text = TextEditingController();
  final svc = PostService();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bình luận')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: svc.commentsStream(widget.postId),
              builder: (c, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('Hãy là người đầu tiên bình luận!'));
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final m = docs[i].data();
                    final ts = (m['createdAt'] as Timestamp?);
                    final created = ts?.toDate().toString() ?? '';
                    return ListTile(
                      title: Text(m['text'] ?? ''),
                      subtitle: Text('${m['userId'] ?? ''} • $created'),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(child: TextField(controller: text, decoration: const InputDecoration(hintText: 'Viết bình luận...'))),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (text.text.trim().isEmpty) return;
                    await svc.addComment(widget.postId, auth.uid!, text.text.trim());
                    text.clear();
                  },
                )
              ]),
            ),
          )
        ],
      ),
    );
  }
}
