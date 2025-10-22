import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(auth.uid ?? ''),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => auth.signOut(), child: const Text('Đăng xuất')),
        ],
      ),
    );
  }
}
