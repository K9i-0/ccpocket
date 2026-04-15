import 'dart:async';

import 'package:collection/collection.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';
import '../models/messages.dart';
import 'bridge_service.dart';

class InAppReviewService {
  InAppReviewService({
    required SharedPreferences prefs,
    InAppReviewGateway? gateway,
    Future<String> Function()? appVersionLoader,
    DateTime Function()? now,
  }) : _prefs = prefs,
       _gateway = gateway ?? InAppReviewGateway(),
       _appVersionLoader = appVersionLoader ?? _defaultAppVersionLoader,
       _now = now ?? DateTime.now;

  static const minInstallAge = Duration(days: 3);
  static const negativeSignalCooldown = Duration(hours: 24);
  static const promptCooldown = Duration(days: 90);

  static const minSuccessfulConnections = 3;
  static const minCreatedSessions = 3;
  static const minApprovalActions = 5;
  static const minUsageDays = 2;

  static const _keyFirstSeenAt = 'review.first_seen_at_ms';
  static const _keyLastNegativeAt = 'review.last_negative_at_ms';
  static const _keyLastPromptAt = 'review.last_prompt_at_ms';
  static const _keyLastPromptVersion = 'review.last_prompt_version';
  static const _keySuccessfulConnections = 'review.successful_connections';
  static const _keyCreatedSessions = 'review.created_sessions';
  static const _keyApprovalActions = 'review.approval_actions';
  static const _keyUsageDays = 'review.usage_days';
  static const _keyCompletedSessions = 'review.completed_sessions';

  static const _trackedMetrics = <ReviewMetric>[
    ReviewMetric(
      key: _keySuccessfulConnections,
      label: 'connections',
      target: minSuccessfulConnections,
    ),
    ReviewMetric(
      key: _keyCreatedSessions,
      label: 'sessions',
      target: minCreatedSessions,
    ),
    ReviewMetric(
      key: _keyApprovalActions,
      label: 'approval_actions',
      target: minApprovalActions,
    ),
    ReviewMetric(key: _keyUsageDays, label: 'usage_days', target: minUsageDays),
  ];

  final SharedPreferences _prefs;
  final InAppReviewGateway _gateway;
  final Future<String> Function() _appVersionLoader;
  final DateTime Function() _now;

  StreamSubscription<BridgeConnectionState>? _connectionSub;
  StreamSubscription<ServerMessage>? _messageSub;

  Future<void> initialize() async {
    if (!_prefs.containsKey(_keyFirstSeenAt)) {
      await _prefs.setInt(_keyFirstSeenAt, _now().millisecondsSinceEpoch);
    }
    logger.info('[review] progress ${buildProgressSummary()}');
  }

  Future<void> attachToBridge(BridgeService bridge) async {
    await initialize();
    _connectionSub ??= bridge.connectionStatus.listen(_onConnectionState);
    _messageSub ??= bridge.messages.listen(_onMessage);
    bridge.onOutgoingMessage = recordOutgoingMessage;
  }

  void dispose() {
    _connectionSub?.cancel();
    _messageSub?.cancel();
  }

  void recordOutgoingMessage(ClientMessage message) {
    switch (message.type) {
      case 'approve':
      case 'approve_always':
      case 'answer':
        unawaited(_increment(_keyApprovalActions));
        unawaited(_markUsageDay());
        return;
      case 'start':
      case 'input':
      case 'resume':
        unawaited(_markUsageDay());
        return;
      default:
        return;
    }
  }

  void _onConnectionState(BridgeConnectionState state) {
    if (state != BridgeConnectionState.connected) return;
    unawaited(_increment(_keySuccessfulConnections));
    unawaited(_markUsageDay());
  }

  void _onMessage(ServerMessage message) {
    switch (message) {
      case SystemMessage(:final subtype) when subtype == 'session_created':
        unawaited(_increment(_keyCreatedSessions));
        unawaited(_markUsageDay());
      case ResultMessage(:final subtype) when subtype == 'success':
        unawaited(_handleSuccessfulSessionCompletion());
      case ErrorMessage():
        unawaited(_markNegativeSignal());
      default:
        break;
    }
  }

  Future<void> _handleSuccessfulSessionCompletion() async {
    await _increment(_keyCompletedSessions);
    await _markUsageDay();
    await maybeRequestReview(trigger: 'session_success');
  }

  Future<void> maybeRequestReview({required String trigger}) async {
    final eligibility = await getEligibility();
    if (!eligibility.isEligible) {
      logger.info(
        '[review] skipped trigger=$trigger reason=${eligibility.reason} '
        'progress=${buildProgressSummary()}',
      );
      return;
    }

    final isAvailable = await _gateway.isAvailable();
    if (!isAvailable) {
      logger.info('[review] unavailable trigger=$trigger');
      return;
    }

    await _gateway.requestReview();
    final now = _now();
    final version = await _appVersionLoader();
    await _prefs.setInt(_keyLastPromptAt, now.millisecondsSinceEpoch);
    await _prefs.setString(_keyLastPromptVersion, version);
    logger.info(
      '[review] requested trigger=$trigger version=$version '
      'progress=${buildProgressSummary()}',
    );
  }

  Future<InAppReviewEligibility> getEligibility() async {
    final baseEligibility = await getSupportBannerEligibility();
    if (!baseEligibility.isEligible) {
      return baseEligibility;
    }

    final now = _now();
    final version = await _appVersionLoader();
    final lastPromptVersion = _prefs.getString(_keyLastPromptVersion);
    if (lastPromptVersion == version) {
      return const InAppReviewEligibility.ineligible('same_version');
    }

    final lastPromptAt = _dateFromMillis(_prefs.getInt(_keyLastPromptAt));
    if (lastPromptAt != null && now.difference(lastPromptAt) < promptCooldown) {
      return const InAppReviewEligibility.ineligible('cooldown');
    }

    return const InAppReviewEligibility.eligible();
  }

  Future<InAppReviewEligibility> getSupportBannerEligibility() async {
    final now = _now();
    final firstSeenAt = _dateFromMillis(_prefs.getInt(_keyFirstSeenAt));
    if (firstSeenAt == null || now.difference(firstSeenAt) < minInstallAge) {
      return const InAppReviewEligibility.ineligible('install_age');
    }

    if ((_prefs.getInt(_keySuccessfulConnections) ?? 0) <
        minSuccessfulConnections) {
      return const InAppReviewEligibility.ineligible('connections');
    }

    if ((_prefs.getInt(_keyCreatedSessions) ?? 0) < minCreatedSessions) {
      return const InAppReviewEligibility.ineligible('created_sessions');
    }

    if ((_prefs.getInt(_keyApprovalActions) ?? 0) < minApprovalActions) {
      return const InAppReviewEligibility.ineligible('approval_actions');
    }

    final usageDays = _prefs.getStringList(_keyUsageDays) ?? const [];
    if (usageDays.length < minUsageDays) {
      return const InAppReviewEligibility.ineligible('usage_days');
    }

    final lastNegativeAt = _dateFromMillis(_prefs.getInt(_keyLastNegativeAt));
    if (lastNegativeAt != null &&
        now.difference(lastNegativeAt) < negativeSignalCooldown) {
      return const InAppReviewEligibility.ineligible('recent_negative_signal');
    }

    return const InAppReviewEligibility.eligible();
  }

  Future<void> _markNegativeSignal() async {
    await _prefs.setInt(_keyLastNegativeAt, _now().millisecondsSinceEpoch);
    logger.warning(
      '[review] negative_signal progress=${buildProgressSummary()}',
    );
  }

  Future<void> _markUsageDay() async {
    final today = _isoDay(_now());
    final days = [...?_prefs.getStringList(_keyUsageDays)];
    if (days.contains(today)) return;
    days.add(today);
    days.sort();
    await _prefs.setStringList(_keyUsageDays, days);
    _logMetricProgress(_keyUsageDays);
  }

  Future<void> _increment(String key) async {
    final current = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, current + 1);
    _logMetricProgress(key);
  }

  String buildProgressSummary() {
    return _trackedMetrics
        .map(
          (metric) =>
              '${metric.label}:${_currentValue(metric.key)}/${metric.target}',
        )
        .join(' ');
  }

  void _logMetricProgress(String key) {
    final metric = _trackedMetrics.where((m) => m.key == key).firstOrNull;
    if (metric == null) return;
    logger.info(
      '[review] ${metric.label} '
      '${_currentValue(metric.key)}/${metric.target} '
      'progress=${buildProgressSummary()}',
    );
  }

  int _currentValue(String key) {
    if (key == _keyUsageDays) {
      return (_prefs.getStringList(_keyUsageDays) ?? const []).length;
    }
    return _prefs.getInt(key) ?? 0;
  }

  DateTime? _dateFromMillis(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);

  static Future<String> _defaultAppVersionLoader() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static String _isoDay(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class InAppReviewEligibility {
  const InAppReviewEligibility._({required this.isEligible, this.reason});

  const InAppReviewEligibility.eligible() : this._(isEligible: true);

  const InAppReviewEligibility.ineligible(String reason)
    : this._(isEligible: false, reason: reason);

  final bool isEligible;
  final String? reason;
}

class InAppReviewGateway {
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  Future<void> requestReview() => InAppReview.instance.requestReview();
}

class ReviewMetric {
  const ReviewMetric({
    required this.key,
    required this.label,
    required this.target,
  });

  final String key;
  final String label;
  final int target;
}
