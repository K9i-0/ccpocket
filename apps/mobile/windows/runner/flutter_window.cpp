#include "flutter_window.h"

#include <commctrl.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <objidl.h>
#include <ole2.h>
#include <wchar.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <cwctype>
#include <iterator>
#include <limits>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

using Microsoft::WRL::ComPtr;

// Opt-in switch: set CCPOCKET_DISABLE_ACCESSIBILITY=1 to keep the Windows
// accessibility bridge off.
constexpr wchar_t kDisableAccessibilityEnv[] = L"CCPOCKET_DISABLE_ACCESSIBILITY";
constexpr UINT_PTR kAccessibilityGuardSubclassId = 1;
// UiaRootObjectId from UIAutomationCoreApi.h.
constexpr LONG kUiaRootObjectId = -25;

constexpr size_t kMaxImageBytes = 20 * 1024 * 1024;
constexpr size_t kMaxRawDibBytes = 128 * 1024 * 1024;
constexpr size_t kMaxDroppedImages = 10;

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

class ScopedClipboard {
 public:
  explicit ScopedClipboard(HWND owner) : opened_(::OpenClipboard(owner) != 0) {}
  ~ScopedClipboard() {
    if (opened_) {
      ::CloseClipboard();
    }
  }
  ScopedClipboard(const ScopedClipboard&) = delete;
  ScopedClipboard& operator=(const ScopedClipboard&) = delete;
  bool is_open() const { return opened_; }

 private:
  bool opened_;
};

class ScopedGlobalLock {
 public:
  explicit ScopedGlobalLock(HGLOBAL handle)
      : handle_(handle), ptr_(handle ? ::GlobalLock(handle) : nullptr) {}
  ~ScopedGlobalLock() {
    if (ptr_) {
      ::GlobalUnlock(handle_);
    }
  }
  ScopedGlobalLock(const ScopedGlobalLock&) = delete;
  ScopedGlobalLock& operator=(const ScopedGlobalLock&) = delete;
  const void* data() const { return ptr_; }
  size_t size() const { return handle_ ? ::GlobalSize(handle_) : 0; }

 private:
  HGLOBAL handle_;
  void* ptr_;
};

class ScopedDropHandle {
 public:
  explicit ScopedDropHandle(HDROP hdrop) : hdrop_(hdrop) {}
  ~ScopedDropHandle() {
    if (hdrop_) {
      ::DragFinish(hdrop_);
    }
  }
  ScopedDropHandle(const ScopedDropHandle&) = delete;
  ScopedDropHandle& operator=(const ScopedDropHandle&) = delete;

 private:
  HDROP hdrop_;
};

struct ClipboardFormatIds {
  UINT gif = ::RegisterClipboardFormatW(L"GIF");
  UINT webp = ::RegisterClipboardFormatW(L"image/webp");
  UINT png = ::RegisterClipboardFormatW(L"PNG");
  UINT jpeg = ::RegisterClipboardFormatW(L"JFIF");
};

const ClipboardFormatIds& GetClipboardFormatIds() {
  static const ClipboardFormatIds ids;
  return ids;
}

std::string DetectMimeTypeFromBytes(const std::vector<uint8_t>& bytes) {
  if (bytes.size() >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x38) {
    return "image/gif";
  }
  if (bytes.size() >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46 && bytes[8] == 0x57 &&
      bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return "image/webp";
  }
  if (bytes.size() >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4E && bytes[3] == 0x47) {
    return "image/png";
  }
  if (bytes.size() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return "image/jpeg";
  }
  return {};
}

std::string MimeTypeFromExtension(const std::wstring& path) {
  const size_t dot = path.find_last_of(L'.');
  if (dot == std::wstring::npos || dot + 1 >= path.size()) {
    return {};
  }
  std::wstring ext = path.substr(dot + 1);
  std::transform(ext.begin(), ext.end(), ext.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(ch));
  });
  if (ext == L"gif") return "image/gif";
  if (ext == L"webp") return "image/webp";
  if (ext == L"png") return "image/png";
  if (ext == L"jpg" || ext == L"jpeg") return "image/jpeg";
  return {};
}

enum class FileReadStatus {
  kOk,
  kTooLarge,
  kFailed,
};

FileReadStatus ReadFileToBytes(const std::wstring& path,
                               std::vector<uint8_t>* out) {
  HANDLE file =
      ::CreateFileW(path.c_str(), GENERIC_READ,
                    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                    nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return FileReadStatus::kFailed;
  }

  LARGE_INTEGER file_size{};
  if (!::GetFileSizeEx(file, &file_size) || file_size.QuadPart <= 0) {
    ::CloseHandle(file);
    return FileReadStatus::kFailed;
  }
  if (static_cast<uint64_t>(file_size.QuadPart) > kMaxImageBytes) {
    ::CloseHandle(file);
    return FileReadStatus::kTooLarge;
  }

  const size_t expected = static_cast<size_t>(file_size.QuadPart);
  std::vector<uint8_t> buffer(expected);
  size_t total_read = 0;
  while (total_read < expected) {
    DWORD chunk = 0;
    const DWORD to_read = static_cast<DWORD>(
        std::min<size_t>(expected - total_read, 64 * 1024));
    if (!::ReadFile(file, buffer.data() + total_read, to_read, &chunk,
                    nullptr)) {
      ::CloseHandle(file);
      return FileReadStatus::kFailed;
    }
    if (chunk == 0) {
      break;
    }
    total_read += chunk;
  }
  ::CloseHandle(file);
  if (total_read == 0) {
    return FileReadStatus::kFailed;
  }
  buffer.resize(total_read);
  *out = std::move(buffer);
  return FileReadStatus::kOk;
}

bool EncodeDibToPng(const uint8_t* dib_data, size_t dib_size,
                    std::vector<uint8_t>* png_out) {
  if (!dib_data || dib_size < sizeof(BITMAPINFOHEADER) ||
      dib_size > kMaxRawDibBytes) {
    return false;
  }

  BITMAPINFOHEADER info{};
  std::memcpy(&info, dib_data, sizeof(BITMAPINFOHEADER));
  if (info.biSize < sizeof(BITMAPINFOHEADER) || info.biSize > dib_size) {
    return false;
  }

  size_t color_table_bytes = 0;
  if (info.biSize == sizeof(BITMAPINFOHEADER)) {
    const size_t mask_bytes =
        info.biCompression == BI_BITFIELDS ? 3 * sizeof(DWORD) : 0;
    const size_t colors =
        info.biBitCount <= 8
            ? (info.biClrUsed != 0 ? static_cast<size_t>(info.biClrUsed)
                                   : (size_t{1} << info.biBitCount))
            : static_cast<size_t>(info.biClrUsed);
    if (colors > dib_size / sizeof(RGBQUAD)) {
      return false;
    }
    color_table_bytes = mask_bytes + colors * sizeof(RGBQUAD);
  } else {
    const size_t colors =
        info.biBitCount <= 8
            ? (info.biClrUsed != 0 ? static_cast<size_t>(info.biClrUsed)
                                   : (size_t{1} << info.biBitCount))
            : static_cast<size_t>(info.biClrUsed);
    if (colors > dib_size / sizeof(RGBQUAD)) {
      return false;
    }
    color_table_bytes = colors * sizeof(RGBQUAD);
  }

  const size_t header_and_palette =
      static_cast<size_t>(info.biSize) + color_table_bytes;
  if (header_and_palette < info.biSize || header_and_palette > dib_size) {
    return false;
  }
  const size_t total_bmp_size = sizeof(BITMAPFILEHEADER) + dib_size;
  if (total_bmp_size > std::numeric_limits<DWORD>::max()) {
    return false;
  }

  BITMAPFILEHEADER file_header{};
  file_header.bfType = 0x4D42;  // 'BM'
  file_header.bfSize = static_cast<DWORD>(total_bmp_size);
  file_header.bfOffBits =
      static_cast<DWORD>(sizeof(BITMAPFILEHEADER) + header_and_palette);

  ComPtr<IWICImagingFactory> factory;
  if (FAILED(::CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return false;
  }

  ComPtr<IStream> input_stream;
  if (FAILED(::CreateStreamOnHGlobal(nullptr, TRUE, &input_stream))) {
    return false;
  }
  ULONG written = 0;
  if (FAILED(input_stream->Write(&file_header, sizeof(file_header),
                                 &written)) ||
      written != sizeof(file_header)) {
    return false;
  }
  size_t remaining = dib_size;
  const uint8_t* cursor = dib_data;
  while (remaining > 0) {
    const ULONG chunk = static_cast<ULONG>(
        std::min<size_t>(remaining, 16 * 1024 * 1024));
    if (FAILED(input_stream->Write(cursor, chunk, &written)) ||
        written != chunk) {
      return false;
    }
    cursor += chunk;
    remaining -= chunk;
  }
  LARGE_INTEGER zero{};
  if (FAILED(input_stream->Seek(zero, STREAM_SEEK_SET, nullptr))) {
    return false;
  }

  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory->CreateDecoderFromStream(
          input_stream.Get(), nullptr, WICDecodeMetadataCacheOnLoad,
          &decoder))) {
    return false;
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) {
    return false;
  }

  ComPtr<IStream> output_stream;
  if (FAILED(::CreateStreamOnHGlobal(nullptr, TRUE, &output_stream))) {
    return false;
  }
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(output_stream.Get(),
                                 WICBitmapEncoderNoCache))) {
    return false;
  }
  ComPtr<IWICBitmapFrameEncode> frame_encode;
  if (FAILED(encoder->CreateNewFrame(&frame_encode, nullptr)) ||
      FAILED(frame_encode->Initialize(nullptr)) ||
      FAILED(frame_encode->WriteSource(frame.Get(), nullptr)) ||
      FAILED(frame_encode->Commit()) || FAILED(encoder->Commit())) {
    return false;
  }

  STATSTG stat{};
  if (FAILED(output_stream->Stat(&stat, STATFLAG_NONAME)) ||
      stat.cbSize.QuadPart == 0 || stat.cbSize.QuadPart > kMaxImageBytes) {
    return false;
  }
  HGLOBAL output_global = nullptr;
  if (FAILED(::GetHGlobalFromStream(output_stream.Get(), &output_global)) ||
      !output_global) {
    return false;
  }
  ScopedGlobalLock locked(output_global);
  const size_t png_size = static_cast<size_t>(stat.cbSize.QuadPart);
  if (!locked.data() || locked.size() < png_size) {
    return false;
  }
  png_out->assign(static_cast<const uint8_t*>(locked.data()),
                  static_cast<const uint8_t*>(locked.data()) + png_size);
  return true;
}

flutter::EncodableMap MakeImagePayload(std::vector<uint8_t> bytes,
                                       const std::string& mime_type) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("bytes"),
       flutter::EncodableValue(std::move(bytes))},
      {flutter::EncodableValue("mimeType"),
       flutter::EncodableValue(mime_type)},
  };
}

bool HasClipboardImage(HWND owner) {
  const auto& ids = GetClipboardFormatIds();
  if ((ids.gif && ::IsClipboardFormatAvailable(ids.gif)) ||
      (ids.webp && ::IsClipboardFormatAvailable(ids.webp)) ||
      (ids.png && ::IsClipboardFormatAvailable(ids.png)) ||
      (ids.jpeg && ::IsClipboardFormatAvailable(ids.jpeg)) ||
      ::IsClipboardFormatAvailable(CF_DIB)) {
    return true;
  }
  if (!::IsClipboardFormatAvailable(CF_HDROP)) {
    return false;
  }
  ScopedClipboard clipboard(owner);
  if (!clipboard.is_open()) {
    return false;
  }
  HANDLE drop_handle = ::GetClipboardData(CF_HDROP);
  if (!drop_handle) {
    return false;
  }
  HDROP hdrop = static_cast<HDROP>(drop_handle);
  const UINT count = ::DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < count; ++i) {
    const UINT len = ::DragQueryFileW(hdrop, i, nullptr, 0);
    if (len == 0) continue;
    std::wstring path(len + 1, L'\0');
    if (::DragQueryFileW(hdrop, i, path.data(), len + 1) > 0) {
      path.resize(len);
      if (!MimeTypeFromExtension(path).empty()) {
        return true;
      }
    }
  }
  return false;
}

void HandleReadClipboardImage(
    HWND owner,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  ScopedClipboard clipboard(owner);
  if (!clipboard.is_open()) {
    result->Error("clipboard_read_failed", "Failed to open system clipboard");
    return;
  }

  const auto& ids = GetClipboardFormatIds();
  struct DirectFormat {
    UINT format;
    const char* mime_type;
  };
  const DirectFormat direct_formats[] = {
      {ids.gif, "image/gif"},
      {ids.webp, "image/webp"},
      {ids.png, "image/png"},
      {ids.jpeg, "image/jpeg"},
  };

  // 1. Direct encoded clipboard formats in priority order.
  for (const auto& entry : direct_formats) {
    if (!entry.format || !::IsClipboardFormatAvailable(entry.format)) {
      continue;
    }
    HANDLE handle = ::GetClipboardData(entry.format);
    if (!handle) continue;
    ScopedGlobalLock locked(static_cast<HGLOBAL>(handle));
    const size_t size = locked.size();
    if (!locked.data() || size == 0) continue;
    if (size > kMaxImageBytes) {
      result->Error("image_load_failed", "Clipboard image exceeds size limit");
      return;
    }
    std::vector<uint8_t> bytes(
        static_cast<const uint8_t*>(locked.data()),
        static_cast<const uint8_t*>(locked.data()) + size);
    const std::string detected = DetectMimeTypeFromBytes(bytes);
    const std::string mime_type = detected.empty() ? entry.mime_type : detected;
    result->Success(
        flutter::EncodableValue(MakeImagePayload(std::move(bytes), mime_type)));
    return;
  }

  // 2. CF_HDROP image files copied in Explorer.
  if (::IsClipboardFormatAvailable(CF_HDROP)) {
    HANDLE drop_handle = ::GetClipboardData(CF_HDROP);
    if (drop_handle) {
      HDROP hdrop = static_cast<HDROP>(drop_handle);
      const UINT count = ::DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; ++i) {
        const UINT len = ::DragQueryFileW(hdrop, i, nullptr, 0);
        if (len == 0) continue;
        std::wstring path(len + 1, L'\0');
        if (::DragQueryFileW(hdrop, i, path.data(), len + 1) == 0) continue;
        path.resize(len);
        const std::string fallback_mime = MimeTypeFromExtension(path);
        if (fallback_mime.empty()) continue;

        std::vector<uint8_t> bytes;
        const FileReadStatus status = ReadFileToBytes(path, &bytes);
        if (status == FileReadStatus::kTooLarge) {
          result->Error("image_load_failed",
                        "Clipboard image exceeds size limit");
          return;
        }
        if (status == FileReadStatus::kOk) {
          const std::string detected = DetectMimeTypeFromBytes(bytes);
          const std::string mime_type =
              detected.empty() ? fallback_mime : detected;
          result->Success(flutter::EncodableValue(
              MakeImagePayload(std::move(bytes), mime_type)));
          return;
        }
      }
    }
  }

  // 3. CF_DIB bitmap encoded to PNG via WIC.
  if (::IsClipboardFormatAvailable(CF_DIB)) {
    HANDLE handle = ::GetClipboardData(CF_DIB);
    if (handle) {
      ScopedGlobalLock locked(static_cast<HGLOBAL>(handle));
      if (locked.data() && locked.size() > 0) {
        std::vector<uint8_t> png_bytes;
        if (EncodeDibToPng(static_cast<const uint8_t*>(locked.data()),
                           locked.size(), &png_bytes)) {
          result->Success(flutter::EncodableValue(
              MakeImagePayload(std::move(png_bytes), "image/png")));
          return;
        }
        result->Error("image_load_failed", "Failed to encode clipboard bitmap");
        return;
      }
    }
  }

  result->Success();
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
  SetupClipboardAndDropChannels();
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

void FlutterWindow::SetupClipboardAndDropChannels() {
  auto* messenger = flutter_controller_->engine()->messenger();

  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "ccpocket/clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() == "hasImage") {
          result->Success(
              flutter::EncodableValue(HasClipboardImage(GetHandle())));
        } else if (call.method_name() == "readImage") {
          HandleReadClipboardImage(GetHandle(), std::move(result));
        } else {
          result->NotImplemented();
        }
      });

  image_drop_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, "ccpocket/image_drop",
          &flutter::StandardMethodCodec::GetInstance());
  auto stream_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* /*arguments*/,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                 events)
          -> std::unique_ptr<
              flutter::StreamHandlerError<flutter::EncodableValue>> {
        image_drop_sink_ = std::move(events);
        if (GetHandle()) {
          ::DragAcceptFiles(GetHandle(), TRUE);
        }
        return nullptr;
      },
      [this](const flutter::EncodableValue* /*arguments*/)
          -> std::unique_ptr<
              flutter::StreamHandlerError<flutter::EncodableValue>> {
        image_drop_sink_.reset();
        if (GetHandle()) {
          ::DragAcceptFiles(GetHandle(), FALSE);
        }
        return nullptr;
      });
  image_drop_channel_->SetStreamHandler(std::move(stream_handler));
}

void FlutterWindow::HandleDropFiles(HDROP hdrop) {
  ScopedDropHandle drop_guard(hdrop);
  if (!image_drop_sink_) {
    return;
  }

  flutter::EncodableList images;
  const UINT count = ::DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < count && images.size() < kMaxDroppedImages; ++i) {
    const UINT len = ::DragQueryFileW(hdrop, i, nullptr, 0);
    if (len == 0) continue;
    std::wstring path(len + 1, L'\0');
    if (::DragQueryFileW(hdrop, i, path.data(), len + 1) == 0) continue;
    path.resize(len);

    const std::string fallback_mime = MimeTypeFromExtension(path);
    if (fallback_mime.empty()) continue;

    std::vector<uint8_t> bytes;
    if (ReadFileToBytes(path, &bytes) == FileReadStatus::kOk) {
      const std::string detected = DetectMimeTypeFromBytes(bytes);
      const std::string mime_type = detected.empty() ? fallback_mime : detected;
      images.emplace_back(MakeImagePayload(std::move(bytes), mime_type));
    }
  }

  if (!images.empty()) {
    image_drop_sink_->Success(flutter::EncodableValue(std::move(images)));
  }
}

void FlutterWindow::OnDestroy() {
  if (GetHandle()) {
    ::DragAcceptFiles(GetHandle(), FALSE);
  }
  image_drop_sink_.reset();
  image_drop_channel_.reset();
  clipboard_channel_.reset();

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
    case WM_DROPFILES:
      HandleDropFiles(reinterpret_cast<HDROP>(wparam));
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
