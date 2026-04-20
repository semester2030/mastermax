import 'package:flutter/material.dart';
import '../src/core/theme/app_colors.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_header.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String currentRoute;

  const AdminLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1024;
        if (isWide) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                AdminSidebar(currentRoute: currentRoute),
                Expanded(
                  child: Column(
                    children: [
                      AdminHeader(title: title),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(title),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            drawer: Drawer(
              child: AdminSidebar(currentRoute: currentRoute),
            ),
            body: child,
          );
        }
      },
    );
  }
}
