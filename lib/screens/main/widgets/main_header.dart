import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '/model/firestore.dart';
import '/utils/colors.dart';
import '/utils/name_utils.dart';

class MainHeader extends StatelessWidget {
  const MainHeader({
    super.key,
    required this.mainPageIndex,
    required this.animation,
    required this.onProfileTap,
    required this.onAddFriendTap,
    required this.onChatsTap,
    required this.friendsList,
    this.selectedFilter,
    required this.onFilterChanged,
  });

  final int mainPageIndex;
  final Animation<double> animation;
  final VoidCallback onProfileTap;
  final VoidCallback onAddFriendTap;
  final VoidCallback onChatsTap;
  final List<Users> friendsList;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return mainPageIndex == 0
        ? _CameraHeader(
            onProfileTap: onProfileTap,
            onAddFriendTap: onAddFriendTap,
            onChatsTap: onChatsTap,
          )
        : _HistoryHeader(
            animation: animation,
            friendsList: friendsList,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            onProfileTap: onProfileTap,
            onChatsTap: onChatsTap,
          );
  }
}

class _CameraHeader extends StatelessWidget {
  const _CameraHeader({
    required this.onProfileTap,
    required this.onAddFriendTap,
    required this.onChatsTap,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onAddFriendTap;
  final VoidCallback onChatsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: secondaryColor,
              child: Icon(Icons.person, color: white),
            ),
          ),
          GestureDetector(
            onTap: onAddFriendTap,
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: secondaryColor,
              child: Icon(Icons.person_add, color: white),
            ),
          ),
          GestureDetector(
            onTap: onChatsTap,
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: secondaryColor,
              child: Icon(Icons.chat_bubble, color: white),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ History Header - Giao diện giống ảnh 100%
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.animation,
    required this.friendsList,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onProfileTap,
    required this.onChatsTap,
  });

  final Animation<double> animation;
  final List<Users> friendsList;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback onProfileTap;
  final VoidCallback onChatsTap;

  @override
  Widget build(BuildContext context) {
    String displayText = 'Tất cả bạn bè';
    String? selectedAvatarUrl;
    
    if (selectedFilter != null && selectedFilter != 'everyone') {
      final friend = friendsList.firstWhereOrNull((f) => f.uid == selectedFilter);
      if (friend != null) {
        displayText = friend.name ?? friend.phoneNumber ?? 'Unknown';
        selectedAvatarUrl = friend.profileUrl;
      }
    }

    return FadeTransition(
      opacity: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ Left: Avatar (thay vì icon user)
            GestureDetector(
              onTap: onProfileTap,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: secondaryColor,
                backgroundImage: selectedAvatarUrl?.isNotEmpty == true
                    ? CachedNetworkImageProvider(selectedAvatarUrl!)
                    : null,
                child: selectedAvatarUrl?.isEmpty ?? true
                    ? const Icon(Icons.person, color: white)
                    : null,
              ),
            ),
            
            // ✅ Center: Everyone filter button
            Expanded(
              child: Center(
                child: PopupMenuButton<String>(
                  color: const Color(0xFF2C2C2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  offset: const Offset(0, 55),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayText,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Color(0xFFAAAAAA),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => [
                    // ✅ Everyone option với icon group
                    PopupMenuItem(
                      value: 'everyone',
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.groups,
                              color: white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tất cả bạn bè',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: white,
                            ),
                          ),
                          const Spacer(),
                          if (selectedFilter == null || selectedFilter == 'everyone')
                            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
                        ],
                      ),
                    ),
                    
                    // ✅ Friends list
                    ...friendsList.map((friend) => PopupMenuItem(
                          value: friend.uid,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: primaryColor,
                                backgroundImage: friend.profileUrl?.isNotEmpty == true
                                    ? CachedNetworkImageProvider(friend.profileUrl!)
                                    : null,
                                child: friend.profileUrl?.isEmpty ?? true
                                    ? Text(
                                        safeInitials(friend.name ?? ''),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  friend.name ?? friend.phoneNumber ?? 'Unknown',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selectedFilter == friend.uid)
                                const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
                            ],
                          ),
                        )),
                  ],
                  onSelected: (String? value) {
                    print('✅ Selected: $value');
                    onFilterChanged(value);
                  },
                ),
              ),
            ),
            
            // ✅ Right: Message icon (thay vì chat bubble)
            GestureDetector(
              onTap: onChatsTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.messenger_outline, // ✅ Đổi icon
                  color: white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
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
