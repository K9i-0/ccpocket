import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/bridge_service_helpers.dart';
import '../state/recent_session_filters.dart';

/// Persists device-local recent-session filters in [SharedPreferences].
///
/// Common filters (period, date field, pinned only, content search) are shared
/// across Bridges on this device. Project filters are stored per Bridge target
/// because project paths and IDs belong to a specific machine.
class RecentSessionFilterStore {
  static const commonFiltersKey = 'session_list_filters_v1';
  static const projectFiltersByBridgeKey =
      'session_list_project_filters_by_bridge_v1';

  const RecentSessionFilterStore();

  /// Canonical key for a Bridge URL (omitting query tokens), or null when the
  /// URL is absent or invalid.
  static String? bridgeScopeKey(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return null;
    return bridgeTargetKey(uri);
  }

  /// Load device-global filter fields (`projectKeys` is always empty).
  RecentSessionFilters loadCommonFilters(SharedPreferences prefs) {
    final raw = prefs.getString(commonFiltersKey);
    if (raw == null || raw.isEmpty) return const RecentSessionFilters();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const RecentSessionFilters();
      final dateFilter = RecentDateFilter.fromJson(decoded['dateFilter']);
      final dateFieldRaw = decoded['dateField'];
      final dateField = RecentDateField.values.firstWhere(
        (field) => field.name == dateFieldRaw,
        orElse: () => RecentDateField.modified,
      );
      final pinnedOnly = decoded['pinnedOnly'] == true;
      final searchContent = decoded['searchContent'] == true;
      return RecentSessionFilters(
        dateFilter: dateFilter,
        dateField: dateField,
        pinnedOnly: pinnedOnly,
        searchContent: searchContent,
      );
    } catch (_) {
      return const RecentSessionFilters();
    }
  }

  Future<void> saveCommonFilters(
    SharedPreferences prefs,
    RecentSessionFilters filters,
  ) async {
    if (filters.hasOnlyDefaultCommonFields) {
      await prefs.remove(commonFiltersKey);
      return;
    }
    final payload = <String, Object?>{
      if (filters.dateFilter != null)
        'dateFilter': filters.dateFilter!.toJson(),
      if (filters.dateField != RecentDateField.modified)
        'dateField': filters.dateField.name,
      if (filters.pinnedOnly) 'pinnedOnly': true,
      if (filters.searchContent) 'searchContent': true,
    };
    await prefs.setString(commonFiltersKey, jsonEncode(payload));
  }

  /// Load all per-Bridge project selections keyed by [bridgeScopeKey].
  Map<String, Set<String>> loadProjectFiltersByBridge(SharedPreferences prefs) {
    final raw = prefs.getString(projectFiltersByBridgeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, Set<String>>{};
      for (final entry in decoded.entries) {
        final bridgeKey = entry.key;
        final value = entry.value;
        if (bridgeKey is! String || bridgeKey.isEmpty || value is! List) {
          continue;
        }
        final keys = value
            .whereType<String>()
            .where((k) => k.isNotEmpty)
            .toSet();
        if (keys.isNotEmpty) {
          result[bridgeKey] = keys;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveProjectFiltersByBridge(
    SharedPreferences prefs,
    Map<String, Set<String>> byBridge,
  ) async {
    final normalized = <String, List<String>>{};
    for (final entry in byBridge.entries) {
      if (entry.key.isEmpty) continue;
      final sorted = entry.value.where((k) => k.isNotEmpty).toList()..sort();
      if (sorted.isNotEmpty) {
        normalized[entry.key] = sorted;
      }
    }
    if (normalized.isEmpty) {
      await prefs.remove(projectFiltersByBridgeKey);
      return;
    }
    await prefs.setString(projectFiltersByBridgeKey, jsonEncode(normalized));
  }
}
