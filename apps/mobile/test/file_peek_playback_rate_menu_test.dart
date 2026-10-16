import 'dart:async';

import 'package:ccpocket/features/file_peek/widgets/file_peek_media_controls.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

class _RateStreams extends Fake implements PlayerStream {
  final controller = StreamController<double>.broadcast();
  @override
  Stream<double> get rate => controller.stream;
}

class _RatePlayer extends Fake implements Player {
  @override
  final _RateStreams stream = _RateStreams();
  @override
  PlayerState state = const PlayerState();
  final selections = <double>[];

  @override
  Future<void> setRate(double rate) async {
    selections.add(rate);
    state = state.copyWith(rate: rate);
    stream.controller.add(rate);
  }
}

void main() {
  for (final hideControls in [false, true]) {
    testWidgets('selects speed with controls hidden=$hideControls', (
      tester,
    ) async {
      final player = _RatePlayer();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      addTearDown(player.stream.controller.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) => show
                  ? FilePeekPlaybackRateMenu(
                      player: player,
                      onDarkSurface: true,
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('file_peek_video_speed_button')),
      );
      await tester.pumpAndSettle();
      if (hideControls) {
        visible.value = false;
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(player.selections, [1.5]);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text('1.5×'), findsOneWidget);
      expect(find.text('1×'), findsNothing);
    });
  }
}
