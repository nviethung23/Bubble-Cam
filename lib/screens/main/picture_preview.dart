import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart'; // ✅ Add this

import '/globals.dart'; // ✅ Add this to access userStorage and firestore
import '/services/widget_service.dart';
import '/services/friend_service.dart';
import '/firebase/firebase_service.dart';
import '/model/firestore.dart' hide userStorage,firestore;
import '../../utils/colors.dart';

class PicturePreview extends StatefulWidget {
  const PicturePreview({super.key, required this.file});

  final File file;

  @override
  State<PicturePreview> createState() => _PicturePreviewState();
}

class _PicturePreviewState extends State<PicturePreview> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final FriendService _friendService = FriendService();
  
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isLoadingFriends = true;
  
  // ✅ Chỉ 2 options: all_friends hoặc selected
  String _selectedVisibility = 'all_friends'; // 'all_friends', 'selected'
  List<Users> _allFriends = [];
  Set<String> _selectedFriendIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    final friends = await _friendService.getFriends();
    setState(() {
      _allFriends = friends;
      _isLoadingFriends = false;
    });
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          Get.snackbar(
            'Từ chối quyền',
            'Cần quyền truy cập ảnh để lưu',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
      }

      final result = await SaverGallery.saveFile(
        filePath: widget.file.path,
        fileName: "BubbleCam_${DateTime.now().millisecondsSinceEpoch}.jpg",
        skipIfExists: false,
      );

      if (result.isSuccess) {
        Get.snackbar(
          'Đã lưu!',
          'Ảnh đã được lưu vào thư viện',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        throw Exception('Failed to save: ${result.errorMessage}');
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể lưu ảnh: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadImage() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      print('🚀 Starting upload...');
      
      // ✅ 1. Get UID + User info
      final uid = userStorage.read('uid') as String?;
      if (uid == null || uid.isEmpty) {
        throw Exception('User not authenticated - no UID in storage');
      }
      
      print('✅ User UID from storage: $uid');

      // ✅ 2. Get current user info (name + avatar)
      final userDoc = await firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final ownerName = userData?['name'] as String? ?? 'Unknown';
      final ownerAvatar = userData?['profileUrl'] as String? ?? '';
      
      print('👤 Owner name: $ownerName');
      print('🖼️ Owner avatar: $ownerAvatar');

      // ✅ 3. Upload ảnh lên Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('images/$uid/$fileName');
      
      print('📤 Uploading to Storage...');
      await storageRef.putFile(widget.file);
      final downloadUrl = await storageRef.getDownloadURL();
      print('✅ Storage URL: $downloadUrl');

      // ✅ 4. Xác định visibleTo IDs
      List<String> visibleToIds = [];
      if (_selectedVisibility == 'all_friends') {
        visibleToIds = _allFriends
            .map((f) => f.uid ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      } else if (_selectedVisibility == 'selected') {
        visibleToIds = _selectedFriendIds.toList();
      }
      
      // ✅ Luôn thêm uid của user hiện tại
      if (!visibleToIds.contains(uid)) {
        visibleToIds.add(uid);
      }

      print('👥 Visible to: $visibleToIds');
      print('🔍 Current user UID: $uid');

      // ✅ 5. Lưu vào Firestore với ownerName + ownerAvatar
      print('💾 Saving to Firestore...');
      final docRef = await firestore.collection('images').add({
        'url': downloadUrl,
        'uid': uid,
        'message': _messageController.text.trim(),
        'dateCreated': FieldValue.serverTimestamp(),
        'visibleTo': visibleToIds,
        'visibility': _selectedVisibility,
        'ownerName': ownerName, // ✅ THÊM
        'ownerAvatar': ownerAvatar, // ✅ THÊM
      });

      print('✅ Firestore doc ID: ${docRef.id}');
      print('✅ visibleTo array: $visibleToIds');
      print('✅ Upload complete!');
      
      if (mounted) {
        setState(() => _isUploading = false);
        Get.back(result: true);
        Get.snackbar(
          '✅ Thành công',
          'Ảnh đã được chia sẻ',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        Get.snackbar(
          '❌ Lỗi',
          'Không thể tải ảnh lên: $e',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: white,
        );
      }
    }
  }

  String _getAudienceText() {
    if (_selectedVisibility == 'all_friends') {
      return 'tất cả bạn bè';
    } else {
      return '${_selectedFriendIds.length} người';
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ✅ Header "Send to..."
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      "Gửi đến...",
                      style: GoogleFonts.rubik(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // ✅ Image preview - CÙNG SIZE VỚI CAMERA
                SizedBox(
                  width: size.width,
                  height: size.width, // ✅ Giống camera: width x width
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(75),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          width: size.width,
                          height: size.width,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: Image.file(widget.file),
                          ),
                        ),
                        // Message input
                        Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: secondaryColor,
                            ),
                            child: IntrinsicWidth(
                              child: TextField(
                                controller: _messageController,
                                scrollPhysics: const NeverScrollableScrollPhysics(),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rubik(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Thêm một tin nhắn",
                                  hintStyle: GoogleFonts.rubik(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white54),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                
                // ✅ Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40)
                      .copyWith(top: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close_outlined,
                            size: 40, color: Colors.white),
                      ),
                      
                      TextButton(
                        onPressed: _isUploading ? null : _uploadImage,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: const CircleBorder(
                            side: BorderSide(
                              width: 5,
                              color: primaryColor,
                              strokeAlign: 3,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(""),
                        ),
                      ),
                      
                      IconButton(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onPressed: _isSaving ? null : _saveToGallery,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.tray_arrow_down,
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ),
                
                // ✅ Audience selector ở dưới
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildAudienceSelector(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Bubble selector - CHỈ 2 OPTIONS
  Widget _buildAudienceSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: _isLoadingFriends
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ✅ 1. Tất cả bạn bè
                    _buildBubbleOption(
                      icon: Iconsax.people,
                      label: 'Tất cả bạn bè',
                      count: _allFriends.length,
                      isSelected: _selectedVisibility == 'all_friends',
                      onTap: () =>
                          setState(() => _selectedVisibility = 'all_friends'),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // ✅ 2. Chọn bạn bè
                    if (_allFriends.isNotEmpty) ...[
                      _buildBubbleOption(
                        icon: Iconsax.user_tick,
                        label: _selectedVisibility == 'selected' &&
                                _selectedFriendIds.isNotEmpty
                            ? '${_selectedFriendIds.length} người'
                            : 'Chọn bạn',
                        isSelected: _selectedVisibility == 'selected',
                        onTap: () =>
                            setState(() => _selectedVisibility = 'selected'),
                      ),
                      if (_selectedVisibility == 'selected') ...[
                        const SizedBox(width: 12),
                        ..._allFriends.map((friend) => _buildFriendBubble(friend)),
                      ],
                    ],
                  ],
                ),
        ),
        
        const SizedBox(height: 8),
        
        // ✅ Indicator dots - CHỈ 2 CHẤM
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            bool isActive = (_selectedVisibility == 'all_friends' && index == 0) ||
                (_selectedVisibility == 'selected' && index == 1);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? primaryColor : Colors.white.withOpacity(0.3),
              ),
            );
          }),
        ),
        
        const SizedBox(height: 10),
      ],
    );
  }

  // ✅ Bubble option - ICON NHỎ
  Widget _buildBubbleOption({
    required IconData icon,
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : secondaryColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18, // ✅ Icon nhỏ
              color: isSelected ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              count != null ? '$label ($count)' : label,
              style: GoogleFonts.rubik(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Friend bubble - AVATAR NHỎ
  Widget _buildFriendBubble(Users friend) {
    final friendId = friend.uid ?? '';
    if (friendId.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final isSelected = _selectedFriendIds.contains(friendId);
    final hasProfileUrl = friend.profileUrl != null && friend.profileUrl!.isNotEmpty;
    final initials = _getInitials(friend.name ?? '');

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFriendIds.remove(friendId);
          } else {
            _selectedFriendIds.add(friendId);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: hasProfileUrl ? null : Colors.grey.shade700,
                  backgroundImage: hasProfileUrl ? NetworkImage(friend.profileUrl!) : null,
                  child: !hasProfileUrl
                      ? Text(
                          initials,
                          style: GoogleFonts.rubik(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D0D0E), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 48,
              child: Text(
                friend.name?.split(' ').first ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  fontSize: 10,
                  color: isSelected ? primaryColor : Colors.white.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}


