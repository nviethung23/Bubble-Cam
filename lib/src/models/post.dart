class Post {
  final String id;
  final String userId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likedBy;

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.likeCount,
    required this.likedBy,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'imageUrl': imageUrl,
        'caption': caption,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'likeCount': likeCount,
        'likedBy': likedBy,
      };

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'],
        userId: m['userId'],
        imageUrl: m['imageUrl'],
        caption: m['caption'],
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
        likeCount: (m['likeCount'] ?? 0) as int,
        likedBy: List<String>.from(m['likedBy'] ?? const []),
      );
}
