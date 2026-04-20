# حل مشكلة Xcode Timeout

## المشكلة
```
Error starting debug session in Xcode: Timed out waiting for CONFIGURATION_BUILD_DIR to update.
Could not run build/ios/iphoneos/Runner.app on 00008110-00191986268BA01E.
```

## الحلول المنفذة تلقائياً ✅

1. ✅ `flutter clean` - تنظيف المشروع
2. ✅ إعادة تثبيت Pods
3. ✅ حذف DerivedData (محاولة)
4. ✅ تشغيل في وضع Release

## الحلول الإضافية (إذا استمرت المشكلة)

### الحل 1: تشغيل من Xcode مباشرة
```bash
open ios/Runner.xcworkspace
```
ثم في Xcode:
1. اختر الجهاز من القائمة العلوية
2. اضغط `Product > Run` (أو Cmd+R)

### الحل 2: إعادة تشغيل الجهاز
- أعد تشغيل iPhone
- أعد تشغيل Mac

### الحل 3: حذف التطبيق من الجهاز
1. احذف التطبيق من iPhone
2. أعد التشغيل:
```bash
flutter run -d 00008110-00191986268BA01E
```

### الحل 4: إعادة تسجيل الجهاز
1. افتح Xcode
2. `Window > Devices and Simulators`
3. احذف الجهاز وأعد تسجيله

### الحل 5: استخدام وضع Release
```bash
flutter run -d 00008110-00191986268BA01E --release
```

### الحل 6: إعادة تثبيت Xcode Command Line Tools
```bash
sudo xcode-select --reset
sudo xcode-select --install
```

### الحل 7: تنظيف شامل
```bash
cd ios
rm -rf Pods Podfile.lock .symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData/*
cd ..
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

## الحل الموصى به الآن

**جرب الحل 1 أولاً** (تشغيل من Xcode مباشرة):
```bash
open ios/Runner.xcworkspace
```

ثم في Xcode:
- اختر الجهاز
- اضغط `Product > Run`

إذا لم يعمل، جرب الحل 5 (وضع Release) - تم تشغيله تلقائياً في الخلفية.

