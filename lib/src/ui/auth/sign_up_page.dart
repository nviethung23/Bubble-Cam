import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password (>=6)'), obscureText: true),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await auth.signUpEmail(email.text.trim(), pass.text);
              Get.back();
            },
            child: const Text('Đăng ký'),
          ),
        ]),
      ),
    );
  }
}
