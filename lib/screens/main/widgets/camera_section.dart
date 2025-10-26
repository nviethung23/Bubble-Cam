import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '/utils/colors.dart';

class CameraSection extends StatelessWidget {
  const CameraSection({
    super.key,
    required this.size,
    required this.controller,
    required this.initializeControllerFuture,
    required this.isFlashToggled,
    required this.onToggleFlash,
    required this.onTakePicture,
    required this.onSwitchCamera,
    required this.onTapDown,
    required this.onHistoryTap,
    required this.isPreviewPaused,
  });

  final Size size;
  final CameraController? controller;
  final Future<void>? initializeControllerFuture;
  final bool isFlashToggled;
  final VoidCallback onToggleFlash;
  final VoidCallback onTakePicture;
  final VoidCallback onSwitchCamera;
  final void Function(TapDownDetails) onTapDown;
  final VoidCallback onHistoryTap;
  final bool isPreviewPaused;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: size.width,
          height: size.width,
          child: FutureBuilder<void>(
            future: initializeControllerFuture,
            builder: (context, snapshot) {
              final bool ready = snapshot.connectionState == ConnectionState.done &&
                  controller?.value.isInitialized == true &&
                  !isPreviewPaused;
              if (ready) {
                return GestureDetector(
                  onTapDown: onTapDown,
                  onDoubleTap: onSwitchCamera,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(75),
                    child: SizedBox(
                      width: size.width,
                      height: size.width,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller!.value.previewSize!.height,
                          height: controller!.value.previewSize!.width,
                          child: CameraPreview(controller!),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(75),
                child: Container(
                  width: size.width,
                  height: size.width,
                  color: black,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40).copyWith(top: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onPressed: onToggleFlash,
                icon: Icon(
                  isFlashToggled ? Iconsax.flash_15 : Iconsax.flash_1,
                  size: 40,
                  color: isFlashToggled ? primaryColor : null,
                ),
              ),
              TextButton(
                onPressed: onTakePicture,
                style: TextButton.styleFrom(
                  backgroundColor: white,
                  shape: const CircleBorder(
                    side: BorderSide(
                      width: 5,
                      color: primaryColor,
                      strokeAlign: 3,
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(""),
                ),
              ),
              IconButton(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onPressed: onSwitchCamera,
                icon: const Icon(Icons.flip_camera_android_outlined, size: 40),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: onHistoryTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "History",
                    style: GoogleFonts.rubik(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Iconsax.arrow_down_1, size: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
