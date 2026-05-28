String bracketIpv6Host(String host) {
  final trimmed = normalizeHostInput(host);
  if (trimmed.isEmpty) return trimmed;
  return trimmed.contains(':') ? '[$trimmed]' : trimmed;
}

String normalizeHostInput(String host) {
  final trimmed = host.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    return trimmed.substring(1, trimmed.length - 1).trim();
  }
  return trimmed;
}

String formatHostPort(String host, int port) =>
    '${bracketIpv6Host(host)}:$port';

String formatUriOrigin({
  required String scheme,
  required String host,
  int? port,
}) {
  final portPart = port == null ? '' : ':$port';
  return '$scheme://${bracketIpv6Host(host)}$portPart';
}
