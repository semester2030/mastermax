import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  List<ChatRoom> _chatRooms = [];
  final Map<String, List<ChatMessage>> _messages = {};
  String? _selectedChatRoomId;
  bool _isLoading = false;

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  List<ChatMessage> get currentMessages => 
      _selectedChatRoomId != null ? _messages[_selectedChatRoomId!] ?? [] : [];
  bool get isLoading => _isLoading;
  String? get selectedChatRoomId => _selectedChatRoomId;

  // تحميل محادثات تجريبية لمنصة أضواء ماكس
  void loadTrialChatRooms() {
    _isLoading = true;
    notifyListeners();

    // محادثات تجريبية
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

    // رسائل تجريبية للمحادثة الأولى
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

    // رسائل تجريبية للمحادثة الثانية
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

  // تحميل المحادثات للمستخدم الحالي
  void loadChatRooms(String userId) {
    _chatService.getChatRooms(userId).listen((rooms) {
      _chatRooms = rooms;
      notifyListeners();
    });
  }

  // تحميل رسائل محادثة معينة
  void loadMessages(String chatRoomId) {
    _selectedChatRoomId = chatRoomId;
    _chatService.getChatMessages(chatRoomId).listen((messages) {
      _messages[chatRoomId] = messages;
      notifyListeners();
    });
  }

  // إنشاء أو فتح محادثة
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

  // إرسال رسالة
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      // في الوضع التجريبي
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
      );

      // إضافة الرسالة المرسلة
      if (_messages[chatRoomId] == null) {
        _messages[chatRoomId] = [];
      }
      _messages[chatRoomId]!.add(message);

      // تحديث آخر رسالة في المحادثة
      final chatRoomIndex = _chatRooms.indexWhere((room) => room.id == chatRoomId);
      if (chatRoomIndex != -1) {
        _chatRooms[chatRoomIndex] = _chatRooms[chatRoomIndex].copyWith(
          lastMessageText: text,
          lastMessageTime: DateTime.now(),
        );
      }

      notifyListeners();

      // إضافة رد تلقائي بعد ثانيتين
      await Future.delayed(const Duration(seconds: 2));
      
      String autoReply = '';
      if (chatRoomId == '1') { // محادثة العقار
        if (text.contains('سعر')) {
          autoReply = 'سعر العقار 1,500,000 ريال، قابل للتفاوض';
        } else if (text.contains('موقع') || text.contains('العنوان')) {
          autoReply = 'العقار يقع في حي الملقا، شمال الرياض';
        } else if (text.contains('مساحة')) {
          autoReply = 'مساحة العقار 450 متر مربع';
        } else {
          autoReply = 'شكراً لاهتمامك، هل لديك أي استفسارات أخرى عن العقار؟';
        }
      } else { // محادثة السيارة
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
      
      // تحديث آخر رسالة في المحادثة
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

  // تغيير المحادثة المحددة
  void selectChatRoom(String chatRoomId) {
    _selectedChatRoomId = chatRoomId;
    loadMessages(chatRoomId);
    notifyListeners();
  }

  @override
  void dispose() {
    _messages.clear();
    _chatRooms.clear();
    super.dispose();
  }
} 