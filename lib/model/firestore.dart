import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';

final GetStorage userStorage = GetStorage();
final firestore = FirebaseFirestore.instance;

class Users {
  String? uid;
  String? name;
  String? phoneNumber;
  String? profileUrl;
  List<String>? friends;

  Users({
    this.uid,
    this.name,
    this.phoneNumber,
    this.profileUrl,
    this.friends,
  });

  // ✅ Dùng fromFirestore thay vì fromJson
  factory Users.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return Users(
      uid: snapshot.id,
      name: data?['name'],
      phoneNumber: data?['phoneNumber'],
      profileUrl: data?['profileUrl'],
      friends: data?['friends'] is Iterable ? List.from(data!['friends']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (name != null) 'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (profileUrl != null) 'profileUrl': profileUrl,
      if (friends != null) 'friends': friends,
    };
  }

  void updateInfo(Users newInfo) {
    name = newInfo.name;
    phoneNumber = newInfo.phoneNumber;
  }

  String get displayName => name?.isNotEmpty == true ? name! : phoneNumber ?? '';
}

class Images {
  // ✅ THÊM field id
  String? id;
  
  String? url;
  String? uid;
  String? message;
  String? dateCreated;
  List<String>? visibleTo;
  String? visibility;
  
  // ✅ THÊM owner info (để không cần query riêng)
  String? ownerName;
  String? ownerAvatar;

  Images({
    this.id, // ✅ THÊM
    this.url,
    this.uid,
    this.message,
    this.dateCreated,
    this.visibleTo,
    this.visibility,
    this.ownerName, // ✅ THÊM
    this.ownerAvatar, // ✅ THÊM
  });

  factory Images.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return Images(
      id: snapshot.id, // ✅ LƯU document ID
      url: data?['url'],
      uid: data?['uid'],
      message: data?['message'],
      dateCreated: data?['dateCreated'] is Timestamp
          ? (data!['dateCreated'] as Timestamp).toDate().toIso8601String()
          : data?['dateCreated'],
      visibleTo: data?['visibleTo'] is Iterable
          ? List.from(data!['visibleTo'])
          : null,
      visibility: data?['visibility'],
      ownerName: data?['ownerName'], // ✅ THÊM
      ownerAvatar: data?['ownerAvatar'], // ✅ THÊM
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (url != null) "url": url,
      if (uid != null) "uid": uid,
      if (message != null) "message": message,
      if (dateCreated != null) "dateCreated": dateCreated,
      if (visibleTo != null) "visibleTo": visibleTo,
      if (visibility != null) "visibility": visibility,
      if (ownerName != null) "ownerName": ownerName, // ✅ THÊM
      if (ownerAvatar != null) "ownerAvatar": ownerAvatar, // ✅ THÊM
    };
  }
}

class FriendRequests {
  String? id;
  String? senderId;
  String? receiverId;
  String? status;
  String? createdAt;

  FriendRequests({
    this.id,
    this.senderId,
    this.receiverId,
    this.status,
    this.createdAt,
  });

  factory FriendRequests.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return FriendRequests(
      id: snapshot.id,
      senderId: data?['senderId'],
      receiverId: data?['receiverId'],
      status: data?['status'],
      createdAt: _normalizeDate(data?['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (senderId != null) 'senderId': senderId,
      if (receiverId != null) 'receiverId': receiverId,
      if (status != null) 'status': status,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

String? _normalizeDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }
  if (value is String) {
    return value;
  }
  return null;
}
