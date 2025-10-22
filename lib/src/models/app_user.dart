class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        uid: m['uid'],
        email: m['email'],
        displayName: m['displayName'] ?? '',
        photoUrl: m['photoUrl'],
      );
}
