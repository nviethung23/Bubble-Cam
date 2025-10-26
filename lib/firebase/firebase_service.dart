import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_storage/get_storage.dart';
import '/model/firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GetStorage _userStorage = GetStorage();

  // ✅ Helper: Đảm bảo có UID (sign-in nếu cần)
  Future<String> _ensureUid() async {
    User? user = _auth.currentUser;
    
    if (user == null) {
      try {
        final credential = await _auth.signInAnonymously();
        user = credential.user;
        print('✅ Đã sign-in anonymous: ${user?.uid}');
      } catch (e) {
        print('❌ Lỗi sign-in: $e');
      }
    }
    
    final uid = user?.uid ?? _userStorage.read('uid');
    if (uid != null && uid.isNotEmpty) {
      await _userStorage.write('uid', uid);
      return uid;
    }
    
    return 'anonymous';
  }

  // Auth helpers
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();
  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();

  // Upload image file to Storage, return download URL
  Future<String> uploadImageFile(File file, {String? pathPrefix}) async {
    final uid = await _ensureUid();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${pathPrefix ?? 'images'}/$uid/$ts.jpg';
    final ref = _storage.ref().child(path);
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  // Save metadata to Firestore (collection 'images')
  Future<String> saveImageMeta({
    required String downloadUrl,
    required String uid,
    String? message,
    List<String>? sharedWith,
    String? visibility,
    String? ownerName, // ✅ THÊM
    String? ownerAvatar, // ✅ THÊM
  }) async {
    final visibleTo = <String>[uid];
    if (sharedWith != null) visibleTo.addAll(sharedWith);

    final docRef = await _fs.collection('images').add({
      'url': downloadUrl,
      'uid': uid,
      'message': message ?? '',
      'dateCreated': FieldValue.serverTimestamp(),
      'visibleTo': visibleTo,
      'visibility': visibility ?? 'all_friends',
      'ownerName': ownerName, // ✅ THÊM
      'ownerAvatar': ownerAvatar, // ✅ THÊM
    });

    print('✅ Saved image meta: ${docRef.id}');
    return downloadUrl;
  }

  // Helper: upload file then save meta; returns download URL
  Future<String> uploadAndSave({
    required File file,
    String message = '',
    String? visibility,
    List<String>? sharedWith,
    String? pathPrefix,
  }) async {
    final url = await uploadImageFile(file, pathPrefix: pathPrefix);
    await saveImageMeta(
      downloadUrl: url,
      uid: (await _ensureUid()),
      message: message,
      visibility: visibility,
      sharedWith: sharedWith,
    );
    return url;
  }

  // ✅ QUERY: Lấy ảnh được share với user
  Stream<List<Images>> getHistoryImages(String currentUid) {
    print('🔑 getHistoryImages() called');
    print('🔑 Querying images for UID: $currentUid');
    print('👤 Current Firebase user: ${_auth.currentUser?.uid}');
    
    if (currentUid.isEmpty) {
      print('❌ UID is empty!');
      return Stream.value([]);
    }
    
    print('🔍 Starting Firestore query...');
    
    return _fs
        .collection('images')
        .where('visibleTo', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
          print('📦 Query snapshot received');
          print('🔍 Query found ${snapshot.docs.length} documents');
          
          if (snapshot.docs.isEmpty) {
            print('⚠️ No images found in Firestore for UID: $currentUid');
            print('⚠️ Check:');
            print('   1. Images uploaded?');
            print('   2. visibleTo contains: $currentUid?');
            print('   3. Firestore index exists?');
          }
          
          final images = snapshot.docs.map((doc) {
            final data = doc.data();
            print('📄 Doc ${doc.id}: visibleTo=${data['visibleTo']}');
            
            try {
              return Images.fromFirestore(doc, null);
            } catch (e) {
              print('❌ Error parsing image ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Images>()
          .where((img) => (img.url ?? '').isNotEmpty)
          .toList();
          
          // ✅ Sort by dateCreated
          images.sort((a, b) {
            final aDate = _resolveDateTime(a.dateCreated);
            final bDate = _resolveDateTime(b.dateCreated);
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });
          
          print('✅ Returning ${images.length} valid images');
          return images;
        })
        .handleError((e) {
          print('❌ Stream error: $e');
          print('❌ Error stack: ${StackTrace.current}');
          return <Images>[];
        });
  }

  // Helper function để parse dateCreated
  DateTime? _resolveDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (e) {
      return null;
    }
  }
}
