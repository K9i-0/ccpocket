// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diff_view_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$diffViewNotifierHash() => r'6dcd079253d74e8a053f5540e4a6d749c3c54a76';

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

abstract class _$DiffViewNotifier
    extends BuildlessAutoDisposeNotifier<DiffViewState> {
  late final String? initialDiff;
  late final String? projectPath;

  DiffViewState build({String? initialDiff, String? projectPath});
}

/// Manages diff viewer state: file parsing, collapse/expand, and filtering.
///
/// Two modes controlled by build parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
///
/// Copied from [DiffViewNotifier].
@ProviderFor(DiffViewNotifier)
const diffViewNotifierProvider = DiffViewNotifierFamily();

/// Manages diff viewer state: file parsing, collapse/expand, and filtering.
///
/// Two modes controlled by build parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
///
/// Copied from [DiffViewNotifier].
class DiffViewNotifierFamily extends Family<DiffViewState> {
  /// Manages diff viewer state: file parsing, collapse/expand, and filtering.
  ///
  /// Two modes controlled by build parameters:
  /// - [initialDiff] provided → parse immediately (individual tool result).
  /// - [projectPath] provided → request `git diff` from Bridge and subscribe.
  ///
  /// Copied from [DiffViewNotifier].
  const DiffViewNotifierFamily();

  /// Manages diff viewer state: file parsing, collapse/expand, and filtering.
  ///
  /// Two modes controlled by build parameters:
  /// - [initialDiff] provided → parse immediately (individual tool result).
  /// - [projectPath] provided → request `git diff` from Bridge and subscribe.
  ///
  /// Copied from [DiffViewNotifier].
  DiffViewNotifierProvider call({String? initialDiff, String? projectPath}) {
    return DiffViewNotifierProvider(
      initialDiff: initialDiff,
      projectPath: projectPath,
    );
  }

  @override
  DiffViewNotifierProvider getProviderOverride(
    covariant DiffViewNotifierProvider provider,
  ) {
    return call(
      initialDiff: provider.initialDiff,
      projectPath: provider.projectPath,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'diffViewNotifierProvider';
}

/// Manages diff viewer state: file parsing, collapse/expand, and filtering.
///
/// Two modes controlled by build parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
///
/// Copied from [DiffViewNotifier].
class DiffViewNotifierProvider
    extends AutoDisposeNotifierProviderImpl<DiffViewNotifier, DiffViewState> {
  /// Manages diff viewer state: file parsing, collapse/expand, and filtering.
  ///
  /// Two modes controlled by build parameters:
  /// - [initialDiff] provided → parse immediately (individual tool result).
  /// - [projectPath] provided → request `git diff` from Bridge and subscribe.
  ///
  /// Copied from [DiffViewNotifier].
  DiffViewNotifierProvider({String? initialDiff, String? projectPath})
    : this._internal(
        () => DiffViewNotifier()
          ..initialDiff = initialDiff
          ..projectPath = projectPath,
        from: diffViewNotifierProvider,
        name: r'diffViewNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$diffViewNotifierHash,
        dependencies: DiffViewNotifierFamily._dependencies,
        allTransitiveDependencies:
            DiffViewNotifierFamily._allTransitiveDependencies,
        initialDiff: initialDiff,
        projectPath: projectPath,
      );

  DiffViewNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialDiff,
    required this.projectPath,
  }) : super.internal();

  final String? initialDiff;
  final String? projectPath;

  @override
  DiffViewState runNotifierBuild(covariant DiffViewNotifier notifier) {
    return notifier.build(initialDiff: initialDiff, projectPath: projectPath);
  }

  @override
  Override overrideWith(DiffViewNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: DiffViewNotifierProvider._internal(
        () => create()
          ..initialDiff = initialDiff
          ..projectPath = projectPath,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialDiff: initialDiff,
        projectPath: projectPath,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<DiffViewNotifier, DiffViewState>
  createElement() {
    return _DiffViewNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DiffViewNotifierProvider &&
        other.initialDiff == initialDiff &&
        other.projectPath == projectPath;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialDiff.hashCode);
    hash = _SystemHash.combine(hash, projectPath.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DiffViewNotifierRef on AutoDisposeNotifierProviderRef<DiffViewState> {
  /// The parameter `initialDiff` of this provider.
  String? get initialDiff;

  /// The parameter `projectPath` of this provider.
  String? get projectPath;
}

class _DiffViewNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<DiffViewNotifier, DiffViewState>
    with DiffViewNotifierRef {
  _DiffViewNotifierProviderElement(super.provider);

  @override
  String? get initialDiff => (origin as DiffViewNotifierProvider).initialDiff;
  @override
  String? get projectPath => (origin as DiffViewNotifierProvider).projectPath;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
