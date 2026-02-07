---
name: flutter-ui-design
description: Flutter UI実装のアーキテクチャ規約・コンポーネント分割・状態管理ガイド（Bloc/Cubit版）
disable-model-invocation: true
allowed-tools: Bash(flutter:*), Bash(dart:*), Read, Write, Edit, Glob, Grep
---

# Flutter UI 実装規約

## アーキテクチャ概要

SSOT (Single Source of Truth) + UDF (Unidirectional Data Flow) に基づく設計。

### データフローパターン

- **Path A (Query)**: Cubit/Bloc → Widget (BlocBuilder/BlocListener)
  - サーバー状態、永続化データ、共有状態
  - BlocProvider を通じて単方向に流れる
- **Path B (Command)**: Widget → Cubit method → State emit
  - ユーザーアクション、API呼び出し
  - Cubit のメソッド経由で状態を変更
- **Path C (Local)**: StatefulWidget / useState
  - テキスト入力、スクロール位置、展開状態等の一時的UI状態

## Widget 分割ルール

### 禁止パターン

```dart
// NG: プライベートメソッドでのWidget分割
class MyScreen extends StatefulWidget {
  Widget _buildHeader() { ... }
  Widget _buildBody() { ... }
  Widget _buildFooter() { ... }
}
```

### 推奨パターン

```dart
// OK: 独立したWidgetクラスに分割
class MyScreenHeader extends StatelessWidget { ... }
class MyScreenBody extends StatelessWidget { ... }
class MyScreenFooter extends StatelessWidget { ... }
```

### 分割の判断基準

- 20行以上のbuildメソッド内ブロック → 独立Widgetに
- 独自のCubitを持つ → 独立Widget + BlocProvider
- BlocBuilder を含む → 独立Widget
- 表示のみ → StatelessWidget

## 状態管理

### Cubit パターン

```dart
class ChatSessionCubit extends Cubit<ChatSessionState> {
  ChatSessionCubit() : super(const ChatSessionState());

  void sendMessage(String text) {
    // Command (Path B)
    emit(state.copyWith(/* ... */));
  }
}
```

### BridgeCubit パターン（Stream購読）

```dart
class ConnectionCubit extends BridgeCubit<BridgeConnectionState> {
  ConnectionCubit(super.initialState, super.stream);
}
```

### Freezed State

```dart
@freezed
class ChatSessionState with _$ChatSessionState {
  const factory ChatSessionState({
    @Default([]) List<ChatEntry> entries,
    @Default(SessionStatus.idle) SessionStatus status,
  }) = _ChatSessionState;
}
```

- 全ての状態クラスは Freezed で定義
- sealed union で排他的状態を表現
- `@Default` で初期値を明示

## ファイル構成

### feature-first 構造

```
lib/features/<feature>/
├── <feature>_screen.dart           # 画面Widget
├── state/
│   ├── <feature>_state.dart        # Freezed state classes
│   ├── <feature>_cubit.dart        # Cubit
│   └── <feature>_state.freezed.dart # 生成ファイル
└── widgets/
    ├── <component_a>.dart          # 独立Widget
    └── <component_b>.dart
```

### 命名規約

| 種別 | 命名 | 例 |
|------|------|-----|
| 画面 | `*_screen.dart` | `chat_screen.dart` |
| 状態 | `*_state.dart` | `chat_session_state.dart` |
| Cubit | `*_cubit.dart` | `chat_session_cubit.dart` |
| Widget | 機能を表す名前 | `chat_app_bar.dart` |

## ValueKey 命名規約（MCP自動テスト対応）

UI要素にはValueKeyを付与し、Marionette MCPでの自動テストを可能にする。

### 命名パターン

```
{要素の機能}_{要素タイプ}
```

### 例

```dart
ElevatedButton(
  key: const ValueKey('approve_button'),
  onPressed: _approve,
  child: const Text('Approve'),
)

TextField(
  key: const ValueKey('message_input'),
  controller: _controller,
)
```

### 要素タイプ一覧

| タイプ | 用途 |
|--------|------|
| `_button` | ボタン |
| `_field` | テキスト入力 |
| `_input` | テキスト入力（短い） |
| `_list` | リスト |
| `_fab` | FloatingActionButton |
| `_toggle` | トグル |
| `_chip` | チップ |
| `_badge` | バッジ |
| `_indicator` | インジケーター |

## build_runner

状態クラスの変更後は必ず実行:

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

## チェックリスト

実装完了時に確認:

- [ ] `_buildXxx()` メソッドが残っていないこと
- [ ] 全状態がFreezedクラスで管理されていること
- [ ] BlocBuilder/BlocListenerが適切に使い分けられていること
- [ ] 新規UI要素にValueKeyが付与されていること
- [ ] `dart analyze apps/mobile` がクリーン
- [ ] `dart format apps/mobile` が適用済み
- [ ] 既存テストがパス (`flutter test`)
- [ ] 新規Cubitのユニットテストが追加されていること
