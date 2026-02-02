import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_providers.dart';
import 'package:ccpocket/services/bridge_service.dart';

void main() {
  group('bridgeServiceProvider', () {
    test('returns a BridgeService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bridge = container.read(bridgeServiceProvider);
      expect(bridge, isA<BridgeService>());
    });

    test('returns the same instance on repeated reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bridge1 = container.read(bridgeServiceProvider);
      final bridge2 = container.read(bridgeServiceProvider);
      expect(identical(bridge1, bridge2), isTrue);
    });
  });

  group('connectionStateProvider', () {
    test('initial state is AsyncLoading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(connectionStateProvider);
      expect(state, isA<AsyncLoading<BridgeConnectionState>>());
    });
  });

  group('sessionListProvider', () {
    test('initial state is AsyncLoading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(sessionListProvider);
      expect(state, isA<AsyncLoading<List<SessionInfo>>>());
    });
  });

  group('recentSessionsProvider', () {
    test('initial state is AsyncLoading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(recentSessionsProvider);
      expect(state, isA<AsyncLoading<List<RecentSession>>>());
    });
  });

  group('galleryProvider', () {
    test('initial state is AsyncLoading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(galleryProvider);
      expect(state, isA<AsyncLoading<List<GalleryImage>>>());
    });
  });

  group('fileListProvider', () {
    test('initial state is AsyncLoading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(fileListProvider);
      expect(state, isA<AsyncLoading<List<String>>>());
    });
  });
}
