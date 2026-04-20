/// مفاتيح موحّدة لوسائط [Navigator.pushNamed] → [ChatScreen] (تفادي التكرار والتعارض).
abstract final class ChatScreenRouteArgs {
  ChatScreenRouteArgs._();

  /// `bool`: المالك يفتح محادثات هذا المقطع فقط ([videoId] مطلوب).
  static const String sellerInboxForVideo = 'sellerInboxForVideo';

  /// `bool`: من الملف الشخصي — كل محادثات البائع على إعلانات سبوتلايت.
  static const String sellerInboxAllListings = 'sellerInboxAllListings';

  static const String sellerId = 'sellerId';
  static const String videoId = 'videoId';
  static const String propertyType = 'propertyType';
  static const String videoTitle = 'videoTitle';
  static const String sellerName = 'sellerName';
}
