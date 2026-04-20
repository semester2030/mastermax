import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../src/core/theme/app_colors.dart';
import '../../../src/features/auth/models/user_type.dart';
import 'widgets/user_row.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  String _typeFilter = 'all';
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .limit(200);
    try {
      q = q.orderBy('createdAt', descending: true);
    } catch (_) {}
    if (_typeFilter != 'all') {
      q = q.where('type', isEqualTo: _typeFilter);
    }
    final snapshot = await q.get();
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
                'المستخدمون',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _typeFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'individual', child: Text('فرد')),
                  DropdownMenuItem(value: 'realEstateCompany', child: Text('شركة عقارية')),
                  DropdownMenuItem(value: 'carDealer', child: Text('معرض سيارات')),
                  DropdownMenuItem(value: 'realEstateAgent', child: Text('وسيط عقاري')),
                  DropdownMenuItem(value: 'carTrader', child: Text('تاجر سيارات')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _typeFilter = v);
                    _load();
                  }
                },
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _docs.isEmpty
                ? const Center(child: Text('لا يوجد مستخدمون'))
                : ListView.builder(
                    itemCount: _docs.length,
                    itemBuilder: (context, i) {
                      final doc = _docs[i];
                      final data = doc.data();
                      final id = doc.id;
                      final typeStr = (data['userType'] ?? data['type']) as String? ?? '';
                      final email = data['email'] as String? ?? '—';
                      final isVerified = data['isVerified'] as bool? ?? false;
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      return UserRow(
                        userId: id,
                        email: email,
                        type: UserType.fromString(typeStr),
                        isVerified: isVerified,
                        createdAt: createdAt,
                        onTap: () => Navigator.of(context).pushNamed('/users/detail', arguments: id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
