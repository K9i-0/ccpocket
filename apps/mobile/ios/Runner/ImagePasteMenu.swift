import Flutter
import UIKit

/// Adds a real paste-identified action to the text field's native edit menu.
/// Uses public responder/menu APIs; does not modify Flutter's input view class.
@available(iOS 16.0, *)
final class ImagePasteMenu: NSObject, UIEditMenuInteractionDelegate {
  private var interaction: UIEditMenuInteraction?
  private var pendingResult: FlutterResult?
  private var requestId: Int?
  private var imageTitle = ""
  private var isLoading = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "show":
      guard let id = args?["requestId"] as? Int,
            let title = args?["title"] as? String,
            let x = args?["x"] as? Double, let y = args?["y"] as? Double else {
        result(FlutterError(code: "invalid_args", message: nil, details: nil))
        return
      }
      finish(nil)
      let windows = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap { $0.windows }
      guard let window = windows.first(where: { $0.isKeyWindow }),
            let input = Self.findTextInput(in: window) else {
        result(nil)
        return
      }
      requestId = id
      imageTitle = title
      pendingResult = result
      isLoading = false
      let menu = UIEditMenuInteraction(delegate: self)
      interaction = menu
      input.addInteraction(menu)
      let source = input.convert(CGPoint(x: x, y: y), from: window)
      menu.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: source))
    case "cancel":
      if args?["requestId"] as? Int == requestId { finish(nil) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func findTextInput(in view: UIView) -> UIView? {
    if view.isFirstResponder, view is UITextInput { return view }
    for child in view.subviews {
      if let input = findTextInput(in: child) { return input }
    }
    return nil
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions: [UIMenuElement]
  ) -> UIMenu? {
    let id = requestId
    return Self.menu(title: imageTitle, suggestedActions: suggestedActions) { [weak self] in
      guard let self, let id, self.requestId == id, !self.isLoading else { return }
      self.isLoading = true
      // Capture providers synchronously inside the genuine .paste menu action.
      // Calling this later from Dart would lose the system's paste intent.
      let providers = UIPasteboard.general.itemProviders
      ImagePasteReader.read(providers) { [weak self] payload in
        guard let self, self.requestId == id else { return }
        self.finish(payload)
      }
    }
  }

  static func menu(
    title: String, suggestedActions: [UIMenuElement], onPaste: @escaping () -> Void
  ) -> UIMenu {
    let paste = UIAction(title: title, image: nil, identifier: .paste) { _ in onPaste() }
    // Keep UIKit's standard text actions and suggestions intact.
    return UIMenu(children: [paste] + suggestedActions)
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    willDismissMenuFor configuration: UIEditMenuConfiguration,
    animator: UIEditMenuInteractionAnimating
  ) {
    let id = requestId
    animator.addCompletion { [weak self] in
      guard let self, self.requestId == id, !self.isLoading else { return }
      self.finish(nil)
    }
  }

  private func finish(_ payload: Any?) {
    let result = pendingResult
    let menu = interaction
    pendingResult = nil
    interaction = nil
    requestId = nil
    isLoading = false
    menu?.dismissMenu()
    if let menu { menu.view?.removeInteraction(menu) }
    result?(payload)
  }
}
