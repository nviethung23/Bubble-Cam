class Comment {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Comment.fromMap(Map<String, dynamic> m) => Comment(
        id: m['id'],
        userId: m['userId'],
        text: m['text'],
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );
}
