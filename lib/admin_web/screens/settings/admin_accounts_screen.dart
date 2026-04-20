import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../src/core/theme/app_colors.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  String? _error;
  bool _bootstrapAdminOnly = false;

  static bool _docLooksAdmin(Map<String, dynamic> d2) {
    final email = d2['email']?.toString().trim().toLowerCase();
    if (email == 'admin@mastermax.com') return true;
    if (d2['isAdmin'] == true || d2['isAdmin'] == 'true' || d2['isAdmin'] == 1) return true;
    final extra = d2['extraData'];
    if (extra is Map && (extra['isAdmin'] == true || extra['isAdmin'] == 'true')) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _bootstrapAdminOnly = false;
    });
    try {
      final db = FirebaseFirestore.instance;
      final seen = <String>{};
      final admins = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      void addDocs(QuerySnapshot<Map<String, dynamic>> snap) {
        for (final d in snap.docs) {
          if (seen.add(d.id)) admins.add(d);
        }
      }

      try {
        final byFlag = await db.collection('users').where('isAdmin', isEqualTo: true).limit(80).get();
        addDocs(byFlag);
      } catch (_) {
        /* قد لا يوجد حقل isAdmin على كل المشاريع */
      }

      try {
        final byEmail = await db.collection('users').where('email', isEqualTo: 'admin@mastermax.com').limit(20).get();
        addDocs(byEmail);
      } catch (_) {
        /* تجاهل إن تعذّر الاستعلام */
      }

      final sample = await db.collection('users').limit(600).get();
      for (final d in sample.docs) {
        if (_docLooksAdmin(d.data()) && seen.add(d.id)) {
          admins.add(d);
        }
      }

      final auth = FirebaseAuth.instance.currentUser;
      final authEmail = auth?.email?.trim().toLowerCase();
      final bootstrap = authEmail == 'admin@mastermax.com';

      if (mounted) {
        setState(() {
          _docs = admins;
          _bootstrapAdminOnly = admins.isEmpty && bootstrap;
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
          const Text(
            'حسابات الأدمن',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'وثائق users التي تُظهر صلاحية أدمن (isAdmin، أو البريد المعروف، أو extraData.isAdmin)، بالإضافة إلى عيّنة من المستخدمين.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          if (_bootstrapAdminOnly) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أدمن المصادقة (بدون وثيقة مطابقة في النتائج)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أنت مسجّل كـ ${FirebaseAuth.instance.currentUser?.email ?? '—'} — صلاحية اللوحة مفعّلة عبر بريد الأدمن في المصادقة حتى لو لم تُعرض وثيقة في users ضمن الاستعلامات أعلاه.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: _docs.isEmpty
                ? Center(
                    child: Text(
                      _bootstrapAdminOnly
                          ? 'لا توجد وثائق users مطابقة للفلتر؛ تظهر معلومات الجلسة في البطاقة أعلاه.'
                          : 'لم يتم العثور على حسابات أدمن بهذا الفلتر',
                    ),
                  )
                : ListView.builder(
                    itemCount: _docs.length,
                    itemBuilder: (context, i) {
                      final d = _docs[i].data();
                      final email = d['email']?.toString() ?? '—';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                          title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('معرف: ${_docs[i].id}', style: const TextStyle(fontSize: 12)),
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
