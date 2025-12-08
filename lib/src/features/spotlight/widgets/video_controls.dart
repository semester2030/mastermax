import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class VideoControls extends StatelessWidget {
  final int likes;
  final int views;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onComment;

  const VideoControls({
    required this.likes, required this.views, required this.onLike, required this.onShare, required this.onComment, super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControlButton(
          icon: Icons.favorite,
          label: _formatNumber(likes),
          onTap: onLike,
        ),
        const SizedBox(height: 16),
        _buildControlButton(
          icon: Icons.remove_red_eye,
          label: _formatNumber(views),
          onTap: () {},
        ),
        const SizedBox(height: 16),
        _buildControlButton(
          icon: Icons.comment,
          label: 'تعليق',
          onTap: onComment,
        ),
        const SizedBox(height: 16),
        _buildControlButton(
          icon: Icons.share,
          label: 'مشاركة',
          onTap: onShare,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(Colors.black, 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.spotlightBorder,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: ColorUtils.withOpacity(AppColors.textLight, 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    }
    return number.toString();
  }
} 