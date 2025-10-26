import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/globals.dart' as g; 
import '/screens/screens.dart';
import '/model/firestore.dart';
import '../../utils/colors.dart';

class CustomChat extends StatelessWidget {
  const CustomChat({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfileUrl,
    this.lastMessage,
    this.lastMessageTime, // ✅ THÊM
  });

  final String receiverId;
  final String receiverName;
  final String receiverProfileUrl;
  final String? lastMessage; // ✅ THÊM
  final Timestamp? lastMessageTime; // ✅ THÊM

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(
        () => ChatPreview(
          receiverId: receiverId,
          receiverName: receiverName,
          receiverProfileUrl: receiverProfileUrl,
        ),
        popGesture: false,
        transition: Transition.rightToLeftWithFade,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: secondaryColor,
                  child: Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor,
                  backgroundImage: receiverProfileUrl.isNotEmpty
                      ? NetworkImage(receiverProfileUrl)
                      : null,
                  child: receiverProfileUrl.isEmpty
                      ? Text(
                          receiverName.isNotEmpty ? receiverName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(
                height: 50,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        receiverName,
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        lastMessage ?? "No replies yet!", // ✅ HIỂN THỊ TIN NHẮN CUỐI
                        style: TextStyle(
                          fontSize: 16,
                          color: termsText,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: termsText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatsList extends StatefulWidget {
  const ChatsList({super.key});

  @override
  State<ChatsList> createState() => _ChatsListState();
}

class _ChatsListState extends State<ChatsList> {
  final double _swipeVelocityThreshold = 100.0;
  double _dragDistance = 0.0;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final currentUid = g.userStorage.read('uid');
    
    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Messages",
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            )
          ],
        ),
        body: Center(
          child: Text('Not logged in', style: GoogleFonts.rubik(color: Colors.white)),
        ),
      );
    }

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
          Navigator.pop(context);
        }
        _dragDistance = 0.0;
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Messages",
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            )
          ],
        ),
        
        // ✅ DÙNG STREAMBUILDER ĐỂ TỰ ĐỘNG CẬP NHẬT
        body: StreamBuilder<QuerySnapshot>(
          stream: g.firestore
              .collection('chats')
              .where('participants', arrayContains: currentUid)
              .orderBy('lastMessageTime', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }

            // Error
            if (snapshot.hasError) {
              print('❌ Chat stream error: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 60, color: Colors.red),
                    SizedBox(height: 20),
                    Text(
                      'Error loading chats',
                      style: GoogleFonts.rubik(fontSize: 18, color: termsText),
                    ),
                  ],
                ),
              );
            }

            // Empty
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 60, color: termsText),
                    const SizedBox(height: 20),
                    Text(
                      'No messages yet',
                      style: GoogleFonts.rubik(fontSize: 18, color: termsText),
                    ),
                  ],
                ),
              );
            }

            // ✅ HIỂN THỊ DANH SÁCH CHAT
            final chatDocs = snapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView.builder(
                itemCount: chatDocs.length,
                itemBuilder: (context, index) {
                  final chatData = chatDocs[index].data() as Map<String, dynamic>;
                  final participants = List<String>.from(chatData['participants'] ?? []);
                  
                  final otherUserId = participants.firstWhere(
                    (id) => id != currentUid,
                    orElse: () => '',
                  );

                  if (otherUserId.isEmpty) {
                    return SizedBox.shrink();
                  }

                  // ✅ LOAD THÔNG TIN USER
                  return FutureBuilder<DocumentSnapshot>(
                    future: g.firestore.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      
                      return CustomChat(
                        receiverId: otherUserId,
                        receiverName: userData?['name'] ?? userData?['phoneNumber'] ?? 'Unknown',
                        receiverProfileUrl: userData?['profileUrl'] ?? '',
                        lastMessage: chatData['lastMessage'], // ✅ TRUYỀN LASTMESSAGE
                        lastMessageTime: chatData['lastMessageTime'], // ✅ TRUYỀN TIME
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
