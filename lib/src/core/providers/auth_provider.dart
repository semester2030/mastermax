import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/models/user_model.dart';

/// مزود المصادقة
class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider() {
    // الاستماع لتغييرات حالة المصادقة
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// المستخدم الحالي
  UserModel? get currentUser => _currentUser;

  /// تسجيل الدخول
  Future<bool> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // التحقق من تأكيد البريد الإلكتروني
      if (!userCredential.user!.emailVerified) {
        await signOut();
        throw Exception('يرجى تأكيد بريدك الإلكتروني أولاً');
      }

      // جلب بيانات المستخدم من Firestore
      final userData = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userData.exists) {
        _currentUser = UserModel.fromJson(userData.data()!);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  /// تحديث بيانات المستخدم
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .update(user.toJson());
      
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  /// التحقق من حالة المصادقة
  bool get isAuthenticated => _currentUser != null;

  /// التحقق من صلاحيات المستخدم
  bool hasPermission(String permission) {
    return _currentUser?.additionalInfo?['permissions']?.contains(permission) ?? false;
  }

  /// معالجة تغييرات حالة المصادقة
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      // التحقق من تأكيد البريد الإلكتروني
      if (!firebaseUser.emailVerified) {
        await signOut();
        return;
      }

      final userData = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (userData.exists) {
        _currentUser = UserModel.fromJson(userData.data()!);
        notifyListeners();
      }
    } catch (e) {
      // Handle error
      await signOut();
    }
  }
} 