import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_room_list.dart';
import '../widgets/chat_messages.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // في الوضع التجريبي، نقوم بتحميل محادثات تجريبية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.loadTrialChatRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثات أضواء ماكس'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedChatRoomId = chatProvider.selectedChatRoomId;
          
          if (selectedChatRoomId == null) {
            return ChatRoomList(
              chatRooms: chatProvider.chatRooms,
              onChatRoomSelected: (chatRoom) {
                chatProvider.selectChatRoom(chatRoom.id);
              },
            );
          }

          return ChatMessages(
            chatRoomId: selectedChatRoomId,
            messages: chatProvider.currentMessages,
            onBack: () {
              chatProvider.selectChatRoom('');
            },
          );
        },
      ),
    );
  }
} 