import 'package:ccpocket/features/file_peek/markdown_link_handler.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  group('classifyMarkdownLink', () {
    test('classifies web and custom-scheme destinations as external', () {
      expect(
        classifyMarkdownLink('https://example.com/report').kind,
        MarkdownLinkTargetKind.external,
      );
      expect(
        classifyMarkdownLink('mailto:hello@example.com').kind,
        MarkdownLinkTargetKind.external,
      );
    });

    test('classifies absolute file paths and removes line suffixes', () {
      final unix = classifyMarkdownLink('/Users/example/report.md:42:8');
      final windows = classifyMarkdownLink(r'C:\work\report.md:42');

      expect(unix.kind, MarkdownLinkTargetKind.file);
      expect(unix.value, '/Users/example/report.md');
      expect(windows.kind, MarkdownLinkTargetKind.file);
      expect(windows.value, r'C:\work\report.md');
    });

    test('classifies file URIs and relative file paths as files', () {
      final fileUri = classifyMarkdownLink('file:///Users/example/report.md');
      final windowsFileUri = classifyMarkdownLink(
        'file:///C:/work/My%20report.md',
      );
      final relative = classifyMarkdownLink('docs/My%20report.md#details');

      expect(fileUri.kind, MarkdownLinkTargetKind.file);
      expect(fileUri.value, '/Users/example/report.md');
      expect(windowsFileUri.kind, MarkdownLinkTargetKind.file);
      expect(windowsFileUri.value, 'C:/work/My report.md');
      expect(relative.kind, MarkdownLinkTargetKind.file);
      expect(relative.value, 'docs/My report.md');
    });

    test('uses the project file list for simple file names', () {
      final target = classifyMarkdownLink(
        'README.md',
        knownPathSuffixes: const {'README.md'},
      );

      expect(target.kind, MarkdownLinkTargetKind.file);
      expect(target.value, 'README.md');
    });

    test('classifies fragments as unsupported', () {
      final target = classifyMarkdownLink('#details');

      expect(target.kind, MarkdownLinkTargetKind.unsupported);
      expect(target.value, '#details');
    });
  });

  testWidgets('absolute markdown file link opens File Peek callback', (
    tester,
  ) async {
    const path =
        '/Users/kotahayashi/Workspace/ccpocket/docs/evals/'
        'zundamon-speech/report.md';
    String? openedPath;

    await tester.pumpWidget(
      _wrap(
        AssistantBubble(
          message: _messageWithText('[評価レポート]($path)'),
          onFileTap: (path) => openedPath = path,
        ),
        files: const ['docs/evals/zundamon-speech/report.md'],
      ),
    );

    await tester.tap(find.text('評価レポート'));
    await tester.pump();

    expect(openedPath, path);
  });

  testWidgets('unsupported link shows a copyable error', (tester) async {
    await tester.pumpWidget(
      _wrap(AssistantBubble(message: _messageWithText('[Section](#details)'))),
    );

    await tester.tap(find.text('Section'));
    await tester.pump();

    expect(find.text('This link type is not supported.'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('failed external launch shows a copyable error', (tester) async {
    final originalLauncher = UrlLauncherPlatform.instance;
    final launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

    await tester.pumpWidget(
      _wrap(
        AssistantBubble(
          message: _messageWithText('[Website](https://example.com/report)'),
        ),
      ),
    );

    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();

    expect(launcher.lastUrl, 'https://example.com/report');
    expect(find.text('Could not open this link.'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}

AssistantServerMessage _messageWithText(String text) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: 'markdown-link-test',
      role: 'assistant',
      content: [TextContent(text: text)],
      model: 'codex',
    ),
  );
}

Widget _wrap(Widget child, {List<String> files = const []}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: BlocProvider<FileListCubit>(
      create: (_) => FileListCubit(files, const Stream.empty()),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  String? lastUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    return false;
  }
}
