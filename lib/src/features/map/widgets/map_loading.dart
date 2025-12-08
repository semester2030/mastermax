import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MapLoading extends StatelessWidget {
  const MapLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الخريطة...',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 