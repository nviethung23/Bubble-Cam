import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/post_service.dart';

class UploadController extends GetxController {
  final StorageService storage;
  final PostService posts;
  final _picker = ImagePicker();

  UploadController({required this.storage, required this.posts});

  RxBool uploading = false.obs;
  RxString? lastUrl;

  Future<void> captureAndUpload({required String uid, String? caption}) async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (x == null) return;
    uploading.value = true;
    try {
      final file = File(x.path);
      final url = await storage.uploadImage(file, 'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await posts.createPost(userId: uid, imageUrl: url, caption: caption);
      lastUrl = RxString(url);
    } finally {
      uploading.value = false;
    }
  }
}
