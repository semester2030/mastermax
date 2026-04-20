import 'package:flutter/material.dart';
import '../../../../src/core/theme/app_colors.dart';
import '../../../services/admin_verification_service.dart' show AdminVerificationRequest;

class VerificationRequestCard extends StatelessWidget {
  final AdminVerificationRequest request;
  final VoidCallback onViewDocument;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const VerificationRequestCard({
    super.key,
    required this.request,
    required this.onViewDocument,
    required this.onApprove,
    required this.onReject,
  });

  bool get _hasDocumentUrl => request.documentUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    request.userType.arabicName.substring(0, 1),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معرف: ${request.userId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        request.userType.arabicName,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        'تاريخ الطلب: ${_formatDate(request.submittedAt)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    request.status == 'pending' ? 'معلق' : request.status == 'approved' ? 'مقبول' : 'مرفوض',
                  ),
                  backgroundColor: request.isPending
                      ? AppColors.primaryLight
                      : request.isApproved
                          ? AppColors.success.withValues(alpha: 0.2)
                          : AppColors.error.withValues(alpha: 0.2),
                ),
              ],
            ),
            if (!request.isPending && request.reviewedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'تاريخ المراجعة: ${_formatDate(request.reviewedAt!)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
            if (_hasDocumentUrl || request.isPending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_hasDocumentUrl)
                    OutlinedButton.icon(
                      onPressed: onViewDocument,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(request.isPending ? 'عرض الملف' : 'عرض الملف مرة أخرى'),
                    ),
                  if (request.isPending) ...[
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('قبول'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('رفض'),
                    ),
                  ],
                ],
              ),
            ],
            if (request.rejectionReason != null && request.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'سبب الرفض: ${request.rejectionReason}',
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
