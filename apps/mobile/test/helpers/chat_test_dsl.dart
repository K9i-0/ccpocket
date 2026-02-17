/// Fluent DSL for writing chat screen widget tests.
///
/// Usage:
/// ```dart
/// await ChatTestScenario($, bridge)
///   .emit([
///     msg.assistant('a1', 'Running command'),
///     msg.bashPermission('tool-1'),
///     msg.status(ProcessStatus.waitingApproval),
///   ])
///   .tap(#approve_button)
///   .expectSent('approve', (m) => m['id'] == 'tool-1')
///   .emit([
///     msg.toolResult('tool-1', 'output'),
///     msg.status(ProcessStatus.idle),
///   ])
///   .expectNoWidget(ApprovalBar)
///   .run();
/// ```
library;

import 'package:ccpocket/models/messages.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import '../chat_screen/helpers/chat_test_helpers.dart';

// ---------------------------------------------------------------------------
// DSL step types
// ---------------------------------------------------------------------------

sealed class _Step {}

class _EmitStep extends _Step {
  _EmitStep(this.messages, {this.sessionId});
  final List<ServerMessage> messages;
  final String? sessionId;
}

class _TapKeyStep extends _Step {
  _TapKeyStep(this.key);
  final Key key;
}

class _TapTextStep extends _Step {
  _TapTextStep(this.text);
  final String text;
}

class _EnterTextStep extends _Step {
  _EnterTextStep(this.key, this.text);
  final Key key;
  final String text;
}

class _PumpStep extends _Step {
  _PumpStep({this.count = 5});
  final int count;
}

class _ExpectSentStep extends _Step {
  _ExpectSentStep(this.type, this.predicate);
  final String type;
  final bool Function(Map<String, dynamic>)? predicate;
}

class _ExpectNotSentStep extends _Step {
  _ExpectNotSentStep(this.type);
  final String type;
}

class _ExpectWidgetStep extends _Step {
  _ExpectWidgetStep(this.widgetType);
  final Type widgetType;
}

class _ExpectNoWidgetStep extends _Step {
  _ExpectNoWidgetStep(this.widgetType);
  final Type widgetType;
}

class _ExpectTextStep extends _Step {
  _ExpectTextStep(this.text);
  final String text;
}

class _ExpectNoTextStep extends _Step {
  _ExpectNoTextStep(this.text);
  final String text;
}

class _CustomStep extends _Step {
  _CustomStep(this.action);
  final Future<void> Function() action;
}

// ---------------------------------------------------------------------------
// ChatTestScenario — fluent builder + runner
// ---------------------------------------------------------------------------

class ChatTestScenario {
  ChatTestScenario(this.$, this.bridge);

  final PatrolTester $;
  final MockBridgeService bridge;
  final List<_Step> _steps = [];

  // -- Builder methods -------------------------------------------------------

  /// Emit a batch of [ServerMessage]s and pump the tester.
  ChatTestScenario emit(List<ServerMessage> messages, {String? sessionId}) {
    _steps.add(_EmitStep(messages, sessionId: sessionId));
    return this;
  }

  /// Tap a widget by its [ValueKey].
  ///
  /// You can pass a [Symbol] (e.g. `#approve_button`) or a [ValueKey].
  ChatTestScenario tap(dynamic key) {
    if (key is Symbol) {
      final name = key
          .toString()
          .replaceFirst('Symbol("', '')
          .replaceFirst('")', '');
      _steps.add(_TapKeyStep(ValueKey(name)));
    } else if (key is Key) {
      _steps.add(_TapKeyStep(key));
    } else {
      throw ArgumentError('tap() expects a Symbol or Key, got: $key');
    }
    return this;
  }

  /// Tap a widget by its visible text.
  ChatTestScenario tapText(String text) {
    _steps.add(_TapTextStep(text));
    return this;
  }

  /// Enter text into a text field identified by key.
  ChatTestScenario enterText(dynamic key, String text) {
    Key k;
    if (key is Symbol) {
      final name = key
          .toString()
          .replaceFirst('Symbol("', '')
          .replaceFirst('")', '');
      k = ValueKey(name);
    } else if (key is Key) {
      k = key;
    } else {
      throw ArgumentError('enterText() expects a Symbol or Key, got: $key');
    }
    _steps.add(_EnterTextStep(k, text));
    return this;
  }

  /// Pump frames without emitting messages.
  ChatTestScenario pump({int count = 5}) {
    _steps.add(_PumpStep(count: count));
    return this;
  }

  /// Assert that a [ClientMessage] of the given [type] was sent.
  /// Optionally pass a [predicate] to check message content.
  ChatTestScenario expectSent(
    String type, [
    bool Function(Map<String, dynamic>)? predicate,
  ]) {
    _steps.add(_ExpectSentStep(type, predicate));
    return this;
  }

  /// Assert that no [ClientMessage] of the given [type] was sent.
  ChatTestScenario expectNotSent(String type) {
    _steps.add(_ExpectNotSentStep(type));
    return this;
  }

  /// Assert that a widget of the given [Type] exists.
  ChatTestScenario expectWidget(Type widgetType) {
    _steps.add(_ExpectWidgetStep(widgetType));
    return this;
  }

  /// Assert that no widget of the given [Type] exists.
  ChatTestScenario expectNoWidget(Type widgetType) {
    _steps.add(_ExpectNoWidgetStep(widgetType));
    return this;
  }

  /// Assert that the given text is visible.
  ChatTestScenario expectText(String text) {
    _steps.add(_ExpectTextStep(text));
    return this;
  }

  /// Assert that the given text is NOT visible.
  ChatTestScenario expectNoText(String text) {
    _steps.add(_ExpectNoTextStep(text));
    return this;
  }

  /// Run a custom async action. Use for complex assertions or interactions.
  ChatTestScenario custom(Future<void> Function() action) {
    _steps.add(_CustomStep(action));
    return this;
  }

  // -- Runner ----------------------------------------------------------------

  /// Execute all steps sequentially.
  ///
  /// Call this after building the screen:
  /// ```dart
  /// await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
  /// await pumpN($.tester);
  /// await ChatTestScenario($, bridge)
  ///   .emit([...])
  ///   .tap(#approve_button)
  ///   .run();
  /// ```
  Future<void> run() async {
    for (final step in _steps) {
      switch (step) {
        case _EmitStep():
          await emitAndPump(
            $.tester,
            bridge,
            step.messages,
            sessionId: step.sessionId,
          );
          await pumpN($.tester);

        case _TapKeyStep():
          await $.tester.tap(find.byKey(step.key));
          await pumpN($.tester);

        case _TapTextStep():
          await $.tester.tap(find.text(step.text));
          await pumpN($.tester);

        case _EnterTextStep():
          await $.tester.enterText(find.byKey(step.key), step.text);
          await pumpN($.tester);

        case _PumpStep():
          await pumpN($.tester, count: step.count);

        case _ExpectSentStep():
          final msgs = findAllSentMessages(bridge, step.type);
          expect(
            msgs,
            isNotEmpty,
            reason: 'Expected at least one sent message of type "${step.type}"',
          );
          if (step.predicate != null) {
            final match = msgs.any(step.predicate!);
            expect(
              match,
              isTrue,
              reason: 'No sent "${step.type}" message matched predicate',
            );
          }

        case _ExpectNotSentStep():
          final msg = findSentMessage(bridge, step.type);
          expect(
            msg,
            isNull,
            reason: 'Expected no sent message of type "${step.type}"',
          );

        case _ExpectWidgetStep():
          expect(
            find.byType(step.widgetType),
            findsWidgets,
            reason: 'Expected widget of type ${step.widgetType} to exist',
          );

        case _ExpectNoWidgetStep():
          expect(
            find.byType(step.widgetType),
            findsNothing,
            reason: 'Expected no widget of type ${step.widgetType}',
          );

        case _ExpectTextStep():
          expect(
            find.text(step.text),
            findsWidgets,
            reason: 'Expected text "${step.text}" to be visible',
          );

        case _ExpectNoTextStep():
          expect(
            find.text(step.text),
            findsNothing,
            reason: 'Expected text "${step.text}" to NOT be visible',
          );

        case _CustomStep():
          await step.action();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Convenience message factories for DSL use
// ---------------------------------------------------------------------------

/// Short-hand message factories for use with [ChatTestScenario.emit].
///
/// Usage:
/// ```dart
/// import 'chat_test_dsl.dart';
///
/// .emit([
///   msg.assistant('a1', 'Hello'),
///   msg.bashPermission('tool-1'),
///   msg.waitingApproval,
/// ])
/// ```
class Msg {
  const Msg._();

  StatusMessage status(ProcessStatus s) => StatusMessage(status: s);

  StatusMessage get running =>
      const StatusMessage(status: ProcessStatus.running);
  StatusMessage get idle => const StatusMessage(status: ProcessStatus.idle);
  StatusMessage get waitingApproval =>
      const StatusMessage(status: ProcessStatus.waitingApproval);

  AssistantServerMessage assistant(
    String id,
    String text, {
    List<ToolUseContent> toolUses = const [],
  }) => makeAssistantMessage(id, text, toolUses: toolUses);

  PermissionRequestMessage bashPermission(String toolUseId) =>
      makeBashPermission(toolUseId);

  PermissionRequestMessage permission(
    String toolUseId,
    String toolName,
    Map<String, dynamic> input,
  ) => PermissionRequestMessage(
    toolUseId: toolUseId,
    toolName: toolName,
    input: input,
  );

  ToolResultMessage toolResult(
    String toolUseId,
    String content, {
    String? toolName,
  }) => makeToolResult(toolUseId, content, toolName: toolName);

  AssistantServerMessage enterPlan(String id, String toolUseId) =>
      makeEnterPlanMessage(id, toolUseId);

  AssistantServerMessage exitPlan(
    String id,
    String toolUseId,
    String planText,
  ) => makePlanExitMessage(id, toolUseId, planText);

  AssistantServerMessage askQuestion(
    String toolUseId,
    List<Map<String, dynamic>> questions,
  ) => makeAskQuestionMessage(toolUseId, questions);

  HistoryMessage historyWithApproval(String toolUseId) =>
      makeHistoryWithPendingApproval(toolUseId);

  HistoryMessage historyWithPlanApproval(String toolUseId) =>
      makeHistoryWithPlanApproval(toolUseId);

  ErrorMessage error(String message) => ErrorMessage(message: message);

  StreamDeltaMessage streamDelta(String text) => StreamDeltaMessage(text: text);

  ResultMessage result({
    String subtype = 'success',
    double? cost,
    double? duration,
  }) => ResultMessage(subtype: subtype, cost: cost, duration: duration);
}

/// Global instance of [Msg] for convenient access in tests.
const msg = Msg._();
