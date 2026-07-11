sealed class DeepLinkParams {}

class ConnectionParams extends DeepLinkParams {
  final String serverUrl;
  final String? token;

  ConnectionParams({required this.serverUrl, this.token});
}

class SessionLinkParams extends DeepLinkParams {
  final String sessionId;

  SessionLinkParams({required this.sessionId});
}

class ConnectionUrlParser {
  /// Parses a deep link URL into [DeepLinkParams].
  ///
  /// Supported formats:
  /// - `ccpocket://connect?url=ws://IP:PORT&token=...` → [ConnectionParams]
  /// - `ccpocket://session/<sessionId>` → [SessionLinkParams]
  /// - `ws://IP:PORT` or `wss://IP:PORT` → [ConnectionParams]
  /// - `IP:PORT` (treated as ws://) → [ConnectionParams]
  static DeepLinkParams? parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    // Deep link: ccpocket://...
    if (trimmed.startsWith('ccpocket://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;

      // ccpocket://session/<sessionId>
      if (uri.host == 'session') {
        final segments = uri.pathSegments;
        if (segments.isEmpty) return null;
        final sessionId = segments.first;
        if (sessionId.isEmpty) return null;
        return SessionLinkParams(sessionId: sessionId);
      }

      // ccpocket://connect?url=...&token=...
      if (uri.host == 'connect') {
        final url = uri.queryParameters['url'];
        if (url == null || !_isValidWebSocketUrl(url)) return null;
        final token = uri.queryParameters['token'];
        return ConnectionParams(
          serverUrl: url,
          token: (token != null && token.isNotEmpty) ? token : null,
        );
      }

      return null;
    }

    // Direct ws:// or wss://
    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return _isValidWebSocketUrl(trimmed)
          ? ConnectionParams(serverUrl: trimmed)
          : null;
    }

    // Bare host:port
    final hostPortPattern = RegExp(r'^[\w.\-]+:\d+$');
    final bracketedIpv6PortPattern = RegExp(r'^\[[^\]]*:[^\]]*\]:\d+$');
    if (hostPortPattern.hasMatch(trimmed)) {
      return ConnectionParams(serverUrl: 'ws://$trimmed');
    }
    if (bracketedIpv6PortPattern.hasMatch(trimmed)) {
      try {
        final uri = Uri.parse('ws://$trimmed');
        if (uri.host.contains(':') &&
            uri.hasPort &&
            uri.port > 0 &&
            uri.port <= 65535) {
          return ConnectionParams(serverUrl: 'ws://$trimmed');
        }
      } on FormatException {
        return null;
      }
    }

    return null;
  }

  static bool _isValidWebSocketUrl(String value) {
    try {
      final uri = Uri.parse(value);
      if ((uri.scheme != 'ws' && uri.scheme != 'wss') || uri.host.isEmpty) {
        return false;
      }
      return !uri.hasPort || (uri.port > 0 && uri.port <= 65535);
    } on FormatException {
      return false;
    }
  }
}
