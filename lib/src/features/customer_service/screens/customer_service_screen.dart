import 'package:flutter/material.dart';
import '../models/support_ticket.dart';
import '../providers/customer_service_provider.dart';
import '../providers/live_chat_provider.dart';
import '../screens/live_chat_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/contact_us_screen.dart';
import '../screens/support_tickets_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/utils/color_utils.dart';

class CustomerServiceScreen extends StatefulWidget {
  const CustomerServiceScreen({super.key});

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> {
  static const _padding = EdgeInsets.all(16.0);
  static const _smallPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _cardBorderRadius = 20.0;
  static const _iconSize = 32.0;
  
  static const _appBarTitleStyle = TextStyle(
    color: AppColors.brightGold,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const _headerTitleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.brightGold,
  );

  static const _sectionTitleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.brightGold,
  );

  static const _cardTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.brightGold,
  );

  static const _ticketTitleStyle = TextStyle(
    color: AppColors.white,
    fontWeight: FontWeight.bold,
  );

  late final CustomerServiceProvider _customerServiceProvider;

  @override
  void initState() {
    super.initState();
    _customerServiceProvider = context.read<CustomerServiceProvider>();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    await _customerServiceProvider.loadTickets();
  }

  Future<void> _showHelpCenter() async {
    if (!mounted) return;
    
    final currentContext = context;
    await Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => const FAQScreen(),
      ),
    );
  }

  Future<void> _createNewTicket() async {
    if (!mounted) return;
    
    final currentContext = context;
    await Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => const SupportTicketsScreen(),
      ),
    );

    if (!mounted) return;
    _customerServiceProvider.loadTickets();
  }

  Future<void> _handleLiveChat() async {
    if (!mounted) return;
    
    final currentContext = context;
    final liveChatProvider = currentContext.read<LiveChatProvider>();
    
    await Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => LiveChatScreen(
          provider: liveChatProvider,
        ),
      ),
    );
  }

  Future<void> _handleContactUs() async {
    if (!mounted) return;
    
    final currentContext = context;
    await Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => const ContactUsScreen(),
      ),
    );
  }

  Future<void> _showTicketDetails(SupportTicket ticket) async {
    if (!mounted) return;
    
    final currentContext = context;
    await Navigator.push(
      currentContext,
      MaterialPageRoute(
        builder: (context) => SupportTicketsScreen(
          initialTicket: ticket,
        ),
      ),
    );

    if (!mounted) return;
    _customerServiceProvider.loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.royalPurple,
                AppColors.skyBlue,
              ],
            ),
          ),
        ),
        title: custom_animations.ShimmerLoading(
          baseColor: AppColors.brightGold.withOpacity(0.5),
          highlightColor: AppColors.brightGold,
          child: const Text(
            'خدمة العملاء',
            style: _appBarTitleStyle,
          ),
        ),
        actions: [
          custom_animations.AnimatedScale(
            onTap: _showHelpCenter,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.help_outline,
                color: AppColors.brightGold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ColorUtils.withOpacity(AppColors.royalPurple, 0.1),
              ColorUtils.withOpacity(AppColors.skyBlue, 0.1),
            ],
          ),
        ),
        child: Consumer<CustomerServiceProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: custom_animations.AnimatedGlow(
                  glowColor: AppColors.brightGold,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brightGold),
                  ),
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
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.lightRed,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    custom_animations.AnimatedScale(
                      onTap: provider.loadTickets,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.royalPurple,
                              AppColors.skyBlue,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: _padding,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
                          ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(_cardBorderRadius),
                      border: Border.all(
                        color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مركز المساعدة',
                          style: _headerTitleStyle,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'كيف يمكننا مساعدتك اليوم؟',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildServiceCard(
                                title: 'الأسئلة الشائعة',
                                icon: Icons.help_outline,
                                onTap: _showHelpCenter,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildServiceCard(
                                title: 'المحادثة المباشرة',
                                icon: Icons.chat_bubble_outline,
                                onTap: _handleLiveChat,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildServiceCard(
                                title: 'تذكرة دعم فني',
                                icon: Icons.support,
                                onTap: _createNewTicket,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildServiceCard(
                                title: 'اتصل بنا',
                                icon: Icons.phone_outlined,
                                onTap: _handleContactUs,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (provider.tickets.isNotEmpty) ...[
                    const Text(
                      'تذاكر الدعم الفني',
                      style: _sectionTitleStyle,
                    ),
                    const SizedBox(height: 16),
                    ...provider.tickets.map((ticket) => _buildTicketCard(ticket)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: custom_animations.AnimatedScale(
        onTap: _createNewTicket,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brightGold,
                ColorUtils.withOpacity(AppColors.brightGold, 0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: AppColors.royalPurple,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return custom_animations.AnimatedScale(
      onTap: onTap,
      child: Container(
        padding: _smallPadding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
              ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(_cardBorderRadius),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                border: Border.all(
                  color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
                ),
              ),
              child: Icon(
                icon,
                color: AppColors.brightGold,
                size: _iconSize,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: _cardTitleStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return custom_animations.AnimatedScale(
      onTap: () => _showTicketDetails(ticket),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: _padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorUtils.withOpacity(AppColors.royalPurple, 0.2),
              ColorUtils.withOpacity(AppColors.skyBlue, 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(_cardBorderRadius),
          border: Border.all(
            color: ColorUtils.withOpacity(AppColors.brightGold, 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ColorUtils.withOpacity(AppColors.brightGold, 0.2),
                        ColorUtils.withOpacity(AppColors.brightGold, 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(ticket.status),
                    style: const TextStyle(
                      color: AppColors.brightGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(ticket.createdAt),
                  style: TextStyle(
                    color: ColorUtils.withOpacity(AppColors.white, 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ticket.title,
              style: _ticketTitleStyle,
            ),
            if (ticket.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ticket.description,
                style: TextStyle(
                  color: ColorUtils.withOpacity(AppColors.white, 0.7),
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
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
      default:
        return 'غير معروف';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 