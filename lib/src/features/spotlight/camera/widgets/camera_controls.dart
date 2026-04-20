import 'package:flutter/material.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/theme/app_colors.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onCapture;
  final bool isProcessing;

  const CameraControls({
    required this.onCapture, required this.isProcessing, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.transparent,
            ColorUtils.withOpacity(AppColors.textPrimary, 0.5),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // زر الإلغاء
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.white, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // زر التقاط الصورة
          GestureDetector(
            onTap: isProcessing ? null : onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 4),
                color: isProcessing ? AppColors.textSecondary : AppColors.white,
              ),
              child: isProcessing
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : const Icon(Icons.camera, size: 36, color: AppColors.textPrimary),
            ),
          ),

          // زر تبديل الكاميرا
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: AppColors.white, size: 32),
            onPressed: () {
              // تبديل الكاميرا الأمامية/الخلفية
            },
          ),
        ],
      ),
    );
  }
} 