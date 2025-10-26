import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/model/firestore.dart';
import '/screens/screens.dart';
import '../../utils/colors.dart';
import '../../firebase/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage extends StatefulWidget {
  SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  GetStorage userStorage = GetStorage();
  Users userInstance = Users();
  final _formKey = GlobalKey<FormState>();
  String fullName = "";
  final FirebaseService _fb = FirebaseService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance; // ✅ THÊM

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
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
                  Text("What's your name?",
                      style: GoogleFonts.rubik(
                        textStyle: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                  const SizedBox(height: 30),
                  nameField('First Name', (value) => fullName += value),
                  const SizedBox(height: 20),
                  nameField('Last Name', (value) => fullName += " $value"),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: size.width,
                child: TextButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        try {
                          final phoneNumber = userStorage.read('phoneNumber') ?? '';
                          
                          // ✅ FIX: Lấy uid từ FirebaseAuth (đã login ở phone_verification)
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? 
                                      _fb.currentUser?.uid;
                          
                          if (uid != null) {
                            // ✅ FIX: Update document với merge (KHÔNG lưu field 'uid')
                            await firestore.collection('users').doc(uid).set({
                              'name': fullName,
                              'profileUrl': '',
                              'phoneNumber': phoneNumber,
                              'friends': [], // ✅ THÊM
                              'blockedUsers': [], // ✅ THÊM
                            }, SetOptions(merge: true));

                            userStorage.write('uid', uid);
                            userStorage.write('name', fullName);
                            userStorage.write('profileUrl', '');

                            userInstance.updateInfo(Users(
                              name: fullName,
                              phoneNumber: phoneNumber,
                            ));

                            Get.offAll(() => MainScreen());
                          } else {
                            // Fallback: Chưa có uid
                            userStorage.write('name', fullName);
                            Get.offAll(() => MainScreen());
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign up failed: $e')),
                          );
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
                      child: Text("Continue →",
                          style: GoogleFonts.rubik(
                              textStyle: const TextStyle(
                            color: black,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ))),
                    )),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  TextFormField nameField(String placeholder, onSaved) {
    return TextFormField(
      cursorColor: primaryColor,
      onSaved: onSaved,
      style: GoogleFonts.rubik(
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      autofocus: true,
      validator: (value) {
        if (value!.isEmpty) {
          return "Field cannot be empty";
        }
        return null;
      },
      decoration: InputDecoration(
        hintStyle: GoogleFonts.rubik(
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        hintText: placeholder,
        filled: true,
        fillColor: secondaryColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
      ),
    );
    
  }
  
}