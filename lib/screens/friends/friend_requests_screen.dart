import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '/model/firestore.dart';
import '/services/friend_service.dart';
import '/utils/colors.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Lời mời kết bạn',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.rubik(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Nhận được'),
            Tab(text: 'Đã gửi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(),
          _buildSentTab(),
        ],
      ),
    );
  }

  // ===== TAB NHẬN ĐƯỢC =====
  Widget _buildReceivedTab() {
    return StreamBuilder<List<FriendRequests>>(
      stream: _friendService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('Không có lời mời nào', Iconsax.user_add);
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return ReceivedRequestTile(request: snapshot.data![index]);
          },
        );
      },
    );
  }

  // ✅ TAB ĐÃ GỬI (MỚI)
  Widget _buildSentTab() {
    return StreamBuilder<List<FriendRequests>>(
      stream: _friendService.getSentRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState('Chưa gửi lời mời nào', Iconsax.user_search);
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return SentRequestTile(request: snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== WIDGET: REQUEST NHẬN ĐƯỢC =====
class ReceivedRequestTile extends StatefulWidget {
  final FriendRequests request;

  const ReceivedRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  State<ReceivedRequestTile> createState() => _ReceivedRequestTileState();
}

class _ReceivedRequestTileState extends State<ReceivedRequestTile> {
  final FriendService _friendService = FriendService();
  bool _isLoading = false;

  Future<void> _accept() async {
    setState(() => _isLoading = true);

    final success = await _friendService.acceptFriendRequest(
      widget.request.id ?? '',
      widget.request.senderId ?? '',
    );

    if (success && mounted) {
      Get.snackbar(
        'Thành công',
        'Đã chấp nhận lời mời',
        backgroundColor: Colors.green,
        colorText: white,
      );
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);

    final success =
        await _friendService.rejectFriendRequest(widget.request.id ?? '');

    if (success && mounted) {
      Get.snackbar(
        'Đã từ chối',
        'Lời mời đã bị từ chối',
        backgroundColor: Colors.orange,
        colorText: white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Users?>(
      future: _friendService.getUserById(widget.request.senderId ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final hasProfileUrl =
            user.profileUrl != null && user.profileUrl!.isNotEmpty;
        final initials = _getInitials(user.name ?? '');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: hasProfileUrl ? null : Colors.grey.shade700,
              backgroundImage:
                  hasProfileUrl ? NetworkImage(user.profileUrl!) : null,
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
              user.name ?? '',
              style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: white,
              ),
            ),
            subtitle: Text(
              user.phoneNumber ?? '',
              style: GoogleFonts.rubik(
                fontSize: 13,
                color: termsText,
              ),
            ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Iconsax.tick_circle,
                            color: Colors.green, size: 28),
                        onPressed: _accept,
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.close_circle,
                            color: Colors.red, size: 28),
                        onPressed: _reject,
                      ),
                    ],
                  ),
          ),
        );
      },
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

// ✅ WIDGET MỚI: REQUEST ĐÃ GỬI
class SentRequestTile extends StatefulWidget {
  final FriendRequests request;

  const SentRequestTile({Key? key, required this.request}) : super(key: key);

  @override
  State<SentRequestTile> createState() => _SentRequestTileState();
}

class _SentRequestTileState extends State<SentRequestTile> {
  final FriendService _friendService = FriendService();
  bool _isLoading = false;

  Future<void> _cancel() async {
    setState(() => _isLoading = true);

    final success =
        await _friendService.cancelFriendRequest(widget.request.receiverId ?? '');

    if (success && mounted) {
      Get.snackbar(
        'Đã hủy',
        'Lời mời đã được hủy',
        backgroundColor: Colors.orange,
        colorText: white,
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Users?>(
      future: _friendService.getUserById(widget.request.receiverId ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final hasProfileUrl =
            user.profileUrl != null && user.profileUrl!.isNotEmpty;
        final initials = _getInitials(user.name ?? '');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: hasProfileUrl ? null : Colors.grey.shade700,
              backgroundImage:
                  hasProfileUrl ? NetworkImage(user.profileUrl!) : null,
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
              user.name ?? '',
              style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: white,
              ),
            ),
            subtitle: Text(
              'Đang chờ phản hồi...',
              style: GoogleFonts.rubik(
                fontSize: 13,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _cancel,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Hủy',
                      style: GoogleFonts.rubik(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}