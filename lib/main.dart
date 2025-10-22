import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // nếu đang dùng flutterfire configure

import 'src/services/auth_service.dart';
import 'src/services/post_service.dart';
import 'src/services/storage_service.dart';
import 'src/controllers/auth_controller.dart';
import 'src/controllers/feed_controller.dart';
import 'src/controllers/upload_controller.dart';
import 'src/ui/auth/sign_in_page.dart';
import 'src/ui/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👉 Quan trọng: chỉ init khi CHƯA có app nào
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
      // Nếu bạn dùng "plan B" không có firebase_options.dart thì dùng:
      // await Firebase.initializeApp();
    );
  } else {
    // Lấy instance hiện có (tránh ném lỗi)
    Firebase.app();
  }

  // DI
  final authService = AuthService();
  final postService = PostService();
  final storageService = StorageService();

  Get.put(AuthController(authService));
  Get.put(FeedController(postService));
  Get.put(UploadController(storage: storageService, posts: postService));

  runApp(const BubbleCamApp());
}

class BubbleCamApp extends StatelessWidget {
  const BubbleCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BubbleCam',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return s.hasData ? const HomePage() : const SignInPage();
        },
      ),
    );
  }
}
