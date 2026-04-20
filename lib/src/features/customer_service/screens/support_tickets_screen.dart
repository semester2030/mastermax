import 'package:flutter/material.dart';
import '../models/support_ticket.dart';
import '../providers/customer_service_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/theme/app_colors.dart';

class SupportTicketsScreen extends StatefulWidget {
  final SupportTicket? initialTicket;

  const SupportTicketsScreen({
    super.key,
    this.initialTicket,
  });

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isCreatingTicket = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!mounted) return;
    context.read<CustomerServiceProvider>().loadTickets();
  }

  void _showCreateTicketDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إنشاء تذكرة جديدة', style: textTheme.titleLarge?.copyWith(color: colorScheme.secondary)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان التذكرة',
                  border: const OutlineInputBorder(),
                  labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'الرجاء إدخال عنوان التذكرة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'وصف المشكلة',
                  border: const OutlineInputBorder(),
                  labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'الرجاء إدخال وصف المشكلة';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary)),
          ),
          ElevatedButton(
            onPressed: _createTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.primary,
            ),
            child: Text('إنشاء', style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _createTicket() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isCreatingTicket = true);
      try {
        await context.read<CustomerServiceProvider>().createTicket(
              title: _titleController.text,
              description: _descriptionController.text,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إنشاء التذكرة بنجاح', style: Theme.of(context).textTheme.bodyMedium)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e', style: Theme.of(context).textTheme.bodyMedium)),
          );
        }
      } finally {
        setState(() => _isCreatingTicket = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('تذاكر الدعم', style: textTheme.titleLarge?.copyWith(color: colorScheme.secondary)),
        backgroundColor: AppColors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colorScheme.secondary.withAlpha(179), // 0.7 * 255
              colorScheme.primary.withAlpha(179),
            ],
          ),
        ),
        child: Consumer<CustomerServiceProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: custom_animations.AnimatedGlow(
                  glowColor: AppColors.accent,
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'حدث خطأ: ${provider.error}',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: provider.loadTickets,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: colorScheme.primary,
                      ),
                      child: Text(
                        'إعادة المحاولة',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }
            if (provider.tickets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.support,
                      size: 64,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد تذاكر دعم حالياً',
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onPrimary, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showCreateTicketDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: colorScheme.primary,
                      ),
                      child: Text(
                        'إنشاء تذكرة جديدة',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => provider.loadTickets(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.tickets.length,
                itemBuilder: (context, index) {
                  final ticket = provider.tickets[index];
                  return custom_animations.AnimatedScale(
                    onTap: () => _showTicketDetails(ticket),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: colorScheme.surface.withAlpha(230),
                      child: ListTile(
                        leading: _buildStatusIcon(ticket.status, colorScheme),
                        title: Text(ticket.title, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
                        subtitle: Text(ticket.description, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha(179))),
                        trailing: Text(
                          _getStatusText(ticket.status),
                          style: textTheme.bodySmall?.copyWith(
                            color: _getStatusColor(ticket.status, colorScheme),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => _showTicketDetails(ticket),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إنشاء تذكرة جديدة',
        onPressed: _isCreatingTicket ? null : _showCreateTicketDialog,
        backgroundColor: colorScheme.secondary,
        child: _isCreatingTicket
            ? custom_animations.AnimatedGlow(
                glowColor: colorScheme.primary,
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : Icon(Icons.add, color: colorScheme.primary),
      ),
    );
  }

  Widget _buildStatusIcon(TicketStatus status, ColorScheme colorScheme) {
    return Icon(
      _getStatusIcon(status),
      color: _getStatusColor(status, colorScheme),
    );
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Icons.fiber_new;
      case TicketStatus.inProgress:
        return Icons.pending;
      case TicketStatus.resolved:
        return Icons.check_circle;
      case TicketStatus.closed:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TicketStatus status, ColorScheme colorScheme) {
    switch (status) {
      case TicketStatus.open:
        return colorScheme.secondary;
      case TicketStatus.inProgress:
        return colorScheme.primary;
      case TicketStatus.resolved:
        return colorScheme.primary.withAlpha(204); // 0.8 * 255
      case TicketStatus.closed:
        return colorScheme.error;
    }
  }

  String _getStatusText(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'جديدة';
      case TicketStatus.inProgress:
        return 'قيد المعالجة';
      case TicketStatus.resolved:
        return 'تم الحل';
      case TicketStatus.closed:
        return 'مغلقة';
    }
  }

  void _showTicketDetails(SupportTicket ticket) {
    // يمكنك هنا فتح صفحة تفاصيل التذكرة أو عرض حوار التفاصيل
  }
} 