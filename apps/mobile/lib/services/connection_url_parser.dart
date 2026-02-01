class ConnectionParams {
  final String serverUrl;
  final String? token;

  const ConnectionParams({required this.serverUrl, this.token});
}

class ConnectionUrlParser {
  /// Parses a connection URL into [ConnectionParams].
  ///
  /// Supported formats:
  /// - `ccpocket://connect?url=ws://IP:PORT&token=...`
  /// - `ws://IP:PORT` or `wss://IP:PORT`
  /// - `IP:PORT` (treated as ws://)
  static ConnectionParams? parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    // Deep link: ccpocket://connect?url=...&token=...
    if (trimmed.startsWith('ccpocket://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      final url = uri.queryParameters['url'];
      if (url == null || url.isEmpty) return null;
      final token = uri.queryParameters['token'];
      return ConnectionParams(
        serverUrl: url,
        token: (token != null && token.isNotEmpty) ? token : null,
      );
    }

    // Direct ws:// or wss://
    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return ConnectionParams(serverUrl: trimmed);
    }

    // Bare host:port
    final hostPortPattern = RegExp(r'^[\w.\-]+:\d+$');
    if (hostPortPattern.hasMatch(trimmed)) {
      return ConnectionParams(serverUrl: 'ws://$trimmed');
    }

    return null;
  }
}
