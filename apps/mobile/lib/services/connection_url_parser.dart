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
        if (url == null || url.isEmpty) return null;
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
