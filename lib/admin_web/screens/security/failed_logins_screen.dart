import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../src/core/theme/app_colors.dart';

class FailedLoginsScreen extends StatefulWidget {
  const FailedLoginsScreen({super.key});

  @override
  State<FailedLoginsScreen> createState() => _FailedLoginsScreenState();
}

class _FailedLoginsScreenState extends State<FailedLoginsScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// بدون `where` + `orderBy` مركّب (يتطلّب فهرساً وقد يعلق التحميل عند فشل الاستعلام).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      final failed = snapshot.docs.where((d) {
        final et = d.data()['eventType']?.toString() ?? '';
        return et.contains('failedLogin');
      }).take(100).toList();
      if (mounted) {
        setState(() {
          _docs = failed;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _docs = [];
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'محاولات الدخول الفاشلة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          Expanded(
            child: _docs.isEmpty
                ? Center(
                    child: Text(
                      _error != null
                          ? 'تعذّر تحميل السجلات. جرّب «تحديث» أو تحقق من القواعد والفهارس.'
                          : 'لا توجد محاولات فاشلة مسجلة',
                    ),
                  )
                : ListView.builder(
                    itemCount: _docs.length,
                    itemBuilder: (context, i) {
                      final d = _docs[i].data();
                      final ts = d['timestamp'] as Timestamp?;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.login, color: AppColors.error),
                          title: Text(
                            d['userId']?.toString() ?? '—',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${d['details'] ?? ''}${ts != null ? "\n${ts.toDate()}" : ""}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
