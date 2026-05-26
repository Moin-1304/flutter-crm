import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API key from ios/Flutter/GoogleMapsKey.xcconfig (see MAPS_SETUP.md)
    let mapsKey = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let placeholder = "YOUR_GOOGLE_MAPS_API_KEY"
    let unresolved = "$(GOOGLE_MAPS_API_KEY)"
    if let key = mapsKey, !key.isEmpty, key != placeholder, key != unresolved, key.hasPrefix("AIza") {
      GMSServices.provideAPIKey(key)
    } else {
      if mapsKey == nil || mapsKey?.isEmpty == true || mapsKey == unresolved {
        print("MAPS: Google Maps API key not set for iOS. Copy ios/Flutter/GoogleMapsKey.xcconfig.example to GoogleMapsKey.xcconfig and add your key. See MAPS_SETUP.md")
      }
      GMSServices.provideAPIKey(placeholder)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
