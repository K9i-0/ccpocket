import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../features/claude_code_session/claude_code_session_screen.dart';
import '../features/codex_session/codex_session_screen.dart';
import '../features/diff/diff_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/session_list/session_list_screen.dart';
import '../features/settings/licenses_screen.dart';
import '../features/settings/settings_screen.dart';
import '../models/messages.dart';
import '../features/swipe_queue/swipe_queue_screen.dart';
import '../screens/mock_preview_screen.dart';
import '../services/connection_url_parser.dart';
import '../screens/qr_scan_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SessionListRoute.page, path: '/', initial: true),
    AutoRoute(page: ClaudeCodeSessionRoute.page, path: '/session/:sessionId'),
    AutoRoute(page: CodexSessionRoute.page, path: '/codex-session/:sessionId'),
    AutoRoute(page: GalleryRoute.page, path: '/gallery'),
    AutoRoute(page: DiffRoute.page, path: '/diff'),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
    AutoRoute(page: LicensesRoute.page, path: '/licenses'),
    AutoRoute(page: QrScanRoute.page, path: '/qr-scan'),
    AutoRoute(page: MockPreviewRoute.page, path: '/mock-preview'),
    AutoRoute(page: SwipeQueueRoute.page, path: '/swipe-queue'),
  ];
}
