import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../services/chat_prefs_service.dart';

/// تصفية قائمة الغرف في [ChatScreen] (صندوق المالك على مقطع / كل إعلاناتي).
enum ChatSellerInboxListMode {
  none,
  singleVideo,
  allMyListingChats,
}

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ChatPrefsService _prefsService = ChatPrefsService();
  List<ChatRoom> _chatRooms = [];
  final Map<String, List<ChatMessage>> _messages = {};
  String? _selectedChatRoomId;
  bool _isLoading = false;
  String? _chatError;
  String? _activeSpotlightTitle;
  ChatSellerInboxListMode _sellerInboxListMode = ChatSellerInboxListMode.none;
  String? _sellerInboxVideoId;
  String? _sellerInboxVideoTitleForAppBar;

  List<ChatRoom> get chatRooms => _chatRooms;
  ChatSellerInboxListMode get sellerInboxListMode => _sellerInboxListMode;
  String? get sellerInboxVideoTitleForAppBar => _sellerInboxVideoTitleForAppBar;
  List<ChatMessage> get currentMessages =>
      _selectedChatRoomId != null ? _messages[_selectedChatRoomId!] ?? [] : [];
  bool get isLoading => _isLoading;
  String? get selectedChatRoomId => _selectedChatRoomId;
  String? get chatError => _chatError;
  String? get activeSpotlightTitle => _activeSpotlightTitle;

  StreamSubscription? _chatRoomsSubscription;
  StreamSubscription? _prefsSubscription;
  final Map<String, StreamSubscription> _messageSubscriptions = {};

  Set<String> _archivedRoomIds = {};
  Set<String> _mutedRoomIds = {};
  final Set<String> _trialArchived = {};
  final Set<String> _trialMuted = {};

  bool _isTrialRoomId(String id) => id == '1' || id == '2';

  bool isRoomArchived(String roomId) {
    final id = roomId.trim();
    if (id.isEmpty) return false;
    if (_isTrialRoomId(id)) return _trialArchived.contains(id);
    return _archivedRoomIds.contains(id);
  }

  bool isRoomMuted(String roomId) {
    final id = roomId.trim();
    if (id.isEmpty) return false;
    if (_isTrialRoomId(id)) return _trialMuted.contains(id);
    return _mutedRoomIds.contains(id);
  }

  /// محادثات وهمية (للاختبار فقط — لا تُستدعى من شاشة التطبيق الرئيسية).
  void loadTrialChatRooms() {
    _isLoading = true;
    notifyListeners();

    _chatRooms = [
      ChatRoom(
        id: '1',
        user1Id: 'trial_user',
        user2Id: 'seller_1',
        propertyId: 'property_1',
        propertyType: 'real_estate',
        lastMessageText: 'هل العقار ما زال متاحاً؟',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatRoom(
        id: '2',
        user1Id: 'trial_user',
        user2Id: 'seller_2',
        propertyId: 'car_1',
        propertyType: 'car',
        lastMessageText: 'ما هو أقل سعر للسيارة؟',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _messages['1'] = [
      ChatMessage(
        id: '1',
        senderId: 'trial_user',
        text: 'مرحباً، هل العقار ما زال متاحاً؟',
        timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
      ),
      ChatMessage(
        id: '2',
        senderId: 'seller_1',
        text: 'نعم، العقار متاح. هل ترغب في معرفة المزيد من التفاصيل؟',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];

    _messages['2'] = [
      ChatMessage(
        id: '3',
        senderId: 'trial_user',
        text: 'ما هو أقل سعر للسيارة؟',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  void setSellerInboxListMode(
    ChatSellerInboxListMode mode, {
    String? spotlightVideoId,
    String? videoTitleForAppBar,
  }) {
    _sellerInboxListMode = mode;
    if (mode == ChatSellerInboxListMode.singleVideo) {
      final v = spotlightVideoId?.trim();
      _sellerInboxVideoId = (v != null && v.isNotEmpty) ? v : null;
      final t = videoTitleForAppBar?.trim();
      _sellerInboxVideoTitleForAppBar =
          (t != null && t.isNotEmpty) ? t : null;
    } else {
      _sellerInboxVideoId = null;
      _sellerInboxVideoTitleForAppBar = null;
    }
    notifyListeners();
  }

  void clearSellerInboxListMode() {
    _sellerInboxListMode = ChatSellerInboxListMode.none;
    _sellerInboxVideoId = null;
    _sellerInboxVideoTitleForAppBar = null;
    notifyListeners();
  }

  List<ChatRoom> _roomsAfterSellerFilter(String userId) {
    final uid = userId.trim();
    final list = List<ChatRoom>.from(_chatRooms);
    list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    switch (_sellerInboxListMode) {
      case ChatSellerInboxListMode.none:
        return list;
      case ChatSellerInboxListMode.singleVideo:
        final vid = _sellerInboxVideoId;
        if (vid == null) return list;
        return list.where((r) => r.propertyId == vid && r.hasUser(uid)).toList();
      case ChatSellerInboxListMode.allMyListingChats:
        return list.where((r) => r.spotlightSellerId == uid).toList();
    }
  }

  /// غرف مرتبة للعرض (بدون المؤرشفة لك).
  List<ChatRoom> roomsVisibleForUser(String userId) {
    return _roomsAfterSellerFilter(userId)
        .where((r) => !isRoomArchived(r.id))
        .toList();
  }

  /// محادثات أخفيتها عن قائمتك (نفس فلاتر صندوق البائع إن وُجدت).
  List<ChatRoom> archivedRoomsForUser(String userId) {
    return _roomsAfterSellerFilter(userId)
        .where((r) => isRoomArchived(r.id))
        .toList();
  }

  Future<void> setRoomArchivedForUser(
    String userId,
    String roomId,
    bool archived,
  ) async {
    final uid = userId.trim();
    final rid = roomId.trim();
    if (uid.isEmpty || rid.isEmpty) return;

    if (_isTrialRoomId(rid)) {
      if (archived) {
        _trialArchived.add(rid);
      } else {
        _trialArchived.remove(rid);
      }
      notifyListeners();
      return;
    }

    _chatError = null;
    try {
      await _prefsService.setArchived(uid, rid, archived);
    } catch (e, st) {
      debugPrint('setRoomArchivedForUser: $e\n$st');
      _chatError = 'تعذّر حفظ الإخفاء. حاول مرة أخرى.';
      notifyListeners();
    }
  }

  Future<void> setRoomMutedForUser(
    String userId,
    String roomId,
    bool muted,
  ) async {
    final uid = userId.trim();
    final rid = roomId.trim();
    if (uid.isEmpty || rid.isEmpty) return;

    if (_isTrialRoomId(rid)) {
      if (muted) {
        _trialMuted.add(rid);
      } else {
        _trialMuted.remove(rid);
      }
      notifyListeners();
      return;
    }

    _chatError = null;
    try {
      await _prefsService.setMuted(uid, rid, muted);
    } catch (e, st) {
      debugPrint('setRoomMutedForUser: $e\n$st');
      _chatError = 'تعذّر حفظ الكتم. حاول مرة أخرى.';
      notifyListeners();
    }
  }

  void _listenChatPrefs(String userId) {
    final uid = userId.trim();
    _prefsSubscription?.cancel();
    _prefsSubscription = null;
    if (uid.isEmpty) return;

    _prefsSubscription = _prefsService.watchPrefs(uid).listen(
      (state) {
        _archivedRoomIds = Set<String>.from(state.archivedRoomIds);
        _mutedRoomIds = Set<String>.from(state.mutedRoomIds);
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('Chat prefs stream: $e');
      },
    );
  }

  void loadChatRooms(String userId) {
    _chatRoomsSubscription?.cancel();
    final uid = userId.trim();
    if (uid.isNotEmpty) {
      _listenChatPrefs(uid);
    } else {
      _prefsSubscription?.cancel();
      _prefsSubscription = null;
    }

    _chatRoomsSubscription = _chatService.getChatRooms(userId).listen(
      (rooms) {
        _chatRooms = rooms;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading chat rooms: $error');
      },
    );
  }

  void loadMessages(String chatRoomId) {
    if (chatRoomId.isEmpty) return;

    _selectedChatRoomId = chatRoomId;

    if (_messageSubscriptions.containsKey(chatRoomId)) {
      return;
    }

    for (final id in _messageSubscriptions.keys.toList()) {
      if (id != chatRoomId) {
        _messageSubscriptions[id]?.cancel();
        _messageSubscriptions.remove(id);
      }
    }

    _messageSubscriptions[chatRoomId] =
        _chatService.getChatMessages(chatRoomId).listen(
      (messages) {
        _messages[chatRoomId] = messages;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading messages for $chatRoomId: $error');
        _chatError = 'تعذّر تحميل الرسائل. تحقق من الصلاحيات والاتصال.';
        notifyListeners();
      },
    );
  }

  Future<ChatRoom> createOrGetChatRoom({
    required String currentUserId,
    required String otherUserId,
    String? propertyId,
    String? propertyType,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final chatRoom = await _chatService.createOrGetChatRoom(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        propertyId: propertyId,
        propertyType: propertyType,
      );

      _selectedChatRoomId = chatRoom.id;
      loadMessages(chatRoom.id);

      return chatRoom;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// فتح محادثة نصية حقيقية مرتبطة بمقطع سبوتلايت (غرفة فريدة لكل فيديو + زوج المستخدمين).
  Future<void> openSpotlightConversation({
    required String buyerId,
    required String sellerId,
    required String videoId,
    required String propertyType,
    String? videoTitle,
    String? sellerName,
  }) async {
    _chatError = null;
    _isLoading = true;
    notifyListeners();

    try {
      final room = await _chatService.createOrGetSpotlightVideoRoom(
        buyerId: buyerId,
        sellerId: sellerId,
        videoId: videoId,
        propertyType: propertyType,
        videoTitle: videoTitle,
      );

      final vt = videoTitle?.trim();
      final sn = sellerName?.trim();
      if (sn != null && sn.isNotEmpty) {
        _activeSpotlightTitle =
            vt != null && vt.isNotEmpty ? '$sn · $vt' : '$sn · مقطع فيديو';
      } else {
        _activeSpotlightTitle =
            vt != null && vt.isNotEmpty ? vt : 'محادثة حول الإعلان';
      }

      _selectedChatRoomId = room.id;
      if (!_chatRooms.any((r) => r.id == room.id)) {
        _chatRooms = [room, ..._chatRooms];
      }
      loadMessages(room.id);
    } catch (e, st) {
      debugPrint('openSpotlightConversation: $e\n$st');
      _chatError = e.toString();
      _activeSpotlightTitle = null;
      _selectedChatRoomId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    _chatError = null;

    if (chatRoomId == '1' || chatRoomId == '2') {
      await _sendTrialMessage(chatRoomId: chatRoomId, senderId: senderId, text: text);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _chatService.sendMessage(
        chatRoomId: chatRoomId,
        senderId: senderId,
        text: text.trim(),
      );
    } catch (e, st) {
      if (e is FirebaseException) {
        debugPrint(
            'sendMessage Firestore: code=${e.code} message=${e.message}\n$st');
      } else {
        debugPrint('sendMessage Firestore: $e\n$st');
      }
      _chatError = 'تعذّر إرسال الرسالة. تحقق من الاتصال والصلاحيات.';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendTrialMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
      );
      if (_messages[chatRoomId] == null) {
        _messages[chatRoomId] = [];
      }
      _messages[chatRoomId]!.add(message);

      final chatRoomIndex = _chatRooms.indexWhere((room) => room.id == chatRoomId);
      if (chatRoomIndex != -1) {
        _chatRooms[chatRoomIndex] = _chatRooms[chatRoomIndex].copyWith(
          lastMessageText: text,
          lastMessageTime: DateTime.now(),
        );
      }
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));

      String autoReply = '';
      if (chatRoomId == '1') {
        if (text.contains('سعر')) {
          autoReply = 'سعر العقار 1,500,000 ريال، قابل للتفاوض';
        } else if (text.contains('موقع') || text.contains('العنوان')) {
          autoReply = 'العقار يقع في حي الملقا، شمال الرياض';
        } else if (text.contains('مساحة')) {
          autoReply = 'مساحة العقار 450 متر مربع';
        } else {
          autoReply = 'شكراً لاهتمامك، هل لديك أي استفسارات أخرى عن العقار؟';
        }
      } else {
        if (text.contains('سعر')) {
          autoReply = 'سعر السيارة 150,000 ريال، قابل للتفاوض';
        } else if (text.contains('موديل') || text.contains('سنة')) {
          autoReply = 'موديل السيارة 2023';
        } else if (text.contains('كم') || text.contains('ممشى')) {
          autoReply = 'الممشى 15,000 كم فقط';
        } else {
          autoReply = 'شكراً لاهتمامك، هل لديك أي استفسارات أخرى عن السيارة؟';
        }
      }

      final replyMessage = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_reply',
        senderId: chatRoomId == '1' ? 'seller_1' : 'seller_2',
        text: autoReply,
        timestamp: DateTime.now(),
      );

      _messages[chatRoomId]!.add(replyMessage);
      if (chatRoomIndex != -1) {
        _chatRooms[chatRoomIndex] = _chatRooms[chatRoomIndex].copyWith(
          lastMessageText: autoReply,
          lastMessageTime: DateTime.now(),
        );
      }
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectChatRoom(String? chatRoomId, {bool fromList = false}) {
    if (chatRoomId == null || chatRoomId.isEmpty) {
      final prev = _selectedChatRoomId;
      if (prev != null) {
        _messageSubscriptions[prev]?.cancel();
        _messageSubscriptions.remove(prev);
      }
      _selectedChatRoomId = null;
      _activeSpotlightTitle = null;
      notifyListeners();
      return;
    }

    if (fromList) {
      ChatRoom? room;
      for (final r in _chatRooms) {
        if (r.id == chatRoomId) {
          room = r;
          break;
        }
      }
      final vt = room?.spotlightVideoTitle?.trim();
      if (vt != null && vt.isNotEmpty) {
        _activeSpotlightTitle = vt;
      } else if (room != null &&
          room.propertyId != null &&
          room.propertyId!.isNotEmpty) {
        _activeSpotlightTitle =
            room.propertyType == 'car' ? 'محادثة سيارة' : 'محادثة عقار';
      } else {
        _activeSpotlightTitle = null;
      }
    }

    _selectedChatRoomId = chatRoomId;
    loadMessages(chatRoomId);
    notifyListeners();
  }

  void clearChatError() {
    _chatError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sellerInboxListMode = ChatSellerInboxListMode.none;
    _sellerInboxVideoId = null;
    _sellerInboxVideoTitleForAppBar = null;
    _prefsSubscription?.cancel();
    _prefsSubscription = null;
    _archivedRoomIds = {};
    _mutedRoomIds = {};
    _chatRoomsSubscription?.cancel();
    _chatRoomsSubscription = null;

    for (final subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();

    _messages.clear();
    _chatRooms.clear();
    super.dispose();
  }
}
