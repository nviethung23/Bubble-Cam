import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/screens/screens.dart';
import '/screens/registration/enter_number.dart';
import '/screens/registration/signup_page.dart';
import '../../utils/colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GetStorage userStorage = GetStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  bool _isLoading = false;

  // ✅ Đăng nhập bằng Google
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // 1. Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }

      // 2. Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      final User? user = userCredential.user;
      
      if (user == null) {
        throw Exception('User is null after Google Sign-In');
      }

      // 5. Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        // ✅ User đã tồn tại → Lưu vào storage và vào MainScreen
        final data = userDoc.data()!;
        userStorage.write('uid', user.uid);
        userStorage.write('name', data['name'] ?? user.displayName ?? '');
        userStorage.write('profileUrl', data['profileUrl'] ?? user.photoURL ?? '');
        userStorage.write('phoneNumber', data['phoneNumber'] ?? '');
        
        Get.offAll(() => MainScreen());
      } else {
        // ✅ User mới → Tạo document và vào SignupPage để nhập tên
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'profileUrl': user.photoURL ?? '',
          'phoneNumber': user.phoneNumber ?? '',
        });
        
        userStorage.write('uid', user.uid);
        userStorage.write('name', user.displayName ?? '');
        userStorage.write('profileUrl', user.photoURL ?? '');
        userStorage.write('phoneNumber', user.phoneNumber ?? '');
        
        // Nếu chưa có tên, yêu cầu nhập
        if (user.displayName == null || user.displayName!.isEmpty) {
          Get.offAll(() => SignupPage());
        } else {
          Get.offAll(() => MainScreen());
        }
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Không thể đăng nhập: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Đăng nhập bằng SĐT
  void _signInWithPhone() {
    Get.to(() => EnterNumber(isLogin: true));
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Logo + Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Iconsax.heart_circle5,
                    color: primaryColor,
                    size: 40,
                  ),
                  Text(
                    "BubbleCam",
                    style: GoogleFonts.rubik(
                      textStyle: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              
              Text(
                "Đăng nhập để tiếp tục",
                textAlign: TextAlign.center,
                style: GoogleFonts.rubik(
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // ✅ Đăng nhập bằng Google
              _isLoading
                  ? const CircularProgressIndicator(color: primaryColor)
                  : Column(
                      children: [
                        // Google Sign-In Button
                        SizedBox(
                          width: size.width,
                          child: OutlinedButton.icon(
                            onPressed: _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: const BorderSide(color: secondaryColor, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: Image.asset(
                              'assets/google_logo.png', // ✅ Thêm logo Google vào assets
                              height: 24,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.mail, color: Colors.white);
                              },
                            ),
                            label: Text(
                              "Đăng nhập bằng Google",
                              style: GoogleFonts.rubik(
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // OR Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white24)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                "HOẶC",
                                style: GoogleFonts.rubik(
                                  fontSize: 12,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white24)),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Phone Sign-In Button
                        SizedBox(
                          width: size.width,
                          child: TextButton.icon(
                            onPressed: _signInWithPhone,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(
                              Iconsax.call,
                              color: Colors.black,
                              size: 20,
                            ),
                            label: Text(
                              "Đăng nhập bằng SĐT",
                              style: GoogleFonts.rubik(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              
              const Spacer(),
              
              // ✅ Chuyển sang đăng ký
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Chưa có tài khoản? ",
                    style: GoogleFonts.rubik(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.to(() => EnterNumber(isLogin: false)),
                    child: Text(
                      "Đăng ký",
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}