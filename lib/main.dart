import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get_storage/get_storage.dart';
import '/screens/screens.dart';
import 'globals.dart' as globals;
import 'utils/colors.dart';

import 'package:get/get.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  globals.cameras = await availableCameras();
  FocusManager.instance.primaryFocus?.unfocus();
  await Firebase.initializeApp();
  
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: backgroundColor,
    ));
  } else if (Platform.isIOS) {
    CupertinoNavigationBar(backgroundColor: backgroundColor);
  }
  await GetStorage.init();

  final user = FirebaseAuth.instance.currentUser;
  
  runApp(MyApp(isLoggedIn: user != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return GetMaterialApp(
      title: 'BubbleCam',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: backgroundColor,
      ),
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? MainScreen() : WelcomeScreen(),
    );
  }
}
