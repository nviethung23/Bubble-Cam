import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('BubbleCam • Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          const SizedBox(height: 12),
          Obx(() => FilledButton(
            onPressed: auth.loading.value ? null : () => auth.signInEmail(email.text.trim(), pass.text),
            child: auth.loading.value ? const CircularProgressIndicator() : const Text('Đăng nhập'),
          )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata),
            onPressed: () => auth.signInGoogle(),
            label: const Text('Đăng nhập Google'),
          ),
          TextButton(
            onPressed: () => Get.to(() => const SignUpPage()),
            child: const Text('Chưa có tài khoản? Đăng ký'),
          )
        ]),
      ),
    );
  }
}
