import 'package:cloud_firestore/cloud_firestore.dart';

/// تفضيلات شخصية: إخفاء خيط من القائمة، كتم (للإشعارات لاحقاً).
/// لا تُعدّل [chatRooms] — الطرف الآخر لا يتأثر.
class ChatPrefsState {
  final Set<String> archivedRoomIds;
  final Set<String> mutedRoomIds;

  const ChatPrefsState({
    this.archivedRoomIds = const {},
    this.mutedRoomIds = const {},
  });

  static const empty = ChatPrefsState();
}

class ChatPrefsService {
  ChatPrefsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const int _maxRoomIdsPerList = 400;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _db.collection('userChatPrefs').doc(userId);

  Stream<ChatPrefsState> watchPrefs(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return Stream.value(ChatPrefsState.empty);
    }
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return ChatPrefsState.empty;
      }
      final d = snap.data()!;
      final a =
          (d['archivedRoomIds'] as List?)?.map((e) => '$e').toSet() ?? {};
      final m = (d['mutedRoomIds'] as List?)?.map((e) => '$e').toSet() ?? {};
      return ChatPrefsState(archivedRoomIds: a, mutedRoomIds: m);
    });
  }

  Future<void> setArchived(String userId, String roomId, bool archived) async {
    final uid = userId.trim();
    final rid = roomId.trim();
    if (uid.isEmpty || rid.isEmpty) return;

    final ref = _doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      var list = List<String>.from(
        (data['archivedRoomIds'] as List?)?.map((e) => '$e') ?? const [],
      );
      final muted = List<String>.from(
        (data['mutedRoomIds'] as List?)?.map((e) => '$e') ?? const [],
      );
      if (archived) {
        list.remove(rid);
        list.insert(0, rid);
        while (list.length > _maxRoomIdsPerList) {
          list = list.sublist(0, _maxRoomIdsPerList);
        }
      } else {
        list.remove(rid);
      }
      tx.set(
        ref,
        {'archivedRoomIds': list, 'mutedRoomIds': muted},
        SetOptions(merge: true),
      );
    });
  }

  Future<void> setMuted(String userId, String roomId, bool mutedFlag) async {
    final uid = userId.trim();
    final rid = roomId.trim();
    if (uid.isEmpty || rid.isEmpty) return;

    final ref = _doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final archived = List<String>.from(
        (data['archivedRoomIds'] as List?)?.map((e) => '$e') ?? const [],
      );
      var list = List<String>.from(
        (data['mutedRoomIds'] as List?)?.map((e) => '$e') ?? const [],
      );
      if (mutedFlag) {
        list.remove(rid);
        list.insert(0, rid);
        while (list.length > _maxRoomIdsPerList) {
          list = list.sublist(0, _maxRoomIdsPerList);
        }
      } else {
        list.remove(rid);
      }
      tx.set(
        ref,
        {'archivedRoomIds': archived, 'mutedRoomIds': list},
        SetOptions(merge: true),
      );
    });
  }
}
