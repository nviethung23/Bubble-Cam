import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lit_relative_date_time/lit_relative_date_time.dart';
import '/model/firestore.dart';
import '/screens/screens.dart';
import '/utils/colors.dart';
import '/globals.dart' as globals;
import 'widgets/camera_section.dart';
import 'widgets/history_section.dart';
import 'widgets/main_header.dart';
import '/utils/name_utils.dart';
import '/utils/phone_helper.dart'; // ✅ Thêm import

import '/services/user_service.dart';
import '/services/friend_service.dart';
import '/firebase/firebase_service.dart'; // ✅ Thêm import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';

class MainScreen extends StatefulWidget {
  MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  PageController _pageViewController = PageController();
  PageController _secondPageController = PageController();
  bool isFlashToggled = false;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int currentCameraIndex = 0;
  int currentPageIndex = 0;
  int mainPageIndex = 0;
  final double _swipeVelocityThreshold = 100.0;
  double _dragDistance = 0.0;
  List<Images> imageItems = [];
  List<List<dynamic>> imageList = [];
  String userName = "";
  String profilePicUrl = "";
  List<String> contactsList = [];
  List<String> phoneNumbers = [];
  String requestStatus = "";
  int requestCount = 0;

  late AnimationController animationController;
  late Animation<double> animation;
  bool _isCapturing = false;
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _requestSubscription;
  StreamSubscription<List<Images>>? _imagesSubscription;

  PageController? _filteredPageController;
  String? _selectedFriendFilter;
  List<Users> _friendsDataList = [];

  List<Images> get _filteredImages {
    if (_selectedFriendFilter == null || _selectedFriendFilter == 'everyone') {
      return imageItems;
    }
    return imageItems.where((img) => img.uid == _selectedFriendFilter).toList();
  }

  void removeItemsfromcommonContacts(List list1, List<List> otherLists) {
    setState(() {
      list1.removeWhere((item) => otherLists.any((list) => list.contains(item)));
    });
  }

  
     
    
  

  void _listenToImages() {
    final currentUid = userStorage.read('uid') ?? '';
    print('📡 _listenToImages() called with UID: $currentUid');
    
    if (currentUid.isEmpty) {
      print('❌ UID is empty, cannot listen to images');
      return;
    }

    // ✅ Cancel previous subscription
    _imagesSubscription?.cancel();

    _imagesSubscription = _firebaseService.getHistoryImages(currentUid).listen(
      (images) {
        print('📥 Received ${images.length} images from stream');
        if (images.isNotEmpty) {
          print('📸 First image URL: ${images.first.url}');
          print('📸 First image UID: ${images.first.uid}');
          print('📸 First image visibleTo: ${images.first.visibleTo}');
        } else {
          print('⚠️ No images received from stream');
        }
        
        if (mounted) {
          setState(() {
            imageItems = images;
          });
        }
      },
      onError: (error) {
        print('❌ Image stream error: $error');
        print('❌ Error type: ${error.runtimeType}');
      },
    );
    
    print('✅ Image stream listener attached');
  }

  void getuserInfo(String uid) async {
    if (uid.isEmpty) return;
    final user = await _userService.getUserInfo(uid);
    if (user != null && mounted) {
      setState(() {
        userName = user.name ?? '';
        profilePicUrl = user.profileUrl ?? '';
      });
    }
  }

  Future<void> getContacts() async {
    try {
      if (!await fc.FlutterContacts.requestPermission()) {
        Get.snackbar('Error', 'Contacts permission required');
        return;
      }

      List<fc.Contact> phoneContacts = await fc.FlutterContacts.getContacts(withProperties: true);
      List<Users> appContacts = [];

      for (var phoneContact in phoneContacts) {
        for (var phone in phoneContact.phones) {
          final raw = phone.number ?? "";
          final normalized = PhoneHelper.normalize(raw); // ✅ Dùng PhoneHelper
          if (normalized.isEmpty) continue;

          try {
            final snapshot = await firestore
                .collection("users")
                .where('phoneNumber', isEqualTo: normalized)
                .get();

            for (var docSnap in snapshot.docs) {
              final doc = docSnap.data();
              if (doc['uid'] != userStorage.read('uid')) {
                appContacts.add(Users(
                    name: doc['name'],
                    profileUrl: doc['profileUrl'],
                    phoneNumber: doc['phoneNumber']));
              }
            }
          } catch (e) {
            debugPrint('Error checking contact $normalized: $e');
          }
        }
      }

      setState(() {
        globals.commonContactsList = appContacts
            .map((u) => {'name': u.name ?? '', 'number': u.phoneNumber ?? ''})
            .toList();
      });
    } catch (e) {
      debugPrint('GetContacts error: $e');
    }
  }

  void _listenToFriendRequests() {
    _requestSubscription = _friendService.getPendingRequests().listen((requests) {
      if (!mounted) return;
      
      setState(() {
        requestCount = requests.length;
      });

      globals.receivedRequestList.clear();
      for (var request in requests) {
        _friendService.getUserById(request.senderId ?? '').then((user) {
          if (user != null) {
            globals.receivedRequestList.add({
              'name': user.name ?? '',
              'number': user.phoneNumber ?? '',
              'requestId': request.id ?? '',
              'senderId': request.senderId ?? '',
            });
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print('🚀 MainScreen initState() started');
    
    // ✅ Khởi tạo AnimationController TRƯỚC KHI dùng
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    animation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // ✅ Khởi tạo controller NGAY
    _filteredPageController = PageController(initialPage: 0);
    
    _initializeUser();
    _loadFriendsList();
    _listenToFriendRequests();
    getContacts();
    
    print('✅ After _initializeUser() call');
  }

  // ✅ THÊM hàm khởi tạo user
  Future<void> _initializeUser() async {
    print('🔍 _initializeUser() START');
    
    String? uid = userStorage.read('uid');
    
    print('🔐 Current UID from storage: $uid');
    
    // Nếu chưa có UID, sign-in anonymous
    if (uid == null || uid.isEmpty) {
      try {
        print('🔄 Attempting anonymous sign-in...');
        final credential = await _firebaseService.signInAnonymously();
        uid = credential.user?.uid;
        if (uid != null) {
          await userStorage.write('uid', uid);
          print('✅ Saved new UID to storage: $uid');
        }
      } catch (e) {
        print('❌ Sign-in failed: $e');
        return;
      }
    }
    
    // ✅ Load user info
    if (uid != null && uid.isNotEmpty) {
      print('👤 Loading user info for UID: $uid');
      getuserInfo(uid);
      
      print('👤 Calling ensurePhoneNumber for UID: $uid');
      await _userService.ensurePhoneNumber(uid);
      
      print('📡 Starting to listen to images...');
      _listenToImages();
      
      print('✅ _initializeUser() DONE');
    } else {
      print('❌ No UID available, cannot listen to images');
    }
  }

  // ✅ Load friends từ Firestore
  Future<void> _loadFriendsList() async {
    try {
      final uid = userStorage.read('uid');
      if (uid == null) return;

      final userDoc = await firestore.collection('users').doc(uid).get();
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

      if (friendIds.isEmpty) {
        setState(() => _friendsDataList = []);
        return;
      }

      // ✅ Load từng friend document
      List<Users> friends = [];
      for (var friendId in friendIds) {
        final friendDoc = await firestore.collection('users').doc(friendId).get();
        if (friendDoc.exists) {
          friends.add(Users.fromFirestore(friendDoc, null));
        }
      }

      setState(() => _friendsDataList = friends);
      print('👥 Loaded ${_friendsDataList.length} friends');
    } catch (e) {
      print('❌ Error loading friends: $e');
    }
  }

  @override
  void dispose() {
    // ✅ Dispose animation controller
    animationController.dispose();
    _pageViewController.dispose();
    _secondPageController.dispose();
    _filteredPageController?.dispose();
    _controller?.dispose();
    _requestSubscription?.cancel();
    _imagesSubscription?.cancel();
    super.dispose();
  }

  // ✅ Recreate controller khi filter thay đổi
  void _updateFilteredController() {
    _filteredPageController?.dispose();
    _filteredPageController = PageController(
      initialPage: 0, // ✅ Luôn bắt đầu từ page 0
    );
    setState(() {
      currentPageIndex = 0;
    });
  }

  Future<void> onSwitchCamera() async {
    if (globals.cameras.isEmpty) return;

    // toggle index
    if (currentCameraIndex == globals.cameras.length - 1) {
      currentCameraIndex = 0;
    } else {
      currentCameraIndex = globals.cameras.length - 1;
    }
    setState(() => isFlashToggled = false);

    // dispose previous controller before creating new one
    try {
      await _controller?.dispose();
    } catch (_) {}

    _controller = CameraController(
      globals.cameras[currentCameraIndex],
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller?.initialize();
    try {
      await _initializeControllerFuture;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to switch camera: $e');
    }
  }

  void onToggleFlash() {
    if (_controller?.value.isInitialized == true) {
      final current = _controller!.value.flashMode;
      final next = current == FlashMode.torch ? FlashMode.off : FlashMode.torch;
      _controller!.setFlashMode(next);
      setState(() {
        isFlashToggled = next == FlashMode.torch;
      });
    }
  }

  void onTapDown(TapDownDetails details) {
    if (_controller?.value.isInitialized == true) {
      final double width = MediaQuery.of(context).size.width;
      final double height = MediaQuery.of(context).size.height;
      final double x = details.globalPosition.dx / width;
      final double y = details.globalPosition.dy / height;
      _controller!.setExposurePoint(Offset(x, y));
      _controller!.setFocusPoint(Offset(x, y));
      _controller!.setExposureMode(ExposureMode.auto);
      _controller!.setFocusMode(FocusMode.auto);
    }
  }

  void takePicture() async {
    final controller = _controller;
    if (controller == null ||
        controller.value.isInitialized != true ||
        _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await _initializeControllerFuture;
      final image = await controller.takePicture();

      try {
        await controller.pausePreview();
      } on CameraException catch (e) {
        debugPrint('pausePreview error: $e');
      }

      Future<dynamic>? previewFuture;
      if (currentCameraIndex == 0) {
        previewFuture = Get.to(
          () => PicturePreview(file: File(image.path)),
          transition: Transition.cupertinoDialog,
        );
      } else {
        final img.Image file = img.decodeImage(await image.readAsBytes())!;
        final img.Image flipped =
            img.flip(file, direction: img.FlipDirection.horizontal);
        final pic = File(image.path)..writeAsBytesSync(img.encodePng(flipped));
        previewFuture = Get.to(
          () => PicturePreview(file: pic),
          transition: Transition.cupertinoDialog,
        );
      }
      await previewFuture;
    } catch (e) {
      debugPrint('takePicture error: $e');
    } finally {
      final resumedController = _controller;
      if (resumedController != null &&
          resumedController.value.isInitialized == true &&
          resumedController.value.isPreviewPaused) {
        try {
          await resumedController.resumePreview();
        } on CameraException catch (e) {
          debugPrint('resumePreview error: $e');
        }
      }
      if (mounted) {
        setState(() => _isCapturing = false);
      } else {
        _isCapturing = false;
      }
    }
  }

  Future<void> _pauseCameraPreview() async {
    debugPrint('📹 Attempting to pause camera preview');
    
    if (_controller?.value.isInitialized == true && 
        !_controller!.value.isPreviewPaused) {
      try {
        await _controller!.pausePreview();
        debugPrint('✅ Camera preview paused successfully');
      } catch (e) {
        debugPrint('❌ Error pausing preview: $e');
      }
    }
  }

  Future<void> _resumeCameraPreview() async {
    debugPrint('📹 Attempting to resume camera preview');
    
    if (_controller?.value.isInitialized == true && 
        _controller!.value.isPreviewPaused) {
      try {
        await _controller!.resumePreview();
        debugPrint('✅ Camera preview resumed successfully');
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('❌ Error resuming preview: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final bool isPreviewPaused =
        _controller?.value.isInitialized == true && _controller!.value.isPreviewPaused;

    // ✅ Bọc toàn bộ màn hình bằng GestureDetector
    return GestureDetector(
      onTap: () {
        // ✅ Bấm ra ngoài để tắt bàn phím
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        // ✅ Quan trọng: Đảm bảo Scaffold co lại khi bàn phím mở
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                MainHeader(
                  mainPageIndex: mainPageIndex,
                  animation: animation,
                  onProfileTap: () {
                    _pauseCameraPreview();
                    Get.to(
                      () => Profile(),
                      transition: Transition.leftToRightWithFade,
                      popGesture: false,
                    )?.then((_) => _resumeCameraPreview());
                  },
                  onAddFriendTap: addFriendsModal,
                  onChatsTap: () {
                    _pauseCameraPreview();
                    Get.to(
                      () => ChatsList(),
                      transition: Transition.rightToLeftWithFade,
                      popGesture: false,
                    )?.then((_) => _resumeCameraPreview());
                  },
                  friendsList: _friendsDataList,
                  selectedFilter: _selectedFriendFilter,
                  onFilterChanged: (String? uid) {
                    print('🔄 Filter changed to: $uid');
                    setState(() {
                      _selectedFriendFilter = uid;
                    });
                    _updateFilteredController(); // ✅ Recreate controller
                  },
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: PageView(
                    controller: _pageViewController,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (int value) {
                      setState(() {
                        mainPageIndex = value;
                        currentPageIndex = 0;
                      });
                      if (value == 1) {
                        _pauseCameraPreview();
                      } else if (value == 0) {
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          _resumeCameraPreview();
                        });
                      }
                    },
                    children: [
                      CameraSection(
                        size: size,
                        controller: _controller,
                        initializeControllerFuture: _initializeControllerFuture,
                        isFlashToggled: isFlashToggled,
                        onToggleFlash: onToggleFlash,
                        onTakePicture: takePicture,
                        onSwitchCamera: onSwitchCamera,
                        onTapDown: onTapDown,
                        onHistoryTap: () {
                          _pauseCameraPreview();
                          _pageViewController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        },
                        isPreviewPaused: isPreviewPaused,
                      ),
                      
                      // ✅ Use filtered controller
                      _filteredPageController == null
                          ? const Center(child: CircularProgressIndicator(color: primaryColor))
                          : HistorySection(
                              key: ValueKey('${_selectedFriendFilter}_${_filteredImages.length}'), // ✅ Unique key
                              size: size,
                              imageItems: _filteredImages,
                              pageController: _filteredPageController!, // ✅ Dùng controller riêng
                              onPageChanged: (value) {
                                setState(() => currentPageIndex = value);
                                _updateUserInfoForIndex(value);
                              },
                              profilePicUrl: profilePicUrl,
                              userName: userName,
                              currentUid: userStorage.read('uid') ?? '',
                              onReplyTap: replyDialog,
                              onJumpToCamera: () {
                                _resumeCameraPreview();
                                _pageViewController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              },
                              relativeDateTimeBuilder: relativedateTime,
                              friendsList: _friendsDataList,
                              onFilterChanged: (String? selectedUid) {
                                print('🔄 History filter changed: $selectedUid');
                                setState(() {
                                  _selectedFriendFilter = selectedUid;
                                });
                                _updateFilteredController(); // ✅ Recreate controller
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  RelativeDateFormat relativedateTime(BuildContext context) {
    return RelativeDateFormat(
      Localizations.localeOf(context),
      localizations: [
        const RelativeDateLocalization(
          languageCode: 'en',
          timeUnitsSingular: ['s', 'm', 'h', 'd', 'w', 'mo', 'y'],
          timeUnitsPlural: ['s', 'm', 'h', 'd', 'w', 'mo', 'y'],
          prepositionPast: '',
          prepositionFuture: '',
          atTheMoment: 'now',
          formatOrderPast: [
            FormatComponent.value,
            FormatComponent.unit,
            FormatComponent.preposition
          ],
          formatOrderFuture: [
            FormatComponent.preposition,
            FormatComponent.value,
            FormatComponent.unit,
          ],
        )
      ],
    );
  }

  void replyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.bottomCenter,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: TextField(
              cursorHeight: 20,
              cursorColor: white,
              style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w400),
              autofocus: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                hintText: "Reply to ${safeFirstName(userName)}...",
                hintStyle: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w400),
                suffixIcon: GestureDetector(
                  onTap: () {
                    print('Sent Message');
                    Get.back();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Icon(Iconsax.send_1, color: termsText),
                  ),
                ),
              ),
            ),
          ),
        );
      });
  }

  // ✅ MỞ AddFriendScreen thay vì ModalBottomSheet
  void addFriendsModal() {
    _pauseCameraPreview();
    Get.to(
      () => const AddFriendScreen(),
      transition: Transition.rightToLeft,
      popGesture: false,
    )?.then((_) {
      _resumeCameraPreview();
      // ✅ Reload contacts sau khi đóng
      getContacts();
      _listenToFriendRequests();
    });
  }

  void _updateUserInfoForIndex(int index) {
    if (_filteredImages.isEmpty) return;
    final clampedIndex = index.clamp(0, _filteredImages.length - 1);
    final uid = _filteredImages[clampedIndex].uid ?? '';
    if (uid.isEmpty) return;
    getuserInfo(uid);
  }

  
}
