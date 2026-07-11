String normalizeHostInput(String host) {
  var normalized = host.trim();
  if (normalized.startsWith('[') && normalized.endsWith(']')) {
    normalized = normalized.substring(1, normalized.length - 1).trim();
  }
  if (normalized.contains(':')) {
    normalized = normalized.replaceFirst(
      RegExp('%25', caseSensitive: false),
      '%',
    );
  }
  return normalized;
}

String bracketIpv6Host(String host) {
  final normalized = normalizeHostInput(host);
  if (normalized.isEmpty || !normalized.contains(':')) return normalized;
  return '[$normalized]';
}

String canonicalHostIdentity(String host) {
  final normalized = normalizeHostInput(host);
  if (!normalized.contains(':')) return normalized.toLowerCase();

  final zoneIndex = normalized.indexOf('%');
  final address = zoneIndex == -1
      ? normalized
      : normalized.substring(0, zoneIndex);
  final zone = zoneIndex == -1 ? '' : normalized.substring(zoneIndex);
  return '${_canonicalIpv6Address(address) ?? address.toLowerCase()}$zone';
}

String? _canonicalIpv6Address(String address) {
  if (address.indexOf('::') != address.lastIndexOf('::')) return null;
  final halves = address.split('::');
  final left = _parseIpv6Parts(halves.first);
  final right = halves.length == 1 ? <int>[] : _parseIpv6Parts(halves.last);
  if (left == null || right == null) return null;

  final hasCompression = halves.length == 2;
  final missing = 8 - left.length - right.length;
  if ((!hasCompression && missing != 0) || (hasCompression && missing < 1)) {
    return null;
  }
  final words = <int>[...left, ...List.filled(missing, 0), ...right];
  if (words.length != 8) return null;

  var bestStart = -1;
  var bestLength = 0;
  for (var index = 0; index < words.length;) {
    if (words[index] != 0) {
      index++;
      continue;
    }
    final start = index;
    while (index < words.length && words[index] == 0) {
      index++;
    }
    final length = index - start;
    if (length >= 2 && length > bestLength) {
      bestStart = start;
      bestLength = length;
    }
  }

  if (bestStart == -1) {
    return words.map((word) => word.toRadixString(16)).join(':');
  }
  final before = words
      .take(bestStart)
      .map((word) => word.toRadixString(16))
      .join(':');
  final after = words
      .skip(bestStart + bestLength)
      .map((word) => word.toRadixString(16))
      .join(':');
  if (before.isEmpty && after.isEmpty) return '::';
  if (before.isEmpty) return '::$after';
  if (after.isEmpty) return '$before::';
  return '$before::$after';
}

List<int>? _parseIpv6Parts(String input) {
  if (input.isEmpty) return <int>[];
  final parts = input.split(':');
  final words = <int>[];
  for (var index = 0; index < parts.length; index++) {
    final part = parts[index];
    if (part.isEmpty) return null;
    if (part.contains('.')) {
      if (index != parts.length - 1) return null;
      final octets = part.split('.').map(int.tryParse).toList();
      if (octets.length != 4 ||
          octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
        return null;
      }
      words.add((octets[0]! << 8) | octets[1]!);
      words.add((octets[2]! << 8) | octets[3]!);
      continue;
    }
    if (part.length > 4) return null;
    final word = int.tryParse(part, radix: 16);
    if (word == null) return null;
    words.add(word);
  }
  return words;
}

String formatHostPort(String host, int port) =>
    '${bracketIpv6Host(host)}:$port';

String endpointIdentityKey(String host, int port) =>
    formatHostPort(canonicalHostIdentity(host), port);

String formatUriOrigin({
  required String scheme,
  required String host,
  int? port,
}) {
  final origin = Uri(scheme: scheme, host: normalizeHostInput(host)).toString();
  return port == null ? origin : '$origin:$port';
}
