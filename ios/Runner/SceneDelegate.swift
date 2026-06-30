import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let messenger = (window?.rootViewController as? FlutterViewController)?.binaryMessenger
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "epilog/app_icon",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "supportsAlternateIcons":
        result(UIApplication.shared.supportsAlternateIcons)
      case "setAlternateIcon":
        guard UIApplication.shared.supportsAlternateIcons else {
          result(
            FlutterError(
              code: "unsupported",
              message: "Alternate app icons are not supported on this device.",
              details: nil
            )
          )
          return
        }

        let arguments = call.arguments as? [String: Any]
        let iconName = arguments?["iconName"] as? String
        UIApplication.shared.setAlternateIconName(iconName) { error in
          if let error = error {
            result(
              FlutterError(
                code: "set_icon_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
