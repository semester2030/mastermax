import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// يربط دورة حياة التطبيق بتسجيل جلسات المستخدم في Firestore (`app_sessions`) للعرض في لوحة المراقبة.
///
/// يُنشأ مستند عند كل [AppLifecycleState.resumed] للمستخدم المسجّل، ويُحدَّد عند [AppLifecycleState.paused].
class SessionTelemetryHost extends StatefulWidget {
  const SessionTelemetryHost({super.key, required this.child});

  final Widget child;

  @override
  State<SessionTelemetryHost> createState() => _SessionTelemetryHostState();
}

class _SessionTelemetryHostState extends State<SessionTelemetryHost> with WidgetsBindingObserver {
  static const String _collection = 'app_sessions';

  String? _sessionDocId;
  DateTime? _foregroundStarted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_startSession());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_endSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startSession());
    } else if (state == AppLifecycleState.paused) {
      unawaited(_endSession());
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> _startSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _endSession();

    final docId = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    _sessionDocId = docId;
    _foregroundStarted = DateTime.now();

    try {
      await FirebaseFirestore.instance.collection(_collection).doc(docId).set({
        'userId': user.uid,
        'email': user.email ?? '',
        'platform': _platformLabel(),
        'startedAt': FieldValue.serverTimestamp(),
        'foregroundSeconds': 0,
        'endedAt': null,
      });
    } catch (e, st) {
      debugPrint('SessionTelemetryHost._startSession: $e\n$st');
      _sessionDocId = null;
      _foregroundStarted = null;
    }
  }

  Future<void> _endSession() async {
    final docId = _sessionDocId;
    final started = _foregroundStarted;
    _sessionDocId = null;
    _foregroundStarted = null;
    if (docId == null || started == null) return;

    final seconds = DateTime.now().difference(started).inSeconds.clamp(0, 86400 * 7);

    try {
      await FirebaseFirestore.instance.collection(_collection).doc(docId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'foregroundSeconds': seconds,
      });
    } catch (e, st) {
      debugPrint('SessionTelemetryHost._endSession: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
