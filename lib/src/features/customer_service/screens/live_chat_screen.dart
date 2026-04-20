import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../providers/live_chat_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/animations/widget_animations.dart' as custom_animations;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';

class LiveChatScreen extends StatefulWidget {
  final LiveChatProvider provider;

  const LiveChatScreen({
    required this.provider, super.key,
  });

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      widget.provider.connectToChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.provider.sendMessage(message);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        title: Text(
          'المحادثة المباشرة',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: colorScheme.secondary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: colorScheme.primary,
                  title: Text(
                    'معلومات المحادثة',
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.secondary),
                  ),
                  content: Text(
                    'فريق خدمة العملاء متواجد للرد على استفساراتك على مدار الساعة',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'حسناً',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
        child: Consumer<LiveChatProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(
                child: custom_animations.AnimatedGlow(
                  glowColor: colorScheme.secondary,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
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
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    custom_animations.AnimatedScale(
                      onTap: () => provider.connectToChat(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.secondary,
                              colorScheme.secondary.withAlpha(204), // 0.8 * 255
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'إعادة المحاولة',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                if (!provider.isConnected)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.secondary.withAlpha(51), // 0.2 * 255
                          colorScheme.secondary.withAlpha(26), // 0.1 * 255
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        custom_animations.AnimatedGlow(
                          glowColor: colorScheme.secondary,
                          child: Icon(
                            Icons.warning_amber,
                            color: colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'جاري الاتصال بخدمة المحادثة...',
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final message = provider.messages[index];
                      return _buildMessageBubble(message, colorScheme, textTheme);
                    },
                  ),
                ),
                _buildMessageInput(colorScheme, textTheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ColorScheme colorScheme, TextTheme textTheme) {
    final isMe = !message.isStaff;
    return custom_animations.AnimatedScale(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              custom_animations.AnimatedGlow(
                glowColor: colorScheme.secondary,
                child: CircleAvatar(
                  backgroundColor: colorScheme.secondary,
                  child: Icon(Icons.support_agent, color: colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isMe
                        ? [
                            colorScheme.secondary.withAlpha(51),
                            colorScheme.secondary.withAlpha(26),
                          ]
                        : [
                            colorScheme.primary.withAlpha(51),
                            colorScheme.primary.withAlpha(26),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.secondary.withAlpha(77),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(26),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.formattedTime,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.secondary.withAlpha(179),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              custom_animations.AnimatedGlow(
                glowColor: colorScheme.secondary,
                child: CircleAvatar(
                  backgroundColor: colorScheme.secondary,
                  child: Icon(Icons.person, color: colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك هنا...',
                hintStyle: TextStyle(
                  color: ColorUtils.withOpacity(AppColors.textPrimary, 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          custom_animations.AnimatedScale(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary,
                    colorScheme.secondary.withAlpha(204), // 0.8 * 255
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 