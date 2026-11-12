#include "flutter_window.h"

#include <commctrl.h>
#include <wchar.h>

#include <iterator>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Opt-in switch: set CCPOCKET_DISABLE_ACCESSIBILITY=1 to keep the Windows
// accessibility bridge off.
constexpr wchar_t kDisableAccessibilityEnv[] = L"CCPOCKET_DISABLE_ACCESSIBILITY";
constexpr UINT_PTR kAccessibilityGuardSubclassId = 1;
// UiaRootObjectId from UIAutomationCoreApi.h.
constexpr LONG kUiaRootObjectId = -25;

bool IsAccessibilityDisabledByEnvironment() {
  wchar_t value[8] = {};
  const DWORD length = ::GetEnvironmentVariableW(
      kDisableAccessibilityEnv, value, static_cast<DWORD>(std::size(value)));
  if (length == 0 || length >= std::size(value)) {
    return false;
  }
  return wcscmp(value, L"1") == 0 || _wcsicmp(value, L"true") == 0;
}

// The Flutter Windows engine enables semantics permanently the first time any
// process sends WM_GETOBJECT for OBJID_CLIENT or UiaRootObjectId. Input
// methods, screenshot tools and remote-desktop agents do this even when no
// screen reader is running, and the engine's AccessibilityBridge can then
// crash with an access violation (flutter/flutter#175041). When the switch is
// set, answer these queries with the default system proxy so the engine never
// sees them.
LRESULT CALLBACK AccessibilityGuardProc(HWND hwnd, UINT message, WPARAM wparam,
                                        LPARAM lparam, UINT_PTR subclass_id,
                                        DWORD_PTR /*ref_data*/) {
  if (message == WM_GETOBJECT) {
    // Only the lower 32 bits of lparam are meaningful for the object id.
    const DWORD object_id =
        static_cast<DWORD>(static_cast<DWORD_PTR>(lparam));
    if (object_id == static_cast<DWORD>(OBJID_CLIENT) ||
        object_id == static_cast<DWORD>(kUiaRootObjectId)) {
      return ::DefWindowProc(hwnd, message, wparam, lparam);
    }
  } else if (message == WM_NCDESTROY) {
    ::RemoveWindowSubclass(hwnd, AccessibilityGuardProc, subclass_id);
  }
  return ::DefSubclassProc(hwnd, message, wparam, lparam);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  HWND flutter_view_window = flutter_controller_->view()->GetNativeWindow();
  if (IsAccessibilityDisabledByEnvironment()) {
    ::SetWindowSubclass(flutter_view_window, AccessibilityGuardProc,
                        kAccessibilityGuardSubclassId, 0);
  }
  SetChildContent(flutter_view_window);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
