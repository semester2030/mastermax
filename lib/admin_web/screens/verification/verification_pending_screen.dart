import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/features/auth/providers/auth_state.dart';
import '../../../src/core/theme/app_colors.dart';
import '../../services/admin_verification_service.dart';
import 'widgets/verification_request_card.dart';
import 'widgets/document_viewer_widget.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final AdminVerificationService _service = AdminVerificationService();
  List<AdminVerificationRequest> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getPendingRequests();
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(AdminVerificationRequest request) async {
    final authState = context.read<AuthState>();
    final reviewerId = authState.user?.id;
    if (reviewerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول'), backgroundColor: AppColors.error),
      );
      return;
    }
    final ok = await _service.approve(userId: request.userId, reviewerId: reviewerId);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول طلب التحقق'), backgroundColor: AppColors.success),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في القبول'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _reject(AdminVerificationRequest request) async {
    final authState = context.read<AuthState>();
    final reviewerId = authState.user?.id;
    if (reviewerId == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              hintText: 'أدخل سبب الرفض',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رفض'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    final ok = await _service.reject(
      userId: request.userId,
      reviewerId: reviewerId,
      rejectionReason: reason,
    );
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب'), backgroundColor: AppColors.error),
        );
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'طلبات التحقق المعلقة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load,
                tooltip: 'تحديث',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_list.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('لا توجد طلبات معلقة حالياً'),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _list.length,
                itemBuilder: (context, i) {
                  final req = _list[i];
                  return VerificationRequestCard(
                    request: req,
                    onViewDocument: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('مستند التحقق'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('سيتم فتح الملف في نافذة جديدة'),
                              const SizedBox(height: 16),
                              DocumentViewerWidget(documentUrl: req.documentUrl, label: 'فتح الملف'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('إغلاق'),
                            ),
                          ],
                        ),
                      );
                    },
                    onApprove: () => _approve(req),
                    onReject: () => _reject(req),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
