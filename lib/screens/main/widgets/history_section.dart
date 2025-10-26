import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lit_relative_date_time/lit_relative_date_time.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '/globals.dart' as g;
import '/model/firestore.dart';
import '/screens/chats/chat_preview.dart';
import '/utils/colors.dart';
import '/utils/name_utils.dart';
import 'post_screen.dart';

typedef RelativeDateFormatBuilder = RelativeDateFormat Function(BuildContext context);

// ========================= HELPER: Format thời gian tiếng Việt =========================
String _formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return 'Mới đây';
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 3) return 'Mới đây';
  if (diff.inMinutes < 60) return '${diff.inMinutes}p';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}ng';

  final weeks = (diff.inDays / 7).floor();
  if (diff.inDays < 30) return '${weeks}t';

  final months = (diff.inDays / 30).floor();
  if (diff.inDays < 365) return '${months}th';

  final years = (diff.inDays / 365).floor();
  return '${years}n';
}

DateTime? _resolveDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

// ========================= EMOJI LIST =========================
const List<String> _emojiList = [
  '😀','😃','😄','😁','😆','🥹','😂','🤣','😊','🙂','😉','😍','🥰','😘','😗','😚','😙','😋','😜','🤪','😝','🤗','🤭','🤫','🤔','🤐','😴','🥱','😪','😮','😯','😲','🤯','😳','🥵','🥶','😱','😭','😤','😡','😔','😞','😟','😕','🙁','☹️','😣','😖','😓','😩','😫','😮‍💨','😵','🤒','🤕','🤧','🤮',
  '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💖','💗','💓','💞','💕','💘','💝','💟',
  '👍','👎','👏','🙌','🙏','🤝','🤙','👌','✌️','🤟','🤘','💪','👋','🫶','🫰','👉','👈','☝️','👇',
  '🔥','✨','🎉','💯','⚡','🌟','⭐','🌈','☀️','🌙'
];

// ========================= SCREEN SECTION =========================
class HistorySection extends StatefulWidget {
  const HistorySection({
    super.key,
    required this.size,
    required this.imageItems,
    required this.pageController,
    required this.onPageChanged,
    required this.profilePicUrl,
    required this.userName,
    required this.currentUid,
    required this.onReplyTap,
    required this.onJumpToCamera,
    required this.relativeDateTimeBuilder,
    required this.friendsList,
    required this.onFilterChanged,
    this.onDeleteTap, // <-- added optional async delete callback
  });

  final Size size;
  final List<Images> imageItems;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final String profilePicUrl;
  final String userName;
  final String currentUid;
  final VoidCallback onReplyTap;
  final VoidCallback onJumpToCamera;
  final RelativeDateFormatBuilder relativeDateTimeBuilder;
  final List<Users> friendsList;
  final ValueChanged<String?> onFilterChanged;
  final Future<void> Function()? onDeleteTap; // <-- added

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  final List<FloatingEmoji> _floatingEmojis = [];
  final _random = Random();
  int _emojiIdCounter = 0;

  bool _isShaking = false;
  Timer? _shakeTimer;
  Timer? _emojiSpamTimer;
  final ValueNotifier<int> _shakeTick = ValueNotifier<int>(0);

  void _addFloatingEmoji(String emoji) {
    final count = 3 + _random.nextInt(2);
    
    for (int i = 0; i < count; i++) {
      final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${_emojiIdCounter++}';
      
      setState(() {
        _floatingEmojis.add(FloatingEmoji(
          emoji: emoji,
          startX: 50 + _random.nextDouble() * (widget.size.width - 100),
          id: uniqueId,
          delay: i * 100,
        ));
      });

      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) {
          setState(() {
            _floatingEmojis.removeWhere((e) => e.id == uniqueId);
          });
        }
      });
    }
  }

  void _startShakeAndSpamEmoji(String emoji) {
    if (_shakeTimer != null) return;
    setState(() => _isShaking = true);

    // Rung UI liên tục
    _shakeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      _shakeTick.value++; // trigger shake
    });

    // Spam emoji bay liên tục
    _emojiSpamTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      _addFloatingEmoji(emoji);
    });
  }

  void _stopShakeAndSpamEmoji() {
    _shakeTimer?.cancel();
    _shakeTimer = null;
    _emojiSpamTimer?.cancel();
    _emojiSpamTimer = null;
    setState(() => _isShaking = false);
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _emojiSpamTimer?.cancel();
    _shakeTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RelativeDateFormat relativeFormat = widget.relativeDateTimeBuilder(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    Widget content = Column(
      children: [
        Expanded(
          child: widget.imageItems.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 80, color: Colors.white30),
                        const SizedBox(height: 20),
                        Text(
                          'Chưa có ảnh nào',
                          style: GoogleFonts.inter(fontSize: 18, color: Colors.white60),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: widget.onJumpToCamera,
                          icon: const Icon(Iconsax.camera, color: primaryColor),
                          label: Text(
                            'Chụp ảnh ngay',
                            style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : PageView.builder(
                  controller: widget.pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: widget.onPageChanged,
                  itemCount: widget.imageItems.length,
                  itemBuilder: (context, index) {
                    final image = widget.imageItems[index];
                    return _HistoryItem(
                      size: widget.size,
                      image: image,
                      profilePicUrl: image.ownerAvatar ?? widget.profilePicUrl,
                      userName: image.ownerName ?? widget.userName,
                      currentUid: widget.currentUid,
                      relativeFormat: relativeFormat,
                    );
                  },
                ),
        ),
      ],
    );

    return Stack(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _shakeTick,
          builder: (context, _, child) {
            final shakeOffset = _isShaking
                ? Offset(8 * sin(DateTime.now().millisecondsSinceEpoch / 40), 0)
                : Offset.zero;
            return Transform.translate(
              offset: shakeOffset,
              child: child,
            );
          },
          child: content,
        ),
        // Message bar popup lên trên footer
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset == 0 ? 120: bottomInset, // cách footer 70 hoặc sát bàn phím
          child: _MessageBar(
            currentImage: widget.imageItems.isNotEmpty
                ? widget.imageItems[widget.pageController.hasClients && widget.pageController.page != null
                    ? widget.pageController.page!.round()
                    : 0]
                : null,
            currentUid: widget.currentUid,
            onEmojiSent: _addFloatingEmoji,
            profilePicUrl: widget.profilePicUrl,
            userName: widget.userName,
            onEmojiLongPress: _startShakeAndSpamEmoji,
            onEmojiLongPressEnd: _stopShakeAndSpamEmoji,
          ),
        ),
        // Footer luôn ở dưới cùng, ẩn khi bàn phím hiện
        if (bottomInset == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _HistoryFooter(
              onJumpToCamera: widget.onJumpToCamera,
              onGridTap: () {
                Get.to(() => PostScreen(imageItems: widget.imageItems, currentUid: widget.currentUid));
              },
              onDownloadTap: () async {
                final currentIndex = widget.pageController.hasClients && widget.pageController.page != null
                    ? widget.pageController.page!.round()
                    : 0;
                final currentImage = widget.imageItems.isNotEmpty && currentIndex < widget.imageItems.length
                    ? widget.imageItems[currentIndex]
                    : null;
                if (currentImage?.url == null) return;
                try {
                  await _BottomSection._saveImage(currentImage!.url!);
                  Get.snackbar(
                    '✅ Đã lưu',
                    'Ảnh đã được lưu vào thư viện',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.8),
                    colorText: white,
                  );
                } catch (e) {
                  Get.snackbar(
                    '❌ Lỗi',
                    'Không thể lưu ảnh',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.8),
                    colorText: white,
                  );
                }
              },
              // forward async delete callback or provide a safe default that deletes the current image
              onDeleteTap: widget.onDeleteTap ?? () async {
                final currentIndex = widget.pageController.hasClients && widget.pageController.page != null
                    ? widget.pageController.page!.round()
                    : 0;
                final currentImage = widget.imageItems.isNotEmpty && currentIndex < widget.imageItems.length
                    ? widget.imageItems[currentIndex]
                    : null;
                if (currentImage == null || currentImage.id == null) return;
                try {
                  final imageId = currentImage.id!;
                  // 1) delete reactions subcollection documents (if any)
                  final reactionsRef = g.firestore.collection('images').doc(imageId).collection('reactions');
                  final reactionsSnap = await reactionsRef.get();
                  for (final doc in reactionsSnap.docs) {
                    await doc.reference.delete();
                  }

                  // 2) delete storage file (best-effort)
                  final url = currentImage.url ?? '';
                  if (url.isNotEmpty) {
                    try {
                      await FirebaseStorage.instance.refFromURL(url).delete();
                    } catch (e) {
                      print('⚠️ Storage delete warning: $e');
                      // continue even if storage deletion fails
                    }
                  }

                  // 3) delete image document
                  await g.firestore.collection('images').doc(imageId).delete();

                  Get.snackbar(
                    '✅ Đã xóa',
                    'Ảnh đã được xóa',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.8),
                    colorText: white,
                  );
                } catch (e) {
                  print('❌ Delete image error: $e');
                  Get.snackbar(
                    '❌ Lỗi',
                    'Không thể xóa ảnh: $e',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.8),
                    colorText: white,
                  );
                }
              },
            ),
          ),
        // Floating emojis
        ...(_floatingEmojis.map((floatingEmoji) => AnimatedFloatingEmoji(
              emoji: floatingEmoji.emoji,
              startX: floatingEmoji.startX,
              delay: floatingEmoji.delay,
            ))),
      ],
    );
  }
}

// ========================= FLOATING EMOJI =========================
class FloatingEmoji {
  final String emoji;
  final double startX;
  final String id;
  final int delay;

  FloatingEmoji({
    required this.emoji,
    required this.startX,
    required this.id,
    required this.delay,
  });
}

class AnimatedFloatingEmoji extends StatefulWidget {
  const AnimatedFloatingEmoji({
    super.key,
    required this.emoji,
    required this.startX,
    required this.delay,
  });

  final String emoji;
  final double startX;
  final int delay;

  @override
  State<AnimatedFloatingEmoji> createState() => _AnimatedFloatingEmojiState();
}

class _AnimatedFloatingEmojiState extends State<AnimatedFloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Bay từ dưới footer (bottom: 80) lên header (top: MediaQuery.height - 120)
    final screenHeight = WidgetsBinding.instance.window.physicalSize.height /
        WidgetsBinding.instance.window.devicePixelRatio;
    final startBottom = 80.0; // footer
    final endBottom = screenHeight - 120.0; // header

    _positionAnimation = Tween<double>(
      begin: startBottom,
      end: endBottom,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.startX,
          bottom: _positionAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ========================= HISTORY ITEM ========================= 
class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.size,
    required this.image,
    required this.profilePicUrl,
    required this.userName,
    required this.currentUid,
    required this.relativeFormat,
  });

  final Size size;
  final Images image;
  final String profilePicUrl;
  final String userName;
  final String currentUid;
  final RelativeDateFormat relativeFormat;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = image.url ?? '';
    final String message = image.message ?? '';
    final bool isMyPost = image.uid == currentUid;
    
    final postTime = _resolveDateTime(image.dateCreated);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        
        // ✅ ẢNH (không có header phía trên)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Image
                  SizedBox.expand(
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: secondaryColor,
                              child: const Center(
                                child: CircularProgressIndicator(color: primaryColor),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: secondaryColor,
                              alignment: Alignment.center,
                              child: const Icon(Icons.error_outline, color: Colors.red, size: 40),
                            ),
                          )
                        : Container(color: secondaryColor),
                  ),
                  
                  // ✅ Message overlay
                  if (message.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // padding nhỏ
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          message,
                          style: GoogleFonts.inter(
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
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // ✅ AVATAR - TÊN - THỜI GIAN (ngang, giữa)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: secondaryColor,
              backgroundImage:
                  profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
              child: profilePicUrl.isEmpty
                  ? Text(
                      safeInitials(userName),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              isMyPost ? 'Bạn' : safeFirstName(userName),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRelativeTime(postTime),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }
}

// ========================= BOTTOM SECTION =========================
class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.imageItems,
    required this.pageController,
    required this.currentUid,
    required this.onReplyTap,
    required this.onJumpToCamera,
    required this.profilePicUrl,
    required this.userName,
    required this.onEmojiSent,
    required this.isKeyboardVisible,
    required this.onEmojiLongPress,
    required this.onEmojiLongPressEnd,
    this.onDeleteTap, // <-- added optional async delete callback
  });

  final List<Images> imageItems;
  final PageController pageController;
  final String currentUid;
  final VoidCallback onReplyTap;
  final VoidCallback onJumpToCamera;
  final String profilePicUrl;
  final String userName;
  final ValueChanged<String> onEmojiSent;
  final bool isKeyboardVisible;
  final ValueChanged<String> onEmojiLongPress;
  final VoidCallback onEmojiLongPressEnd;
  final Future<void> Function()? onDeleteTap; // <-- added

  @override
  Widget build(BuildContext context) {
    final currentIndex = pageController.hasClients && pageController.page != null
        ? pageController.page!.round()
        : 0;
    final currentImage = imageItems.isNotEmpty && currentIndex < imageItems.length
        ? imageItems[currentIndex]
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Message bar
        _MessageBar(
          currentImage: currentImage,
          currentUid: currentUid,
          onEmojiSent: onEmojiSent,
          profilePicUrl: profilePicUrl,
          userName: userName,
          onEmojiLongPress: onEmojiLongPress,
          onEmojiLongPressEnd: onEmojiLongPressEnd,
        ),
        
        // ✅ Footer (chỉ hiển thị khi bàn phím tắt)
        if (!isKeyboardVisible) ...[
          const SizedBox(height: 15),
          _HistoryFooter(
            onJumpToCamera: onJumpToCamera,
            onGridTap: () {
              Get.to(() => PostScreen(imageItems: imageItems, currentUid: currentUid));
            },
            onDownloadTap: () async {
              final currentIndex = pageController.hasClients && pageController.page != null
                  ? pageController.page!.round()
                  : 0;
              final currentImage = imageItems.isNotEmpty && currentIndex < imageItems.length
                  ? imageItems[currentIndex]
                  : null;
              if (currentImage?.url == null) return;
              try {
                await _saveImage(currentImage!.url!);
                Get.snackbar(
                  '✅ Đã lưu',
                  'Ảnh đã được lưu vào thư viện',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.8),
                  colorText: white,
                );
              } catch (e) {
                Get.snackbar(
                  '❌ Lỗi',
                  'Không thể lưu ảnh',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: white,
                );
              }
            },
            // forward async delete callback or provide a safe default that deletes the current image
            onDeleteTap: onDeleteTap ?? () async {
              final currentIndex = pageController.hasClients && pageController.page != null
                  ? pageController.page!.round()
                  : 0;
              final currentImage = imageItems.isNotEmpty && currentIndex < imageItems.length
                  ? imageItems[currentIndex]
                  : null;
              if (currentImage == null || currentImage.id == null) return;
              try {
                final imageId = currentImage.id!;
                // 1) delete reactions subcollection documents (if any)
                final reactionsRef = g.firestore.collection('images').doc(imageId).collection('reactions');
                final reactionsSnap = await reactionsRef.get();
                for (final doc in reactionsSnap.docs) {
                  await doc.reference.delete();
                }

                // 2) delete storage file (best-effort)
                final url = currentImage.url ?? '';
                if (url.isNotEmpty) {
                  try {
                    await FirebaseStorage.instance.refFromURL(url).delete();
                  } catch (e) {
                    print('⚠️ Storage delete warning: $e');
                    // continue even if storage deletion fails
                  }
                }

                // 3) delete image document
                await g.firestore.collection('images').doc(imageId).delete();

                Get.snackbar(
                  '✅ Đã xóa',
                  'Ảnh đã được xóa',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.8),
                  colorText: white,
                );
              } catch (e) {
                print('❌ Delete image error: $e');
                Get.snackbar(
                  '❌ Lỗi',
                  'Không thể xóa ảnh: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: white,
                );
              }
            },
          ),
          const SizedBox(height: 15),
        ],
      ],
    );
  }

  static Future<void> _saveImage(String url) async {
    try {
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(response.data);
      final fileName = 'BubbleCam_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        androidRelativePath: "Pictures/BubbleCam",
        skipIfExists: false,
      );
    } catch (e) {
      print('❌ Error saving image: $e');
      rethrow;
    }
  }
}

// ========================= MESSAGE BAR =========================
class _MessageBar extends StatefulWidget {
  const _MessageBar({
    required this.currentImage,
    required this.currentUid,
    required this.onEmojiSent,
    required this.profilePicUrl,
    required this.userName,
    required this.onEmojiLongPress,
    required this.onEmojiLongPressEnd,
  });

  final Images? currentImage;
  final String currentUid;
  final ValueChanged<String> onEmojiSent;
  final String profilePicUrl;
  final String userName;
  final ValueChanged<String> onEmojiLongPress;
  final VoidCallback onEmojiLongPressEnd;

  @override
  State<_MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<_MessageBar> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;

  String? _myReaction;
  Map<String, int> _reactionCounts = {'😊': 0, '❤️': 0, '🔥': 0};
  List<Map<String, dynamic>> _othersReactions = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reactionsSub;

  @override
  void initState() {
    super.initState();
    _subscribeReactions();
    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.isNotEmpty;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _MessageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImage?.id != widget.currentImage?.id) {
      _subscribeReactions();
    }
  }

  @override
  void dispose() {
    _reactionsSub?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _subscribeReactions() {
    _reactionsSub?.cancel();
    final imageId = widget.currentImage?.id;
    if (imageId == null || imageId.isEmpty) return;

    _reactionsSub = g.firestore
        .collection('images')
        .doc(imageId)
        .collection('reactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) {
      final items = snap.docs.map((d) {
        final data = d.data();
        print('[DEBUG] Reaction doc: ${d.id} => $data'); // Log từng document
        return {
          'userId': data['userId'] ?? d.id,
          'userName': data['userName'] ?? '',
          'avatar': data['avatar'] ?? '',
          'emoji': data['emoji'] ?? '❤️',
          'timestamp': data['timestamp'],
        };
      }).toList();

      final mine = items.firstWhereOrNull((e) => e['userId'] == widget.currentUid);

      print('[DEBUG] Current UID: ${widget.currentUid}');
      print('[DEBUG] All reactions: $items');
      print('[DEBUG] Mine: $mine');

      setState(() {
        _myReaction = mine?['emoji'] as String?;
        _reactionCounts = {
          '😊': items.where((e) => e['emoji'] == '😊').length,
          '❤️': items.where((e) => e['emoji'] == '❤️').length,
          '🔥': items.where((e) => e['emoji'] == '🔥').length,
        };
        _othersReactions = items.where((e) => e['userId'] != widget.currentUid).toList();
        print('[DEBUG] Others reactions: $_othersReactions');
      });
    });
  }

  Future<void> _saveReactionRemote(String? emoji) async {
    final imageId = widget.currentImage?.id;
    if (imageId == null || imageId.isEmpty) return;

    final doc = g.firestore
        .collection('images')
        .doc(imageId)
        .collection('reactions')
        .doc(widget.currentUid);

    if (emoji == null || emoji.isEmpty) {
      await doc.delete();
      return;
    }

    await doc.set({
      'userId': widget.currentUid, // người đang đăng nhập
      'userName': widget.userName, // phải là tên người đăng nhập
      'avatar': widget.profilePicUrl, // phải là avatar người đăng nhập
      'emoji': emoji,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  int _lastTap = 0;
  int _tapCount = 0;

  Future<void> _toggleReaction(String emoji) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - _lastTap < 500) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTap = now;

    // Rung mạnh dần theo số lần ấn liên tiếp
    if (await Vibration.hasVibrator() ?? false) {
      if (_tapCount >= 5) {
        Vibration.vibrate(duration: 80, amplitude: 255);
      } else if (_tapCount >= 3) {
        Vibration.vibrate(duration: 40, amplitude: 180);
      } else {
        Vibration.vibrate(duration: 20, amplitude: 100);
      }
    } else {
      HapticFeedback.selectionClick();
    }

    final newEmoji = (_myReaction == emoji) ? null : emoji;

    setState(() {
      if (_myReaction != null) {
        final old = _myReaction!;
        _reactionCounts[old] = (_reactionCounts[old] ?? 1) - 1;
      }
      _myReaction = newEmoji;
      if (newEmoji != null) {
        _reactionCounts[newEmoji] = (_reactionCounts[newEmoji] ?? 0) + 1;
        widget.onEmojiSent(newEmoji);
      }
    });

    await _saveReactionRemote(newEmoji);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final receiverId = widget.currentImage?.uid ?? '';
    final currentUid = widget.currentUid;
    if (receiverId.isEmpty || currentUid.isEmpty) return;

    // ✅ LẤY THÔNG TIN NGƯỜI ĐĂNG ẢNH
    final ownerName = widget.currentImage?.ownerName ?? '';
    final ownerAvatar = widget.currentImage?.ownerAvatar ?? '';

    try {
      final ids = [currentUid, receiverId]..sort();
      final chatId = ids.join('_');
      final chatRef = g.firestore.collection('chats').doc(chatId);

      // Lấy metadata ảnh
      final imageUrl = widget.currentImage?.url ?? '';
      final imageCaption = widget.currentImage?.message ?? '';
      final imageTimestamp = widget.currentImage?.dateCreated ?? '';

      // Cập nhật lastMessage cho chat_list
      await chatRef.set({
        'participants': [currentUid, receiverId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': imageCaption.isNotEmpty
            ? '🖼️ $imageCaption'
            : '🖼️ [Ảnh]',
        'lastSenderId': currentUid,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Thêm message vào subcollection
      await chatRef.collection('messages').add({
        'senderId': currentUid,
        'receiverId': receiverId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'image_reply',
        'imageUrl': widget.currentImage?.url ?? '',
        'imageCaption': widget.currentImage?.message ?? '',
        'imageUploadTime': widget.currentImage?.dateCreated ?? '',
        // ✅ Lưu đúng owner info
        'ownerName': ownerName,
        'ownerAvatarUrl': ownerAvatar,
        'ownerId': receiverId,
      });

      _messageController.clear();
      _focusNode.unfocus();

      Get.snackbar(
        '✅ Đã gửi',
        'Tin nhắn đã được gửi',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.withOpacity(0.85),
        colorText: white,
      );
    } catch (e) {
      print('❌ Send message error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Không thể gửi tin nhắn: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.85),
        colorText: white,
      );
    }
  }

  void _openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EmojiPickerSheet(
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          _toggleReaction(emoji);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyPost = widget.currentImage?.uid == widget.currentUid;

    if (isMyPost) {
      return _buildOwnerView();
    } else {
      return _buildViewerView();
    }
  }

  Widget _buildOwnerView() {
    print('[DEBUG] BuildOwnerView - _othersReactions: $_othersReactions');
    if (_othersReactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Iconsax.emoji_sad, color: Color(0xFF8E8E93), size: 20),
              const SizedBox(width: 10),
              Text(
                'Chưa có hoạt động nào',
                style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(28),
        ),
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _othersReactions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final r = _othersReactions[index];
            print('[DEBUG] OwnerView reaction: $r');
            final avatar = (r['avatar'] ?? '').toString();
            final uname = (r['userName'] ?? '').toString();
            final emoji = (r['emoji'] ?? '❤️').toString();

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: secondaryColor,
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? Text(
                          safeInitials(uname),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(emoji, style: const TextStyle(fontSize: 20)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewerView() {
    final isMyPost = widget.currentImage?.uid == widget.currentUid;
    // Nếu là chủ ảnh, không cho gửi reaction
    if (isMyPost) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: GoogleFonts.inter(fontSize: 16, color: white),
                decoration: InputDecoration(
                  hintText: 'Gửi tin nhắn...',
                  hintStyle: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            if (_isTyping)
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, color: white, size: 18),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReactionEmoji(
                    emoji: '😊',
                    isSelected: _myReaction == '😊',
                    onTap: () => _toggleReaction('😊'),
                    onLongPress: widget.onEmojiLongPress,
                    onLongPressEnd: widget.onEmojiLongPressEnd,
                  ),
                  const SizedBox(width: 8),
                  _ReactionEmoji(
                    emoji: '❤️',
                    isSelected: _myReaction == '❤️',
                    onTap: () => _toggleReaction('❤️'),
                    onLongPress: widget.onEmojiLongPress,
                    onLongPressEnd: widget.onEmojiLongPressEnd,
                  ),
                  const SizedBox(width: 8),
                  _ReactionEmoji(
                    emoji: '🔥',
                    isSelected: _myReaction == '🔥',
                    onTap: () => _toggleReaction('🔥'),
                    onLongPress: widget.onEmojiLongPress,
                    onLongPressEnd: widget.onEmojiLongPressEnd,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openEmojiPicker,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF48484A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: white, size: 18),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ========================= SMALL WIDGETS =========================
class _ReactionEmoji extends StatelessWidget {
  const _ReactionEmoji({
    required this.emoji,
    required this.onTap,
    required this.isSelected,
    required this.onLongPress,
    required this.onLongPressEnd,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => onLongPress(emoji),
      onLongPressUp: onLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : const Color(0xFF48484A),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: primaryColor, width: 1) : null,
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet({required this.onEmojiSelected});
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(12),
          height: 320,
          child: GridView.builder(
            itemCount: _emojiList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => onEmojiSelected(_emojiList[i]),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(_emojiList[i], style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= HISTORY FOOTER ========================= ✅ SỬA ĐÂY
class _HistoryFooter extends StatelessWidget {
  const _HistoryFooter({
    required this.onJumpToCamera,
    required this.onGridTap,
    required this.onDownloadTap,
    required this.onDeleteTap, // <-- added async delete callback
  });

  final VoidCallback onJumpToCamera;
  final VoidCallback onGridTap;
  final VoidCallback onDownloadTap;
  final Future<void> Function() onDeleteTap; // <-- added

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ 1. Tất cả ảnh (TRÁI)
          GestureDetector(
            onTap: onGridTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.grid_2, size: 45, color: white),
                const SizedBox(height: 5),
              ],
            ),
          ),
          
          // ✅ 2. Camera (GIỮA)
          GestureDetector(
            onTap: onJumpToCamera,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: white,
                border: Border.all(width: 4, color: primaryColor),
              ),
              child: const Icon(Iconsax.camera, color: Colors.black, size: 28),
            ),
          ),
          
          // ✅ 3. Menu 3 chấm (PHẢI)
          GestureDetector(
            onTap: () => _showActionMenu(context, onDownloadTap, onDeleteTap),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryColor,
                border: Border.all(width: 2, color: const Color(0xFF48484A)),
              ),
              child: const Icon(Icons.more_horiz, color: white, size: 35),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(BuildContext context, VoidCallback onDownloadTap, Future<void> Function() onDeleteTap) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true, // ✅ Bấm ra ngoài để đóng
      builder: (context) => _ActionMenuSheet(onDownloadTap: onDownloadTap, onDeleteTap: onDeleteTap),
    );
  }
}

// ✅ MENU ACTIONS BOTTOM SHEET
class _ActionMenuSheet extends StatelessWidget {
  const _ActionMenuSheet({required this.onDownloadTap, required this.onDeleteTap});
  
  final VoidCallback onDownloadTap;
  final Future<void> Function() onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            // ✅ 1. Chia sẻ
            _MenuItem(
              icon: Icons.share,
              label: 'Chia sẻ',
              onTap: () {
                Navigator.pop(context);
                _shareCurrentImage(context);
              },
            ),
            
            // ✅ 2. Tải về
            _MenuItem(
              icon: Iconsax.arrow_down_1,
              label: 'Tải về',
              onTap: () {
                Navigator.pop(context);
                onDownloadTap();
              },
            ),
            
            // ✅ 3. Xóa (TODO: kiểm tra isOwner)
            _MenuItem(
              icon: Icons.delete,
              label: 'Xóa',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor: secondaryColor,
                    title: Text('Xóa ảnh?', style: GoogleFonts.inter(color: white)),
                    content: Text(
                      'Hành động này không thể hoàn tác.',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text('Hủy', style: GoogleFonts.inter(color: white)),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: Text('Xóa', style: GoogleFonts.inter(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await onDeleteTap();
                  } catch (e) {
                    print('❌ Delete via menu error: $e');
                    Get.snackbar(
                      '❌ Lỗi',
                      'Không thể xóa ảnh: $e',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red.withOpacity(0.8),
                      colorText: white,
                    );
                  }
                }
              },
            ),
            
            const Divider(color: Color(0xFF48484A), height: 1),
            
            // ✅ 4. Hủy
            _MenuItem(
              icon: Icons.close,
              label: 'Hủy',
              onTap: () => Navigator.pop(context),
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentImage(BuildContext context) async {
    // TODO: Implement share (cần truyền currentImage vào)
    Get.snackbar(
      'Chia sẻ',
      'Tính năng đang phát triển',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: primaryColor.withOpacity(0.8),
      colorText: white,
    );
  }
}

// ✅ MENU ITEM WIDGET
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    );
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
