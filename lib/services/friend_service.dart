import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/firestore.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // ===== TÌM KIẾM USER =====
  
  // ✅ SỬA: Trả về Map thay vì Users
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      
      final doc = query.docs.first;
      return {
        'uid': doc.id,
        'name': doc.data()['name'],
        'phoneNumber': doc.data()['phoneNumber'],
        'profileUrl': doc.data()['profileUrl'],
      };
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  // Tìm theo tên (search)
  Future<List<Users>> searchUsersByName(String name) async {
    if (name.isEmpty) return [];
    
    try {
      final query = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: name)
          .where('name', isLessThanOrEqualTo: name + '\uf8ff')
          .limit(20)
          .get();

      final results = <Users>[];
      for (var doc in query.docs) {
        if (doc.id != currentUserId) {
          results.add(Users.fromFirestore(doc, null));
        }
      }
      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Lấy thông tin user theo UID
  Future<Users?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return Users.fromFirestore(doc, null);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // ===== GỬI LỜI MỜI KẾT BẠN =====
  
  Future<bool> sendFriendRequest(String toUserId) async {
    try {
      // Kiểm tra đã là bạn bè chưa
      if (await isFriend(toUserId)) {
        print('Already friends');
        return false;
      }

      // Kiểm tra đã gửi chưa
      final existing = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        print('Already sent request');
        return false;
      }

      // ✅ Kiểm tra có bị block không
      if (await isBlocked(toUserId)) {
        print('User blocked you');
        return false;
      }

      // Gửi lời mời
      await _firestore.collection('friendRequests').add({
        'senderId': currentUserId,
        'receiverId': toUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  // ===== CHẤP NHẬN LỜI MỜI =====

  Future<bool> acceptFriendRequest(String requestId, String senderId) async {
    try {
      print('🔍 Current user: $currentUserId');
      print('🔍 Sender: $senderId');
      print('🔍 Request ID: $requestId');

      // ✅ Verify user is authenticated
      if (_auth.currentUser == null) {
        print('❌ Error: User not authenticated');
        return false;
      }
    
      // 1. Update request status
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });
      print('✅ Step 1: Updated request status');

      // 2. Thêm UID vào friends của current user
      await _firestore.collection('users').doc(currentUserId).update({
        'friends': FieldValue.arrayUnion([senderId]),
      });
      print('✅ Step 2: Added $senderId to current user friends');

      // 3. Thêm UID vào friends của sender
      await _firestore.collection('users').doc(senderId).update({
        'friends': FieldValue.arrayUnion([currentUserId]),
      });
      print('✅ Step 3: Added $currentUserId to sender friends');

      return true;
    } on FirebaseException catch (e) {
      print('❌ Firebase Error accepting friend request: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        print('❌ Permission denied. Check Firestore security rules.');
      }
      return false;
    } catch (e) {
      print('❌ Error accepting friend request: $e');
      return false;
    }
  }

  // ===== TỪ CHỐI LỜI MỜI =====
  
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      // ✅ CẢI THIỆN: Xóa luôn thay vì update status
      // Lý do: Giảm dữ liệu rác, user không cần xem lại request đã từ chối
      await _firestore.collection('friendRequests').doc(requestId).delete();
      
      // ❌ Hoặc nếu muốn giữ lại để tracking:
      // await _firestore.collection('friendRequests').doc(requestId).update({
      //   'status': 'rejected',
      //   'rejectedAt': FieldValue.serverTimestamp(),
      // });
      
      return true;
    } catch (e) {
      print('Error rejecting friend request: $e');
      return false;
    }
  }

  // ===== LẤY DANH SÁCH LỜI MỜI ĐẾN =====
  
  Stream<List<FriendRequests>> getPendingRequests() {
    return _firestore
        .collection('friendRequests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequests.fromFirestore(doc, null))
            .toList());
  }

  // ✅ MỚI: Lấy danh sách request ĐÃ GỬI (để hiển thị "Đang chờ")
  Stream<List<FriendRequests>> getSentRequests() {
    return _firestore
        .collection('friendRequests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequests.fromFirestore(doc, null))
            .toList());
  }

  // Đếm số lời mời chưa đọc
  Future<int> getPendingRequestsCount() async {
    try {
      final query = await _firestore
          .collection('friendRequests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ===== LẤY DANH SÁCH BẠN BÈ =====
  
  Future<List<Users>> getFriends() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

      if (friendIds.isEmpty) return [];

      // Chia nhỏ query (Firestore giới hạn 10 items trong whereIn)
      List<Users> allFriends = [];
      
      for (int i = 0; i < friendIds.length; i += 10) {
        final chunk = friendIds.skip(i).take(10).toList();
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allFriends.addAll(
          query.docs.map((doc) => Users.fromFirestore(doc, null))
        );
      }

      return allFriends;
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // ===== LẤY DANH SÁCH UID BẠN BÈ =====
  
  // ⚠️ QUAN TRỌNG: Luôn trả về UID, không phải phoneNumber
  // Vì sharedWith trong /images collection dùng UID
  Future<List<String>> getFriendIds() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      return List<String>.from(userDoc.data()?['friends'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // Stream danh sách bạn bè (real-time)
  Stream<List<String>> getFriendsStream() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['friends'] ?? []));
  }

  // ===== XÓA BẠN BÈ =====
  
  Future<bool> removeFriend(String friendId) async {
    try {
      print('🗑️ Removing friend: $friendId');
      print('🗑️ Current user: $currentUserId');
    
      // ✅ Verify user is authenticated
      if (_auth.currentUser == null) {
        print('❌ Error: User not authenticated');
        return false;
      }

      // ✅ Verify they are actually friends first
      final isFriendCheck = await isFriend(friendId);
      if (!isFriendCheck) {
        print('❌ Error: Not friends with this user');
        return false;
      }
    
      // 1. Xóa khỏi friends của current user
      await _firestore.collection('users').doc(currentUserId).update({
        'friends': FieldValue.arrayRemove([friendId])
      });
      print('✅ Step 1: Removed $friendId from current user');

      // 2. Xóa khỏi friends của friend
      await _firestore.collection('users').doc(friendId).update({
        'friends': FieldValue.arrayRemove([currentUserId])
      });
      print('✅ Step 2: Removed $currentUserId from friend');

      return true;
    } on FirebaseException catch (e) {
      print('❌ Firebase Error removing friend: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        print('❌ Permission denied. Check Firestore security rules.');
      }
      return false;
    } catch (e) {
      print('❌ Error removing friend: $e');
      return false;
    }
  }

  // ===== KIỂM TRA TRẠNG THÁI =====
  
  // Kiểm tra đã là bạn bè chưa
  Future<bool> isFriend(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      final friends = List<String>.from(doc.data()?['friends'] ?? []);
      return friends.contains(userId);
    } catch (e) {
      return false;
    }
  }

  // Kiểm tra trạng thái request
  Future<String?> getRequestStatus(String userId) async {
    try {
      // Kiểm tra đã gửi request chưa
      final sent = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (sent.docs.isNotEmpty) return 'sent';

      // Kiểm tra có request đến không
      final received = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: userId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (received.docs.isNotEmpty) return 'received';

      return null;
    } catch (e) {
      return null;
    }
  }

  // ===== HUỶ LỜI MỜI ĐÃ GỬI =====
  
  Future<bool> cancelFriendRequest(String toUserId) async {
    try {
      final query = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (query.docs.isEmpty) return false;

      await query.docs.first.reference.delete();
      return true;
    } catch (e) {
      print('Error canceling request: $e');
      return false;
    }
  }

  // ===== LẤY THÔNG TIN REQUEST =====
  
  Future<FriendRequests?> getRequestById(String requestId) async {
    try {
      final doc = await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .get();

      if (!doc.exists) return null;
      return FriendRequests.fromFirestore(doc, null);
    } catch (e) {
      return null;
    }
  }

  // ===== ✅ MỚI: BLOCK USER =====
  
  Future<bool> blockUser(String userId) async {
    try {
      // 1. Xóa bạn bè (nếu có)
      if (await isFriend(userId)) {
        await removeFriend(userId);
      }

      // 2. Xóa tất cả request giữa 2 người
      final requests = await _firestore
          .collection('friendRequests')
          .where('senderId', whereIn: [currentUserId, userId])
          .get();

      for (var doc in requests.docs) {
        final data = doc.data();
        if ((data['senderId'] == currentUserId && data['receiverId'] == userId) ||
            (data['senderId'] == userId && data['receiverId'] == currentUserId)) {
          await doc.reference.delete();
        }
      }

      // 3. Thêm vào blockedUsers
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([userId]),
      });

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  // ✅ MỚI: UNBLOCK USER
  Future<bool> unblockUser(String userId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  // ✅ MỚI: Kiểm tra có block không
  Future<bool> isBlocked(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final blockedUsers = List<String>.from(doc.data()?['blockedUsers'] ?? []);
      return blockedUsers.contains(currentUserId);
    } catch (e) {
      return false;
    }
  }

  // ✅ MỚI: Lấy danh sách đã block
  Future<List<Users>> getBlockedUsers() async {
    try {
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final blockedIds = List<String>.from(userDoc.data()?['blockedUsers'] ?? []);

      if (blockedIds.isEmpty) return [];

      List<Users> blocked = [];
      for (int i = 0; i < blockedIds.length; i += 10) {
        final chunk = blockedIds.skip(i).take(10).toList();
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        blocked.addAll(query.docs.map((doc) => Users.fromFirestore(doc, null)));
      }

      return blocked;
    } catch (e) {
      return [];
    }
  }

  // ===== ✅ MỚI: GỢI Ý BẠN BÈ =====
  
  // Bạn chung
  Future<List<Users>> getMutualFriends(String userId) async {
    try {
      final myFriends = await getFriendIds();
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final theirFriends = List<String>.from(userDoc.data()?['friends'] ?? []);

      final mutualIds = myFriends.where((id) => theirFriends.contains(id)).toList();

      if (mutualIds.isEmpty) return [];

      List<Users> mutual = [];
      for (int i = 0; i < mutualIds.length; i += 10) {
        final chunk = mutualIds.skip(i).take(10).toList();
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        mutual.addAll(query.docs.map((doc) => Users.fromFirestore(doc, null)));
      }

      return mutual;
    } catch (e) {
      return [];
    }
  }

  // Gợi ý từ bạn của bạn
  Future<List<Users>> getSuggestedFriends({int limit = 20}) async {
    try {
      final myFriends = await getFriendIds();
      if (myFriends.isEmpty) return [];

      final Set<String> suggested = {};

      // Lấy bạn của bạn
      for (var friendId in myFriends.take(5)) { // Chỉ lấy 5 người để tránh quá tải
        final doc = await _firestore.collection('users').doc(friendId).get();
        final theirFriends = List<String>.from(doc.data()?['friends'] ?? []);
        
        for (var id in theirFriends) {
          if (id != currentUserId && !myFriends.contains(id)) {
            suggested.add(id);
          }
        }
      }

      if (suggested.isEmpty) return [];

      final suggestedList = suggested.take(limit).toList();
      List<Users> users = [];

      for (int i = 0; i < suggestedList.length; i += 10) {
        final chunk = suggestedList.skip(i).take(10).toList();
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        users.addAll(query.docs.map((doc) => Users.fromFirestore(doc, null)));
      }

      return users;
    } catch (e) {
      return [];
    }
  }
}