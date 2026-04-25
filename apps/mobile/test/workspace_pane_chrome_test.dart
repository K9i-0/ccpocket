import 'package:ccpocket/widgets/workspace_pane_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS single-pane chrome adds top inset without adaptive inset', () {
    final chrome = resolveWorkspacePaneChrome(
      platform: TargetPlatform.macOS,
      isAdaptiveWorkspace: false,
      isLeftPaneVisible: true,
      slot: WorkspacePaneSlot.center,
    );

    expect(chrome.useMacOSAdaptiveChrome, isFalse);
    expect(chrome.ownsWindowControls, isFalse);
    expect(chrome.topInset, kWorkspaceMacOSSinglePaneTopInset);
    expect(chrome.leadingInset, 0);
  });

  test(
    'adaptive macOS center pane owns controls only when left pane hidden',
    () {
      final withLeftPane = resolveWorkspacePaneChrome(
        platform: TargetPlatform.macOS,
        isAdaptiveWorkspace: true,
        isLeftPaneVisible: true,
        slot: WorkspacePaneSlot.center,
      );
      final withoutLeftPane = resolveWorkspacePaneChrome(
        platform: TargetPlatform.macOS,
        isAdaptiveWorkspace: true,
        isLeftPaneVisible: false,
        slot: WorkspacePaneSlot.center,
      );

      expect(withLeftPane.leadingInset, 0);
      expect(withoutLeftPane.leadingInset, kWorkspaceMacOSLeadingInset);
    },
  );

  testWidgets('standalone chrome uses macOS top inset from theme', (
    tester,
  ) async {
    late WorkspacePaneChrome chrome;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (context) {
            chrome = resolveStandalonePaneChrome(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(chrome.topInset, kWorkspaceMacOSSinglePaneTopInset);
    expect(chrome.toolbarHeight, kToolbarHeight);
    expect(chrome.leadingInset, 0);
  });

  testWidgets('standalone chrome keeps default height off macOS', (
    tester,
  ) async {
    late WorkspacePaneChrome chrome;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            chrome = resolveStandalonePaneChrome(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(chrome.topInset, 0);
    expect(chrome.toolbarHeight, kToolbarHeight);
    expect(chrome.leadingInset, 0);
  });
}
