import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UrlHistoryEntry {
  final String url;
  final String apiKey;
  final DateTime lastConnected;
  final String? name;

  UrlHistoryEntry({
    required this.url,
    required this.apiKey,
    required this.lastConnected,
    this.name,
  });

  /// 表示用の名前（名前が設定されていなければURLを返す）
  String get displayName => name?.isNotEmpty == true ? name! : url;

  UrlHistoryEntry copyWith({
    String? url,
    String? apiKey,
    DateTime? lastConnected,
    String? name,
  }) {
    return UrlHistoryEntry(
      url: url ?? this.url,
      apiKey: apiKey ?? this.apiKey,
      lastConnected: lastConnected ?? this.lastConnected,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'apiKey': apiKey,
    'lastConnected': lastConnected.toIso8601String(),
    if (name != null) 'name': name,
  };

  factory UrlHistoryEntry.fromJson(Map<String, dynamic> json) {
    return UrlHistoryEntry(
      url: json['url'] as String,
      apiKey: json['apiKey'] as String? ?? '',
      lastConnected: DateTime.parse(json['lastConnected'] as String),
      name: json['name'] as String?,
    );
  }
}

class UrlHistoryService {
  static const _prefsKey = 'url_history';
  static const _maxEntries = 10;

  final SharedPreferences _prefs;

  UrlHistoryService(this._prefs);

  List<UrlHistoryEntry> load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final entries = list
          .map((e) => UrlHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String url, String apiKey) async {
    final entries = load();
    // Remove existing entry with same URL
    entries.removeWhere((e) => e.url == url);
    // Add new entry at the beginning
    entries.insert(
      0,
      UrlHistoryEntry(url: url, apiKey: apiKey, lastConnected: DateTime.now()),
    );
    // Enforce max entries
    final trimmed = entries.take(_maxEntries).toList();
    await _save(trimmed);
  }

  Future<void> remove(String url) async {
    final entries = load();
    entries.removeWhere((e) => e.url == url);
    await _save(entries);
  }

  Future<void> updateName(String url, String? name) async {
    final entries = load();
    final index = entries.indexWhere((e) => e.url == url);
    if (index != -1) {
      entries[index] = entries[index].copyWith(name: name);
      await _save(entries);
    }
  }

  Future<void> _save(List<UrlHistoryEntry> entries) async {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_prefsKey, json);
  }
}
