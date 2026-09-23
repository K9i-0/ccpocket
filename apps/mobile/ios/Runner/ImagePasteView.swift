import Flutter
import UIKit

@available(iOS 16.0, *)
final class ImagePasteViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    ImagePastePlatformView(frame: frame, viewId: viewId, messenger: messenger, args: args)
  }
}

@available(iOS 16.0, *)
private final class ImagePastePlatformView: NSObject, FlutterPlatformView {
  private let pasteView: ImagePasteView

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
    let channel = FlutterMethodChannel(
      name: "ccpocket/image_paste_button/\(viewId)", binaryMessenger: messenger
    )
    pasteView = ImagePasteView(frame: frame, channel: channel, args: args as? [String: Any])
    super.init()
  }

  func view() -> UIView { pasteView }
}

/// Only consumes providers delivered by a real tap on UIPasteControl. Never
/// re-read UIPasteboard here: that would bring back the permission prompt.
@available(iOS 16.0, *)
private final class ImagePasteView: UIView {
  private let channel: FlutterMethodChannel
  private var isLoading = false

  init(frame: CGRect, channel: FlutterMethodChannel, args: [String: Any]?) {
    self.channel = channel
    super.init(frame: frame)
    pasteConfiguration = UIPasteConfiguration(
      acceptableTypeIdentifiers: ImagePasteReader.formats.map { $0.0 }
    )
    overrideUserInterfaceStyle = args?["dark"] as? Bool == true ? .dark : .light
    let configuration = UIPasteControl.Configuration()
    configuration.displayMode = .iconAndLabel
    configuration.cornerStyle = .capsule
    if let background = args?["backgroundColor"] as? NSNumber {
      configuration.baseBackgroundColor = Self.color(background.uint32Value)
    }
    if let foreground = args?["foregroundColor"] as? NSNumber {
      configuration.baseForegroundColor = Self.color(foreground.uint32Value)
    }
    let control = UIPasteControl(configuration: configuration)
    control.target = self
    control.accessibilityIdentifier = "ios_image_paste_button"
    control.translatesAutoresizingMaskIntoConstraints = false
    addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.topAnchor.constraint(equalTo: topAnchor),
      control.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    if args?["menuStyle"] as? Bool == true {
      // UIPasteControl centers its contents even with .leading alignment.
      // Keep its intrinsic width and align the actual system control instead.
      control.setContentHuggingPriority(.required, for: .horizontal)
      control.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor).isActive = true
    } else {
      control.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func paste(itemProviders: [NSItemProvider]) {
    guard !isLoading else { return }
    isLoading = true
    isUserInteractionEnabled = false
    ImagePasteReader.read(itemProviders) { [weak self] payload in
      guard let self else { return }
      self.isLoading = false
      if payload is FlutterError {
        self.isUserInteractionEnabled = true
        self.channel.invokeMethod("error", arguments: nil)
      } else {
        self.channel.invokeMethod("image", arguments: payload)
      }
    }
  }

  private static func color(_ argb: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}

/// Shared item-provider decoder for the native button and native paste menu.
/// The caller obtains providers only from a system-authorized paste interaction.
enum ImagePasteReader {
  static let formats = [
    ("com.compuserve.gif", "image/gif"),
    ("org.webmproject.webp", "image/webp"),
    ("public.png", "image/png"),
    ("public.jpeg", "image/jpeg"),
  ]

  static func read(_ providers: [NSItemProvider], completion: @escaping (Any) -> Void) {
    for provider in providers {
      for (type, mimeType) in formats where provider.hasItemConformingToTypeIdentifier(type) {
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
          DispatchQueue.main.async {
            if let data, !data.isEmpty, error == nil {
              completion(["bytes": FlutterStandardTypedData(bytes: data), "mimeType": mimeType])
            } else {
              completion(FlutterError(code: "image_read_failed", message: nil, details: nil))
            }
          }
        }
        return
      }
    }
    completion(FlutterError(code: "no_image", message: nil, details: nil))
  }
}
