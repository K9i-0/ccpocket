# ユーザーメッセージ フィルタリング比較レポート

セッション: 9d8edf3b (3516行, 477 userエントリ)
テキスト付きユーザーメッセージ: 22 件 (tool_resultのみは除外済み)

## JSONLに記録されているフラグ一覧

全プロジェクト横断で確認した結果:

| フラグ | 値 | 件数 | 説明 |
|--------|-----|------|------|
| `userType` | `"external"` | 全件 | ユーザー由来（他の値は未発見） |
| `isMeta` | `true` | 141件 | スキル読み込みプロンプト |
| `isCompactSummary` | `true` | 35件 | コンテキスト圧縮メッセージ |
| `isVisibleInTranscriptOnly` | `true` | 35件 | UI非表示（常にisCompactSummaryと同時出現） |
| `isSynthetic` | - | 0件 | **JSONLには一切保存されない**（ランタイム専用） |
| `isSidechain` | `true`/`false` | 全件 | サイドチェーン判定 |
| `sourceToolUseID` | string | isMeta時 | スキルを起動したToolUse ID |

## フラグ組み合わせパターン（テキスト付きメッセージのみ）

| パターン | 件数 | isMeta | isCompactSummary | isVisibleInTranscriptOnly | 内容 |
|---------|------|--------|-----------------|-------------------------|------|
| 14件 | 14 | None | None | None | 競合アプリ(公式含む)との差別化を考えた時モバイルに特化した新しいエージェント管理UIUXが重要にな... |
|  5件 | 5 | None | True | True | This session is being continued from a previous co... |
|  3件 | 3 | True | None | None | Base directory for this skill: /Users/k9i-mini/Wor... |

---

## 現在の実装の処理結果

### リアルタイム経路 (`_handleMessage` / `_handleHistory`)
判定: `isSynthetic == true` → 非表示, `isMeta == true` → チップ表示

### 過去履歴経路 (`_handlePastHistory` / `getSessionHistory`)
判定: テキスト先頭が `'Base directory for this skill:'` → isMeta, それ以外は全て表示

| # | L | 現在の判定 | 表示 | テキスト |
|---|---|-----------|------|---------|
| 1 | 2 | 通常メッセージ | ✅ | 競合アプリ(公式含む)との差別化を考えた時モバイルに特化した新しいエージェント管理UIUXが重要になる\nマッチングアプリ的なスワイプでの承認対応(複数セッション |
| 2 | 8 | 通常メッセージ | ✅ | 承認もyes noだけじゃない\n複数の選択肢やプランの承認など\nスワイプでこれらの承認を連続して捌くにはどんなやり方が良さそう？\nスワイプ式のアプリを参考に提案 |
| 3 | 14 | 通常メッセージ | ✅ | ダミーのデータを用意してサンプルの画面を作ることはできる？\nできればリリースビルドで見えるように既存モックとは別動線 |
| 4 | 120 | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 5 | 334 | 通常メッセージ | ✅ | <command-message>shorebird-patch</command-message>\n<command-name>/shorebird-patc |
| 6 | 335 | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 7 | 492 | 通常メッセージ | ✅ | パッチはきたけど、操作ができない |
| 8 | 496 | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 9 | 648 | 通常メッセージ | ✅ | This session is being continued from a previous conversation that ran out of con |
| 10 | 1062 | 通常メッセージ | ✅ | 結構いいね\nサブエージェントに改善案を出させてブラッシュアップのループを回して\nいろんなペルソナのサブエージェントに聞いて |
| 11 | 1457 | 通常メッセージ | ✅ | 複数選択の時にスワイプ方向で選択可能にしたい\nスワイプに入ったらエフェクトをかけることでどれを選ぼうとしてるか分かる感じ(ボタンハイライトとか\n\nテキスト入力系 |
| 12 | 1495 | 通常メッセージ | ✅ | This session is being continued from a previous conversation that ran out of con |
| 13 | 1807 | 通常メッセージ | ✅ | 選択肢複数の単一選択について\nスワイプ領域のガイドを出して、どこにスワイプすればいいか視覚的に示したい\n選択肢を色分けしてもいいかも\n\n全てのカードについて\n共 |
| 14 | 2064 | 通常メッセージ | ✅ | 良くなった\n\n- 新しいカードになった時に、前スワイプの判定が残ってるかも。クリーンな状態で始めたい\n- 領域分けをさらに踏み込んで、境界線が分かる半透明のオー |
| 15 | 2085 | 通常メッセージ | ✅ | This session is being continued from a previous conversation that ran out of con |
| 16 | 2372 | 通常メッセージ | ✅ | まだカードの初期位置が前回に引きずられてる |
| 17 | 2565 | 通常メッセージ | ✅ | 直ってそう\n\n複数領域の分割について\n放射状に領域を分けることはできる？ |
| 18 | 2680 | 通常メッセージ | ✅ | This session is being continued from a previous conversation that ran out of con |
| 19 | 2990 | 通常メッセージ | ✅ | オーバーレイがなぜかカード内に出てる\nオーバーレイは画面全体に出るはず |
| 20 | 3201 | 通常メッセージ | ✅ | 微調整したいところはあるけどだいぶできたのでコミットしたい |
| 21 | 3221 | 通常メッセージ | ✅ | queueが空になった時の体験を考えたい\n- エージェントの回答が終わって、次のプロンプト待ちの時\n- そもそもセッションがない時 |
| 22 | 3303 | 通常メッセージ | ✅ | This session is being continued from a previous conversation that ran out of con |

---

## 仮説実装の処理結果

### 判定ロジック（JSONLフラグベース）

```
1. isCompactSummary == true || isVisibleInTranscriptOnly == true → 非表示
2. isMeta == true → チップ表示（スキル読み込み）
3. テキストが <command-message> で始まる → チップ表示（スラッシュコマンド）
4. それ以外 → 通常表示（本物のユーザーメッセージ）
```

| # | L | JSONLフラグ | 仮説の判定 | 表示 | テキスト |
|---|---|------------|-----------|------|---------|
| 1 | 2 | - | 通常メッセージ | ✅ | 競合アプリ(公式含む)との差別化を考えた時モバイルに特化した新しいエージェント管理UIUXが重要になる\nマッチングアプリ的なスワイプでの承認対応(複数セッション |
| 2 | 8 | - | 通常メッセージ | ✅ | 承認もyes noだけじゃない\n複数の選択肢やプランの承認など\nスワイプでこれらの承認を連続して捌くにはどんなやり方が良さそう？\nスワイプ式のアプリを参考に提案 |
| 3 | 14 | - | 通常メッセージ | ✅ | ダミーのデータを用意してサンプルの画面を作ることはできる？\nできればリリースビルドで見えるように既存モックとは別動線 |
| 4 | 120 | isMeta | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 5 | 334 | - | コマンド → チップ | 🟡 | <command-message>shorebird-patch</command-message>\n<command-name>/shorebird-patc |
| 6 | 335 | isMeta | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 7 | 492 | - | 通常メッセージ | ✅ | パッチはきたけど、操作ができない |
| 8 | 496 | isMeta | isMeta → チップ | 🔵 | Base directory for this skill: /Users/k9i-mini/Workspace/ccpocket/.claude/skills |
| 9 | 648 | isCompact, isTranscriptOnly | コンテキスト圧縮 → 非表示 | ❌ | This session is being continued from a previous conversation that ran out of con |
| 10 | 1062 | - | 通常メッセージ | ✅ | 結構いいね\nサブエージェントに改善案を出させてブラッシュアップのループを回して\nいろんなペルソナのサブエージェントに聞いて |
| 11 | 1457 | - | 通常メッセージ | ✅ | 複数選択の時にスワイプ方向で選択可能にしたい\nスワイプに入ったらエフェクトをかけることでどれを選ぼうとしてるか分かる感じ(ボタンハイライトとか\n\nテキスト入力系 |
| 12 | 1495 | isCompact, isTranscriptOnly | コンテキスト圧縮 → 非表示 | ❌ | This session is being continued from a previous conversation that ran out of con |
| 13 | 1807 | - | 通常メッセージ | ✅ | 選択肢複数の単一選択について\nスワイプ領域のガイドを出して、どこにスワイプすればいいか視覚的に示したい\n選択肢を色分けしてもいいかも\n\n全てのカードについて\n共 |
| 14 | 2064 | - | 通常メッセージ | ✅ | 良くなった\n\n- 新しいカードになった時に、前スワイプの判定が残ってるかも。クリーンな状態で始めたい\n- 領域分けをさらに踏み込んで、境界線が分かる半透明のオー |
| 15 | 2085 | isCompact, isTranscriptOnly | コンテキスト圧縮 → 非表示 | ❌ | This session is being continued from a previous conversation that ran out of con |
| 16 | 2372 | - | 通常メッセージ | ✅ | まだカードの初期位置が前回に引きずられてる |
| 17 | 2565 | - | 通常メッセージ | ✅ | 直ってそう\n\n複数領域の分割について\n放射状に領域を分けることはできる？ |
| 18 | 2680 | isCompact, isTranscriptOnly | コンテキスト圧縮 → 非表示 | ❌ | This session is being continued from a previous conversation that ran out of con |
| 19 | 2990 | - | 通常メッセージ | ✅ | オーバーレイがなぜかカード内に出てる\nオーバーレイは画面全体に出るはず |
| 20 | 3201 | - | 通常メッセージ | ✅ | 微調整したいところはあるけどだいぶできたのでコミットしたい |
| 21 | 3221 | - | 通常メッセージ | ✅ | queueが空になった時の体験を考えたい\n- エージェントの回答が終わって、次のプロンプト待ちの時\n- そもそもセッションがない時 |
| 22 | 3303 | isCompact, isTranscriptOnly | コンテキスト圧縮 → 非表示 | ❌ | This session is being continued from a previous conversation that ran out of con |

---

## 差分サマリー

| メッセージ | 現在 | 仮説 | 変化 |
|-----------|------|------|------|
| L334: <command-message>shorebird-patch</comman | ✅ 表示 | 🟡 チップ | ⚡ 変更 |
| L648: This session is being continued from a p | ✅ 表示 | ❌ 非表示 | ⚡ 変更 |
| L1495: This session is being continued from a p | ✅ 表示 | ❌ 非表示 | ⚡ 変更 |
| L2085: This session is being continued from a p | ✅ 表示 | ❌ 非表示 | ⚡ 変更 |
| L2680: This session is being continued from a p | ✅ 表示 | ❌ 非表示 | ⚡ 変更 |
| L3303: This session is being continued from a p | ✅ 表示 | ❌ 非表示 | ⚡ 変更 |

変更なしのメッセージは省略。

---

## 🔥 問題2: リアルタイムセッションでユーザーメッセージが消える

### シミュレーター検証で判明した事実

**Bridge側ログ:**
```
[DEBUG-GET-HISTORY] Sending history: total=1 user_input=0 texts=[]
```

**Flutter側ログ:**
```
[DEBUG-HISTORY-FLUTTER] _handleHistory: total=1 userInput=0 texts=[]
[DEBUG-REPLACE] replaceEntries: oldEntries=559 (user=14) → pastEntries=559 + newEntries=0 (user=0)
```

### 根本原因

**SDK Agent SDKの`query()`ストリームは`type: "user"`メッセージをリアルタイムで流さない。**

```
Flutter sendMessage() → UserChatEntry を state に追加 (✅ 一時的に表示)
         ↓
Flutter sendInput → Bridge → SdkProcess.sendInput() → resolve() → SDK
         ↓
SDK はユーザーメッセージを処理するが、ストリームには流さない
         ↓
Bridge の in-memory history に user_input が入らない (❌)
         ↓
Flutter get_history → history に user_input=0 → replaceEntries で全消し (❌)
```

### 影響

| シナリオ | ユーザーメッセージ |
|---------|-------------------|
| メッセージ送信直後 | ✅ sendMessage で一時的に表示 |
| get_history レスポンス受信後 | ❌ replaceEntries で消える |
| アプリ再接続時 (in-memory) | ❌ history に含まれない |
| セッション復元時 (past_history / JSONL) | ✅ JSONL から正しく読み込まれる |
| セッション一覧でのサマリー | (historyとは別経路) |

### 修正方針

**Bridge側 (`websocket.ts` の `input` ハンドラ):**

ユーザーからのinputを受けた時に、手動で `user_input` を history に追加してFlutterにも送信する:

```typescript
case "input": {
  // ... 既存の処理 ...

  // ★ ユーザーメッセージを history に明示的に追加
  const userInputMsg: ServerMessage = {
    type: "user_input",
    text: msg.text,
    // userMessageUuid は SDK から後で来る可能性があるため、ここでは省略
  };
  session.history.push(userInputMsg);
  // Flutter にも送信して ChatEntry として追加させる
  this.send(ws, { ...userInputMsg, sessionId: session.id });

  // ... sendInput() ...
}
```

**または Flutter側 (`claude_code_session_cubit.dart`):**

`replaceEntries` 時にローカルの `UserChatEntry` を保護する:

```dart
if (update.replaceEntries) {
  final pastEntries = entries.take(_pastEntryCount).toList();
  // ★ ローカルで追加した UserChatEntry も保護
  final localUserEntries = entries
      .skip(_pastEntryCount)
      .whereType<UserChatEntry>()
      .toList();
  entries = [...pastEntries, ...localUserEntries, ...nonStreamingEntries];
}
```