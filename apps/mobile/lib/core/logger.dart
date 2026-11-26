import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Severity levels supported by [AppLogger].
enum AppLogLevel {
  debug,
  info,
  warning,
  error,
  critical;

  /// Short uppercase tag used in console output and log badges.
  String get label => switch (this) {
    AppLogLevel.debug => 'DEBUG',
    AppLogLevel.info => 'INFO',
    AppLogLevel.warning => 'WARN',
    AppLogLevel.error => 'ERROR',
    AppLogLevel.critical => 'CRITICAL',
  };

  /// Human-readable name for UI filters and labels.
  String get displayName => switch (this) {
    AppLogLevel.debug => 'Debug',
    AppLogLevel.info => 'Info',
    AppLogLevel.warning => 'Warning',
    AppLogLevel.error => 'Error',
    AppLogLevel.critical => 'Critical',
  };
}

/// Immutable record stored in [AppLogger]'s ring buffer.
@immutable
class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Monotonically increasing identifier unique within an [AppLogger] instance.
  final int id;

  /// Time at which this log entry was recorded.
  final DateTime timestamp;

  /// Severity level of the entry.
  final AppLogLevel level;

  /// Primary human-readable message.
  final String message;

  /// Optional associated error or exception object.
  final Object? error;

  /// Optional associated stack trace.
  final StackTrace? stackTrace;

  /// Compact wall-clock time formatted as `HH:mm:ss.SSS`.
  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Full ISO-8601 timestamp for exports.
  String get formattedIsoTimestamp => timestamp.toIso8601String();

  /// Formats this entry as multi-line plain text for copying or sharing.
  String format({bool includeStackTrace = true}) {
    final buffer = StringBuffer(
      '[$formattedIsoTimestamp] [${level.label}] $message',
    );
    if (error != null) {
      buffer.write('\nError: $error');
    }
    if (includeStackTrace && stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  /// Returns whether this entry matches a case-insensitive keyword [query].
  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (message.toLowerCase().contains(normalized)) return true;
    if (level.label.toLowerCase().contains(normalized)) return true;
    if (level.displayName.toLowerCase().contains(normalized)) return true;
    if (error != null && error.toString().toLowerCase().contains(normalized)) {
      return true;
    }
    if (stackTrace != null &&
        stackTrace.toString().toLowerCase().contains(normalized)) {
      return true;
    }
    return false;
  }
}

/// Lightweight in-memory ring-buffer logger with [ChangeNotifier] updates
/// for live UI inspection and debug/profile console output.
class AppLogger extends ChangeNotifier {
  AppLogger({
    this.maxEntries = 1000,
    this.useConsoleLogs = true,
    this.consoleOutput,
    DateTime Function()? clock,
  }) : assert(maxEntries > 0, 'maxEntries must be positive'),
       _clock = clock ?? DateTime.now;

  /// Maximum number of log entries retained before oldest entries are evicted.
  final int maxEntries;

  /// Whether logs should also be printed to the console in debug/profile mode.
  final bool useConsoleLogs;

  /// Optional custom console sink used instead of [debugPrint].
  final void Function(String line)? consoleOutput;

  final DateTime Function() _clock;
  final ListQueue<AppLogEntry> _buffer = ListQueue<AppLogEntry>();
  int _nextId = 0;

  /// Chronological snapshot of retained log entries (oldest first).
  List<AppLogEntry> get entries => List<AppLogEntry>.unmodifiable(_buffer);

  /// Alias for [entries] retained for API compatibility.
  List<AppLogEntry> get history => entries;

  /// Number of entries currently stored in the ring buffer.
  int get length => _buffer.length;

  /// Whether the ring buffer currently holds no entries.
  bool get isEmpty => _buffer.isEmpty;

  /// Records a debug-level message.
  void debug(Object? msg, [Object? exception, StackTrace? stackTrace]) {
    _record(AppLogLevel.debug, msg, exception, stackTrace);
  }

  /// Records an info-level message.
  void info(Object? msg, [Object? exception, StackTrace? stackTrace]) {
    _record(AppLogLevel.info, msg, exception, stackTrace);
  }

  /// Records a warning-level message.
  void warning(Object? msg, [Object? exception, StackTrace? stackTrace]) {
    _record(AppLogLevel.warning, msg, exception, stackTrace);
  }

  /// Records an error-level message.
  void error(Object? msg, [Object? exception, StackTrace? stackTrace]) {
    _record(AppLogLevel.error, msg, exception, stackTrace);
  }

  /// Records a critical-level message.
  void critical(Object? msg, [Object? exception, StackTrace? stackTrace]) {
    _record(AppLogLevel.critical, msg, exception, stackTrace);
  }

  /// Records a handled [exception] at [AppLogLevel.error].
  void handle(Object exception, [StackTrace? stackTrace, Object? msg]) {
    _record(AppLogLevel.error, msg ?? exception, exception, stackTrace);
  }

  /// Records a message with an explicit [level] (defaults to [AppLogLevel.info]).
  void log(
    Object? msg, {
    AppLogLevel level = AppLogLevel.info,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    _record(level, msg, exception, stackTrace);
  }

  /// Removes all buffered entries and notifies listeners if any were removed.
  void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    notifyListeners();
  }

  /// Exports [entries] (or all buffered entries if omitted) as newline-delimited
  /// plain text suitable for clipboard copy or sharing.
  String exportText({Iterable<AppLogEntry>? entries}) {
    final target = entries ?? _buffer;
    return target.map((entry) => entry.format()).join('\n');
  }

  void _record(
    AppLogLevel level,
    Object? msg,
    Object? exception,
    StackTrace? stackTrace,
  ) {
    final entry = AppLogEntry(
      id: ++_nextId,
      timestamp: _clock(),
      level: level,
      message: msg?.toString() ?? 'null',
      error: exception,
      stackTrace: stackTrace,
    );
    while (_buffer.length >= maxEntries) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);
    _emitConsole(entry);
    notifyListeners();
  }

  void _emitConsole(AppLogEntry entry) {
    if (!useConsoleLogs) return;
    final sink = consoleOutput;
    if (sink == null && kReleaseMode) return;

    final buffer = StringBuffer(
      '[${entry.formattedTimestamp}] [${entry.level.label}] ${entry.message}',
    );
    if (entry.error != null) {
      buffer.write('\nError: ${entry.error}');
    }
    if (entry.stackTrace != null) {
      buffer.write('\n${entry.stackTrace}');
    }

    if (sink != null) {
      sink(buffer.toString());
    } else {
      debugPrint(buffer.toString());
    }
  }
}

/// Global [AppLogger] instance shared across the entire app.
///
/// Usage:
/// ```dart
/// import 'package:ccpocket/core/logger.dart';
/// logger.info('message');
/// logger.error('failed', exception, stackTrace);
/// ```
final logger = AppLogger();
