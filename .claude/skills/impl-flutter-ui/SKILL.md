---
name: impl-flutter-ui
description: Flutter UI実装のアーキテクチャ規約・コンポーネント分割・状態管理ガイド
disable-model-invocation: true
allowed-tools: Bash(flutter:*), Bash(dart:*), Read, Write, Edit, Glob, Grep
---

# Flutter UI 実装規約

## アーキテクチャ概要

SSOT (Single Source of Truth) + UDF (Unidirectional Data Flow) に基づく設計。

### データフローパターン

- **Path A (Query)**: Provider → Widget (ref.watch)
  - サーバー状態、永続化データ、共有状態
  - Riverpod provider を通じて単方向に流れる
- **Path B (Command)**: Widget → Notifier method → State更新
  - ユーザーアクション、API呼び出し
  - notifier のメソッド経由で状態を変更
- **Path C (Local)**: useState / useTextEditingController
  - テキスト入力、スクロール位置、展開状態等の一時的UI状態
  - flutter_hooks で管理

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
class MyScreenBody extends ConsumerWidget { ... }
class MyScreenFooter extends HookConsumerWidget { ... }
```

### 分割の判断基準

- 20行以上のbuildメソッド内ブロック → 独立Widgetに
- 独自の状態を持つ → HookConsumerWidget
- provider を watch する → ConsumerWidget / HookConsumerWidget
- 表示のみ → StatelessWidget

## 状態管理

### Riverpod Provider

```dart
// @riverpod アノテーションでコード生成
@riverpod
class ChatSessionNotifier extends _$ChatSessionNotifier {
  @override
  ChatSessionState build(String sessionId) {
    // 初期状態 + stream購読
    return const ChatSessionState();
  }

  void sendMessage(String text) {
    // Command (Path B)
  }
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
- sealed union で排他的状態を表現 (例: ApprovalState)
- `@Default` で初期値を明示

### flutter_hooks (ローカル状態)

```dart
class ChatScreen extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final focusNode = useFocusNode();
    final isExpanded = useState(false);

    // サーバー状態は provider から
    final state = ref.watch(chatSessionProvider(sessionId));
    ...
  }
}
```

## ファイル構成

### feature-first 構造

```
lib/features/<feature>/
├── <feature>_screen.dart           # 画面Widget (HookConsumerWidget)
├── state/
│   ├── <feature>_state.dart        # Freezed state classes
│   ├── <feature>_notifier.dart     # Riverpod Notifier
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
| Notifier | `*_notifier.dart` | `chat_session_notifier.dart` |
| Widget | 機能を表す名前 | `chat_app_bar.dart` |

## テスト

### 状態テスト (ProviderContainer)

```dart
void main() {
  test('sendMessage adds entry', () {
    final container = ProviderContainer(overrides: [
      bridgeServiceProvider.overrideWithValue(mockBridge),
    ]);
    final notifier = container.read(chatSessionProvider('s1').notifier);
    notifier.sendMessage('hello');
    expect(container.read(chatSessionProvider('s1')).entries, isNotEmpty);
  });
}
```

### ウィジェットテスト (ProviderScope.overrides)

```dart
testWidgets('ChatInputBar sends message on submit', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatSessionProvider('s1').overrideWith(() => MockNotifier()),
      ],
      child: const MaterialApp(home: ChatInputBar(sessionId: 's1')),
    ),
  );
  await tester.enterText(find.byType(TextField), 'hello');
  await tester.testTextInput.receiveAction(TextInputAction.send);
  // verify
});
```

## build_runner

状態クラス・プロバイダの変更後は必ず実行:

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

## チェックリスト

実装完了時に確認:

- [ ] `build_Xxx()` メソッドが残っていないこと
- [ ] 全状態がFreezedクラスまたはuseStateで管理されていること
- [ ] providerのwatch/readが適切に使い分けられていること
- [ ] `dart analyze apps/mobile` がクリーン
- [ ] `dart format apps/mobile` が適用済み
- [ ] 既存テストがパス (`flutter test`)
- [ ] 新規Notifierのユニットテストが追加されていること
