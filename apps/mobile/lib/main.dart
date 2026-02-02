import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'screens/session_list_screen.dart';
import 'services/connection_url_parser.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint('[FlutterError] ${details.stack}');
  };
  // Initialize notifications in background to avoid blocking app startup
  NotificationService.instance.init().catchError((e) {
    debugPrint('[main] NotificationService init failed: $e');
  });
  runApp(const ProviderScope(child: CcpocketApp()));
}

class CcpocketApp extends StatefulWidget {
  const CcpocketApp({super.key});

  @override
  State<CcpocketApp> createState() => _CcpocketAppState();
}

class _CcpocketAppState extends State<CcpocketApp> {
  final _appLinks = AppLinks();
  final _deepLinkNotifier = ValueNotifier<ConnectionParams?>(null);
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Handle cold start
    try {
      final initialUri = await _appLinks.getInitialLink().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('[deep_link] getInitialLink failed: $e');
    }

    // Handle warm start / incoming links while running
    try {
      _linkSub = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (e) => debugPrint('[deep_link] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[deep_link] uriLinkStream failed: $e');
    }
  }

  void _handleUri(Uri uri) {
    final params = ConnectionUrlParser.parse(uri.toString());
    if (params != null) {
      _deepLinkNotifier.value = params;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _deepLinkNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ccpocket',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: SessionListScreen(deepLinkNotifier: _deepLinkNotifier),
    );
  }
}
