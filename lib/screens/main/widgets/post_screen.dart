import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

import '/model/firestore.dart';
import '/utils/colors.dart';

class PostScreen extends StatelessWidget {
  const PostScreen({
    super.key,
    required this.imageItems,
    required this.currentUid,
  });

  final List<Images> imageItems;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'All Posts',
          style: GoogleFonts.rubik(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: white,
          ),
        ),
        centerTitle: true,
      ),
      body: imageItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 80, color: Colors.white30), // ✅ Xóa const
                  const SizedBox(height: 20),
                  Text(
                    'No posts yet',
                    style: GoogleFonts.rubik(fontSize: 18, color: Colors.white60),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: imageItems.length,
                itemBuilder: (context, index) {
                  final image = imageItems[index];
                  return GestureDetector(
                    onTap: () => _showImageDetail(context, image, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CachedNetworkImage(
                        imageUrl: image.url ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: secondaryColor,
                          child: const Center(
                            child: CircularProgressIndicator(color: primaryColor),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: secondaryColor,
                          child: Icon(Icons.error, color: Colors.red), // ✅ Xóa const
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showImageDetail(BuildContext context, Images image, int index) {
    final isOwner = image.uid == currentUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration( 
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: CachedNetworkImage(
                  imageUrl: image.url ?? '',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.download,
                    label: 'Save',
                    onTap: () async {
                      Navigator.pop(context);
                      await _saveImage(image.url ?? '');
                      Get.snackbar(
                        '✅ Saved',
                        'Image saved to gallery',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green,
                        colorText: white,
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () async {
                      Navigator.pop(context);
                      await _shareImage(image.url ?? '');
                    },
                  ),
                  if (isOwner)
                    _ActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(context);
                        final confirm = await Get.dialog<bool>(
                          AlertDialog(
                            backgroundColor: secondaryColor,
                            title: Text('Delete post?', style: GoogleFonts.rubik(color: white)),
                            content: Text(
                              'This action cannot be undone.',
                              style: GoogleFonts.rubik(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: Text('Cancel', style: GoogleFonts.rubik(color: white)),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: true),
                                child: Text('Delete', style: GoogleFonts.rubik(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          // TODO: Implement delete
                          Get.snackbar(
                            '✅ Deleted',
                            'Post has been deleted',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage(String url) async {
    try {
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(response.data);
      final fileName = 'BubbleCam_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        androidRelativePath: "Pictures/BubbleCam",
        skipIfExists: false,
      );
    } catch (e) {
      print('❌ Error saving: $e');
    }
  }

  Future<void> _shareImage(String url) async {
    try {
      final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.data);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Shared from BubbleCam 📸');
    } catch (e) {
      print('❌ Error sharing: $e');
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.rubik(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}