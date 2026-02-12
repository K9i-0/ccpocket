import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet for taking screenshots of the macOS desktop or
/// individual windows. Captured images are automatically saved to the gallery.
Future<void> showScreenshotSheet({
  required BuildContext context,
  required BridgeService bridge,
  required String projectPath,
  String? sessionId,
}) {
  bridge.requestWindowList();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _ScreenshotSheetContent(
      bridge: bridge,
      projectPath: projectPath,
      sessionId: sessionId,
    ),
  );
}

class _ScreenshotSheetContent extends StatefulWidget {
  final BridgeService bridge;
  final String projectPath;
  final String? sessionId;

  const _ScreenshotSheetContent({
    required this.bridge,
    required this.projectPath,
    this.sessionId,
  });

  @override
  State<_ScreenshotSheetContent> createState() =>
      _ScreenshotSheetContentState();
}

class _ScreenshotSheetContentState extends State<_ScreenshotSheetContent> {
  List<WindowInfo>? _windows;
  bool _capturing = false;
  StreamSubscription<List<WindowInfo>>? _windowSub;
  StreamSubscription<ScreenshotResultMessage>? _resultSub;

  @override
  void initState() {
    super.initState();
    _windowSub = widget.bridge.windowList.listen((windows) {
      if (mounted) setState(() => _windows = windows);
    });
    _resultSub = widget.bridge.screenshotResults.listen((result) {
      if (!mounted) return;
      setState(() => _capturing = false);
      // Capture references before pop (context may become invalid after pop)
      final messenger = ScaffoldMessenger.of(context);
      if (result.success) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Screenshot saved'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(result.error ?? 'Screenshot failed')),
        );
      }
    });
  }

  @override
  void dispose() {
    _windowSub?.cancel();
    _resultSub?.cancel();
    super.dispose();
  }

  void _capture({required String mode, int? windowId}) {
    if (_capturing) return;
    setState(() => _capturing = true);
    widget.bridge.takeScreenshot(
      mode: mode,
      windowId: windowId,
      projectPath: widget.projectPath,
      sessionId: widget.sessionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.screenshot_monitor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Screenshot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _capturing
                      ? null
                      : () {
                          setState(() => _windows = null);
                          widget.bridge.requestWindowList();
                        },
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Capturing overlay
          if (_capturing)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else ...[
            // Full screen option
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Icon(Icons.fullscreen, size: 24, color: cs.primary),
                title: const Text(
                  'Full Screen',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Capture entire desktop',
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                ),
                onTap: () => _capture(mode: 'fullscreen'),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            // Window list
            if (_windows == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (_windows!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No windows found',
                    style: TextStyle(color: appColors.subtleText),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _windows!.length,
                  itemBuilder: (context, index) {
                    final w = _windows![index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.web_asset,
                          size: 20,
                          color: appColors.subtleText,
                        ),
                        title: Text(
                          w.ownerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: w.windowTitle.isNotEmpty
                            ? Text(
                                w.windowTitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: appColors.subtleText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () =>
                            _capture(mode: 'window', windowId: w.windowId),
                      ),
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
