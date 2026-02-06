// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatSessionNotifierHash() =>
    r'f3444996d71523be9743bbc432dc37cbc1161a6c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ChatSessionNotifier
    extends BuildlessAutoDisposeNotifier<ChatSessionState> {
  late final String sessionId;

  ChatSessionState build(String sessionId);
}

/// Manages the state of a single chat session.
///
/// Subscribes to [BridgeService.messagesForSession] and delegates message
/// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
/// applied to the immutable [ChatSessionState].
///
/// Copied from [ChatSessionNotifier].
@ProviderFor(ChatSessionNotifier)
const chatSessionNotifierProvider = ChatSessionNotifierFamily();

/// Manages the state of a single chat session.
///
/// Subscribes to [BridgeService.messagesForSession] and delegates message
/// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
/// applied to the immutable [ChatSessionState].
///
/// Copied from [ChatSessionNotifier].
class ChatSessionNotifierFamily extends Family<ChatSessionState> {
  /// Manages the state of a single chat session.
  ///
  /// Subscribes to [BridgeService.messagesForSession] and delegates message
  /// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
  /// applied to the immutable [ChatSessionState].
  ///
  /// Copied from [ChatSessionNotifier].
  const ChatSessionNotifierFamily();

  /// Manages the state of a single chat session.
  ///
  /// Subscribes to [BridgeService.messagesForSession] and delegates message
  /// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
  /// applied to the immutable [ChatSessionState].
  ///
  /// Copied from [ChatSessionNotifier].
  ChatSessionNotifierProvider call(String sessionId) {
    return ChatSessionNotifierProvider(sessionId);
  }

  @override
  ChatSessionNotifierProvider getProviderOverride(
    covariant ChatSessionNotifierProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatSessionNotifierProvider';
}

/// Manages the state of a single chat session.
///
/// Subscribes to [BridgeService.messagesForSession] and delegates message
/// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
/// applied to the immutable [ChatSessionState].
///
/// Copied from [ChatSessionNotifier].
class ChatSessionNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<ChatSessionNotifier, ChatSessionState> {
  /// Manages the state of a single chat session.
  ///
  /// Subscribes to [BridgeService.messagesForSession] and delegates message
  /// processing to [ChatMessageHandler]. The resulting [ChatStateUpdate] is
  /// applied to the immutable [ChatSessionState].
  ///
  /// Copied from [ChatSessionNotifier].
  ChatSessionNotifierProvider(String sessionId)
    : this._internal(
        () => ChatSessionNotifier()..sessionId = sessionId,
        from: chatSessionNotifierProvider,
        name: r'chatSessionNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatSessionNotifierHash,
        dependencies: ChatSessionNotifierFamily._dependencies,
        allTransitiveDependencies:
            ChatSessionNotifierFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  ChatSessionNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  ChatSessionState runNotifierBuild(covariant ChatSessionNotifier notifier) {
    return notifier.build(sessionId);
  }

  @override
  Override overrideWith(ChatSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatSessionNotifierProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatSessionNotifier, ChatSessionState>
  createElement() {
    return _ChatSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatSessionNotifierProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatSessionNotifierRef
    on AutoDisposeNotifierProviderRef<ChatSessionState> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _ChatSessionNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          ChatSessionNotifier,
          ChatSessionState
        >
    with ChatSessionNotifierRef {
  _ChatSessionNotifierProviderElement(super.provider);

  @override
  String get sessionId => (origin as ChatSessionNotifierProvider).sessionId;
}

String _$streamingStateNotifierHash() =>
    r'06126e7be5303cf482ed4a61695de7282ba60a91';

abstract class _$StreamingStateNotifier
    extends BuildlessAutoDisposeNotifier<StreamingState> {
  late final String sessionId;

  StreamingState build(String sessionId);
}

/// Manages the high-frequency streaming state for a chat session.
///
/// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
/// entire message list on every streaming delta.
///
/// Copied from [StreamingStateNotifier].
@ProviderFor(StreamingStateNotifier)
const streamingStateNotifierProvider = StreamingStateNotifierFamily();

/// Manages the high-frequency streaming state for a chat session.
///
/// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
/// entire message list on every streaming delta.
///
/// Copied from [StreamingStateNotifier].
class StreamingStateNotifierFamily extends Family<StreamingState> {
  /// Manages the high-frequency streaming state for a chat session.
  ///
  /// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
  /// entire message list on every streaming delta.
  ///
  /// Copied from [StreamingStateNotifier].
  const StreamingStateNotifierFamily();

  /// Manages the high-frequency streaming state for a chat session.
  ///
  /// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
  /// entire message list on every streaming delta.
  ///
  /// Copied from [StreamingStateNotifier].
  StreamingStateNotifierProvider call(String sessionId) {
    return StreamingStateNotifierProvider(sessionId);
  }

  @override
  StreamingStateNotifierProvider getProviderOverride(
    covariant StreamingStateNotifierProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'streamingStateNotifierProvider';
}

/// Manages the high-frequency streaming state for a chat session.
///
/// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
/// entire message list on every streaming delta.
///
/// Copied from [StreamingStateNotifier].
class StreamingStateNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          StreamingStateNotifier,
          StreamingState
        > {
  /// Manages the high-frequency streaming state for a chat session.
  ///
  /// Kept separate from [ChatSessionNotifier] to avoid rebuilding the
  /// entire message list on every streaming delta.
  ///
  /// Copied from [StreamingStateNotifier].
  StreamingStateNotifierProvider(String sessionId)
    : this._internal(
        () => StreamingStateNotifier()..sessionId = sessionId,
        from: streamingStateNotifierProvider,
        name: r'streamingStateNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$streamingStateNotifierHash,
        dependencies: StreamingStateNotifierFamily._dependencies,
        allTransitiveDependencies:
            StreamingStateNotifierFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  StreamingStateNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  StreamingState runNotifierBuild(covariant StreamingStateNotifier notifier) {
    return notifier.build(sessionId);
  }

  @override
  Override overrideWith(StreamingStateNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: StreamingStateNotifierProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<StreamingStateNotifier, StreamingState>
  createElement() {
    return _StreamingStateNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StreamingStateNotifierProvider &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StreamingStateNotifierRef
    on AutoDisposeNotifierProviderRef<StreamingState> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _StreamingStateNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          StreamingStateNotifier,
          StreamingState
        >
    with StreamingStateNotifierRef {
  _StreamingStateNotifierProviderElement(super.provider);

  @override
  String get sessionId => (origin as StreamingStateNotifierProvider).sessionId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
