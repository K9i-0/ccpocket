import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/markdown_style.dart';

enum _AuthHelpLanguage { ja, en, zhHans }

extension on _AuthHelpLanguage {
  String get assetPath {
    return switch (this) {
      _AuthHelpLanguage.ja => 'assets/docs/auth-troubleshooting.ja.md',
      _AuthHelpLanguage.en => 'assets/docs/auth-troubleshooting.en.md',
      _AuthHelpLanguage.zhHans => 'assets/docs/auth-troubleshooting.zh-CN.md',
    };
  }
}

@RoutePage()
class AuthHelpScreen extends StatefulWidget {
  const AuthHelpScreen({super.key});

  @override
  State<AuthHelpScreen> createState() => _AuthHelpScreenState();
}

class _AuthHelpScreenState extends State<AuthHelpScreen> {
  Map<_AuthHelpLanguage, String>? _markdownByLanguage;
  _AuthHelpLanguage? _selectedLanguage;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedLanguage != null) return;
    _selectedLanguage = _preferredLanguage(Localizations.localeOf(context));
    _loadMarkdown();
  }

  _AuthHelpLanguage _preferredLanguage(Locale locale) {
    return switch (locale.languageCode) {
      'ja' => _AuthHelpLanguage.ja,
      'zh' => _AuthHelpLanguage.zhHans,
      _ => _AuthHelpLanguage.en,
    };
  }

  Future<void> _loadMarkdown() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ja = await rootBundle.loadString(_AuthHelpLanguage.ja.assetPath);
      final en = await rootBundle.loadString(_AuthHelpLanguage.en.assetPath);
      final zhHans = await rootBundle.loadString(
        _AuthHelpLanguage.zhHans.assetPath,
      );
      if (!mounted) return;
      setState(() {
        _markdownByLanguage = {
          _AuthHelpLanguage.ja: ja,
          _AuthHelpLanguage.en: en,
          _AuthHelpLanguage.zhHans: zhHans,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.authHelpTitle)),
      body: _AuthHelpBody(
        loading: _loading,
        error: _error,
        selectedLanguage: _selectedLanguage ?? _AuthHelpLanguage.en,
        markdownByLanguage: _markdownByLanguage,
        onRetry: _loadMarkdown,
        onLanguageChanged: (_AuthHelpLanguage language) {
          setState(() {
            _selectedLanguage = language;
          });
        },
      ),
    );
  }
}

class _AuthHelpBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final _AuthHelpLanguage selectedLanguage;
  final Map<_AuthHelpLanguage, String>? markdownByLanguage;
  final Future<void> Function() onRetry;
  final ValueChanged<_AuthHelpLanguage> onLanguageChanged;

  const _AuthHelpBody({
    required this.loading,
    required this.error,
    required this.selectedLanguage,
    required this.markdownByLanguage,
    required this.onRetry,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null || markdownByLanguage == null) {
      return _AuthHelpErrorState(onRetry: onRetry);
    }

    final markdown = markdownByLanguage![selectedLanguage]!;

    return Column(
      children: [
        _AuthHelpLanguageSwitcher(
          selectedLanguage: selectedLanguage,
          onChanged: onLanguageChanged,
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(
                data: markdown,
                styleSheet: buildMarkdownStyle(context),
                onTapLink: handleMarkdownLink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthHelpLanguageSwitcher extends StatelessWidget {
  final _AuthHelpLanguage selectedLanguage;
  final ValueChanged<_AuthHelpLanguage> onChanged;

  const _AuthHelpLanguageSwitcher({
    required this.selectedLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<_AuthHelpLanguage>(
          key: const ValueKey('auth_help_language_switcher'),
          segments: [
            ButtonSegment<_AuthHelpLanguage>(
              value: _AuthHelpLanguage.ja,
              label: Text(l.authHelpLanguageJa),
            ),
            ButtonSegment<_AuthHelpLanguage>(
              value: _AuthHelpLanguage.en,
              label: Text(l.authHelpLanguageEn),
            ),
            ButtonSegment<_AuthHelpLanguage>(
              value: _AuthHelpLanguage.zhHans,
              label: Text(l.authHelpLanguageZhHans),
            ),
          ],
          selected: {selectedLanguage},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            onChanged(selection.first);
          },
        ),
      ),
    );
  }
}

class _AuthHelpErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AuthHelpErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l.authHelpFetchError,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }
}
