/// A Bridge URL safe to show on screen: without the `token` query (the API
/// key travels in the URL of QR and "connect from this app" links) and
/// without user info.
String? displayBridgeUrl(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    final cut = url.indexOf('?');
    return cut < 0 ? url : url.substring(0, cut);
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final path = uri.path == '/' ? '' : uri.path;
  return '${uri.scheme}://$host$port$path';
}
