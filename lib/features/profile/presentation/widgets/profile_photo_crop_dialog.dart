import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';

/// Interactive modal allowing users to zoom, reposition, rotate, and crop their profile photo.
class ProfilePhotoCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfilePhotoCropDialog({
    super.key,
    required this.imageBytes,
  });

  /// Static helper to display the crop dialog and return processed image bytes.
  static Future<Uint8List?> show(BuildContext context, Uint8List bytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfilePhotoCropDialog(imageBytes: bytes),
    );
  }

  @override
  State<ProfilePhotoCropDialog> createState() => _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<ProfilePhotoCropDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  int _quarterTurns = 0;
  bool _isProcessing = false;

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _confirmAndCrop() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.imageBytes);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final croppedBytes = byteData.buffer.asUint8List();
        if (mounted) {
          Navigator.pop(context, croppedBytes);
        }
      } else {
        if (mounted) {
          Navigator.pop(context, widget.imageBytes);
        }
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, widget.imageBytes);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('editAndCropPhoto'),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Crop Box with circular mask
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                width: 280.r,
                height: 280.r,
                color: Colors.black87,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Capture area
                    RepaintBoundary(
                      key: _cropKey,
                      child: ClipOval(
                        child: SizedBox(
                          width: 250.r,
                          height: 250.r,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            child: RotatedBox(
                              quarterTurns: _quarterTurns,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Circular overlay guide
                    IgnorePointer(
                      child: Container(
                        width: 250.r,
                        height: 250.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceWhite.withValues(alpha: 0.8),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Rotation & Reset Tools
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _rotate,
                  icon: const Icon(Icons.rotate_right_rounded),
                  label: Text(context.tr('rotatePhoto')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                  ),
                ),
                SizedBox(width: 16.w),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(context.tr('resetCrop')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Actions: Confirm & Cancel
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(context.tr('cancel')),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmAndCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: AppColors.surfaceWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surfaceWhite,
                            ),
                          )
                        : Text(context.tr('confirmCrop')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
