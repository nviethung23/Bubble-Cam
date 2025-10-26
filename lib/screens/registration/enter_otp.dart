import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';

import '/screens/screens.dart';
import '/utils/colors.dart';
import '/utils/phone_helper.dart';

class EnterOTP extends StatefulWidget {
  final bool isLogin;
  
  const EnterOTP({super.key, this.isLogin = false});

  @override
  State<EnterOTP> createState() => _EnterOTPState();
}

class _EnterOTPState extends State<EnterOTP> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage userStorage = GetStorage();
  
  String _verificationId = '';
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _auth.setSettings(
      appVerificationDisabledForTesting: true,
      forceRecaptchaFlow: false,
    );
    _sendOTP();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _sendOTP() async {
    final phoneNumber = userStorage.read('phoneNumber');
    if (phoneNumber == null) {
      Get.snackbar('❌ Lỗi', 'Không tìm thấy số điện thoại');
      Get.back();
      return;
    }

    print('📱 Sending OTP to: $phoneNumber');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto verification completed');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.code} - ${e.message}');
          
          String errorMsg = 'Xác thực thất bại';
          if (e.code == 'invalid-phone-number') {
            errorMsg = 'Số điện thoại không hợp lệ';
          } else if (e.code == 'too-many-requests') {
            errorMsg = 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
          } else if (e.message != null) {
            errorMsg = e.message!;
          }
          
          Get.snackbar(
            '❌ Lỗi',
            errorMsg,
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ Code sent! VerificationId: $verificationId');
          setState(() {
            _verificationId = verificationId;
          });
          _startResendTimer();
          
          Get.snackbar(
            '✅ Đã gửi',
            'Mã OTP đã được gửi đến ${PhoneHelper.format(phoneNumber)}',
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ Auto retrieval timeout');
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      print('❌ Error sending OTP: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Không thể gửi mã OTP: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _verifyOTP() async {
    if (_verificationId.isEmpty) {
      Get.snackbar(
        '❌ Lỗi',
        'Chưa nhận được mã xác thực. Vui lòng gửi lại.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      print('❌ Verification error: ${e.code} - ${e.message}');
      
      String errorMsg = 'Xác thực thất bại';
      if (e.code == 'invalid-verification-code') {
        errorMsg = 'Mã OTP không đúng';
      } else if (e.code == 'session-expired') {
        errorMsg = 'Mã OTP đã hết hạn. Vui lòng gửi lại.';
      } else if (e.message != null) {
        errorMsg = e.message!;
      }
      
      Get.snackbar(
        '❌ Lỗi',
        errorMsg,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      
      setState(() => _isVerifying = false);
    } catch (e) {
      print('❌ Unexpected error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Đã xảy ra lỗi: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final phoneNumber = userStorage.read('phoneNumber');

      print('✅ Signed in! UID: $uid');

      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        print('✅ Existing user - logging in');
        userStorage.write('uid', uid);
        
        final userData = userDoc.data();
        if (userData != null) {
          userStorage.write('name', userData['name'] ?? '');
          userStorage.write('profileUrl', userData['profileUrl'] ?? '');
        }
        
        Get.offAll(() => MainScreen());
      } else {
        print('✅ New user - creating document');
        await _firestore.collection('users').doc(uid).set({
          'name': '',
          'profileUrl': '',
          'phoneNumber': phoneNumber,
          'friends': [],
          'blockedUsers': [],
        });
        
        userStorage.write('uid', uid);
        Get.offAll(() => SignupPage());
      }
    } catch (e) {
      print('❌ Sign in error: $e');
      Get.snackbar(
        '❌ Lỗi',
        'Đăng nhập thất bại: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);
    await _sendOTP();
    setState(() => _isResending = false);
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = userStorage.read('phoneNumber') ?? '';
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea( // ✅ THÊM SafeArea
        child: SingleChildScrollView( // ✅ THÊM scroll
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 
                      MediaQuery.of(context).padding.top - 
                      kToolbarHeight - 40, // ✅ Trừ AppBar + padding
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.message_outlined,
                            size: 50, // ✅ GIẢM size từ 60 → 50
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20), // ✅ GIẢM từ 30 → 20
                        
                        // Title
                        Text(
                          'Xác thực OTP',
                          style: GoogleFonts.rubik(
                            fontSize: 24, // ✅ GIẢM từ 28 → 24
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8), // ✅ GIẢM từ 10 → 8
                        
                        // Description
                        Text(
                          'Nhập mã 6 số đã gửi đến\n${PhoneHelper.format(phoneNumber)}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rubik(
                            fontSize: 13, // ✅ GIẢM từ 14 → 13
                            color: Colors.white54,
                          ),
                        ),
                        
                        // ✅ TEST MODE BANNER
                        if (phoneNumber == '+84584222383')
                          Container(
                            margin: const EdgeInsets.only(top: 12), // ✅ GIẢM từ 15 → 12
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8, // ✅ GIẢM padding
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 18, // ✅ GIẢM từ 20 → 18
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '🧪 Test: Code 123456',
                                  style: GoogleFonts.rubik(
                                    fontSize: 12, // ✅ GIẢM từ 13 → 12
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 30), // ✅ GIẢM từ 40 → 30
                        
                        // OTP Input
                        TextFormField(
                          controller: _otpController,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          cursorColor: primaryColor,
                          style: GoogleFonts.rubik(
                            fontSize: 28, // ✅ GIẢM từ 32 → 28
                            fontWeight: FontWeight.bold,
                            letterSpacing: 16, // ✅ GIẢM từ 20 → 16
                            color: Colors.white,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '------',
                            hintStyle: GoogleFonts.rubik(
                              fontSize: 28, // ✅ GIẢM từ 32 → 28
                              letterSpacing: 16, // ✅ GIẢM từ 20 → 16
                              color: Colors.white24,
                            ),
                            filled: true,
                            fillColor: secondaryColor,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, // ✅ THÊM padding
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length != 6) {
                              return 'Vui lòng nhập đủ 6 số';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20), // ✅ GIẢM từ 30 → 20
                        
                        // Resend Button
                        _resendTimer > 0
                            ? Text(
                                'Gửi lại mã sau $_resendTimer giây',
                                style: GoogleFonts.rubik(
                                  color: Colors.white54,
                                  fontSize: 13, // ✅ GIẢM từ 14 → 13
                                ),
                              )
                            : TextButton(
                                onPressed: _isResending ? null : _resendOTP,
                                child: _isResending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: primaryColor,
                                        ),
                                      )
                                    : Text(
                                        'Gửi lại mã OTP',
                                        style: GoogleFonts.rubik(
                                          color: primaryColor,
                                          fontSize: 15, // ✅ GIẢM từ 16 → 15
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                              ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20), // ✅ THÊM spacing
                  
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isVerifying
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _verifyOTP();
                              }
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: _isVerifying
                            ? Colors.grey
                            : primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14), // ✅ GIẢM từ 15 → 14
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Xác thực',
                              style: GoogleFonts.rubik(
                                color: Colors.black,
                                fontSize: 17, // ✅ GIẢM từ 18 → 17
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}