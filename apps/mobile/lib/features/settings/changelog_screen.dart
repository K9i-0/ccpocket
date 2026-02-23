import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/markdown_style.dart';

const _changelogUrl =
    'https://raw.githubusercontent.com/K9i-0/ccpocket/main/CHANGELOG.md';

@RoutePage()
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  String? _markdown;
  String? _error;
  bool _loading = true;
  bool _showAll = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;
    await _fetchChangelog();
  }

  Future<void> _fetchChangelog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_changelogUrl));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _markdown = response.body;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'HTTP ${response.statusCode}';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Filters the changelog markdown to only include entries for versions
  /// up to and including the current app version.
  String _filterByVersion(String markdown) {
    if (_appVersion.isEmpty) return markdown;

    final lines = markdown.split('\n');
    final buffer = StringBuffer();
    var foundCurrentOrOlder = false;
    var skipping = false;

    for (final line in lines) {
      final versionMatch = RegExp(r'^## \[(\d+\.\d+\.\d+)\]').firstMatch(line);
      if (versionMatch != null) {
        final entryVersion = versionMatch.group(1)!;
        final cmp = _compareVersions(entryVersion, _appVersion);
        if (cmp <= 0) {
          // This version is <= current app version
          foundCurrentOrOlder = true;
          skipping = false;
        } else {
          // This version is newer than current app version
          skipping = true;
          continue;
        }
      }

      if (skipping) continue;

      // Include the header lines before any version entry
      if (!foundCurrentOrOlder && versionMatch == null) {
        buffer.writeln(line);
        continue;
      }

      if (foundCurrentOrOlder) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trimRight();
  }

  /// Compares two semantic version strings.
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.changelogTitle),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.showAllMain,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Switch(
                value: _showAll,
                onChanged: (value) => setState(() => _showAll = value),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _markdown == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                l.changelogFetchError,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchChangelog,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }

    final displayMarkdown = _showAll
        ? _markdown!
        : _filterByVersion(_markdown!);

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: displayMarkdown,
          styleSheet: buildMarkdownStyle(context),
          onTapLink: handleMarkdownLink,
        ),
      ),
    );
  }
}
