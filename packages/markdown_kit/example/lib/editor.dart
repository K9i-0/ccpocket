// A Markdown editor with a live preview: source on the left, the rendered
// document on the right, scrolling in step.
//
//     flutter run -t lib/editor.dart
//
// What comes from markdown_kit:
//
// - `MarkdownView` renders the preview. It is handed the whole text on every
//   keystroke and only rebuilds the blocks that changed.
// - `MarkdownDocument.blockSourceRanges` says which stretch of the source
//   each block came from. Scroll sync, the active block marker and tap to
//   jump are all built on it (editor/scroll_sync.dart).
// - `MarkdownView.blockWrapper` wraps each block of the preview, which is how
//   the editor finds a block on screen.
//
// The source pane itself is ordinary Flutter text editing and has nothing to
// do with the package (editor/source_pane.dart, editor/markdown_editing.dart,
// editor/markdown_highlight.dart).
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

import 'editor/markdown_editing.dart';
import 'editor/markdown_highlight.dart';
import 'editor/sample_document.dart';
import 'editor/scroll_sync.dart';
import 'editor/source_pane.dart';
import 'math.dart';
import 'theme.dart';

export 'theme.dart' show EditorColors;

void main() => runApp(const EditorApp());

/// The editor as an app.
class EditorApp extends StatelessWidget {
  /// Creates the app, opening [initialText].
  const EditorApp({super.key, this.initialText = sampleDocument});

  /// Markdown the editor starts with.
  final String initialText;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'markdown_kit editor',
      color: const Color(0xFF1F6FEB),
      debugShowCheckedModeBanner: false,
      // A Navigator supplies the Overlay that selection handles and menus are
      // drawn in.
      home: EditorPage(initialText: initialText),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

/// The parsed document with what the status bar says about it.
typedef _Parsed = ({
  MarkdownDocument document,
  int words,
  int characters,
  Duration parseTime,
});

/// The editor screen.
class EditorPage extends StatefulWidget {
  /// Creates the screen, opening [initialText].
  const EditorPage({
    super.key,
    this.initialText = sampleDocument,
    this.showHeader = true,
    this.dark,
    this.onDarkChanged,
    this.active = true,
  });

  /// Markdown the editor starts with.
  final String initialText;

  /// Whether to render the standalone header bar (title, Sync and Dark
  /// switches). When false, Sync and narrow-screen Preview switches move into
  /// the toolbar row so the editor embeds cleanly inside another shell.
  final bool showHeader;

  /// Optional external dark-mode flag. When null, the editor manages dark mode
  /// internally.
  final bool? dark;

  /// Optional callback invoked when the standalone Dark switch is toggled.
  final ValueChanged<bool>? onDarkChanged;

  /// Whether this pane is currently visible inside a tabbed host.
  final bool active;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static const _previewPadding = EdgeInsets.fromLTRB(24, 16, 24, 32);

  /// Below this width one pane is shown at a time.
  static const _wideLayout = 720.0;

  // An editor parses a new text on every keystroke, and no text comes back
  // once it has been typed over. So the cache of whole documents is off (it
  // would hold a copy of the source per keystroke), and the cache of blocks,
  // which is what makes a keystroke cheap, is large enough for a long file.
  final _parser = GfmMarkdownParser(
    maxCacheEntries: 0,
    maxBlockCacheEntries: 4096,
  );

  late final MarkdownEditingController _text = MarkdownEditingController(
    text: widget.initialText,
    palette: _colors.syntax,
  );
  final _focus = FocusNode(debugLabel: 'source');
  final _editableKey = GlobalKey<EditableTextState>();
  final _sourcePaneKey = GlobalKey();
  final _previewPaneKey = GlobalKey();
  final _sourceScroll = ScrollController();
  final _previewScroll = ScrollController();
  final _blocks = PreviewBlocks();
  late final _sync = ScrollSync(
    source: _sourceScroll,
    preview: _previewScroll,
    anchors: _anchors,
  );
  late final ValueNotifier<_Parsed> _parsed = ValueNotifier(_parse(_text.text));

  // The same instances on every build: the view rebuilds every block when
  // either of these changes.
  late final _builders = MarkdownBuilders(
    onLinkTap: (url, _) => setState(() => _notice = url),
    inlineLatexBuilder: buildInlineMath,
    blockLatexBuilder: buildBlockMath,
  );
  // Finds each block of the preview again on screen. A method, so the view
  // is handed an equal function on every build.
  Widget _wrapBlock(int index, MarkdownBlock block, Widget child) {
    return PreviewBlock(
      index: index,
      blocks: _blocks,
      color: _colors.accent,
      child: child,
    );
  }

  bool _dark = false;
  bool _syncScroll = true;
  bool _showPreview = false;
  double _split = 0.5;
  String? _notice;

  late String _lastText = _text.text;
  TextSelection? _lastSelection;
  bool _followScheduled = false;
  bool _skipFollow = false;

  bool get _isDark => widget.dark ?? _dark;

  EditorColors get _colors => _isDark ? EditorColors.dark : EditorColors.light;

  @override
  void initState() {
    super.initState();
    _text.addListener(_textChanged);
    _blocks.onTap = _jumpToBlock;
    _sync.enabled = _syncScroll;
    _updateActiveBlock();
  }

  @override
  void didUpdateWidget(covariant EditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark) {
      _text.palette = _colors.syntax;
    }
    if (oldWidget.active && !widget.active) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _sync.dispose();
    _text.dispose();
    _focus.dispose();
    _sourceScroll.dispose();
    _previewScroll.dispose();
    _blocks.dispose();
    _parsed.dispose();
    super.dispose();
  }

  _Parsed _parse(String text) {
    final watch = Stopwatch()..start();
    final document = _parser.parse(text);
    watch.stop();
    return (
      document: document,
      words: countWords(text),
      characters: text.characters.length,
      parseTime: watch.elapsed,
    );
  }

  void _textChanged() {
    final value = _text.value;
    final textChanged = value.text != _lastText;
    if (textChanged) {
      _lastText = value.text;
      _parsed.value = _parse(value.text);
      _anchorCache = null;
    }
    if (textChanged || value.selection != _lastSelection) {
      _lastSelection = value.selection;
      _updateActiveBlock();
      _scheduleFollow();
    }
  }

  /// Marks the blocks whose source the caret is in.
  void _updateActiveBlock() {
    final document = _parsed.value.document;
    final ranges = document.blockSourceRanges;
    final selection = _text.selection;
    final offset = selection.isValid ? selection.extentOffset : 0;
    final index = document.blockIndexAtSourceOffset(offset);
    if (ranges == null || index == null) {
      _blocks.active = null;
      return;
    }
    // Blocks made from one stretch of source share a range.
    var last = index;
    while (last + 1 < ranges.length && ranges[last + 1] == ranges[index]) {
      last++;
    }
    // One range for a whole document (raw HTML across blank lines) says
    // nothing about where the caret is.
    final everything = index == 0 && last == ranges.length - 1 && last > 0;
    _blocks.active = everything ? null : (first: index, last: last);
  }

  /// After the next layout, brings the preview to where the caret is.
  void _scheduleFollow() {
    if (_followScheduled) return;
    _followScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted) return;
      if (_skipFollow) {
        _skipFollow = false;
        return;
      }
      // Typing rarely scrolls the editor, and when it does the preview
      // follows through the scroll listener. All that is left to do here is
      // to make sure the block being edited is in view, which takes two
      // boxes rather than the anchors of the whole document.
      if (_syncScroll) _revealActiveBlock();
    });
  }

  /// Scrolls the preview just enough to show the block being edited. The two
  /// panes are matched at the top of the viewport, so a block near the bottom
  /// of the editor can still be below the fold of the preview.
  void _revealActiveBlock() {
    final active = _blocks.active;
    if (active == null || !_previewScroll.hasClients) return;
    final first = _blocks.boxOf(active.first);
    final last = _blocks.boxOf(active.last);
    if (first == null || last == null) return;
    final viewport = RenderAbstractViewport.of(first);
    final position = _previewScroll.position;
    final top = viewport.getOffsetToReveal(first, 0).offset;
    final bottom = viewport.getOffsetToReveal(last, 1).offset;
    const margin = 16.0;
    double? target;
    if (top - margin < position.pixels) {
      target = top - margin;
    } else if (bottom + margin > position.pixels) {
      // Taller than the viewport: show its start.
      target = bottom + margin < top - margin ? bottom + margin : top - margin;
    }
    if (target == null) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 0.5) return;
    _sync.withoutFollowing(() => _previewScroll.jumpTo(clamped));
  }

  /// Puts the caret at the start of the source of the tapped block.
  void _jumpToBlock(int index) {
    final ranges = _parsed.value.document.blockSourceRanges;
    if (ranges == null || index >= ranges.length) return;
    final offset = ranges[index].start.clamp(0, _text.text.length);
    // The preview is where the user is looking: it stays put and the editor
    // comes to it.
    final selection = TextSelection.collapsed(offset: offset);
    if (_text.selection != selection) {
      _skipFollow = true;
      _text.selection = selection;
    }
    if (_syncScroll) _sync.sourceFollowsPreview();
    _sync.withoutFollowing(
      () => _editableKey.currentState?.bringIntoView(
        TextPosition(offset: offset),
      ),
    );
  }

  // Anchors are measured from the layout, so they are kept until the text or
  // the size of either side changes.
  ({
    MarkdownDocument document,
    double sourceMax,
    double previewMax,
    double sourceViewport,
    double previewViewport,
    List<SyncAnchor> anchors,
  })?
  _anchorCache;

  List<SyncAnchor> _anchors() {
    final editable = _editableKey.currentState?.renderEditable;
    if (editable == null ||
        !editable.hasSize ||
        !_sourceScroll.hasClients ||
        !_previewScroll.hasClients) {
      return const [];
    }
    final source = _sourceScroll.position;
    final preview = _previewScroll.position;
    final document = _parsed.value.document;
    final cached = _anchorCache;
    if (cached != null &&
        identical(cached.document, document) &&
        cached.sourceMax == source.maxScrollExtent &&
        cached.previewMax == preview.maxScrollExtent &&
        cached.sourceViewport == source.viewportDimension &&
        cached.previewViewport == preview.viewportDimension) {
      return cached.anchors;
    }

    final measured = <SyncAnchor>[];
    final ranges = document.blockSourceRanges ?? const [];
    final sourceViewport = RenderAbstractViewport.of(editable);
    MarkdownSourceRange? previous;
    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      // One anchor per stretch of source, at its first block.
      if (range == previous) continue;
      previous = range;
      final box = _blocks.boxOf(i);
      if (box == null) continue;
      final line = editable.getLocalRectForCaret(
        TextPosition(offset: range.start),
      );
      measured.add((
        source:
            sourceViewport.getOffsetToReveal(editable, 0, rect: line).offset -
            SourcePane.padding.top,
        preview:
            RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
            _previewPadding.top,
      ));
    }
    final anchors = boundSyncAnchors(
      measured,
      sourceMax: source.maxScrollExtent,
      previewMax: preview.maxScrollExtent,
    );
    _anchorCache = (
      document: document,
      sourceMax: source.maxScrollExtent,
      previewMax: preview.maxScrollExtent,
      sourceViewport: source.viewportDimension,
      previewViewport: preview.viewportDimension,
      anchors: anchors,
    );
    return anchors;
  }

  void _apply(TextEditingValue Function(TextEditingValue value) command) {
    _text.value = command(_text.value);
    _focus.requestFocus();
  }

  void _setDark(bool dark) {
    if (widget.onDarkChanged != null) {
      widget.onDarkChanged!(dark);
      return;
    }
    setState(() => _dark = dark);
    _text.palette = _colors.syntax;
  }

  void _setSync(bool on) {
    setState(() => _syncScroll = on);
    _sync.enabled = on;
    if (on) _sync.previewFollowsSource();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.tab): () => _apply(indentLines),
      const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
          _apply((value) => indentLines(value, outdent: true)),
    };
    void bind(LogicalKeyboardKey key, VoidCallback action) {
      bindings[SingleActivator(key, meta: true)] = action;
      bindings[SingleActivator(key, control: true)] = action;
    }

    bind(LogicalKeyboardKey.keyB, () => _apply((v) => toggleInline(v, '**')));
    bind(LogicalKeyboardKey.keyI, () => _apply((v) => toggleInline(v, '*')));
    bind(LogicalKeyboardKey.keyE, () => _apply((v) => toggleInline(v, '`')));
    bind(LogicalKeyboardKey.keyK, () => _apply(insertLink));
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideLayout;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) _buildTopBar(colors, wide: wide),
            _buildToolbar(colors, wide: wide),
            _Rule(colors.border),
            Expanded(
              child: ColoredBox(
                color: colors.background,
                child: wide
                    ? _buildSplit(colors, constraints.maxWidth)
                    : _buildSingle(colors),
              ),
            ),
            _Rule(colors.border),
            _buildStatusBar(colors),
          ],
        );
      },
    );

    if (!widget.showHeader) {
      return ColoredBox(color: colors.chrome, child: body);
    }

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return ColoredBox(
      color: colors.chrome,
      child: DefaultTextStyle(
        style: TextStyle(color: colors.text, fontSize: 14),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(EditorColors colors, {required bool wide}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Markdown editor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!wide) ...[
            ToggleChip(
              key: const ValueKey('show-preview'),
              label: 'Preview',
              on: _showPreview,
              colors: colors,
              onChanged: (on) {
                setState(() => _showPreview = on);
                // The source is out of sight: put the keyboard away with it.
                if (on) _focus.unfocus();
              },
            ),
            const SizedBox(width: 6),
          ],
          ToggleChip(
            key: const ValueKey('sync-scroll'),
            label: 'Sync',
            on: _syncScroll,
            colors: colors,
            onChanged: _setSync,
          ),
          const SizedBox(width: 6),
          ToggleChip(
            key: const ValueKey('dark'),
            label: 'Dark',
            on: _isDark,
            colors: colors,
            onChanged: _setDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(EditorColors colors, {required bool wide}) {
    Widget button(
      String label,
      String name,
      TextEditingValue Function(TextEditingValue) command, {
      TextStyle? style,
    }) => _ToolButton(
      key: ValueKey('tool-$name'),
      label: label,
      semanticLabel: name,
      style: style,
      colors: colors,
      onPressed: () => _apply(command),
    );

    final tools = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: widget.showHeader
          ? const EdgeInsets.fromLTRB(12, 0, 12, 8)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          button(
            'B',
            'bold',
            (v) => toggleInline(v, '**'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          button(
            'I',
            'italic',
            (v) => toggleInline(v, '*'),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          button(
            'S',
            'strikethrough',
            (v) => toggleInline(v, '~~'),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          button('</>', 'code', (v) => toggleInline(v, '`')),
          _ToolGap(colors.border),
          button('H', 'heading', cycleHeading),
          button('•', 'bullets', (v) => toggleLineStyle(v, LineStyle.bullet)),
          button('1.', 'numbers', (v) => toggleLineStyle(v, LineStyle.ordered)),
          button('[ ]', 'tasks', (v) => toggleLineStyle(v, LineStyle.task)),
          button('>', 'quote', (v) => toggleLineStyle(v, LineStyle.quote)),
          _ToolGap(colors.border),
          button('{ }', 'code block', insertCodeBlock),
          button('Link', 'link', insertLink),
        ],
      ),
    );

    if (widget.showHeader) return tools;

    return Row(
      children: [
        Expanded(child: tools),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!wide) ...[
                ToggleChip(
                  key: const ValueKey('show-preview'),
                  label: 'Preview',
                  on: _showPreview,
                  colors: colors,
                  onChanged: (on) {
                    setState(() => _showPreview = on);
                    if (on) _focus.unfocus();
                  },
                ),
                const SizedBox(width: 6),
              ],
              ToggleChip(
                key: const ValueKey('sync-scroll'),
                label: 'Sync',
                on: _syncScroll,
                colors: colors,
                onChanged: _setSync,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplit(EditorColors colors, double width) {
    const handle = 9.0;
    final sourceWidth = ((width - handle) * _split).roundToDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: sourceWidth, child: _buildSource(colors)),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            key: const ValueKey('split-handle'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => setState(() {
              _split = ((sourceWidth + details.delta.dx) / (width - handle))
                  .clamp(0.2, 0.8);
            }),
            child: SizedBox(
              width: handle,
              child: Center(
                child: SizedBox(
                  width: 1,
                  height: double.infinity,
                  child: ColoredBox(color: colors.border),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _buildPreview(colors)),
      ],
    );
  }

  /// One pane at a time. Both stay laid out, so they keep scrolling in step
  /// and switching shows the same place.
  Widget _buildSingle(EditorColors colors) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: _showPreview, child: _buildSource(colors)),
        Offstage(offstage: !_showPreview, child: _buildPreview(colors)),
      ],
    );
  }

  Widget _buildSource(EditorColors colors) {
    return CallbackShortcuts(
      key: _sourcePaneKey,
      bindings: _shortcuts,
      child: SourcePane(
        controller: _text,
        focusNode: _focus,
        scrollController: _sourceScroll,
        editableKey: _editableKey,
        colors: colors.source,
      ),
    );
  }

  Widget _buildPreview(EditorColors colors) {
    return ValueListenableBuilder<_Parsed>(
      key: _previewPaneKey,
      valueListenable: _parsed,
      builder: (context, parsed, _) {
        if (parsed.document.isEmpty) {
          return Center(
            child: Text(
              'Nothing to preview yet',
              style: TextStyle(color: colors.muted),
            ),
          );
        }
        return SingleChildScrollView(
          key: const ValueKey('preview-scroll'),
          controller: _previewScroll,
          padding: _previewPadding,
          child: MarkdownView(
            // Parsed above, once per change, so the source ranges are at
            // hand for the scroll sync.
            document: parsed.document,
            documentId: 'preview',
            theme: colors.markdown,
            builders: _builders,
            blockWrapper: _wrapBlock,
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(EditorColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListenableBuilder(
        listenable: Listenable.merge([_text, _parsed]),
        builder: (context, _) {
          final parsed = _parsed.value;
          final caret = caretLineAndColumn(_text.value);
          final milliseconds = (parsed.parseTime.inMicroseconds / 1000)
              .toStringAsFixed(2);
          final notice = _notice;
          return Text(
            notice != null
                ? 'Link: $notice'
                : 'Ln ${caret.line}, Col ${caret.column}'
                      '  ·  ${parsed.words} words'
                      '  ·  ${parsed.characters} characters'
                      '  ·  ${parsed.document.blocks.length} blocks'
                      '  ·  parsed in $milliseconds ms',
            key: const ValueKey('status'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted, fontSize: 12),
          );
        },
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, child: ColoredBox(color: color));
}

class _ToolGap extends StatelessWidget {
  const _ToolGap(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(width: 1, height: 18, child: ColoredBox(color: color)),
  );
}

/// A toolbar button with a text label. It does not take focus, so the caret
/// stays in the source while it is pressed.
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.colors,
    required this.onPressed,
    this.style,
  });

  final String label;
  final String semanticLabel;
  final EditorColors colors;
  final VoidCallback onPressed;
  final TextStyle? style;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _pressed || _hovered ? colors.hover : null,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ).merge(widget.style),
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
