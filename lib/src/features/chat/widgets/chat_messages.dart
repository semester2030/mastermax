import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../../shared/utils/formatters.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/app_colors.dart';

class ChatMessages extends StatefulWidget {
  final String chatRoomId;
  final List<ChatMessage> messages;
  final VoidCallback onBack;
  /// عنوان إضافي عند فتح المحادثة من مقطع سبوتلايت (اسم البائع · عنوان المقطع).
  final String? conversationTitle;

  const ChatMessages({
    required this.chatRoomId,
    required this.messages,
    required this.onBack,
    this.conversationTitle,
    super.key,
  });

  @override
  State<ChatMessages> createState() => _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onChatMenuAction(BuildContext context, String action) async {
    final uid = context.read<AuthState>().user?.id ??
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final chat = context.read<ChatProvider>();

    if (action == 'archive') {
      final next = !chat.isRoomArchived(widget.chatRoomId);
      await chat.setRoomArchivedForUser(uid, widget.chatRoomId, next);
      if (!context.mounted) return;
      final err = chat.chatError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        chat.clearChatError();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'أُخفيت من قائمتك فقط. الطرف الآخر لا يتأثر.'
                : 'أُعيدت المحادثة إلى القائمة.',
          ),
        ),
      );
      if (next) widget.onBack();
      return;
    }

    if (action == 'mute') {
      final next = !chat.isRoomMuted(widget.chatRoomId);
      await chat.setRoomMutedForUser(uid, widget.chatRoomId, next);
      if (!context.mounted) return;
      final err = chat.chatError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        chat.clearChatError();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'تم كتم هذه المحادثة (سيُطبَّق على الإشعارات عند تفعيلها).'
                : 'أُلغي الكتم.',
          ),
        ),
      );
    }
  }

  void _sendMessage(BuildContext context) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final senderId =
        FirebaseAuth.instance.currentUser?.uid ?? context.read<AuthState>().user?.id;
    if (senderId == null || senderId.isEmpty) return;

    final chat = context.read<ChatProvider>();
    await chat.sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: senderId,
      text: text,
    );

    if (!context.mounted) return;
    final err = chat.chatError;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      chat.clearChatError();
      return;
    }

    _messageController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthState>().user?.id;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          color: primary.withValues(alpha: 0.1),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.conversationTitle ?? 'المحادثة',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) => _onChatMenuAction(context, v),
                itemBuilder: (ctx) {
                  final p = ctx.read<ChatProvider>();
                  final archived = p.isRoomArchived(widget.chatRoomId);
                  final muted = p.isRoomMuted(widget.chatRoomId);
                  return [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        archived
                            ? 'إظهار في قائمة المحادثات'
                            : 'إخفاء من قائمة المحادثات',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mute',
                      child: Text(
                        muted
                            ? 'إلغاء كتم الإشعارات'
                            : 'كتم إشعارات هذه المحادثة',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.all(8),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[index];
              final isMe = message.senderId == currentUserId;

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).primaryColor
                        : ColorUtils.withOpacity(AppColors.textSecondary, 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? AppColors.white : AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(message.timestamp),
                        style: TextStyle(
                          color: isMe
                              ? ColorUtils.withOpacity(AppColors.white, 0.7)
                              : ColorUtils.withOpacity(AppColors.textPrimary, 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
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
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendMessage(context),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
