import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;

import '../../l10n/app_localizations.dart';
import '../../theme/markdown_style.dart';

const _authHelpUrl =
    'https://raw.githubusercontent.com/K9i-0/ccpocket/main/docs/auth-troubleshooting.md';

@RoutePage()
class AuthHelpScreen extends StatefulWidget {
  const AuthHelpScreen({super.key});

  @override
  State<AuthHelpScreen> createState() => _AuthHelpScreenState();
}

class _AuthHelpScreenState extends State<AuthHelpScreen> {
  String? _markdown;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_authHelpUrl));
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.authHelpTitle)),
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
                l.authHelpFetchError,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: _markdown!,
          styleSheet: buildMarkdownStyle(context),
          onTapLink: handleMarkdownLink,
        ),
      ),
    );
  }
}
