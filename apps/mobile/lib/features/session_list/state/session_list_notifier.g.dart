// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionListNotifierHash() =>
    r'9e37f09c422a2b50ab40be41f09c7d26b3bbec50';

/// Manages session list state: sessions, filters, pagination, and
/// accumulated project paths.
///
/// Subscribes to [BridgeService.recentSessionsStream] and
/// [BridgeService.projectHistoryStream] to accumulate project paths
/// and track session data.
///
/// Copied from [SessionListNotifier].
@ProviderFor(SessionListNotifier)
final sessionListNotifierProvider =
    AutoDisposeNotifierProvider<SessionListNotifier, SessionListState>.internal(
      SessionListNotifier.new,
      name: r'sessionListNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionListNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionListNotifier = AutoDisposeNotifier<SessionListState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
