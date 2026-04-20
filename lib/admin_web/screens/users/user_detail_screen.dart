import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../src/core/theme/app_colors.dart';
import '../../../../src/features/auth/models/user_type.dart';
import '../../../../src/features/auth/services/document_verification_service.dart';
import '../verification/widgets/document_viewer_widget.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    if (widget.userId.isNotEmpty) {
      _load();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (mounted) {
      setState(() {
        _data = doc.data();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null || widget.userId.isEmpty) {
      return const Center(child: Text('المستخدم غير موجود'));
    }
    final d = _data!;
    final typeStr = (d['userType'] ?? d['type']) as String? ?? '';
    final type = UserType.fromString(typeStr);
    final verificationLabel = _verificationStatusLabel(d['verificationStatus']?.toString());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات المستخدم',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Row('المعرف', widget.userId),
                    _Row('البريد', d['email']?.toString() ?? '—'),
                    _Row('الاسم', d['name']?.toString() ?? '—'),
                    _Row('نوع الحساب', type.arabicName),
                    _Row('موثق', (d['isVerified'] == true) ? 'نعم' : 'لا'),
                    _Row('حالة التحقق', verificationLabel),
                    if (d['createdAt'] != null)
                      _Row('تاريخ التسجيل', _formatTimestamp(d['createdAt'])),
                    if ((d['verificationDocumentUrl'] as String?)?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'مستند التحقق المحفوظ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DocumentViewerWidget(
                        documentUrl: (d['verificationDocumentUrl'] as String).trim(),
                        label: 'عرض الملف',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _verificationStatusLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    const keys = [
      'pending',
      'approved',
      'rejected',
      'notRequired',
    ];
    for (final k in keys) {
      if (raw == k || raw.endsWith(k)) {
        return VerificationStatus.values
            .firstWhere((s) => s.statusString == k, orElse: () => VerificationStatus.pending)
            .arabicName;
      }
    }
    return raw;
  }

  String _formatTimestamp(dynamic t) {
    if (t is Timestamp) return '${t.toDate().year}-${t.toDate().month.toString().padLeft(2, '0')}-${t.toDate().day.toString().padLeft(2, '0')}';
    return t.toString();
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
