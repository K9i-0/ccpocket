String? bridgeHttpBaseUrlFromWsUrl(String? wsUrl) {
  if (wsUrl == null) return null;
  final uri = Uri.tryParse(wsUrl.trim());
  if (uri == null) return null;
  final scheme = uri.scheme == 'wss' ? 'https' : 'http';
  final normalizedPath = _normalizeBasePath(uri.path);
  return Uri(
    scheme: scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: normalizedPath,
  ).toString();
}

String buildBridgeHttpUrl(String httpBaseUrl, String endpointPath) {
  final base = httpBaseUrl.endsWith('/')
      ? httpBaseUrl.substring(0, httpBaseUrl.length - 1)
      : httpBaseUrl;
  final path = endpointPath.startsWith('/')
      ? endpointPath.substring(1)
      : endpointPath;
  return '$base/$path';
}

String stripBridgeAuthToken(String wsUrl) {
  final uri = Uri.tryParse(wsUrl.trim());
  if (uri == null) return wsUrl.trim();

  final query = Map<String, String>.from(uri.queryParameters);
  query.remove('token');

  return uri
      .replace(queryParameters: query.isEmpty ? null : query, fragment: null)
      .toString();
}

String _normalizeBasePath(String path) {
  if (path.isEmpty || path == '/') return '';
  if (path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}
