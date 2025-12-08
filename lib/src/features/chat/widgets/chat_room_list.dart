import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_room.dart';
import '../../auth/providers/auth_state.dart';
import '../../../shared/utils/formatters.dart';

class ChatRoomList extends StatelessWidget {
  final List<ChatRoom> chatRooms;
  final Function(ChatRoom) onChatRoomSelected;

  const ChatRoomList({
    required this.chatRooms, required this.onChatRoomSelected, super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthState>().user?.id;

    if (chatRooms.isEmpty) {
      return Center(
        child: Text(
          'لا توجد محادثات',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];
        final isUser1 = chatRoom.user1Id == currentUserId;
        final otherUserId = isUser1 ? chatRoom.user2Id : chatRoom.user1Id;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(
              '${chatRoom.propertyType == 'car' ? 'محادثة سيارة' : 'محادثة عقار'} - $otherUserId',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chatRoom.lastMessageText.isEmpty 
                  ? 'لا توجد رسائل'
                  : chatRoom.lastMessageText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              formatDateTime(chatRoom.lastMessageTime),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            onTap: () => onChatRoomSelected(chatRoom),
          ),
        );
      },
    );
  }
} 