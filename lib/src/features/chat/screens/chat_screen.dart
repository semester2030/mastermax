import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../chat_screen_route_args.dart';
import '../models/chat_room.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_room_list.dart';
import '../widgets/chat_messages.dart';
import '../../../core/constants/app_brand.dart';
import '../../auth/providers/auth_state.dart';

/// وسائط [Navigator.pushNamed] — استخدم [ChatScreenRouteArgs] للمفاتيح.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatProvider? _chat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chat ??= context.read<ChatProvider>();
  }

  @override
  void dispose() {
    _chat?.selectChatRoom(null);
    _chat?.clearSellerInboxListMode();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final auth = context.read<AuthState>();
    final chatProvider = context.read<ChatProvider>();
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      final sellerInboxAll =
          args[ChatScreenRouteArgs.sellerInboxAllListings] == true;
      final sellerInboxVideo =
          args[ChatScreenRouteArgs.sellerInboxForVideo] == true;

      if (sellerInboxAll) {
        final uid = auth.user?.id;
        if (uid == null || uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سجّل الدخول لعرض المحادثات')),
            );
          }
          return;
        }
        chatProvider.setSellerInboxListMode(
          ChatSellerInboxListMode.allMyListingChats,
        );
        chatProvider.selectChatRoom(null);
        chatProvider.loadChatRooms(uid);
        return;
      }

      if (sellerInboxVideo) {
        final videoId = args[ChatScreenRouteArgs.videoId] as String?;
        if (videoId == null || videoId.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('معرّف المقطع غير متوفر')),
            );
          }
          return;
        }
        final uid = auth.user?.id;
        if (uid == null || uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سجّل الدخول لعرض المحادثات')),
            );
          }
          return;
        }
        final videoTitle =
            args[ChatScreenRouteArgs.videoTitle] as String?;
        chatProvider.setSellerInboxListMode(
          ChatSellerInboxListMode.singleVideo,
          spotlightVideoId: videoId,
          videoTitleForAppBar: videoTitle,
        );
        chatProvider.selectChatRoom(null);
        chatProvider.loadChatRooms(uid);
        return;
      }

      final sellerId = args[ChatScreenRouteArgs.sellerId] as String?;
      final videoId = args[ChatScreenRouteArgs.videoId] as String?;
      final propertyType =
          args[ChatScreenRouteArgs.propertyType] as String? ?? 'car';
      final videoTitle =
          args[ChatScreenRouteArgs.videoTitle] as String?;
      final sellerName =
          args[ChatScreenRouteArgs.sellerName] as String?;

      if (sellerId != null &&
          sellerId.isNotEmpty &&
          videoId != null &&
          videoId.isNotEmpty) {
        final uid = auth.user?.id;
        if (uid == null || uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('سجّل الدخول لمراسلة صاحب الإعلان')),
            );
          }
          return;
        }
        if (uid == sellerId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لعرض رسائل هذا المقطع: افتح المحادثة من المقطع أو من الملف الشخصي — محادثات على إعلاناتي',
                ),
              ),
            );
          }
          return;
        }

        await chatProvider.openSpotlightConversation(
          buyerId: uid,
          sellerId: sellerId,
          videoId: videoId,
          propertyType: propertyType,
          videoTitle: videoTitle,
          sellerName: sellerName,
        );

        if (!mounted) return;
        if (chatProvider.chatError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(chatProvider.chatError!)),
          );
          chatProvider.clearChatError();
        } else {
          chatProvider.loadChatRooms(uid);
        }
        return;
      }
    }

    final uid = auth.user?.id;
    if (uid != null && uid.isNotEmpty) {
      chatProvider.setSellerInboxListMode(ChatSellerInboxListMode.none);
      chatProvider.loadChatRooms(uid);
    }
  }

  void _openArchivedSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.5;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'محادثات مخفية عن القائمة',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'الإخفاء لك وحدك؛ الطرف الآخر لا يزال يرى المحادثة.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(
                  height: maxH,
                  child: Consumer<ChatProvider>(
                    builder: (context, p, _) {
                      final archived = p.archivedRoomsForUser(uid);
                      if (archived.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا توجد محادثات مخفية حالياً'),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: archived.length,
                        itemBuilder: (context, i) {
                          final r = archived[i];
                          return ListTile(
                            title: Text(
                              chatRoomRowTitle(r, uid),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await p.setRoomArchivedForUser(uid, r.id, false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('أُعيدت المحادثة إلى القائمة'),
                                  ),
                                );
                                if (p.archivedRoomsForUser(uid).isEmpty &&
                                    context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('استعادة'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _appBarTitle(ChatProvider p) {
    switch (p.sellerInboxListMode) {
      case ChatSellerInboxListMode.allMyListingChats:
        return 'محادثات على إعلاناتي';
      case ChatSellerInboxListMode.singleVideo:
        final t = p.sellerInboxVideoTitleForAppBar;
        if (t != null && t.isNotEmpty) {
          return t;
        }
        return 'محادثات هذا المقطع';
      case ChatSellerInboxListMode.none:
        return 'محادثات ${AppBrand.displayName}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final uid = auth.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            return Text(
              _appBarTitle(chatProvider),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          if (uid.isNotEmpty)
            Consumer<ChatProvider>(
              builder: (context, p, _) {
                if (p.selectedChatRoomId != null) {
                  return const SizedBox.shrink();
                }
                final n = p.archivedRoomsForUser(uid).length;
                if (n == 0) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'محادثات مخفية',
                  onPressed: () => _openArchivedSheet(context, uid),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      Positioned(
                        left: -6,
                        top: -6,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 14,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              n > 99 ? '99+' : '$n',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedChatRoomId = chatProvider.selectedChatRoomId;

          if (selectedChatRoomId == null) {
            final rooms = uid.isEmpty
                ? <ChatRoom>[]
                : chatProvider.roomsVisibleForUser(uid);
            if (rooms.isEmpty &&
                chatProvider.sellerInboxListMode ==
                    ChatSellerInboxListMode.allMyListingChats) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لا توجد محادثات على إعلاناتك بعد.\n'
                    'المحادثات الجديدة تظهر هنا تلقائياً بعد تواصل المهتمين.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            if (rooms.isEmpty &&
                chatProvider.sellerInboxListMode ==
                    ChatSellerInboxListMode.singleVideo) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لا توجد رسائل على هذا المقطع بعد.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            return ChatRoomList(
              chatRooms: rooms,
              onChatRoomSelected: (chatRoom) {
                chatProvider.selectChatRoom(chatRoom.id, fromList: true);
              },
            );
          }

          return ChatMessages(
            chatRoomId: selectedChatRoomId,
            messages: chatProvider.currentMessages,
            conversationTitle: chatProvider.activeSpotlightTitle,
            onBack: () {
              chatProvider.selectChatRoom(null);
            },
          );
        },
      ),
    );
  }
}
