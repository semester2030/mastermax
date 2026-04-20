import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../src/core/theme/app_colors.dart';

class VideosManagementScreen extends StatefulWidget {
  const VideosManagementScreen({super.key});

  @override
  State<VideosManagementScreen> createState() => _VideosManagementScreenState();
}

class _VideosManagementScreenState extends State<VideosManagementScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('spotlight_videos')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    if (mounted) {
      setState(() {
        _docs = snapshot.docs;
        _loading = false;
      });
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
                'إدارة الفيديوهات',
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
          Expanded(
            child: _docs.isEmpty
                ? const Center(child: Text('لا توجد فيديوهات'))
                : ListView.builder(
                    itemCount: _docs.length,
                    itemBuilder: (context, i) {
                      final d = _docs[i].data();
                      return Card(
                        key: ValueKey(_docs[i].id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            d['title']?.toString() ?? 'بدون عنوان',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'نوع: ${d['type'] ?? '—'} • مالك: ${d['userId'] ?? '—'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_left),
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
