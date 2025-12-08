import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../../shared/utils/formatters.dart';
import '../../../core/utils/color_utils.dart';

class ChatMessages extends StatefulWidget {
  final String chatRoomId;
  final List<ChatMessage> messages;
  final VoidCallback onBack;

  const ChatMessages({
    required this.chatRoomId, required this.messages, required this.onBack, super.key,
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

  void _sendMessage(BuildContext context) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = context.read<AuthState>().user?.id;
    if (currentUserId == null) return;

    await context.read<ChatProvider>().sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: currentUserId,
      text: text,
    );

    _messageController.clear();
    
    // التمرير إلى أحدث رسالة
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

    return Column(
      children: [
        // شريط العنوان
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              const Text(
                'المحادثة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // قائمة الرسائل
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
                        : ColorUtils.withOpacity(Colors.grey, 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(message.timestamp),
                        style: TextStyle(
                          color: isMe 
                              ? ColorUtils.withOpacity(Colors.white, 0.7)
                              : ColorUtils.withOpacity(Colors.black, 0.5),
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

        // حقل إدخال الرسالة
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك هنا...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
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