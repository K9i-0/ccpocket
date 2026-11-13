import Flutter
import UIKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appIconChannelName = "ccpocket/app_icon"
  private let clipboardChannelName = "ccpocket/clipboard"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoLibraryChannel") {
      let channel = FlutterMethodChannel(name: "ccpocket/photo_library", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler(handlePhotoLibraryMethodCall)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconChannel") {
      let channel = FlutterMethodChannel(
        name: appIconChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler(handleAppIconMethodCall)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FloatingKeyboardChannel") {
      FloatingKeyboardTracker.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClipboardChannel") {
      let channel = FlutterMethodChannel(
        name: clipboardChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler(handleClipboardMethodCall)
      if #available(iOS 16.0, *) {
        let imagePasteMenu = ImagePasteMenu()
        let menuChannel = FlutterMethodChannel(
          name: "ccpocket/image_paste_menu", binaryMessenger: registrar.messenger()
        )
        menuChannel.setMethodCallHandler(imagePasteMenu.handle)
        registrar.register(
          ImagePasteViewFactory(messenger: registrar.messenger()),
          withId: "ccpocket/image_paste_button"
        )
      }
    }
  }

  private func handlePhotoLibraryMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "save" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let isVideo = args["isVideo"] as? Bool,
          (args["path"] as? String != nil || args["bytes"] as? FlutterStandardTypedData != nil) else {
      result(FlutterError(code: "invalid_args", message: nil, details: nil))
      return
    }
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_denied", message: nil, details: nil))
        }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        let type: PHAssetResourceType = isVideo ? .video : .photo
        if let path = args["path"] as? String {
          request.addResource(with: type, fileURL: URL(fileURLWithPath: path), options: nil)
        } else if let bytes = args["bytes"] as? FlutterStandardTypedData {
          request.addResource(with: type, data: bytes.data, options: nil)
        }
      }) { success, error in
        DispatchQueue.main.async {
          result(success ? nil : FlutterError(code: "save_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleAppIconMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "supportsAlternateIcons":
      result(UIApplication.shared.supportsAlternateIcons)
    case "getCurrentIcon":
      result(currentIconId())
    case "setIcon":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
        return
      }
      let icon = args["icon"] as? String
      setAlternateIcon(icon: icon, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleClipboardMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "supportsPasteControl" {
      if #available(iOS 16.0, *) {
        result(true)
      } else {
        result(false)
      }
      return
    }
    guard call.method == "hasSupportedImage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let supportedTypes = [
      "com.compuserve.gif",
      "org.webmproject.webp",
      "public.png",
      "public.jpeg",
    ]
    result(
      UIPasteboard.general.contains(
        pasteboardTypes: supportedTypes,
        inItemSet: nil
      )
    )
  }

  private func currentIconId() -> String? {
    switch UIApplication.shared.alternateIconName {
    case "SupporterLightOutline":
      return "light_outline"
    case "SupporterProCopperEmerald":
      return "pro_copper_emerald"
    default:
      return nil
    }
  }

  private func setAlternateIcon(icon: String?, result: @escaping FlutterResult) {
    guard UIApplication.shared.supportsAlternateIcons else {
      result(FlutterError(code: "unsupported", message: "Alternate icons unsupported", details: nil))
      return
    }

    let iconName: String?
    switch icon {
    case nil, "default":
      iconName = nil
    case "light_outline":
      iconName = "SupporterLightOutline"
    case "pro_copper_emerald":
      iconName = "SupporterProCopperEmerald"
    default:
      result(FlutterError(code: "invalid_icon", message: "Unknown app icon \(icon ?? "nil")", details: nil))
      return
    }

    DispatchQueue.main.async {
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error {
          result(
            FlutterError(
              code: "set_icon_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(nil)
      }
    }
  }
}

/// Streams the keyboard frame from `keyboardLayoutGuide` with
/// `followsUndockedKeyboard = true`, so Dart can follow iPad floating and
/// undocked keyboards. Flutter's own `viewInsets` stay 0 for those keyboards.
/// Event: {x, y, w, h, viewW, viewH} in the Flutter view's logical points.
final class FloatingKeyboardTracker: NSObject, FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var sink: FlutterEventSink?
  private var trackerView: KeyboardGuideTrackerView?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FloatingKeyboardTracker()
    instance.registrar = registrar
    FlutterEventChannel(
      name: "ccpocket/floating_keyboard",
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    attach()
    if let view = trackerView { send(view.frame) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func attach(retries: Int = 50) {
    guard trackerView == nil else { return }
    guard let host = registrar?.viewController?.view else {
      if retries > 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.attach(retries: retries - 1)
        }
      }
      return
    }
    let view = KeyboardGuideTrackerView()
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    view.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(view)
    let guide = host.keyboardLayoutGuide
    guide.followsUndockedKeyboard = true
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
      view.topAnchor.constraint(equalTo: guide.topAnchor),
      view.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    view.onFrameChange = { [weak self] frame in self?.send(frame) }
    trackerView = view
    host.layoutIfNeeded()
  }

  private func send(_ frame: CGRect) {
    guard let sink, let host = trackerView?.superview else { return }
    sink([
      "x": frame.origin.x, "y": frame.origin.y,
      "w": frame.size.width, "h": frame.size.height,
      "viewW": host.bounds.width, "viewH": host.bounds.height,
    ])
  }
}

/// Invisible view pinned to the keyboard layout guide; reports frame changes,
/// which UIKit applies every frame while a floating keyboard is dragged.
final class KeyboardGuideTrackerView: UIView {
  var onFrameChange: ((CGRect) -> Void)?
  private var lastFrame: CGRect = .null

  override var center: CGPoint { didSet { notifyIfChanged() } }
  override var bounds: CGRect { didSet { notifyIfChanged() } }
  override var frame: CGRect { didSet { notifyIfChanged() } }

  private func notifyIfChanged() {
    let current = frame
    guard !current.equalTo(lastFrame) else { return }
    lastFrame = current
    onFrameChange?(current)
  }
}
