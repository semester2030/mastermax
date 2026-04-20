/// الهوية الظاهرة للمستخدم (اسم + شعار).
///
/// لا تغيّر من هنا: معرف الحزمة، Bundle ID، Firebase، عناوين API، أو بريد الأدمن.
abstract final class AppBrand {
  static const String displayName = 'دار كار';

  /// الشعار الرسمي (PNG بقناة ألفا — الملف: `dar_car_logo.png`).
  static const String logoAsset = 'assets/images/logos/dar_car_logo.png';

  /// نسبة عرض/ارتفاع ملف الشعار (1536×1024) — لاستخدامها مع [AspectRatio] وتفادي فراغ تحت الصورة.
  static const double logoImageAspectRatio = 1536 / 1024;
}
