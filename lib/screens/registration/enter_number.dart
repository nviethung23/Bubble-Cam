import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';

import '/screens/registration/enter_otp.dart';
import '/utils/colors.dart';
import '/utils/phone_helper.dart';

class EnterNumber extends StatefulWidget {
  final bool isLogin;
  
  const EnterNumber({super.key, this.isLogin = false});

  @override
  State<EnterNumber> createState() => _EnterNumberState();
}

class _EnterNumberState extends State<EnterNumber> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String phoneNumber = "";
  final GetStorage userStorage = GetStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isChecking = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 50),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isLogin 
                          ? "Đăng nhập bằng SĐT" 
                          : "Số điện thoại của bạn?",
                      style: GoogleFonts.rubik(
                        textStyle: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Nhập số bắt đầu bằng 0 hoặc +84",
                      style: GoogleFonts.rubik(
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      cursorColor: primaryColor,
                      onChanged: (value) {
                        if (value.isNotEmpty && !value.startsWith('0') && !value.startsWith('+')) {
                          _phoneController.text = '0$value';
                          _phoneController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _phoneController.text.length),
                          );
                        }
                      },
                      onSaved: (value) {
                        phoneNumber = PhoneHelper.normalize(value!.trim());
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Vui lòng nhập số điện thoại";
                        }
                        
                        final normalized = PhoneHelper.normalize(value.trim());
                        
                        if (!PhoneHelper.isValidVietnamesePhone(normalized)) {
                          return "Số điện thoại không hợp lệ";
                        }
                        
                        return null;
                      },
                      style: GoogleFonts.rubik(
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintStyle: GoogleFonts.rubik(
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Colors.white54,
                          ),
                        ),
                        hintText: "Vui lòng nhập SDT",
                        filled: true,
                        fillColor: secondaryColor,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        helperText: _phoneController.text.isNotEmpty
                            ? "Sẽ lưu: ${PhoneHelper.normalize(_phoneController.text)}"
                            : null,
                        helperStyle: GoogleFonts.rubik(
                          fontSize: 12,
                          color: primaryColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: size.width,
                  child: TextButton(
                    onPressed: _isChecking
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              
                              setState(() => _isChecking = true);
                              
                              try {
                                // ✅ LƯU SĐT TRƯỚC (để EnterOTP dùng)
                                userStorage.write('phoneNumber', phoneNumber);
                                
                                // ✅ CHUYỂN SANG OTP LUÔN (không check Firestore)
                                Get.snackbar(
                                  '✅ Hợp lệ',
                                  'Đang gửi OTP đến ${PhoneHelper.format(phoneNumber)}...',
                                  backgroundColor: Colors.green.withOpacity(0.8),
                                  colorText: Colors.white,
                                  duration: const Duration(seconds: 2),
                                );
                                
                                await Future.delayed(const Duration(milliseconds: 500));
                                Get.to(() => EnterOTP(isLogin: widget.isLogin));
                                
                              } catch (e) {
                                print('❌ Error: $e');
                                Get.snackbar(
                                  '❌ Lỗi',
                                  'Không thể tiếp tục: $e',
                                  backgroundColor: Colors.red.withOpacity(0.8),
                                  colorText: Colors.white,
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isChecking = false);
                                }
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: _isChecking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Tiếp tục →",
                              style: GoogleFonts.rubik(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
