# إعداد قواعد Firebase Storage

## المشكلة
عند محاولة رفع فيديو، يظهر الخطأ:
```
[firebase_storage/unauthorized] User is not authorized to perform the desired action
```

## الحل
يجب تحديث قواعد الأمان في Firebase Storage Console.

## خطوات الإعداد

### 1. فتح Firebase Console
- اذهب إلى: https://console.firebase.google.com/
- اختر المشروع: `mastermax-2030-backend`

### 2. فتح Storage Rules
- من القائمة الجانبية، اختر **Storage**
- اضغط على تبويب **Rules**

### 3. نسخ القواعد التالية
انسخ والصق القواعد التالية في محرر القواعد:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // قواعد محددة للفيديوهات (يجب أن تأتي أولاً)
    match /videos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // قواعد محددة للصور المصغرة
    match /thumbnails/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // قواعد محددة للصور (العقارات والسيارات)
    match /images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // قواعد محددة للوثائق
    match /documents/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // قاعدة عامة: السماح للمستخدمين المسجلين فقط (يجب أن تأتي في النهاية)
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 4. حفظ القواعد
- اضغط على **Publish** لحفظ القواعد

## ملاحظات مهمة

1. **الأمان**: القواعد الحالية تسمح فقط للمستخدمين المسجلين (المصادق عليهم) برفع الملفات
2. **التحقق من الهوية**: كل مستخدم يمكنه فقط رفع الملفات في مجلده الخاص (`userId`)
3. **القراءة**: جميع المستخدمين المسجلين يمكنهم قراءة الملفات
4. **الكتابة**: المستخدم يمكنه الكتابة فقط في مجلده الخاص

## اختبار القواعد

بعد حفظ القواعد:
1. تأكد من تسجيل الدخول في التطبيق
2. حاول رفع فيديو جديد
3. يجب أن يعمل الرفع بنجاح الآن

## استكشاف الأخطاء

إذا استمرت المشكلة:
1. تأكد من أن المستخدم مسجل دخول (`FirebaseAuth.instance.currentUser != null`)
2. تحقق من أن قواعد Storage تم نشرها بنجاح
3. تحقق من أن `userId` في مسار الملف يطابق `request.auth.uid`

