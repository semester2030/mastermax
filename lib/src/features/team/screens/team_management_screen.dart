import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_member.dart';
import '../services/team_service.dart';

class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final teamService = Provider.of<TeamService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إدارة الفريق',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: colorScheme.onPrimary),
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<TeamMember>>(
        stream: teamService.getTeamMembers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ: ${snapshot.error}',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          final members = snapshot.data!;
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    member.name[0],
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ),
                title: Text(
                  member.name,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  member.role,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: colorScheme.primary),
                      onPressed: () => _showEditMemberDialog(context, member),
                    ),
                    IconButton(
                      icon: Icon(
                        member.isActive ? Icons.toggle_on : Icons.toggle_off,
                        color: member.isActive ? colorScheme.primary : colorScheme.outline,
                        size: 28,
                      ),
                      onPressed: () => teamService.toggleMemberStatus(member.id, !member.isActive),
                    ),
                  ],
                ),
                onTap: () => _showMemberDetails(context, member),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final roleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إضافة عضو جديد',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'الاسم'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'البريد الإلكتروني'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: roleController,
                decoration: InputDecoration(labelText: 'الدور'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final teamService = Provider.of<TeamService>(context, listen: false);
                final newMember = TeamMember(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  email: emailController.text,
                  role: roleController.text,
                  permissions: const [],
                  createdAt: DateTime.now(),
                );
                teamService.addTeamMember(newMember);
                Navigator.pop(context);
              }
            },
            child: Text(
              'إضافة',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context, TeamMember member) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: member.name);
    final emailController = TextEditingController(text: member.email);
    final roleController = TextEditingController(text: member.role);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل بيانات العضو',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'الاسم'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'البريد الإلكتروني'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: roleController,
                decoration: InputDecoration(labelText: 'الدور'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final teamService = Provider.of<TeamService>(context, listen: false);
                final updatedMember = TeamMember(
                  id: member.id,
                  name: nameController.text,
                  email: emailController.text,
                  role: roleController.text,
                  permissions: member.permissions,
                  createdAt: member.createdAt,
                  isActive: member.isActive,
                );
                teamService.updateTeamMember(updatedMember);
                Navigator.pop(context);
              }
            },
            child: Text(
              'حفظ',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(BuildContext context, TeamMember member) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تفاصيل العضو',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: ${member.name}', style: textTheme.bodyMedium),
            Text('البريد الإلكتروني: ${member.email}', style: textTheme.bodyMedium),
            Text('الدور: ${member.role}', style: textTheme.bodyMedium),
            Text('الحالة: ${member.isActive ? 'نشط' : 'غير نشط'}', style: textTheme.bodyMedium),
            Text('تاريخ الإنشاء: ${member.createdAt.toString()}', style: textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('الصلاحيات:', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
            ...member.permissions.map((p) => Text('- $p', style: textTheme.bodySmall)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
} 