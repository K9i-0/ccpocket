import 'dart:convert';

/// Applied only to HTTP(S) links opened from agent messages.
enum LocalUrlMode { original, replace, ask }

String? localUrlConnectionKey(String? bridgeUrl) {
  final uri = Uri.tryParse(bridgeUrl ?? '');
  if (uri == null || uri.host.isEmpty) return null;
  // Exclude credentials, paths and tokens from preference keys.
  return '${uri.scheme}://${uri.host}:${uri.port}';
}

String? normalizeLocalUrlHost(String input) {
  final host = input.trim();
  if (host.isEmpty || host.contains(RegExp(r'[\s/@?#\\]'))) return null;
  final uri = Uri.tryParse('http://$host');
  if (uri == null || uri.host.isEmpty || uri.hasPort || uri.path.isNotEmpty) {
    return null;
  }
  return uri.host.contains(':') ? '[${uri.host}]' : uri.host;
}

Uri? replaceLocalUrlHost(Uri uri, String host) {
  if (!{'http', 'https'}.contains(uri.scheme) ||
      !{'localhost', '127.0.0.1', '[::1]', '::1'}.contains(uri.host)) {
    return null;
  }
  final normalized = normalizeLocalUrlHost(host);
  return normalized == null ? null : uri.replace(host: normalized);
}

class LocalUrlSettings {
  const LocalUrlSettings({this.mode = LocalUrlMode.original, this.host = ''});

  final LocalUrlMode mode;
  final String host;

  String encode() => jsonEncode({'mode': mode.name, 'host': host});

  static LocalUrlSettings decode(String? raw) {
    try {
      final value = jsonDecode(raw ?? '') as Map<String, dynamic>;
      return LocalUrlSettings(
        mode: LocalUrlMode.values.firstWhere(
          (mode) => mode.name == value['mode'],
          orElse: () => LocalUrlMode.original,
        ),
        host: value['host'] as String? ?? '',
      );
    } catch (_) {
      return const LocalUrlSettings();
    }
  }
}
