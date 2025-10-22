import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/upload_controller.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});
  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final caption = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final up = Get.find<UploadController>();
    final auth = Get.find<AuthController>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: caption, decoration: const InputDecoration(labelText: 'Caption (tuỳ chọn)')),
          const SizedBox(height: 16),
          Obx(() => FilledButton.icon(
                onPressed: up.uploading.value
                    ? null
                    : () async {
                        await up.captureAndUpload(
                            uid: auth.uid!,
                            caption: caption.text.trim().isEmpty
                                ? null
                                : caption.text.trim());
                        caption.clear();
                      },
                icon: const Icon(Icons.camera_alt),
                label: up.uploading.value
                    ? const Text('Đang tải...')
                    : const Text('Chụp & đăng'),
              )),
          const SizedBox(height: 16),
          if (up.lastUrl != null) const Text('Đã up xong!')
        ],
      ),
    );
  }
}
