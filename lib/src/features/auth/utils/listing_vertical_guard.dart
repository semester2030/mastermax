import '../models/user_type.dart';

/// فصل صارم بين نشر **العقارات** ونشر **السيارات** حسب نوع الحساب.
///
/// - حسابات العقار: شركة عقارية، وسيط عقاري — عقارات فقط (لا سيارات).
/// - حسابات السيارات: معرض، تاجر — سيارات فقط (لا عقارات).
/// - الفرد [individual]: **سيارات فقط** — لا يُسمح بنشر عقارات (ضوابط التسويق العقاري).
/// - الأدمن: يتجاوز القيود لأغراض الإدارة.
abstract final class ListingVerticalGuard {
  static const String carsDeniedMessage =
      'حسابك مسجّل كقطاع عقارات. لا يمكن إضافة أو نشر إعلانات سيارات من هذا الحساب.';

  /// حساب قطاع سيارات يحاول نشر عقار.
  static const String propertiesDeniedForCarsVerticalMessage =
      'حسابك مسجّل كقطاع سيارات. لا يمكن إضافة أو نشر إعلانات عقارية من هذا الحساب.';

  /// حساب فرد يحاول نشر عقار (غير مسموح قانونياً/تنظيمياً عبر التطبيق).
  static const String propertiesDeniedForIndividualMessage =
      'حساب الأفراد مخصّص لإعلانات المركبات فقط. لا يُسمح بنشر إعلانات عقارية من حساب فردي.';

  /// رسالة الرفض عند محاولة فتح إضافة/تعديل عقار دون صلاحية.
  static String denialMessageForPropertyListing(UserType type) {
    if (type == UserType.individual) {
      return propertiesDeniedForIndividualMessage;
    }
    return propertiesDeniedForCarsVerticalMessage;
  }

  static bool mayPublishProperties(UserType type, {bool isAdmin = false}) {
    if (isAdmin) return true;
    switch (type) {
      case UserType.realEstateCompany:
      case UserType.realEstateAgent:
        return true;
      case UserType.individual:
      case UserType.carDealer:
      case UserType.carTrader:
        return false;
    }
  }

  static bool mayPublishCars(UserType type, {bool isAdmin = false}) {
    if (isAdmin) return true;
    switch (type) {
      case UserType.carDealer:
      case UserType.carTrader:
      case UserType.individual:
        return true;
      case UserType.realEstateCompany:
      case UserType.realEstateAgent:
        return false;
    }
  }
}
