#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <sys/stat.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <cstdint>
#include <cstring>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr size_t kMaxImageBytes = 20 * 1024 * 1024;
constexpr size_t kMaxDroppedImages = 10;

constexpr const char* kSupportedImageMimeTypes[] = {
    "image/gif",
    "image/webp",
    "image/png",
    "image/jpeg",
};

const char* DetectMimeTypeFromBytes(const uint8_t* bytes, size_t length) {
  if (length >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x38) {
    return "image/gif";
  }
  if (length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46 && bytes[8] == 0x57 &&
      bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return "image/webp";
  }
  if (length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 &&
      bytes[2] == 0x4E && bytes[3] == 0x47) {
    return "image/png";
  }
  if (length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return "image/jpeg";
  }
  return nullptr;
}

const char* MimeTypeFromFilename(const gchar* path) {
  if (path == nullptr) return nullptr;
  const gchar* dot = strrchr(path, '.');
  if (dot == nullptr || dot[1] == '\0') return nullptr;
  g_autofree gchar* ext = g_ascii_strdown(dot + 1, -1);
  if (g_strcmp0(ext, "gif") == 0) return "image/gif";
  if (g_strcmp0(ext, "webp") == 0) return "image/webp";
  if (g_strcmp0(ext, "png") == 0) return "image/png";
  if (g_strcmp0(ext, "jpg") == 0 || g_strcmp0(ext, "jpeg") == 0) {
    return "image/jpeg";
  }
  return nullptr;
}

FlValue* MakeImagePayload(const uint8_t* bytes, size_t length,
                          const char* mime_type) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "bytes", fl_value_new_uint8_list(bytes, length));
  fl_value_set_string_take(map, "mimeType", fl_value_new_string(mime_type));
  return map;
}

enum class FileImageReadStatus {
  kOk,
  kTooLarge,
  kSkip,
};

FileImageReadStatus ReadImageFileUri(const gchar* uri, FlValue** out_payload) {
  g_autofree gchar* path = g_filename_from_uri(uri, nullptr, nullptr);
  if (path == nullptr) {
    return FileImageReadStatus::kSkip;
  }
  const char* fallback_mime = MimeTypeFromFilename(path);
  if (fallback_mime == nullptr) {
    return FileImageReadStatus::kSkip;
  }

  GStatBuf st{};
  if (g_stat(path, &st) != 0 || !S_ISREG(st.st_mode) || st.st_size <= 0) {
    return FileImageReadStatus::kSkip;
  }
  if (static_cast<size_t>(st.st_size) > kMaxImageBytes) {
    return FileImageReadStatus::kTooLarge;
  }

  gchar* contents = nullptr;
  gsize length = 0;
  if (!g_file_get_contents(path, &contents, &length, nullptr)) {
    return FileImageReadStatus::kSkip;
  }
  if (length == 0 || length > kMaxImageBytes) {
    g_free(contents);
    return length > kMaxImageBytes ? FileImageReadStatus::kTooLarge
                                   : FileImageReadStatus::kSkip;
  }
  const auto* data = reinterpret_cast<const uint8_t*>(contents);
  const char* detected = DetectMimeTypeFromBytes(data, length);
  *out_payload =
      MakeImagePayload(data, length, detected != nullptr ? detected : fallback_mime);
  g_free(contents);
  return FileImageReadStatus::kOk;
}

gboolean ClipboardHasSupportedImage(GtkClipboard* clipboard) {
  GdkAtom* targets = nullptr;
  gint n_targets = 0;
  if (!gtk_clipboard_wait_for_targets(clipboard, &targets, &n_targets)) {
    return FALSE;
  }

  gboolean has_uri_list = FALSE;
  GdkAtom uri_list_atom = gdk_atom_intern_static_string("text/uri-list");
  for (gint i = 0; i < n_targets; ++i) {
    for (const char* mime : kSupportedImageMimeTypes) {
      if (targets[i] == gdk_atom_intern_static_string(mime)) {
        g_free(targets);
        return TRUE;
      }
    }
    if (targets[i] == uri_list_atom) {
      has_uri_list = TRUE;
    }
  }
  g_free(targets);

  if (has_uri_list) {
    gchar** uris = gtk_clipboard_wait_for_uris(clipboard);
    if (uris != nullptr) {
      gboolean found = FALSE;
      for (gsize i = 0; uris[i] != nullptr; ++i) {
        g_autofree gchar* path = g_filename_from_uri(uris[i], nullptr, nullptr);
        if (MimeTypeFromFilename(path) != nullptr) {
          found = TRUE;
          break;
        }
      }
      g_strfreev(uris);
      return found;
    }
  }
  return FALSE;
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* clipboard_channel;
  FlEventChannel* image_drop_channel;
  gboolean image_drop_listening;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void clipboard_method_call_cb(FlMethodChannel* /*channel*/,
                                     FlMethodCall* method_call,
                                     gpointer /*user_data*/) {
  const gchar* method = fl_method_call_get_name(method_call);
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);

  if (g_strcmp0(method, "hasImage") == 0) {
    g_autoptr(FlValue) result =
        fl_value_new_bool(ClipboardHasSupportedImage(clipboard));
    fl_method_call_respond_success(method_call, result, nullptr);
    return;
  }

  if (g_strcmp0(method, "readImage") == 0) {
    // 1. Direct encoded image targets in priority order.
    for (const char* mime : kSupportedImageMimeTypes) {
      GdkAtom target = gdk_atom_intern_static_string(mime);
      if (!gtk_clipboard_wait_is_target_available(clipboard, target)) {
        continue;
      }
      GtkSelectionData* sel = gtk_clipboard_wait_for_contents(clipboard, target);
      if (sel == nullptr) {
        continue;
      }
      gint len = 0;
      const guchar* raw = gtk_selection_data_get_data_with_length(sel, &len);
      if (raw != nullptr && len > 0) {
        if (static_cast<size_t>(len) > kMaxImageBytes) {
          gtk_selection_data_free(sel);
          fl_method_call_respond_error(method_call, "image_load_failed",
                                       "Clipboard image exceeds size limit",
                                       nullptr, nullptr);
          return;
        }
        const auto* data = reinterpret_cast<const uint8_t*>(raw);
        const char* detected =
            DetectMimeTypeFromBytes(data, static_cast<size_t>(len));
        g_autoptr(FlValue) payload = MakeImagePayload(
            data, static_cast<size_t>(len), detected != nullptr ? detected : mime);
        gtk_selection_data_free(sel);
        fl_method_call_respond_success(method_call, payload, nullptr);
        return;
      }
      gtk_selection_data_free(sel);
    }

    // 2. Local image file URIs (text/uri-list).
    gchar** uris = gtk_clipboard_wait_for_uris(clipboard);
    if (uris != nullptr) {
      for (gsize i = 0; uris[i] != nullptr; ++i) {
        FlValue* payload_raw = nullptr;
        const FileImageReadStatus status =
            ReadImageFileUri(uris[i], &payload_raw);
        if (status == FileImageReadStatus::kTooLarge) {
          g_strfreev(uris);
          fl_method_call_respond_error(method_call, "image_load_failed",
                                       "Clipboard image exceeds size limit",
                                       nullptr, nullptr);
          return;
        }
        if (status == FileImageReadStatus::kOk && payload_raw != nullptr) {
          g_autoptr(FlValue) payload = payload_raw;
          g_strfreev(uris);
          fl_method_call_respond_success(method_call, payload, nullptr);
          return;
        }
      }
      g_strfreev(uris);
    }

    fl_method_call_respond_success(method_call, nullptr, nullptr);
    return;
  }

  fl_method_call_respond_not_implemented(method_call, nullptr);
}

static FlMethodErrorResponse* image_drop_listen_cb(FlEventChannel* /*channel*/,
                                                   FlValue* /*args*/,
                                                   gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->image_drop_listening = TRUE;
  return nullptr;
}

static FlMethodErrorResponse* image_drop_cancel_cb(FlEventChannel* /*channel*/,
                                                   FlValue* /*args*/,
                                                   gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->image_drop_listening = FALSE;
  return nullptr;
}

static void on_drag_data_received(GtkWidget* /*widget*/,
                                  GdkDragContext* context,
                                  gint /*x*/,
                                  gint /*y*/,
                                  GtkSelectionData* selection_data,
                                  guint /*info*/,
                                  guint time,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!self->image_drop_listening || self->image_drop_channel == nullptr) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }

  gchar** uris = gtk_selection_data_get_uris(selection_data);
  if (uris == nullptr) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }

  g_autoptr(FlValue) list = fl_value_new_list();
  for (gsize i = 0;
       uris[i] != nullptr && fl_value_get_length(list) < kMaxDroppedImages;
       ++i) {
    FlValue* payload = nullptr;
    if (ReadImageFileUri(uris[i], &payload) == FileImageReadStatus::kOk &&
        payload != nullptr) {
      fl_value_append_take(list, payload);
    }
  }
  g_strfreev(uris);

  const gboolean accepted = fl_value_get_length(list) > 0;
  if (accepted) {
    fl_event_channel_send(self->image_drop_channel, list, nullptr, nullptr);
  }
  gtk_drag_finish(context, accepted, FALSE, time);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "CC Pocket");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "CC Pocket");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_enable_flutter_gpu(project, TRUE);
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  g_clear_object(&self->clipboard_channel);
  self->clipboard_channel = fl_method_channel_new(
      messenger, "ccpocket/clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->clipboard_channel, clipboard_method_call_cb, self, nullptr);

  g_clear_object(&self->image_drop_channel);
  self->image_drop_channel = fl_event_channel_new(
      messenger, "ccpocket/image_drop", FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(self->image_drop_channel,
                                       image_drop_listen_cb,
                                       image_drop_cancel_cb, self, nullptr);

  static GtkTargetEntry drop_targets[] = {
      {const_cast<gchar*>("text/uri-list"), 0, 0},
  };
  gtk_drag_dest_set(GTK_WIDGET(view), GTK_DEST_DEFAULT_ALL, drop_targets,
                    G_N_ELEMENTS(drop_targets), GDK_ACTION_COPY);
  g_signal_connect(GTK_WIDGET(view), "drag-data-received",
                   G_CALLBACK(on_drag_data_received), self);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->clipboard_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->clipboard_channel, nullptr,
                                              nullptr, nullptr);
    g_clear_object(&self->clipboard_channel);
  }
  if (self->image_drop_channel != nullptr) {
    fl_event_channel_set_stream_handlers(self->image_drop_channel, nullptr,
                                         nullptr, nullptr, nullptr);
    g_clear_object(&self->image_drop_channel);
  }
  self->image_drop_listening = FALSE;
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
