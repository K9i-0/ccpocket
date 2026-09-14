---
name: test-flutter
description: Flutter App のテスト実行・静的解析・フォーマット・テスト記述ガイド
allowed-tools: Bash(flutter:*), Bash(dart:*), Read, Glob, Grep
---

# Flutter App テスト

## 実行手順

変更した挙動に対応するテストと静的検証を選ぶ。全体テストは、共通基盤・依存関係への変更や回帰懸念がある場合、または全体検証を依頼された場合に実行する。成功済みの検証を理由なく繰り返さない。以下はコマンドの選択肢。

### 1. 静的解析

```bash
dart analyze apps/mobile
```

今回の変更で生じた warning 以上は修正する。既存の無関係な問題は報告し、info は必要に応じて対応する。

**MCP代替:** `mcp__dart-mcp__analyze_files` でも実行可能だが、CLI推奨。

### 2. フォーマット

```bash
dart format <変更したDartファイル>
```

### 3. ユニットテスト

```bash
cd apps/mobile && flutter test
```

特定ファイルのみ:
```bash
cd apps/mobile && flutter test test/<filename>_test.dart
```

**MCP代替:** `mcp__dart-mcp__run_tests` でも実行可能だが、CLI推奨。
MCP版はDTD接続不要な操作のため、CLIの方が効率的。

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
