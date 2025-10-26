import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '/model/firestore.dart';
import '/services/friend_service.dart';
import '/utils/colors.dart';
import 'add_friend_screen.dart';
import 'friend_requests_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({Key? key}) : super(key: key);

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FriendService _friendService = FriendService();
  List<Users> _friends = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadPendingCount();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final friends = await _friendService.getFriends();
    setState(() {
      _friends = friends;
      _isLoading = false;
    });
  }

  Future<void> _loadPendingCount() async {
    final count = await _friendService.getPendingRequestsCount();
    setState(() => _pendingCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Bạn bè (${_friends.length})',
          style: GoogleFonts.rubik(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: white,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Nút thông báo lời mời
          Stack(
            children: [
              IconButton(
                icon: const Icon(Iconsax.notification, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FriendRequestsScreen(),
                    ),
                  );
                  _loadPendingCount();
                  _loadFriends();
                },
              ),
              if (_pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        '$_pendingCount',
                        style: GoogleFonts.rubik(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFriends,
                  child: ListView.builder(
                    itemCount: _friends.length,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemBuilder: (context, index) {
                      return _buildFriendTile(_friends[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddFriendScreen()),
          );
          _loadFriends();
        },
        backgroundColor: primaryColor,
        icon: const Icon(Iconsax.user_add, color: Colors.black),
        label: Text(
          'Thêm bạn',
          style: GoogleFonts.rubik(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.people, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            'Chưa có bạn bè nào',
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hãy thêm bạn bè để bắt đầu',
            style: GoogleFonts.rubik(
              fontSize: 14,
              color: termsText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Users friend) {
    final hasProfileUrl =
        friend.profileUrl != null && friend.profileUrl!.isNotEmpty;
    final initials = _getInitials(friend.name ?? '');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: hasProfileUrl ? null : Colors.grey.shade700,
          backgroundImage:
              hasProfileUrl ? NetworkImage(friend.profileUrl!) : null,
          child: !hasProfileUrl
              ? Text(
                  initials,
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                )
              : null,
        ),
        title: Text(
          friend.name ?? '',
          style: GoogleFonts.rubik(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          friend.phoneNumber ?? '',
          style: GoogleFonts.rubik(
            fontSize: 13,
            color: termsText,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: backgroundColor,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  const Icon(Iconsax.user_remove, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Xóa bạn bè',
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'remove') {
              _showRemoveDialog(friend);
            }
          },
        ),
      ),
    );
  }

  void _showRemoveDialog(Users friend) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // ✅ Đổi tên context
        backgroundColor: backgroundColor,
        title: Text(
          'Xác nhận',
          style: GoogleFonts.rubik(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: white,
          ),
        ),
        content: Text(
          'Xóa ${friend.name} khỏi danh sách bạn bè?',
          style: GoogleFonts.rubik(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // ✅ Dùng dialogContext
            child: Text(
              'Hủy',
              style: GoogleFonts.rubik(color: termsText),
            ),
          ),
          TextButton(
            onPressed: () async {
              // ✅ FIX: Đóng dialog TRƯỚC khi xử lý
              Navigator.pop(dialogContext);
              
              // ✅ Kiểm tra uid
              final friendUid = friend.uid;
              
              if (friendUid == null || friendUid.isEmpty) {
                Get.snackbar(
                  '❌ Lỗi',
                  'Không tìm thấy thông tin bạn bè',
                  backgroundColor: Colors.red,
                  colorText: white,
                );
                return;
              }

              // ✅ Show loading RIÊNG BIỆT (không dùng dialog context)
              if (!mounted) return;
              
              // Dùng Get.dialog thay vì showDialog
              Get.dialog(
                const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
                barrierDismissible: false,
              );

              // ✅ Xóa bạn
              final success = await _friendService.removeFriend(friendUid);

              // ✅ Đóng loading
              if (Get.isDialogOpen ?? false) {
                Get.back();
              }

              // ✅ Hiển thị kết quả
              if (mounted) {
                if (success) {
                  Get.snackbar(
                    '✅ Thành công',
                    'Đã xóa bạn bè',
                    backgroundColor: Colors.green,
                    colorText: white,
                  );
                  _loadFriends(); // Reload danh sách
                } else {
                  Get.snackbar(
                    '❌ Lỗi',
                    'Không thể xóa bạn bè',
                    backgroundColor: Colors.red,
                    colorText: white,
                  );
                }
              }
            },
            child: Text(
              'Xóa',
              style: GoogleFonts.rubik(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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