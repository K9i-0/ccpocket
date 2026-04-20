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
}
