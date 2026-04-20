# نشر قواعد Firebase Storage باستخدام CMD

## ✅ تم تثبيت Firebase CLI بنجاح!

## الخطوات:

### 1. تسجيل الدخول إلى Firebase
```bash
cd /Users/fayez/Desktop/mastermax/mastermax
firebase login
```
- سيتم فتح المتصفح تلقائياً
- سجل دخولك بحساب Google المرتبط بـ Firebase
- بعد تسجيل الدخول، ارجع إلى Terminal

### 2. ربط المشروع
```bash
firebase use mastermax-2030-backend
```

### 3. نشر القواعد
```bash
firebase deploy --only storage
```

## أو الحل الأسهل (يدوياً):

### في Firebase Console:
1. **فعّل Authentication** في Rules Playground (ON)
2. **انسخ القواعد** من ملف `storage.rules`
3. **الصقها** في محرر القواعد
4. **اضغط Publish**

## القواعد الصحيحة (من storage.rules):

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

