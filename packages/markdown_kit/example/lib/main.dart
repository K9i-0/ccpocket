import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'chat.dart';
import 'editor.dart';
import 'showcase.dart';
import 'theme.dart';

export 'chat.dart' show sampleReply;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Let markdown_kit's context menu (Copy / Copy as Markdown / Select all)
    // and the editor menu appear on right-click without the browser menu on top.
    BrowserContextMenu.disableContextMenu();
  }
  runApp(ExampleApp(initialTab: _initialTabFromRoute()));
}

/// The three demos included in the example app.
enum ExampleTab {
  /// Token-by-token streaming AI chat with syntax holding and lazy list
  /// selection.
  chat(label: 'Chat', fragment: 'chat'),

  /// Split-pane Markdown editor with incremental parsing and synced scrolling.
  editor(label: 'Editor', fragment: 'editor'),

  /// Single long document rendered with `SliverMarkdownView`, math builders,
  /// custom inline rules and Copy vs Copy as Markdown inspection.
  showcase(label: 'Showcase', fragment: 'showcase');

  const ExampleTab({required this.label, required this.fragment});

  final String label;
  final String fragment;
}

ExampleTab _initialTabFromRoute() {
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName
      .toLowerCase();
  if (route.contains('editor')) return ExampleTab.editor;
  if (route.contains('showcase')) return ExampleTab.showcase;
  return ExampleTab.chat;
}

/// Interactive demo app for `markdown_kit`, built on `package:flutter/widgets.dart`
/// only (no Material or Cupertino dependency).
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key, this.initialTab = ExampleTab.chat});

  /// Tab shown first.
  final ExampleTab initialTab;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'markdown_kit',
      color: const Color(0xFF1F6FEB),
      debugShowCheckedModeBanner: false,
      // A Navigator supplies the Overlay that selection handles and context
      // menus are drawn in.
      home: ExampleShell(initialTab: initialTab),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

/// Top-level tabbed shell hosting the Chat, Editor and Showcase views.
class ExampleShell extends StatefulWidget {
  /// Creates the shell starting on [initialTab].
  const ExampleShell({super.key, this.initialTab = ExampleTab.chat});

  /// Tab shown first.
  final ExampleTab initialTab;

  @override
  State<ExampleShell> createState() => _ExampleShellState();
}

class _ExampleShellState extends State<ExampleShell> {
  late ExampleTab _tab = widget.initialTab;
  bool _dark = false;

  ExampleColors get _colors => _dark ? ExampleColors.dark : ExampleColors.light;

  void _selectTab(ExampleTab tab) {
    if (tab == _tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: colors.chrome,
      child: DefaultTextStyle(
        style: TextStyle(color: colors.text, fontSize: 14),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  tab: _tab,
                  dark: _dark,
                  colors: colors,
                  onTabSelected: _selectTab,
                  onDarkChanged: (on) => setState(() => _dark = on),
                ),
                Hairline(colors.border),
                Expanded(
                  child: IndexedStack(
                    index: _tab.index,
                    children: [
                      TickerMode(
                        enabled: _tab == ExampleTab.chat,
                        child: ChatTab(
                          colors: colors,
                          active: _tab == ExampleTab.chat,
                        ),
                      ),
                      TickerMode(
                        enabled: _tab == ExampleTab.editor,
                        child: EditorPage(
                          showHeader: false,
                          dark: _dark,
                          onDarkChanged: (on) => setState(() => _dark = on),
                          active: _tab == ExampleTab.editor,
                        ),
                      ),
                      TickerMode(
                        enabled: _tab == ExampleTab.showcase,
                        child: ShowcaseTab(
                          colors: colors,
                          active: _tab == ExampleTab.showcase,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.tab,
    required this.dark,
    required this.colors,
    required this.onTabSelected,
    required this.onDarkChanged,
  });

  final ExampleTab tab;
  final bool dark;
  final ExampleColors colors;
  final ValueChanged<ExampleTab> onTabSelected;
  final ValueChanged<bool> onDarkChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= 520;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                if (showTitle) ...[
                  Text(
                    'markdown_kit',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Hairline.vertical(colors.border, length: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in ExampleTab.values)
                          _NavTab(
                            key: ValueKey('tab-${entry.fragment}'),
                            label: entry.label,
                            selected: entry == tab,
                            colors: colors,
                            onTap: () => onTabSelected(entry),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ToggleChip(
                  key: const ValueKey('app-dark'),
                  label: 'Dark',
                  on: dark,
                  colors: colors,
                  onChanged: onDarkChanged,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavTab extends StatefulWidget {
  const _NavTab({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ExampleColors colors;
  final VoidCallback onTap;

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? colors.accent : const Color(0x00000000),
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: selected || _hovered ? colors.text : colors.muted,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
