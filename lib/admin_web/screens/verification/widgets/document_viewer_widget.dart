import 'package:flutter/material.dart';

import '../../../../src/core/theme/app_colors.dart';
import 'document_viewer_open.dart';

/// فتح مستند التحقق (PDF) مع جلسة Firebase على الويب لتفادي 403 عند «فتح الرابط خام».
class DocumentViewerWidget extends StatefulWidget {
  final String documentUrl;
  final String? label;

  const DocumentViewerWidget({
    super.key,
    required this.documentUrl,
    this.label,
  });

  @override
  State<DocumentViewerWidget> createState() => _DocumentViewerWidgetState();
}

class _DocumentViewerWidgetState extends State<DocumentViewerWidget> {
  bool _loading = false;

  Future<void> _open(BuildContext context) async {
    if (widget.documentUrl.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد رابط للمستند'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await openVerificationDocumentUrl(widget.documentUrl);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح المستند'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح المستند: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : () => _open(context),
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.picture_as_pdf, size: 20),
      label: Text(_loading ? 'جاري التحميل…' : (widget.label ?? 'عرض المستند')),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    );
  }
}
