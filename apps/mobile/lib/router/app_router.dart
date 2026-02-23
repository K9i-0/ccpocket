import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../features/claude_session/claude_session_screen.dart';
import '../features/debug/debug_screen.dart';
import '../features/codex_session/codex_session_screen.dart';
import '../features/diff/diff_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/session_list/session_list_screen.dart';
import '../features/settings/changelog_screen.dart';
import '../features/settings/licenses_screen.dart';
import '../features/settings/settings_screen.dart';
import '../models/messages.dart';
import '../screens/mock_preview_screen.dart';
import '../services/connection_url_parser.dart';
import '../features/setup_guide/setup_guide_screen.dart';
import '../screens/qr_scan_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SessionListRoute.page, path: '/', initial: true),
    AutoRoute(page: ClaudeSessionRoute.page, path: '/session/:sessionId'),
    AutoRoute(page: CodexSessionRoute.page, path: '/codex-session/:sessionId'),
    AutoRoute(page: GalleryRoute.page, path: '/gallery'),
    AutoRoute(page: DiffRoute.page, path: '/diff'),
    AutoRoute(page: SettingsRoute.page, path: '/settings'),
    AutoRoute(page: LicensesRoute.page, path: '/licenses'),
    AutoRoute(page: ChangelogRoute.page, path: '/changelog'),
    AutoRoute(page: QrScanRoute.page, path: '/qr-scan'),
    AutoRoute(page: MockPreviewRoute.page, path: '/mock-preview'),
    AutoRoute(page: SetupGuideRoute.page, path: '/setup-guide'),
    AutoRoute(page: DebugRoute.page, path: '/debug'),
  ];
}
