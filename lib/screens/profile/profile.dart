import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '/model/firestore.dart';
import '/screens/screens.dart';
import '/utils/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/friend_service.dart'; // ✅ Thêm import

class CustomTileItems extends StatelessWidget {
  const CustomTileItems(
      {super.key,
      required this.leadingIcon,
      required this.title,
      required this.onTap});

  final leadingIcon;
  final String title;
  final onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade700,
                child: leadingIcon),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                title,
                style: GoogleFonts.rubik(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.white70,
                    ))),
          ]),
        ),
      ),
    );
  }
}

class Profile extends StatefulWidget {
  Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  double _scrolloffset = 0.0;
  final double _swipeVelocityThreshold = 100.0;
  double _dragDistance = 0.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CollectionReference users = FirebaseFirestore.instance.collection('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FriendService _friendService = FriendService(); // ✅ Thêm service

  // ✅ Thêm biến lưu danh sách bạn bè
  List<Users> _friendsList = [];
  bool _isLoadingFriends = true;

  Future<void> deleteFolder(String folderPath) async {
    var folderRef = storage.ref().child(folderPath);
    ListResult folderContents = await folderRef.listAll();
    for (var file in folderContents.items) {
      await file.delete();
    }
    await folderRef.delete();
  }

  // Safe accessors to avoid Null errors from GetStorage
  String get _storedName => (userStorage.read('name') ?? '').toString();
  String get _storedProfileUrl => (userStorage.read('profileUrl') ?? '').toString();
  String get _storedPhoneNumber => (userStorage.read('phoneNumber') ?? '').toString();

  List<String> _nameParts() {
    final n = _storedName.trim();
    if (n.isEmpty) return ['', ''];
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return [parts[0], ''];
    return [parts[0], parts.sublist(1).join(' ')];
  }

  String _initialsFromName() {
    final parts = _nameParts();
    final a = parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    final initials = (a + b).trim();
    return initials.isNotEmpty ? initials.toUpperCase() : '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrolloffset = _scrollController.offset;
        });
      });
    _loadFriends();
    _checkAuthStatus(); // ✅ Thêm check auth
  }

  // ✅ Thêm method check auth
  Future<void> _checkAuthStatus() async {
    final currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      print('⚠️ User not authenticated');
      Get.snackbar(
        '⚠️ Cảnh báo',
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
      );
      
      // Đợi 2s rồi logout
      await Future.delayed(Duration(seconds: 2));
      _auth.signOut();
      userStorage.remove("name");
      userStorage.remove("profileUrl");
      userStorage.remove("uid");
      Get.offAll(() => WelcomeScreen());
    } else {
      // ✅ Refresh token nếu cần
      await currentUser.getIdToken(true);
      print('✅ User authenticated: ${currentUser.uid}');
    }
  }

  // ✅ Thêm method load friends
  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    final friends = await _friendService.getFriends();
    setState(() {
      _friendsList = friends;
      _isLoadingFriends = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final nameParts = _nameParts();
    final firstName = nameParts[0];
    final lastName = nameParts[1];
    return GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.primaryDelta! < 0) {
            _dragDistance += details.primaryDelta!.abs();
          } else {
            _dragDistance = 0.0;
          }
        },
        onHorizontalDragEnd: (details) {
          if (_dragDistance >= size.width / 4 &&
              details.primaryVelocity!.abs() > _swipeVelocityThreshold &&
              details.primaryVelocity! < 0) {
            Navigator.pop(context);
          }
          // Reset drag distance
          _dragDistance = 0.0;
        },
        child: Scaffold(
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 70,
            backgroundColor: backgroundColor!
                .withOpacity((_scrolloffset / 250).clamp(0, 1).toDouble()),
            elevation: 0,
            actions: [
              _scrolloffset > 250
                  ? Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 30),
                            _storedProfileUrl.isEmpty
                                ? CircleAvatar(
                                    radius: 20,
                                    backgroundColor: secondaryColor,
                                    child: Center(
                                      child: Text(
                                        _initialsFromName(),
                                        style: GoogleFonts.rubik(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: termsText),
                                      ),
                                    ))
                                : CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(_storedProfileUrl),
                                  ),
                            const SizedBox(width: 10),
                            Text(
                              firstName,
                              style: GoogleFonts.rubik(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xB3FFFFFF)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_forward_ios, size: 26)),
              )
            ],
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50)
                  .copyWith(top: 70),
              child: Column(children: [
                Center(
                  child: GestureDetector(
                    onTap: addProfileModal,
                    child: Stack(alignment: Alignment.center, children: [
                      CircleAvatar(
                          radius: 90,
                          backgroundColor: primaryColor,
                          child: Container(
                            height: 170,
                            decoration: BoxDecoration(
                                color: backgroundColor, shape: BoxShape.circle),
                          )),
                      _storedProfileUrl.isEmpty
                          ? CircleAvatar(
                              radius: 80,
                              backgroundColor: secondaryColor,
                              child: Stack(children: [
                                Center(
                                  child: Text(
                                    _initialsFromName(),
                                    style: GoogleFonts.rubik(
                                        fontSize: 72,
                                        fontWeight: FontWeight.w700,
                                        color: termsText),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: backgroundColor,
                                        shape: BoxShape.circle),
                                    child: const Icon(
                                      Icons.add_circle_rounded,
                                      color: primaryColor,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ]),
                            )
                          : CircleAvatar(
                              radius: 80,
                              backgroundColor: secondaryColor,
                              backgroundImage: NetworkImage(_storedProfileUrl),
                              child: Stack(children: [
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: backgroundColor,
                                        shape: BoxShape.circle),
                                    child: const Icon(
                                      Icons.add_circle_rounded,
                                      color: primaryColor,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                    ]),
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: Text(
                      _storedName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rubik(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: white),
                    )),
                TextButton(
                    onPressed: () {
                      modalSheet("name");
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: secondaryColor,
                      padding: const EdgeInsets.all(15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Edit Info",
                      style: GoogleFonts.rubik(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: white),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10)
                      .copyWith(top: 35),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.heart_circle,
                        color: termsText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Widgets",
                        style: GoogleFonts.rubik(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: termsText),
                      )
                    ],
                  ),
                ),
                // ✅ Widget container đã được cập nhật
                _buildWidgetsSection(),
                // ...existing code (menu items)...
                menuListItems(
                  Icon(
                    Iconsax.user4,
                    color: termsText,
                    size: 18,
                  ),
                  "General",
                  [
                    CustomTileItems(
                        leadingIcon: const Icon(
                          Icons.phone_rounded,
                          size: 25,
                          color: Colors.white60,
                        ),
                        title: "Change phone number",
                        onTap: () {
                          modalSheet("phone");
                        }),
                    CustomTileItems(
                        leadingIcon: const Icon(
                          Icons.help_rounded,
                          size: 25,
                          color: Colors.white60,
                        ),
                        title: "Get Help",
                        onTap: () async {
                          Uri url = Uri(
                              scheme: "https",
                              host: "github.com",
                              path: "/nviethung23/");
                          if (!await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          )) {
                            throw Exception('Could not launch $url');
                          }
                        }),
                    CustomTileItems(
                        leadingIcon: const Icon(
                          Iconsax.add_square5,
                          size: 25,
                          color: Colors.white60,
                        ),
                        title: "How to add the widget",
                        onTap: () {}),
                    CustomTileItems(
                        leadingIcon: const Icon(
                          Iconsax.send_2,
                          size: 25,
                          color: Colors.white60,
                        ),
                        title: "Share feedback",
                        onTap: () {})
                  ],
                  size,
                ),
                menuListItems(
                    Icon(
                      Iconsax.heart5,
                      color: termsText,
                      size: 18,
                    ),
                    "About",
                    [
                      CustomTileItems(
                          leadingIcon: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  Color(0xFFF58529),
                                  Color(0xFFDD2A7B),
                                  Color(0xFF8134AF),
                                  Color(0xFF515BD4),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded, // ✅ Instagram icon
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: "Instagram",
                          onTap: () async {
                            Uri url = Uri.parse("https://www.instagram.com/_nviethung23/");
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              throw Exception('Could not launch $url');
                            }
                          }),
                      CustomTileItems(
                          leadingIcon: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFC6D26), // GitLab orange
                            ),
                            child: Icon(
                              Icons.interests_rounded, // ✅ GitLab icon
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: "GitLab",
                          onTap: () async {
                            Uri url = Uri.parse("https://gitlab.com/22dthg5/2280601318-nguyenviethung");
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              throw Exception('Could not launch $url');
                            }
                          }),
                      CustomTileItems(
                          leadingIcon: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white, // GitHub white
                            ),
                            child: Icon(
                              Icons.code_rounded, // ✅ GitHub icon
                              color: Colors.black,
                              size: 16,
                            ),
                          ),
                          title: "GitHub",
                          onTap: () async {
                            Uri url = Uri.parse("https://github.com/nviethung23");
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              throw Exception('Could not launch $url');
                            }
                          }),
                      CustomTileItems(
                          leadingIcon: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1877F2), // Facebook blue
                            ),
                            child: Icon(
                              Icons.facebook_rounded, // ✅ Facebook icon
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: "Facebook",
                          onTap: () async {
                            Uri url = Uri.parse("https://www.facebook.com/nviethung23");
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              throw Exception('Could not launch $url');
                            }
                          }),
                    ],
                    size),
                menuListItems(
                    Icon(
                      Iconsax.danger5,
                      color: termsText,
                      size: 18,
                    ),
                    "Danger Zone",
                    [
                      CustomTileItems(
                          leadingIcon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 25,
                            color: Colors.white60,
                          ),
                          title: "Delete account",
                          onTap: () {
                            _showDeleteAccountDialog(); // ✅ Gọi dialog xác nhận
                          }),
                      CustomTileItems(
                          leadingIcon: const Icon(
                            Icons.waving_hand_rounded,
                            size: 25,
                            color: Colors.white60,
                          ),
                          title: "Sign out",
                          onTap: () {
                            _auth.signOut();
                            userStorage.remove("name");
                            userStorage.remove("profileUrl");
                            userStorage.remove("uid");
                            Get.offAll(() => WelcomeScreen());
                          }),
                    ],
                    size),
              ]),
            ),
          ),
        ));
  }

  void addProfileModal() {
    Size size = MediaQuery.of(context).size;
    final ImagePicker picker = ImagePicker();

    void saveImage(File file) async {
      try {
        // ✅ Kiểm tra user đã đăng nhập
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          Get.snackbar(
            '❌ Lỗi',
            'Bạn chưa đăng nhập. Vui lòng đăng nhập lại.',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
          return;
        }
        
        Get.dialog(
          const Center(child: CircularProgressIndicator(color: primaryColor)),
          barrierDismissible: false,
        );

        String fileName = "${userStorage.read('phoneNumber')}_profilePic";
        Reference reference = storage.ref().child('images/$fileName');
        
        // ✅ Thêm metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );
        
        UploadTask uploadTask = reference.putFile(file, metadata);
        
        // ✅ Lắng nghe tiến trình upload
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
        }, onError: (error) {
          print('❌ Upload error: $error');
          Get.back();
          Get.snackbar(
            '❌ Lỗi upload',
            'Không thể tải ảnh lên: $error',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
        });
        
        TaskSnapshot storageTaskSnapshot = await uploadTask.whenComplete(() {});
        String downloadUrl = await storageTaskSnapshot.ref.getDownloadURL();
        
        final imageRef = users.doc(userStorage.read('uid'));
        await imageRef.update({
          'profileUrl': downloadUrl,
        });
        
        userStorage.write('profileUrl', downloadUrl);
        
        if (mounted) {
          Get.back(); // Close loading
          setState(() {}); // Refresh UI
          
          Get.snackbar(
            '✅ Thành công',
            'Đã cập nhật ảnh đại diện',
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      } catch (e) {
        print('❌ Save image error: $e');
        if (mounted) {
          Get.back();
          
          // ✅ Phân loại lỗi cụ thể
          String errorMessage = 'Không thể tải ảnh lên';
          if (e.toString().contains('unauthorized')) {
            errorMessage = 'Bạn không có quyền upload ảnh. Vui lòng đăng nhập lại.';
          } else if (e.toString().contains('network')) {
            errorMessage = 'Lỗi kết nối mạng. Vui lòng thử lại.';
          }
          
          Get.snackbar(
            '❌ Lỗi',
            errorMessage,
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            duration: Duration(seconds: 4),
          );
        }
      }
    }

    Future<void> _selectImage() async {
      try {
        Get.back(); // Đóng modal
        
        await Future.delayed(Duration(milliseconds: 500)); // ✅ Tăng delay
        
        final XFile? selectedImage = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512, // ✅ Giảm size
          maxHeight: 512,
          imageQuality: 80,
        );
        
        if (selectedImage == null) return;

        // ✅ BỎ ImageCropper - Dùng ảnh trực tiếp
        saveImage(File(selectedImage.path));
        
      } catch (e) {
        print('❌ Select image error: $e');
        if (mounted) {
          Get.snackbar(
            '❌ Lỗi',
            'Không thể chọn ảnh: $e',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      }
    }

    Future<void> _takeImage() async {
      try {
        Get.back(); // Đóng modal
        
        await Future.delayed(Duration(milliseconds: 500)); // ✅ Tăng delay
        
        final XFile? selectedImage = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
          preferredCameraDevice: CameraDevice.front,
        );
        
        if (selectedImage == null) return;

        // ✅ BỎ ImageCropper - Dùng ảnh trực tiếp
        saveImage(File(selectedImage.path));
        
      } catch (e) {
        print('❌ Take photo error: $e');
        if (mounted) {
          Get.snackbar(
            '❌ Lỗi',
            'Không thể chụp ảnh: $e',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      }
    }

    showModalBottomSheet(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(30), topLeft: Radius.circular(30)),
        ),
        context: context,
        builder: (context) {
          return IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    topLeft: Radius.circular(30)),
                color: backgroundColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Ảnh đại diện của bạn hiển thị với những người bạn.",
                      style: GoogleFonts.rubik(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    pfpmenuButtons(size, () {
                      _selectImage();
                    }, "Chọn từ thư viện", false),
                    pfpmenuButtons(size, () {
                      _takeImage();
                    }, "Chụp ảnh", false),
                    userStorage.read('profileUrl') != ""
                        ? pfpmenuButtons(size, () async {
                            try {
                              Get.back(); // Đóng modal trước
                              
                              Get.dialog(
                                const Center(child: CircularProgressIndicator(color: primaryColor)),
                                barrierDismissible: false,
                              );
                              
                              setState(() {
                                userStorage.write('profileUrl', "");
                              });
                              
                              final imageRef = users.doc(userStorage.read('uid'));
                              await imageRef.update({
                                'profileUrl': "",
                              });
                              
                              await storage
                                  .ref()
                                  .child(
                                      "images/${userStorage.read('phoneNumber')}_profilePic")
                                  .delete();
                              
                              Get.back(); // Close loading
                              
                              Get.snackbar(
                                '✅ Thành công',
                                'Đã xóa ảnh đại diện',
                                backgroundColor: Colors.green.withOpacity(0.8),
                                colorText: Colors.white,
                              );
                            } catch (e) {
                              Get.back();
                              Get.snackbar(
                                '❌ Lỗi',
                                'Không thể xóa ảnh: $e',
                                backgroundColor: Colors.red.withOpacity(0.8),
                                colorText: Colors.white,
                              );
                            }
                          }, "Xóa ảnh đại diện", true)
                        : const SizedBox(height: 0),
                    pfpmenuButtons(size, () => Get.back(), "Hủy", false),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget pfpmenuButtons(Size size, onTap, String text, bool isDelete) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 70,
        width: size.width,
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDelete ? Colors.red : Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget editField(
      String placeholder, onSaved, String initialValue, bool isEditable,
      {bool isRequired = true}) {
    Size size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      child: TextFormField(
        readOnly: !isEditable,
        autofocus: true,
        cursorColor: primaryColor,
        style: GoogleFonts.rubik(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: !isEditable ? Colors.grey[500] : Colors.white),
        initialValue: initialValue,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: GoogleFonts.rubik(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          filled: true,
          fillColor: !isEditable ? Colors.grey[700] : secondaryColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
        ),
        onSaved: onSaved,
        validator: (value) {
          if (!isRequired) return null;
          if (value == null || value.trim().isEmpty) {
            return "Field cannot be empty";
          }
          return null;
        },
      ),
    );
  }

  void modalSheet(String type) {
    Future<void> addName(String name) async {
      final user = _auth.currentUser;
      if (user != null) {
        final userRef = users.doc(userStorage.read('uid'));
        await userRef.update({
          'name': name,
        });
      }
    }

    final parts = _nameParts();
    String newFirst = parts[0];
    String newLast = parts[1];
    GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String newName = "";
    Size size = MediaQuery.of(context).size;
    showModalBottomSheet(
        backgroundColor: backgroundColor,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50), topRight: Radius.circular(50)),
        ),
        context: _scaffoldKey.currentContext!,
        builder: (modalContext) {
          return type == "phone"
              ? SizedBox(
                  height: size.height * 0.95,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 50,
                          height: 7,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: secondaryColor),
                        ),
                      ),
                      Expanded(
                          child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 50),
                              child: Text(
                                "Change phone number",
                                style: GoogleFonts.rubik(
                                  fontSize: 26,
                                  color: white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            editField(
                              "",
                              (value) {},
                              _storedPhoneNumber,
                              false,
                              isRequired: false,
                            ),
                            const SizedBox(height: 50),
                            Container(
                              width: size.width,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                color: Colors.grey[500],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 20),
                                child: Center(
                                  child: Text("Save",
                                      style: GoogleFonts.rubik(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: termsText)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                    ]),
                  ),
                )
              : SizedBox(
                  height: size.height * 0.95,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 50,
                          height: 7,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: secondaryColor),
                        ),
                      ),
                      Expanded(
                          child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 50),
                              child: Text(
                                "Edit your info",
                                style: GoogleFonts.rubik(
                                  fontSize: 26,
                                  color: white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            editField(
                              "First name",
                              (value) => newFirst = value.trim(),
                              newFirst,
                              true,
                            ),
                            const SizedBox(height: 20),
                            editField(
                              "Last name",
                              (value) => newLast = value.trim(),
                              newLast,
                              true,
                              isRequired: false,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: size.width,
                              child: TextButton(
                                  onPressed: () {
                                    if (formKey.currentState!.validate()) {
                                      formKey.currentState!.save();
                                      final composedName = [newFirst, newLast]
                                          .where((part) => part.isNotEmpty)
                                          .join(' ');
                                      addName(composedName);
                                      setState(() {
                                        userStorage.write('name', composedName);
                                      });
                                      Get.back();
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text("Save",
                                        style: GoogleFonts.rubik(
                                            textStyle: const TextStyle(
                                          color: black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 20,
                                        ))),
                                  )),
                            ),
                          ],
                        ),
                      ))
                    ]),
                  ),
                );
        });
  }

  Widget profilesPictureStack(double radius, Color color, AssetImage image) {
    return Stack(alignment: Alignment.center, children: [
      CircleAvatar(
        radius: radius + 8.5,
        backgroundColor: color,
        child: CircleAvatar(
            radius: radius + 6,
            backgroundColor: primaryColor,
            child: Container(
              height: (radius + 3) * 2,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )),
      ),
      CircleAvatar(
        radius: radius,
        backgroundColor: white,
        backgroundImage: image,
      ),
    ]);
  }

  Widget menuListItems(
      Icon icon, String title, List<CustomTileItems> children, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: termsText),
              ),
            ],
          ),
        ),
        Container(
            width: size.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: secondaryColor,
            ),
            child: ListView(
              controller: ScrollController(
                  initialScrollOffset: 0, keepScrollOffset: false),
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: children,
            )),
      ],
    );
  }

  // ✅ Widget mới hiển thị danh sách bạn bè thật
  Widget _buildWidgetsSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: secondaryColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Widget 1: New Widget
            Expanded(
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: backgroundColor,
                    border: Border.all(
                        width: 4,
                        color: const Color.fromARGB(166, 86, 86, 86))),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(alignment: Alignment.center, children: [
                        CircleAvatar(
                            radius: 28,
                            backgroundColor: primaryColor,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                  color: backgroundColor,
                                  shape: BoxShape.circle),
                            )),
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: termsText,
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white60,
                            size: 26,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        "New Widget",
                        style: GoogleFonts.rubik(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white60),
                      ),
                      Text(
                        "Pick a friend",
                        style: GoogleFonts.rubik(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: termsText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ✅ Widget 2: Everyone (hiển thị thật)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Navigate đến FriendsListScreen
                  Get.to(() => FriendsListScreen());
                },
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey.shade700,
                      border: Border.all(width: 4, color: termsText!)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isLoadingFriends
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ✅ Hiển thị avatar bạn bè thật
                              _buildFriendsAvatarStack(),
                              const SizedBox(height: 8),
                              Text(
                                "Everyone",
                                style: GoogleFonts.rubik(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70),
                              ),
                              Text(
                                "${_friendsList.length} Friend${_friendsList.length != 1 ? 's' : ''}", // ✅ Số bạn bè thật
                                style: GoogleFonts.rubik(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ✅ Widget hiển thị stack avatar bạn bè
  Widget _buildFriendsAvatarStack() {
    if (_friendsList.isEmpty) {
      // Nếu chưa có bạn bè
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade600,
        child: Icon(Iconsax.user, size: 20, color: Colors.grey[400]),
      );
    }

    // Lấy tối đa 3 bạn bè đầu tiên
    final displayFriends = _friendsList.take(3).toList();

    if (displayFriends.length == 1) {
      // 1 bạn bè
      return _buildSingleAvatar(displayFriends[0]);
    } else if (displayFriends.length == 2) {
      // 2 bạn bè
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(left: 25, child: _buildSingleAvatar(displayFriends[0])),
          Positioned(right: 25, child: _buildSingleAvatar(displayFriends[1])),
        ],
      );
    } else {
      // 3+ bạn bè
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(left: 40, child: _buildSingleAvatar(displayFriends[0])),
          Positioned(right: 40, child: _buildSingleAvatar(displayFriends[1])),
          _buildSingleAvatar(displayFriends[2]),
        ],
      );
    }
  }

  // ✅ Widget avatar đơn
  Widget _buildSingleAvatar(Users friend) {
    final hasProfileUrl =
        friend.profileUrl != null && friend.profileUrl!.isNotEmpty;
    final initials = _getInitials(friend.name ?? '');

    return Stack(alignment: Alignment.center, children: [
      CircleAvatar(
        radius: 21.5,
        backgroundColor: Colors.grey.shade700,
        child: CircleAvatar(
            radius: 19,
            backgroundColor: primaryColor,
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                  color: Colors.grey.shade700, shape: BoxShape.circle),
            )),
      ),
      CircleAvatar(
        radius: 13,
        backgroundColor: hasProfileUrl ? null : secondaryColor,
        backgroundImage: hasProfileUrl ? NetworkImage(friend.profileUrl!) : null,
        child: !hasProfileUrl
            ? Text(
                initials,
                style: GoogleFonts.rubik(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70),
              )
            : null,
      ),
    ]);
  }

  // ✅ Helper lấy initials từ tên
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // ✅ THÊM METHOD MỚI: Dialog xác nhận xóa account
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          '⚠️ Xác nhận xóa tài khoản',
          style: GoogleFonts.rubik(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động này sẽ:',
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            _buildWarningItem('❌ Xóa vĩnh viễn tài khoản'),
            _buildWarningItem('🖼️ Xóa toàn bộ ảnh đã đăng'),
            _buildWarningItem('👥 Xóa danh sách bạn bè'),
            _buildWarningItem('📱 Xóa ảnh đại diện'),
            SizedBox(height: 10),
            Text(
              'KHÔNG THỂ KHÔI PHỤC!',
              style: GoogleFonts.rubik(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Hủy',
              style: GoogleFonts.rubik(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteAccount();
            },
            child: Text(
              'XÓA VĨNH VIỄN',
              style: GoogleFonts.rubik(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.rubik(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ METHOD XÓA ACCOUNT HOÀN CHỈNH
  Future<void> _deleteAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Get.snackbar(
          '❌ Lỗi',
          'Không tìm thấy thông tin người dùng',
          backgroundColor: Colors.red,
          colorText: white,
        );
        return;
      }

      // ✅ Show loading
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 20),
                Text(
                  'Đang xóa tài khoản...',
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      final uid = currentUser.uid;
      final phoneNumber = userStorage.read('phoneNumber') ?? '';

      print('🗑️ Deleting account for UID: $uid');

      // ✅ BƯỚC 1: Xóa ảnh đại diện
      try {
        if (phoneNumber.isNotEmpty) {
          await storage
              .ref()
              .child("images/${phoneNumber}_profilePic")
              .delete();
          print('✅ Deleted profile picture');
        }
      } catch (e) {
        print('⚠️ Profile picture not found or already deleted: $e');
      }

      // ✅ BƯỚC 2: Xóa toàn bộ ảnh trong folder của user
      try {
        final folderRef = storage.ref().child("images/$uid");
        final listResult = await folderRef.listAll();
        
        for (var item in listResult.items) {
          try {
            await item.delete();
            print('✅ Deleted: ${item.fullPath}');
          } catch (e) {
            print('⚠️ Failed to delete ${item.fullPath}: $e');
          }
        }
        
        print('✅ Deleted user folder');
      } catch (e) {
        print('⚠️ User folder not found or already deleted: $e');
      }

      // ✅ BƯỚC 3: Xóa tất cả documents trong /images collection
      try {
        final imagesQuery = await FirebaseFirestore.instance
            .collection("images")
            .where('uid', isEqualTo: uid)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in imagesQuery.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('✅ Deleted ${imagesQuery.docs.length} image documents');
      } catch (e) {
        print('⚠️ Failed to delete image documents: $e');
      }

      // ✅ BƯỚC 4: Xóa khỏi friends array của tất cả bạn bè
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final friends = List<String>.from(userData?['friends'] ?? []);
          
          final batch = FirebaseFirestore.instance.batch();
          
          for (var friendUid in friends) {
            batch.update(
              FirebaseFirestore.instance.collection('users').doc(friendUid),
              {
                'friends': FieldValue.arrayRemove([uid])
              },
            );
          }
          
          await batch.commit();
          print('✅ Removed from ${friends.length} friends lists');
        }
      } catch (e) {
        print('⚠️ Failed to remove from friends: $e');
      }

      // ✅ BƯỚC 5: Xóa tất cả friend requests liên quan
      try {
        // Xóa requests mà user là sender
        final sentRequestsQuery = await FirebaseFirestore.instance
            .collection('friendRequests')
            .where('senderId', isEqualTo: uid)
            .get();
        
        // Xóa requests mà user là receiver
        final receivedRequestsQuery = await FirebaseFirestore.instance
            .collection('friendRequests')
            .where('receiverId', isEqualTo: uid)
            .get();
        
        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in sentRequestsQuery.docs) {
          batch.delete(doc.reference);
        }
        
        for (var doc in receivedRequestsQuery.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('✅ Deleted friend requests');
      } catch (e) {
        print('⚠️ Failed to delete friend requests: $e');
      }

      // ✅ BƯỚC 6: Xóa user document trong Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete();
        print('✅ Deleted user document');
      } catch (e) {
        print('⚠️ Failed to delete user document: $e');
      }

      // ✅ BƯỚC 7: Xóa Firebase Auth account
      try {
        await currentUser.delete();
        print('✅ Deleted Firebase Auth account');
      } catch (e) {
        print('⚠️ Failed to delete auth account: $e');
        
        // Nếu lỗi là requires-recent-login, yêu cầu đăng nhập lại
        if (e.toString().contains('requires-recent-login')) {
          Get.back(); // Close loading
          
          Get.snackbar(
            '⚠️ Yêu cầu xác thực',
            'Vui lòng đăng xuất và đăng nhập lại để xóa tài khoản',
            backgroundColor: Colors.orange,
            colorText: white,
            duration: Duration(seconds: 4),
          );
          
          // Đăng xuất
          await _auth.signOut();
          userStorage.erase();
          Get.offAll(() => WelcomeScreen());
          return;
        }
      }

      // ✅ BƯỚC 8: Xóa local storage
      userStorage.erase();

      // ✅ Close loading
      Get.back();

      // ✅ Hiển thị thông báo thành công
      Get.snackbar(
        '✅ Thành công',
        'Tài khoản đã được xóa vĩnh viễn',
        backgroundColor: Colors.green,
        colorText: white,
        duration: Duration(seconds: 2),
      );

      // ✅ Chuyển về WelcomeScreen
      await Future.delayed(Duration(seconds: 1));
      Get.offAll(() => WelcomeScreen());
      
    } catch (e) {
      print('❌ Delete account error: $e');
      
      Get.back(); // Close loading
      
      Get.snackbar(
        '❌ Lỗi',
        'Không thể xóa tài khoản: $e',
        backgroundColor: Colors.red,
        colorText: white,
        duration: Duration(seconds: 4),
      );
    }
  }
}
