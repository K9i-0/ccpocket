---
name: test-flutter
description: Flutter App のテスト実行・静的解析・フォーマット・テスト記述ガイド
disable-model-invocation: true
allowed-tools: Bash(flutter:*), Bash(dart:*), Read, Glob, Grep
---

# Flutter App テスト

## 実行手順

以下を順番に実行し、全てパスすることを確認する。

### 1. 静的解析

```bash
dart analyze apps/mobile
```

warning 以上は修正する。info レベルは必要に応じて対応。

### 2. フォーマット

```bash
dart format apps/mobile
```

### 3. ユニットテスト

```bash
cd apps/mobile && flutter test
```

特定ファイルのみ:
```bash
cd apps/mobile && flutter test test/<filename>_test.dart
```

## テスト記述規約

### ファイル配置・命名

- テストファイルは `apps/mobile/test/` に配置
- 命名: `<対象の概念>_test.dart`
  - ウィジェットテスト例: `approval_bar_test.dart`, `chat_input_bar_test.dart`
  - ロジックテスト例: `chat_message_handler_test.dart`

### import

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/...';
```

### テスト構造

```dart
void main() {
  group('対象クラスまたは機能', () {
    test('動作の説明', () {
      // ロジックテスト
      expect(actual, expected);
    });

    testWidgets('UI動作の説明', (tester) async {
      // ウィジェットテスト
      await tester.pumpWidget(MaterialApp(home: TargetWidget()));
      expect(find.text('expected'), findsOneWidget);
    });
  });
}
```

- `group` で対象機能ごとにグルーピング
- ロジックテストは `test()`、UI テストは `testWidgets()` を使い分ける
- `setUp()` でテスト前の共通初期化を行う

### テスト対象の方針

- **ウィジェットテスト**: 画面の表示・インタラクション検証
  - `pumpWidget` でウィジェット構築 → `find` で要素確認 → `tap`/`enterText` で操作
- **ロジックテスト**: サービス・ハンドラーの振る舞い検証
  - 純粋なDartクラスのメソッド呼び出しと結果確認
- WebSocket通信やBridge接続のモックが必要なテストは避ける (E2E領域)

### 既存テストファイル一覧

- `approval_bar_test.dart` — 承認バーUI
- `ask_user_question_widget_test.dart` — AskUserQuestion UI
- `chat_input_bar_test.dart` — チャット入力バーUI
- `chat_message_handler_test.dart` — メッセージハンドラーロジック
- `gallery_screen_test.dart` — ギャラリー画面
- `home_screen_test.dart` — ホーム画面
- `plan_mode_test.dart` — プランモードUI
- `session_card_test.dart` — セッションカードUI
- `slash_command_test.dart` — スラッシュコマンドUI
- `tool_result_bubble_test.dart` — ツール結果表示
- `tool_use_tile_test.dart` — ツール使用タイル表示
