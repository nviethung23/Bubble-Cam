import 'package:cloud_firestore/cloud_firestore.dart';
import '/model/firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<Users?> getUserInfo(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (!docSnapshot.exists) {
        debugPrint('❌ User document does not exist for uid: $uid');
        return null;
      }
      final data = docSnapshot.data();
      if (data == null) {
        debugPrint('❌ User document data is null for uid: $uid');
        return null;
      }
      
      // Debug log để check data
      debugPrint('✅ User data for $uid: ${data.toString()}');
      debugPrint('📞 Phone number: ${data['phoneNumber']}');
      
      return Users(
        name: data['name']?.toString() ?? '',
        profileUrl: data['profileUrl']?.toString() ?? '',
        phoneNumber: data['phoneNumber']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('❌ getUserInfo error for uid $uid: $e');
      return null;
    }
  }
  
  Future<String?> getUserIdByPhone(String phoneNumber) async {
    try {
      debugPrint('🔍 Searching for phone: $phoneNumber');
      
      final snapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('❌ No user found with phone: $phoneNumber');
        return null;
      }
      
      final userId = snapshot.docs.first.id;
      debugPrint('✅ Found user ID: $userId for phone: $phoneNumber');
      return userId;
    } catch (e) {
      debugPrint('❌ getUserIdByPhone error: $e');
      return null;
    }
  }
  
  Future<bool> updatePhoneNumber(String uid, String phoneNumber) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'phoneNumber': phoneNumber,
      });
      debugPrint('✅ Updated phone number for uid: $uid');
      return true;
    } catch (e) {
      debugPrint('❌ updatePhoneNumber error: $e');
      return false;
    }
  }
  
  // Kiểm tra và fix phoneNumber nếu bị thiếu
  Future<void> ensurePhoneNumber(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      
      if (data != null && (data['phoneNumber'] == null || data['phoneNumber'] == '')) {
        // Lấy phoneNumber từ userStorage
        final GetStorage storage = GetStorage();
        final phone = storage.read('phoneNumber');
        
        if (phone != null && phone.toString().isNotEmpty) {
          await updatePhoneNumber(uid, phone);
          debugPrint('✅ Fixed missing phoneNumber for uid: $uid');
        }
      }
    } catch (e) {
      debugPrint('❌ ensurePhoneNumber error: $e');
    }
  }
}
