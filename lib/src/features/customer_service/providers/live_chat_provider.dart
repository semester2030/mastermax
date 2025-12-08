import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/live_chat_service.dart';

class LiveChatProvider with ChangeNotifier {
  final LiveChatService _service = LiveChatService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String? get error => _error;

  Future<void> connectToChat() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.connect();
      _messages = await _service.getMessages();
      _isConnected = true;
      
      // إضافة رسائل تجريبية في حالة عدم وجود رسائل
      if (_messages.isEmpty) {
        final now = DateTime.now();
        _messages = [
          ChatMessage(
            id: '1',
            userId: 'trial_user',
            message: 'مرحباً، أحتاج إلى مساعدة',
            isStaff: false,
            timestamp: now.subtract(const Duration(minutes: 5)),
          ),
          ChatMessage(
            id: '2',
            userId: 'staff_1',
            message: 'مرحباً بك! كيف يمكنني مساعدتك؟',
            isStaff: true,
            timestamp: now.subtract(const Duration(minutes: 4)),
          ),
        ];
      }
      
      _isLoading = false;
      notifyListeners();

      // بدء الاستماع للرسائل الجديدة
      _service.listenToMessages((message) {
        _messages.add(message);
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String message) async {
    try {
      final newMessage = await _service.sendMessage(message);
      _messages.add(newMessage);
      notifyListeners();

      // محاكاة رد تلقائي من فريق الدعم بعد ثانيتين
      await Future.delayed(const Duration(seconds: 2));
      final autoReply = await _service.simulateStaffReply(message);
      _messages.add(autoReply);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendAttachment(String filePath) async {
    try {
      final message = await _service.sendAttachment(filePath);
      _messages.add(message);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void markAsRead(String messageId) {
    _service.markAsRead(messageId);
  }

  @override
  void dispose() {
    _service.disconnect();
    super.dispose();
  }
} 