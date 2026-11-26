import 'package:flutter/foundation.dart';

/// Period presets offered by the quick period filter.
enum RecentDatePreset {
  today,
  yesterday,
  dayBeforeYesterday,
  last7Days,
  last30Days,
  custom,
}

/// Which timestamp a period filter compares.
enum RecentDateField { modified, created }

/// A period filter: a preset, or a custom inclusive range of local days.
@immutable
class RecentDateFilter {
  final RecentDatePreset preset;

  /// First local day of a [RecentDatePreset.custom] range (inclusive).
  final DateTime? customStart;

  /// Last local day of a [RecentDatePreset.custom] range (inclusive).
  final DateTime? customEnd;

  const RecentDateFilter(this.preset) : customStart = null, customEnd = null;

  RecentDateFilter.custom({required DateTime start, required DateTime end})
    : preset = RecentDatePreset.custom,
      customStart = _day(start),
      customEnd = _day(end);

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDay(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static final _isoDayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime? _parseDay(Object? raw) {
    if (raw is! String) return null;
    final match = _isoDayPattern.firstMatch(raw);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    if (preset == RecentDatePreset.custom && customStart != null)
      'customStart': _formatDay(customStart!),
    if (preset == RecentDatePreset.custom && customEnd != null)
      'customEnd': _formatDay(customEnd!),
  };

  static RecentDateFilter? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final presetName = raw['preset'];
    if (presetName is! String) return null;
    RecentDatePreset? preset;
    for (final candidate in RecentDatePreset.values) {
      if (candidate.name == presetName) {
        preset = candidate;
        break;
      }
    }
    if (preset == null) return null;
    if (preset != RecentDatePreset.custom) {
      return RecentDateFilter(preset);
    }
    final start = _parseDay(raw['customStart']);
    final end = _parseDay(raw['customEnd']);
    if (start == null || end == null || start.isAfter(end)) return null;
    return RecentDateFilter.custom(start: start, end: end);
  }

  /// Resolve to a half-open `[start, end)` range of local instants.
  ({DateTime start, DateTime? end}) resolve(DateTime now) {
    final today = _day(now);
    DateTime daysAgo(int days) =>
        DateTime(today.year, today.month, today.day - days);
    return switch (preset) {
      RecentDatePreset.today => (start: today, end: null),
      RecentDatePreset.yesterday => (start: daysAgo(1), end: today),
      RecentDatePreset.dayBeforeYesterday => (
        start: daysAgo(2),
        end: daysAgo(1),
      ),
      RecentDatePreset.last7Days => (start: daysAgo(6), end: null),
      RecentDatePreset.last30Days => (start: daysAgo(29), end: null),
      RecentDatePreset.custom => (
        start: customStart ?? today,
        end: DateTime(
          (customEnd ?? today).year,
          (customEnd ?? today).month,
          (customEnd ?? today).day + 1,
        ),
      ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RecentDateFilter &&
      other.preset == preset &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode => Object.hash(preset, customStart, customEnd);
}

/// Recent session filters beyond provider / named only / search text.
///
/// Requires the Bridge capability `recent_sessions_filters_v1` for everything
/// except a single [projectKeys] entry. See docs/recent-sessions-filters.md.
@immutable
class RecentSessionFilters {
  /// Selected project filter keys (`project:<id>` or a folder path).
  final Set<String> projectKeys;
  final RecentDateFilter? dateFilter;
  final RecentDateField dateField;
  final bool pinnedOnly;

  /// Also search transcript text (slow path).
  final bool searchContent;

  const RecentSessionFilters({
    this.projectKeys = const {},
    this.dateFilter,
    this.dateField = RecentDateField.modified,
    this.pinnedOnly = false,
    this.searchContent = false,
  });

  /// The single selected project key, or null for none / several.
  String? get singleProjectKey =>
      projectKeys.length == 1 ? projectKeys.first : null;

  /// Filters that only the advanced search screen edits.
  int get advancedOnlyCount =>
      (searchContent ? 1 : 0) + (dateField != RecentDateField.modified ? 1 : 0);

  /// Advanced-only conditions that actively affect the current listing.
  ///
  /// [searchContent] only applies while a keyword query is set, and [dateField]
  /// only applies while a [dateFilter] is set.
  int effectiveAdvancedOnlyCount({required bool hasSearchQuery}) =>
      (searchContent && hasSearchQuery ? 1 : 0) +
      (dateFilter != null && dateField != RecentDateField.modified ? 1 : 0);

  bool get isActive =>
      projectKeys.isNotEmpty ||
      dateFilter != null ||
      pinnedOnly ||
      searchContent;

  /// Whether any filter in this object actively narrows the current listing.
  bool hasEffectiveFilters({required bool hasSearchQuery}) =>
      projectKeys.isNotEmpty ||
      dateFilter != null ||
      pinnedOnly ||
      (searchContent && hasSearchQuery);

  /// Whether all device-global filter fields (everything except [projectKeys])
  /// are at their defaults.
  bool get hasOnlyDefaultCommonFields =>
      dateFilter == null &&
      dateField == RecentDateField.modified &&
      !pinnedOnly &&
      !searchContent;

  RecentSessionFilters copyWith({
    Set<String>? projectKeys,
    RecentDateFilter? dateFilter,
    bool clearDateFilter = false,
    RecentDateField? dateField,
    bool? pinnedOnly,
    bool? searchContent,
  }) {
    return RecentSessionFilters(
      projectKeys: projectKeys ?? this.projectKeys,
      dateFilter: clearDateFilter ? null : (dateFilter ?? this.dateFilter),
      dateField: dateField ?? this.dateField,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      searchContent: searchContent ?? this.searchContent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RecentSessionFilters &&
      setEquals(other.projectKeys, projectKeys) &&
      other.dateFilter == dateFilter &&
      other.dateField == dateField &&
      other.pinnedOnly == pinnedOnly &&
      other.searchContent == searchContent;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(projectKeys),
    dateFilter,
    dateField,
    pinnedOnly,
    searchContent,
  );
}
