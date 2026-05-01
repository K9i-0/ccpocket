import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/claude_session/claude_session_screen.dart';
import 'package:ccpocket/features/git/state/git_status_cubit.dart';
import 'package:ccpocket/features/git/state/git_view_cache_service.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';

import 'chat_screen/helpers/chat_test_helpers.dart';

class _TestGitStatusCubit extends GitStatusCubit {
  _TestGitStatusCubit({required super.bridge});

  void setEntry(GitStatusEntry entry) {
    emit(state.upsert(entry));
  }
}

void main() {
  testWidgets('session git button badge follows uncommitted status', (
    tester,
  ) async {
    final bridge = MockBridgeService();
    final gitStatusCubit = _TestGitStatusCubit(bridge: bridge);
    final gitViewCache = GitViewCacheService(
      bridge: bridge,
      gitStatusCubit: gitStatusCubit,
    );
    addTearDown(() async {
      await gitViewCache.dispose();
      await gitStatusCubit.close();
      bridge.dispose();
    });

    final screen = await buildTestClaudeSessionScreen(
      bridge: bridge,
      sessionId: 's1',
      projectPath: '/repo',
    );
    await tester.pumpWidget(
      RepositoryProvider<GitViewCacheService>.value(
        value: gitViewCache,
        child: BlocProvider<GitStatusCubit>.value(
          value: gitStatusCubit,
          child: screen,
        ),
      ),
    );
    await tester.pump();

    final buttonFinder = find.byKey(const ValueKey('appbar_view_changes'));
    expect(buttonFinder, findsOneWidget);
    Badge badge() => tester.widget<Badge>(
      find.descendant(of: buttonFinder, matching: find.byType(Badge)),
    );
    expect(badge().isLabelVisible, isFalse);

    gitStatusCubit.setEntry(
      const GitStatusEntry(
        sessionId: 's1',
        projectPath: '/repo',
        hasUncommittedChanges: true,
        unstagedCount: 1,
      ),
    );
    await tester.pump();

    expect(badge().isLabelVisible, isTrue);

    gitStatusCubit.setEntry(
      const GitStatusEntry(
        sessionId: 's1',
        projectPath: '/repo',
        hasUncommittedChanges: false,
      ),
    );
    await tester.pump();

    expect(badge().isLabelVisible, isFalse);
  });

  testWidgets('session git button shows subtle badge for remote status', (
    tester,
  ) async {
    final bridge = MockBridgeService();
    final gitStatusCubit = _TestGitStatusCubit(bridge: bridge);
    final gitViewCache = GitViewCacheService(
      bridge: bridge,
      gitStatusCubit: gitStatusCubit,
    );
    addTearDown(() async {
      await gitViewCache.dispose();
      await gitStatusCubit.close();
      bridge.dispose();
    });

    final screen = await buildTestClaudeSessionScreen(
      bridge: bridge,
      sessionId: 's1',
      projectPath: '/repo',
    );
    await tester.pumpWidget(
      RepositoryProvider<GitViewCacheService>.value(
        value: gitViewCache,
        child: BlocProvider<GitStatusCubit>.value(
          value: gitStatusCubit,
          child: screen,
        ),
      ),
    );
    await tester.pump();

    final screenContext = tester.element(find.byType(ClaudeSessionScreen));
    screenContext.read<SettingsCubit>().setShowRemoteGitStatusBadge(true);

    gitStatusCubit.setEntry(
      const GitStatusEntry(
        sessionId: 's1',
        projectPath: '/repo',
        hasRemoteChanges: true,
        commitsAhead: 1,
      ),
    );
    await tester.pump();

    final buttonFinder = find.byKey(const ValueKey('appbar_view_changes'));
    final badge = tester.widget<Badge>(
      find.descendant(of: buttonFinder, matching: find.byType(Badge)),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(badge.backgroundColor?.a, lessThan(1));
  });
}
