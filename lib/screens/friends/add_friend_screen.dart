import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/utils/colors.dart';
import '/utils/phone_helper.dart';
import '/services/friend_service.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoadingContacts = false;
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _friendService = FriendService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContactSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===== ĐỌC DANH BẠ VÀ TÌM SUGGESTIONS =====
  Future<void> _loadContactSuggestions() async {
    setState(() => _isLoadingContacts = true);

    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        Get.snackbar(
          '⚠️ Cần quyền',
          'Vui lòng cấp quyền truy cập danh bạ để tìm bạn bè',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        setState(() => _isLoadingContacts = false);
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final phoneNumbers = <String>{};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          final normalized = PhoneHelper.normalize(phone.number);
          if (normalized.isNotEmpty && normalized.startsWith('+84')) {
            phoneNumbers.add(normalized);
          }
        }
      }

      if (phoneNumbers.isEmpty) {
        setState(() => _isLoadingContacts = false);
        return;
      }

      final currentUid = _auth.currentUser!.uid;
      final friendIds = await _friendService.getFriendIds();

      final suggestions = <Map<String, dynamic>>[];
      final phoneList = phoneNumbers.toList();

      for (var i = 0; i < phoneList.length; i += 10) {
        final batch = phoneList.skip(i).take(10).toList();
        
        final querySnapshot = await _firestore
            .collection('users')
            .where('phoneNumber', whereIn: batch)
            .get();

        for (var doc in querySnapshot.docs) {
          final uid = doc.id;
          
          if (uid == currentUid || friendIds.contains(uid)) continue;

          final status = await _friendService.getRequestStatus(uid);
          if (status == 'sent') continue;

          suggestions.add({
            'uid': uid,
            'name': doc.data()['name'] ?? 'User',
            'phoneNumber': doc.data()['phoneNumber'] ?? '',
            'profileUrl': doc.data()['profileUrl'] ?? '',
          });
        }
      }

      setState(() {
        _suggestions = suggestions;
        _isLoadingContacts = false;
      });

    } catch (e) {
      print('❌ Error loading contacts: $e');
      setState(() => _isLoadingContacts = false);
      Get.snackbar(
        '❌ Lỗi',
        'Không thể đọc danh bạ. Vui lòng thử lại.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  // ===== TÌM KIẾM BẰNG SĐT =====
  Future<void> _searchByPhone() async {
    final phoneInput = _searchController.text.trim();
    if (phoneInput.isEmpty) {
      Get.snackbar(
        '⚠️ Thông báo',
        'Vui lòng nhập số điện thoại',
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResult = null;
    });

    try {
      final normalized = PhoneHelper.normalize(phoneInput);
      final currentUid = _auth.currentUser!.uid;
      
      // ✅ FIX: Nhận Map thay vì Users
      final user = await _friendService.findUserByPhone(normalized);

      if (user == null) {
        Get.snackbar(
          '❌ Không tìm thấy',
          'Số điện thoại "$phoneInput" chưa đăng ký BubbleCam',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        setState(() => _isSearching = false);
        return;
      }

      // ✅ FIX: Lấy uid trực tiếp từ Map
      final userUid = user['uid'] as String;
      
      if (userUid == currentUid) {
        Get.snackbar(
          '⚠️ Thông báo',
          'Đây là số điện thoại của bạn',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
        setState(() => _isSearching = false);
        return;
      }

      if (await _friendService.isFriend(userUid)) {
        Get.snackbar(
          '✅ Thông báo',
          'Bạn đã là bạn bè với người này rồi',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        setState(() => _isSearching = false);
        return;
      }

      // ✅ FIX: Sử dụng Map đã có
      setState(() {
        _searchResult = user;
        _isSearching = false;
      });

    } catch (e) {
      print('❌ Search error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Không thể tìm kiếm. Vui lòng thử lại.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      setState(() => _isSearching = false);
    }
  }

  // ===== GỬI LỜI MỜI KẾT BẠN =====
  Future<void> _sendFriendRequest(String friendUid) async {
    final success = await _friendService.sendFriendRequest(friendUid);

    if (success) {
      Get.snackbar(
        '✅ Thành công',
        'Đã gửi lời mời kết bạn',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      
      _loadContactSuggestions();
      setState(() {
        _searchResult = null;
        _searchController.clear();
      });
    } else {
      Get.snackbar(
        '❌ Lỗi',
        'Không thể gửi lời mời. Vui lòng thử lại.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  // ===== MỞ APP KHÁC =====
  Future<void> _openApp(String app) async {
    Uri? uri;
    String appName = '';
    
    switch (app) {
      case 'messenger':
        uri = Uri.parse('fb-messenger://');
        appName = 'Messenger';
        break;
      case 'zalo':
        uri = Uri.parse('zalo://');
        appName = 'Zalo';
        break;
      case 'instagram':
        uri = Uri.parse('instagram://');
        appName = 'Instagram';
        break;
    }

    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          Get.snackbar(
            '⚠️ Thông báo',
            'Bạn chưa cài đặt $appName',
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      } catch (e) {
        print('❌ Error opening app: $e');
        Get.snackbar(
          '❌ Lỗi',
          'Không thể mở $appName',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Tìm bạn bè',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.rubik(color: Colors.white),
                  onSubmitted: (_) => _searchByPhone(),
                  decoration: InputDecoration(
                    hintText: 'Nhập số điện thoại ',
                    hintStyle: GoogleFonts.rubik(color: Colors.white54, fontSize: 14),
                    filled: true,
                    fillColor: secondaryColor,
                    prefixIcon: const Icon(Iconsax.search_normal, color: primaryColor),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Iconsax.search_normal, color: primaryColor),
                            onPressed: _searchByPhone,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.rubik(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: const [
                  Tab(text: 'Các đề xuất'),
                  Tab(text: 'Từ ứng dụng khác'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuggestionsTab(),
          _buildOtherAppsTab(),
        ],
      ),
    );
  }

  // ===== TAB ĐỀ XUẤT =====
  Widget _buildSuggestionsTab() {
    return Column(
      children: [
        // Kết quả tìm kiếm
        if (_searchResult != null)
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết quả tìm kiếm',
                  style: GoogleFonts.rubik(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                _buildUserTile(_searchResult!),
              ],
            ),
          ),

        // Danh sách đề xuất
        Expanded(
          child: _isLoadingContacts
              ? const Center(child: CircularProgressIndicator(color: primaryColor))
              : _suggestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.people, size: 80, color: Colors.white24),
                          const SizedBox(height: 20),
                          Text(
                            'Không có đề xuất',
                            style: GoogleFonts.rubik(
                              fontSize: 18,
                              color: Colors.white54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Mời bạn bè tải BubbleCam để kết nối',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Text(
                            'Người bạn có thể biết (${_suggestions.length})',
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final user = _suggestions[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildUserTile(user),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ===== TAB ỨNG DỤNG KHÁC =====
  Widget _buildOtherAppsTab() {
    final apps = [
      {
        'name': 'Messenger',
        'icon': 'assets/images/messenger_icon.png', // ✅ SỬA
        'color': const Color(0xFF0084FF),
        'key': 'messenger',
        'description': 'Tìm bạn bè từ Facebook Messenger',
      },
      {
        'name': 'Zalo',
        'icon': 'assets/images/zalo_icon.png', // ✅ SỬA
        'color': const Color(0xFF0068FF),
        'key': 'zalo',
        'description': 'Tìm bạn bè từ Zalo',
      },
      {
        'name': 'Instagram',
        'icon': 'assets/images/instagram_icon.png', // ✅ SỬA
        'color': const Color(0xFFE1306C),
        'key': 'instagram',
        'description': 'Tìm bạn bè từ Instagram',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tìm bạn bè từ các ứng dụng khác',
          style: GoogleFonts.rubik(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Kết nối với bạn bè từ các mạng xã hội khác',
          style: GoogleFonts.rubik(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 20),
        ...apps.map((app) => Container(
          margin: const EdgeInsets.only(bottom: 15),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: app['color'] as Color,
              // ✅ SỬA: Dùng Image.asset
              child: ClipOval(
                child: Image.asset(
                  app['icon'] as String,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      app['name'].toString()[0],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            title: Text(
              app['name'] as String,
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              app['description'] as String,
              style: GoogleFonts.rubik(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            trailing: ElevatedButton(
              onPressed: () => _openApp(app['key'] as String),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Mở',
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            tileColor: secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        )),
      ],
    );
  }

  // ===== WIDGET USER TILE =====
  Widget _buildUserTile(Map<String, dynamic> user) {
    final hasProfileUrl = user['profileUrl'] != null && user['profileUrl'].toString().isNotEmpty;
    final userName = user['name'] ?? 'User';
    final initials = _getInitials(userName);

    return FutureBuilder<String?>(
      future: _friendService.getRequestStatus(user['uid']),
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data;
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: hasProfileUrl ? null : Colors.grey.shade700,
            backgroundImage: hasProfileUrl ? NetworkImage(user['profileUrl']) : null,
            child: !hasProfileUrl
                ? Text(
                    initials,
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          title: Text(
            userName,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            status == 'sent' ? 'Đã gửi lời mời' : 'Đã có trên BubbleCam 💛',
            style: GoogleFonts.rubik(
              color: status == 'sent' ? Colors.orange : Colors.white54,
              fontSize: 13,
              fontStyle: status == 'sent' ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          trailing: status == 'sent'
              ? TextButton(
                  onPressed: () async {
                    final success = await _friendService.cancelFriendRequest(user['uid']);
                    if (success) {
                      Get.snackbar(
                        'Đã hủy',
                        'Lời mời đã được hủy',
                        backgroundColor: Colors.orange,
                        colorText: white,
                      );
                      _loadContactSuggestions();
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Hủy',
                    style: GoogleFonts.rubik(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _sendFriendRequest(user['uid']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        'Thêm',
                        style: GoogleFonts.rubik(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
          tileColor: secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // ===== HELPER: LẤY CHỮ CÁI ĐẦU =====
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}