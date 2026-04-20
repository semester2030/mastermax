# دليل إعداد CRM للويب

## الملفات المطلوبة

### ✅ الملفات الجديدة (4 ملفات فقط):
```
lib/web/
├── web_main.dart              (162 سطر) - نقطة الدخول
├── web_router.dart            (147 سطر) - توجيه الصفحات
├── web_layout.dart            (342 سطر) - تصميم الويب (Sidebar + Header)
└── web_dashboard_screen.dart  (368 سطر) - لوحة التحكم
```

### ✅ الملفات الموجودة (نستخدمها مباشرة):
- ✅ 26 ملف في `real_estate/screens` (نستخدمها مباشرة)
- ✅ 5 خدمات في `real_estate/services` (نستخدمها مباشرة)
- ✅ جميع الـ Providers (نستخدمها مباشرة)
- ✅ جميع الـ Models (نستخدمها مباشرة)

## كيف يعمل الكود

### 1. نقطة الدخول (`web_main.dart`):
```dart
void main() {
  // 1. تهيئة Firebase للويب
  Firebase.initializeApp(options: DefaultFirebaseOptions.web)
  
  // 2. تهيئة الخدمات (نفس الخدمات الموجودة)
  final authService = AuthService();
  final rentalService = RentalService();
  
  // 3. تهيئة Providers (نفس الـ Providers)
  ChangeNotifierProvider(create: (_) => AuthState())
  ChangeNotifierProvider(create: (_) => RentalProvider(...))
  
  // 4. تشغيل التطبيق
  runApp(WebCrmApp())
}
```

### 2. التوجيه (`web_router.dart`):
```dart
switch (route) {
  case '/sales-management':
    return WebLayout(
      child: RealEstateSalesManagementScreen(), // ✅ نفس الملف الموجود!
      title: 'إدارة المبيعات',
    );
}
```

### 3. التصميم (`web_layout.dart`):
```dart
WebLayout(
  child: RealEstateSalesManagementScreen(), // ✅ المحتوى
  title: 'إدارة المبيعات',
)
  ↓
Scaffold(
  body: Row([
    Sidebar(),    // القائمة الجانبية (260px)
    Column([
      Header(),   // الهيدر (70px)
      child,      // المحتوى (نفس الشاشات الموجودة)
    ])
  ])
)
```

## كيفية التشغيل

### الطريقة 1: استخدام `web_main.dart` منفصل (موصى به)

```bash
# بناء نسخة الويب
flutter build web --target=lib/web/web_main.dart

# تشغيل محلي
flutter run -d chrome --target=lib/web/web_main.dart
```

### الطريقة 2: تعديل `main.dart` للتحقق من `kIsWeb`

يمكن تعديل `main.dart` ليتحقق من `kIsWeb` ويستخدم `web_main` تلقائياً.

## النشر على Firebase Hosting

```bash
# 1. بناء نسخة الويب
flutter build web --target=lib/web/web_main.dart --release

# 2. النشر
firebase deploy --only hosting
```

## البنية النهائية

```
lib/
├── main.dart                    (للموبايل)
└── web/
    ├── web_main.dart            (للويب - نقطة الدخول)
    ├── web_router.dart          (توجيه الصفحات)
    ├── web_layout.dart          (تصميم الويب)
    └── web_dashboard_screen.dart (لوحة التحكم)
```

## المزايا

✅ **4 ملفات فقط** - كل شيء منظم
✅ **نفس الكود** - نستخدم جميع الملفات الموجودة
✅ **نفس البيانات** - Firebase Firestore
✅ **نفس المصادقة** - Firebase Auth
✅ **سهولة الصيانة** - كل شيء منظم
