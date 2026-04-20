import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps: GMSApiKey from Info.plist (GOOGLE_MAPS_API_KEY in ios/Flutter/*.xcconfig)
    var mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? ""
    if mapsKey.isEmpty || mapsKey.contains("$(") {
      mapsKey = "AIzaSyDqTUgEpUZmwM602S6TVc57d5erB_c-dr4"
    }
    GMSServices.provideAPIKey(mapsKey)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
