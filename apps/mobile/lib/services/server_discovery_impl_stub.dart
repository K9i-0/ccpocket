// Web stub for server discovery. mDNS is not available in browsers.

Future<dynamic> startDiscovery({
  required void Function(String name, String host, int port, bool authRequired)
  onResolved,
  required void Function(String host, int port) onLost,
}) async {
  // No-op on Web
  return null;
}

Future<void> stopDiscovery(dynamic discovery) async {
  // No-op on Web
}
