import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '/globals.dart' as g;
import '../../utils/colors.dart';
import '../../utils/name_utils.dart';

// ✅ WIDGET TIN NHẮN BUBBLE - HỖ TRỢ IMAGE REPLY
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isSentByMe;
  final Timestamp? timestamp;
  final String? messageType;
  final String? imageUrl;
  final String? imageCaption;
  final String? imageUploadTime;
  final String? senderName;
  final String? senderAvatarUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSentByMe,
    this.timestamp,
    this.messageType,
    this.imageUrl,
    this.imageCaption,
    this.imageUploadTime,
    this.senderName,
    this.senderAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isImageReply = messageType == 'image_reply';

    if (isImageReply && imageUrl != null && imageUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Khung avatar-tên-thời gian đè lên góc trên ảnh, tự scale
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.50),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      senderAvatarUrl != null && senderAvatarUrl!.isNotEmpty
                          ? CircleAvatar(
                              radius: 13,
                              backgroundImage: CachedNetworkImageProvider(senderAvatarUrl!),
                              backgroundColor: secondaryColor,
                            )
                          : CircleAvatar(
                              radius: 13,
                              backgroundColor: secondaryColor,
                              child: Text(
                                (senderName ?? "A")[0].toUpperCase(),
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                              ),
                            ),
                      const SizedBox(width: 7),
                      Text(
                        senderName ?? (isSentByMe ? "Bạn" : "Bạn bè"),
                        style: GoogleFonts.rubik(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        imageUploadTime != null && imageUploadTime!.isNotEmpty
                            ? _formatUploadTime(imageUploadTime!)
                            : "",
                        style: GoogleFonts.rubik(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Caption đè lên ảnh, tự scale
              if (imageCaption != null && imageCaption!.isNotEmpty)
                Positioned(
                  bottom: 18,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      imageCaption!,
                      style: GoogleFonts.rubik(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          // Bubble reply riêng biệt
          Align(
            alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isSentByMe ? Colors.white : const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isSentByMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isSentByMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.rubik(
                      fontSize: 15,
                      color: isSentByMe ? Colors.black : Colors.white,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(timestamp!),
                      style: GoogleFonts.rubik(
                        fontSize: 11,
                        color: isSentByMe ? Colors.black45 : Colors.white54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Tin nhắn thường
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSentByMe ? Colors.white : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isSentByMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isSentByMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.rubik(
                fontSize: 15,
                color: isSentByMe ? Colors.black : Colors.white,
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(timestamp!),
                style: GoogleFonts.rubik(
                  fontSize: 11,
                  color: isSentByMe ? Colors.black45 : Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatUploadTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 3) return 'Mới đây';
      if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
      if (diff.inHours < 24) return '${diff.inHours}h trước';
      if (diff.inDays == 1) return 'Hôm qua';
      if (diff.inDays < 7) return '${diff.inDays} ngày trước';
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return 'Không rõ';
    }
  }
}

// ✅ WIDGET HEADER NGÀY
class DateHeader extends StatelessWidget {
  final DateTime date;

  const DateHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    String label;
    if (difference == 0) {
      label = 'Hôm nay';
    } else if (difference == 1) {
      label = 'Hôm qua';
    } else if (difference < 7) {
      final weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
      label = weekdays[date.weekday - 1];
    } else {
      label = '${date.day}/${date.month}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white24, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: GoogleFonts.rubik(
                fontSize: 13,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white24, thickness: 0.5)),
        ],
      ),
    );
  }
}

class ChatPreview extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverProfileUrl;

  const ChatPreview({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfileUrl,
  });

  @override
  State<ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<ChatPreview> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final double _swipeVelocityThreshold = 100.0;
  double _dragDistance = 0.0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _chatId {
    final currentUid = g.userStorage.read('uid') ?? '';
    final ids = [currentUid, widget.receiverId]..sort();
    return ids.join('_');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUid = g.userStorage.read('uid');
    if (currentUid == null) {
      Get.snackbar('❌ Lỗi', 'Bạn chưa đăng nhập', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      final chatRef = g.firestore.collection('chats').doc(_chatId);

      await chatRef.set({
        'participants': [currentUid, widget.receiverId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
        'lastSenderId': currentUid,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': currentUid,
        'receiverId': widget.receiverId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      });

      _messageController.clear();
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      print('❌ Send message error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Không thể gửi tin nhắn: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.85),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = g.userStorage.read('uid');
    Size size = MediaQuery.of(context).size;
    final bool hasProfileUrl = widget.receiverProfileUrl.isNotEmpty &&
        Uri.tryParse(widget.receiverProfileUrl)?.hasAbsolutePath == true;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.primaryDelta! > 0) {
          _dragDistance += details.primaryDelta!;
        } else {
          _dragDistance = 0.0;
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragDistance >= size.width / 4 &&
            details.primaryVelocity!.abs() > _swipeVelocityThreshold &&
            details.primaryVelocity! > 0) {
          Get.back();
        }
        _dragDistance = 0.0;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: secondaryColor,
                backgroundImage: hasProfileUrl
                    ? CachedNetworkImageProvider(widget.receiverProfileUrl)
                    : null,
                child: !hasProfileUrl
                    ? Text(
                        safeInitials(widget.receiverName),
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.receiverName,
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ✅ DANH SÁCH TIN NHẮN VỚI DATE HEADERS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: g.firestore
                    .collection('chats')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  if (snapshot.hasError) {
                    print('❌ Messages stream error: ${snapshot.error}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 60, color: Colors.red),
                          const SizedBox(height: 20),
                          Text(
                            'Error loading messages',
                            style: GoogleFonts.rubik(color: termsText),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 58,
                                backgroundColor: secondaryColor,
                                child: Container(
                                  height: 108,
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: secondaryColor,
                                backgroundImage: hasProfileUrl
                                    ? CachedNetworkImageProvider(widget.receiverProfileUrl)
                                    : null,
                                child: !hasProfileUrl
                                    ? Text(
                                        safeInitials(widget.receiverName),
                                        style: const TextStyle(fontSize: 28),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Start the convo!",
                            style: GoogleFonts.rubik(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "Say hi to ${widget.receiverName}",
                              style: GoogleFonts.rubik(
                                fontSize: 16,
                                color: termsText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  // ✅ Auto scroll sau khi build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

final String currentUserId = g.userStorage.read('uid') ?? '';

                  // ✅ NHÓM TIN NHẮN THEO NGÀY
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageData = messages[index].data() as Map<String, dynamic>;
                      final isSentByMe = messageData['senderId'] == currentUid;
                      final message = messageData['message'] ?? '';
                      final timestamp = messageData['timestamp'] as Timestamp?;

                      // ✅ HIỂN THỊ DATE HEADER NẾU LÀ TIN NHẮN ĐẦU TIÊN TRONG NGÀY
                      Widget? dateHeader;
                      if (timestamp != null) {
                        final currentDate = timestamp.toDate();
                        final currentDateKey = DateFormat('yyyy-MM-dd').format(currentDate);
                        
                        // Kiểm tra xem có phải tin nhắn đầu tiên trong ngày không
                        bool shouldShowDate = false;
                        if (index == 0) {
                          shouldShowDate = true;
                        } else {
                          final prevMessageData = messages[index - 1].data() as Map<String, dynamic>;
                          final prevTimestamp = prevMessageData['timestamp'] as Timestamp?;
                          if (prevTimestamp != null) {
                            final prevDate = prevTimestamp.toDate();
                            final prevDateKey = DateFormat('yyyy-MM-dd').format(prevDate);
                            if (currentDateKey != prevDateKey) {
                              shouldShowDate = true;
                            }
                          }
                        }

                        if (shouldShowDate) {
                          dateHeader = DateHeader(date: currentDate);
                        }
                      }

                      return Column(
                        children: [
                          if (dateHeader != null) dateHeader,
                          // ✅ TRUYỀN ĐẦY ĐỦ METADATA
                          MessageBubble(
                            message: messageData['message'] ?? '',
                            isSentByMe: messageData['senderId'] == currentUserId,
                            timestamp: messageData['timestamp'],
                            messageType: messageData['type'],
                            imageUrl: messageData['imageUrl'],
                            imageCaption: messageData['imageCaption'],
                            imageUploadTime: messageData['imageUploadTime'],
                            senderName: messageData['ownerName'],        // ✅ tên người đăng ảnh
                            senderAvatarUrl: messageData['ownerAvatarUrl'], // ✅ avatar người đăng ảnh
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ✅ THANH NHẬP TIN NHẮN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.3),
                border: const Border(
                  top: BorderSide(color: Color(0xFF666666)),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.rubik(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.rubik(color: termsText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: backgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
