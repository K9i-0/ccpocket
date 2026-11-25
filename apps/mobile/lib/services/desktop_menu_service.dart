import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/platform_helper.dart';

/// Top-level native menu bar categories whose titles can be localized dynamically.
enum DesktopTopLevelMenu {
  file('file'),
  view('view'),
  session('session'),
  help('help');

  const DesktopTopLevelMenu(this.wireName);

  final String wireName;
}

/// Actions dispatched from the native macOS menu bar (`AppMenuBridge.swift`).
enum DesktopMenuAction {
  openSettings('openSettings'),
  openLocalBridge('openLocalBridge'),
  checkForUpdates('checkForUpdates'),
  newSession('newSession'),
  closeActive('closeActive'),
  reload('reload'),
  disconnect('disconnect'),
  toggleSidebar('toggleSidebar'),
  openSearch('openSearch'),
  toggleGitPane('toggleGitPane'),
  toggleExplorePane('toggleExplorePane'),
  toggleGalleryPane('toggleGalleryPane'),
  actualSize('actualSize'),
  zoomIn('zoomIn'),
  zoomOut('zoomOut'),
  stopGeneration('stopGeneration'),
  permissionMode('permissionMode'),
  showShortcuts('showShortcuts'),
  openSetupGuide('openSetupGuide'),
  openChangelog('openChangelog'),
  openGitHub('openGitHub');

  const DesktopMenuAction(this.wireName);

  final String wireName;

  static final Map<String, DesktopMenuAction> _byWireName = {
    for (final action in values) action.wireName: action,
  };

  static DesktopMenuAction? fromWireName(String? value) {
    if (value == null) return null;
    return _byWireName[value];
  }
}

/// Dynamic state for a single native menu item. Omitted fields are left unchanged.
@immutable
class DesktopMenuItemState {
  const DesktopMenuItemState({this.title, this.enabled, this.checked});

  final String? title;
  final bool? enabled;
  final bool? checked;

  Map<String, Object> toMap() => {
    'title': ?title,
    'enabled': ?enabled,
    'checked': ?checked,
  };

  @override
  bool operator ==(Object other) =>
      other is DesktopMenuItemState &&
      other.title == title &&
      other.enabled == enabled &&
      other.checked == checked;

  @override
  int get hashCode => Object.hash(title, enabled, checked);
}

/// Batch update sent to the native macOS menu bar via `updateMenuState`.
@immutable
class DesktopMenuState {
  const DesktopMenuState({this.menuTitles = const {}, this.items = const {}});

  final Map<DesktopTopLevelMenu, String> menuTitles;
  final Map<DesktopMenuAction, DesktopMenuItemState> items;

  Map<String, Object> toMap() => {
    if (menuTitles.isNotEmpty)
      'menuTitles': {
        for (final entry in menuTitles.entries) entry.key.wireName: entry.value,
      },
    if (items.isNotEmpty)
      'items': {
        for (final entry in items.entries)
          entry.key.wireName: entry.value.toMap(),
      },
  };
}

/// Flutter bridge for the native macOS menu bar, window title, Dock badge,
/// and window closing (`ccpocket/app_menu`).
///
/// All outgoing calls gracefully no-op on non-macOS platforms and in test
/// environments without the macOS native runner.
class DesktopMenuService {
  DesktopMenuService({MethodChannel? channel, bool Function()? isSupported})
    : _channel = channel ?? const MethodChannel(channelName),
      _isSupported = isSupported ?? _defaultIsSupported {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const channelName = 'ccpocket/app_menu';

  static final DesktopMenuService instance = DesktopMenuService();

  static bool _defaultIsSupported() => !kIsWeb && isMacOSPlatform;

  final MethodChannel _channel;
  final bool Function() _isSupported;
  final StreamController<DesktopMenuAction> _actionsController =
      StreamController<DesktopMenuAction>.broadcast();
  bool _disposed = false;

  /// Whether the native macOS menu bridge is active on this platform.
  bool get isSupported => _isSupported();

  /// Stream of actions triggered by the native macOS menu bar.
  Stream<DesktopMenuAction> get actions => _actionsController.stream;

  /// Updates localized menu titles and per-item enabled/checked/title states.
  Future<void> updateMenuState(DesktopMenuState state) async {
    if (!_isSupported() || _disposed) return;
    await _invokeSilently('updateMenuState', state.toMap());
  }

  /// Updates the native macOS window title (shown in Window menu, Mission
  /// Control, and Dock menu).
  Future<void> setWindowTitle(String title) async {
    if (!_isSupported() || _disposed) return;
    await _invokeSilently('setWindowTitle', {'title': title});
  }

  /// Updates the macOS Dock tile badge. Pass `null` or an empty string to clear.
  Future<void> setDockBadge(String? label) async {
    if (!_isSupported() || _disposed) return;
    await _invokeSilently('setDockBadge', {'label': label ?? ''});
  }

  /// Requests AppKit to close the main window (`NSWindow.performClose`).
  Future<void> closeWindow() async {
    if (!_isSupported() || _disposed) return;
    await _invokeSilently('performCloseWindow');
  }

  Future<void> _invokeSilently(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Non-macOS targets and tests without the native runner have no handler.
    } on PlatformException catch (error) {
      debugPrint('DesktopMenuService.$method failed: ${error.code}');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMenuAction':
        final args = call.arguments;
        final rawAction = args is Map ? args['action'] as String? : null;
        final action = DesktopMenuAction.fromWireName(rawAction);
        if (action != null && !_disposed) {
          _actionsController.add(action);
        }
        return null;
      default:
        throw PlatformException(
          code: 'unimplemented',
          message: 'Unknown desktop menu method: ${call.method}',
        );
    }
  }

  /// Releases stream resources and detaches the MethodChannel handler.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    await _actionsController.close();
  }
}
