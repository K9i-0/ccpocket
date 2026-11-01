# スキル呼び出し記号（`/` と `$`）の統一

ステータス: 実装済み / 2026-11-01

## 背景と課題

Claude と Codex でスキルの呼び出し記号が違うため、両方を使い分けるユーザーが混乱する。

| | Claude (Agent SDK) | Codex (app-server) |
|---|---|---|
| スキル呼び出し | `/name`（**メッセージ先頭のみ**コマンドとして実行。途中の `/name` はただの文字列になることを実機で確認済み） | `$name`（任意の位置・複数可） |
| 構造化入力 | なし（本文テキストのみ） | `{type:"skill", name, path}` を本文の前に置く（Bridge `toRpcInput`） |
| 反対側の記号 | `$name` はただの文字列 | `/name` はスキルとして解釈しない（ただの文字列） |

Codex 本体の検出規則（`codex-rs/skills/src/mentions.rs` `extract_tool_mentions`）:
`$` の直後から名前に使える文字 `[A-Za-z0-9_:-]`（`is_mention_name_char`）が続く間を名前として扱う。`$HOME` などよく使う環境変数は除外される。構造化された `skill` 入力がある場合はそちらを優先する。

### 現状の ccpocket 実装

- `composer_tokens.dart`: `$` トリガーは `provider == codex` のときだけ有効（`allowsTrigger`, `_resolveCategory`）。
- `chat_input_with_overlays.dart`: `$` の補完は `isCodex` のときだけ開く。`/` の補完はどちらでも開く。
- `chat_message_handler.dart` `_buildCommandList(includeDollarEntities: isCodex)`:
  Codex のときは `buildSlashSkill`（`/name` を表示し、選ぶと `$name ` を**挿入**する）と `buildDollarSkill` を作る。
  つまり Codex では「`/` の補完から選んだ場合だけ」すでに `$` に置き換わる。
- `chat_session_cubit.dart` `_extractCodexStructuredInputs`: 本文中の `$name` を探して `skills[]` を作る。使われるのは `sendMessage` と `updateQueuedInput` だけ。
- 問題が残るケース:
  - Codex で `/name` を手入力する、履歴から呼び出す、貼り付ける → `/name` がそのまま届き、スキルが発動しない。
  - Claude で `$name` と入力する → 補完が出ず、届いても発動しない。
  - retry（`chat_session_cubit.dart` の再送）は `_extractCodexStructuredInputs` を通らないため、`skills[]` が付かない（既存の抜け）。

## 決定事項（ユーザー確認済み）

1. **設定は3択で、既定は「両方」**
   - `both`（既定）: `/` と `$` のどちらを打ってもスキル候補を出す。選んだときに挿入する記号は、そのセッションのエージェントが使う記号。
   - `slash`: 常に `/name` で挿入・表示する（Codex でも `/`）。
   - `dollar`: 常に `$name` で挿入・表示する（Claude でも `$`）。
   - どの設定でも、**送信時にはエージェントが使う記号へ自動変換する**。設定が変えるのは入力欄での見え方と補完の入口だけ。
2. **履歴に表示するのは変換後のテキスト**。楽観的に追加するローカルの `UserChatEntry` にも変換後の文字列を使い、Bridge から履歴を取り直したときの表示と揃える。

## 設計

### 1. 変換を1つの純粋関数にまとめる

`lib/utils/skill_invocation.dart`（新規）

```dart
class SkillCatalog {            // セッションの slashCommands から作る
  final Provider provider;
  final Map<String, SkillRef> skills;   // name -> (name, path?) / スキルだけ
  final Set<String> reservedSlashNames; // builtin（/compact, /goal ...）
}

({String text, List<Map<String, String>> skills, List<Map<String, String>> mentions})
normalizeOutgoingInput(String text, SkillCatalog catalog, {Iterable<String>? mentionablePaths});
```

- 既存の `_extractCodexStructuredInputs` はこの関数に取り込む（apps / plugins / ファイルメンションの抽出もここで行う）。
- `$name` の名前部分の文字は Codex の `[A-Za-z0-9_:-]` に揃える。今の `_extractCodexStructuredInputs` の正規表現 `[A-Za-z0-9_:/.-]` は `/` と `.` も含んでいて、Codex の判定とずれている（`$skill.` のように文末にピリオドがあると一致しない）。
- トークンの境界判定は `composer_tokens.dart` の `_isTokenBoundary` / `_findTokenEnd` と共通化し、ハイライト・補完・送信で同じ判定を使う。

#### 変換規則

**Codex 宛（`/name` → `$name`）**
- `/name` の `name` が Codex スキル（`skillInfo` を持つもの）に完全一致し、かつ Codex の組み込み（`fallbackCodexSlashCommands`。`/goal` `/plan` `/skills` `/permissions`）に**含まれない**ときだけ変換する。位置は問わない。
- 変換したスキルは `skills[]` にも入れる（構造化入力。同名スキルがあっても Codex 側で正しく1つに決まる）。
- `/goal ...` のように cubit が特別に処理するものは、変換の前に従来どおり処理する。

**Claude 宛（`$name` → `/name`）**
- `$name` の `name` が Claude のスキル／カスタムコマンドに完全一致するときだけ変換する。
- Claude がコマンドとして実行するのは**先頭のトークンだけ**。途中にある `$name` も `/name` に書き換えるが、これは「参照」として渡るだけで、発動するとは限らない（UI でもこの違いを説明する。下記 3.）。
- Claude で `$` に対応させるのはスキル（およびプロジェクトのカスタムコマンド）だけ。`knownCommands` に入っている組み込み（`/compact` など）には `$` 版を作らない。

**共通**
- 変換対象はスキルだけ。Codex の app（`$id`）、plugin（`@name`）、ファイルメンションには手を加えない。
- 一覧にない名前は変換しない。`$5`、`$HOME`、`/usr/bin` などを誤って書き換えないため。
- コードブロック（```` ``` ```` で囲んだ範囲とインラインの `` ` ``）の中は変換しない。
- 名前の大文字・小文字は区別する（Codex の判定に合わせる）。

### 2. 変換するタイミング（ChatSessionCubit）

| 経路 | 現状 | 変更 |
|---|---|---|
| `sendMessage` | Codex のときだけ `$` を抽出 | 最初に `normalizeOutgoingInput` を呼び、以降（ローカルの entry、キュー、`ClientMessage.input`）はすべて変換後のテキストを使う |
| `updateQueuedInput` | Codex のときだけ `$` を抽出 | 同上 |
| retry | `entry.text` をそのまま再送し、`skills` は付けない | 同じ関数を通して `skills` / `mentions` も付ける（既存の抜けの修正） |
| 新規セッションの `initialPrompt` | 補完なしの通常の入力欄 | Bridge 側で変換する（下記「最初のメッセージの変換（Bridge）」） |

プロトコル（メッセージの型）は変更しない。既存の `input.text` / `input.skills` / `input.mentions` だけで実現できるので、`unsupported_message` への対応も不要。チャット欄の変換は古い Bridge でも動く。最初のメッセージの変換だけは新しい Bridge が必要で、古い Bridge では変換されずにそのまま届く。

### 3. 入力欄（補完とハイライト）

- `ComposerTokenConfig` に `SkillTriggerStyle style` を追加する。`allowsTrigger('$')` は provider ではなく style で判定する（`both` / `dollar` なら Claude でも有効）。
- `_resolveCategory`: `/name` と `$name` のどちらもスキル一覧で引き、`skill` として扱う。Claude での `$` の判定も同じようにする。
- `chat_input_with_overlays.dart`:
  - `$` の補完の条件を `isCodex` から `style.allowsDollar` に変える。`useEffect` の依存に `style` を追加する。
  - `/` の補完: Claude でも Codex でもスキルを候補に出す（Codex は今もそうなっている）。
  - 選んだときに挿入する文字列は `insertTokenFor(skill, provider, style)` の1か所で決める。`buildSlashSkill` の `insertText: '$name '` という Codex 専用の処理は、この関数に置き換える。
- `_buildCommandList`: `includeDollarEntities` の代わりに、Claude でもスキルの `$` 版を作る。Claude の `sdk-process` は `path:""` のメタデータを作っているので、`buildDollarSkill` をそのまま使える（Codex 用の `path` が無いときは `skills[]` に入れない）。
- 候補の重複: `both` のときに `/name` と `$name` が同じ候補として2回出ないよう、補完リストでは片方の記号だけを表示する。
- Claude で途中に置いた `$name` / `/name` は、ハイライトは付けるが「先頭でないと実行されない」ことを候補の説明文などで示す（任意。Phase 1 ではハイライトの扱いを変えない案も可）。

### 4. 設定

- `SettingsState` に `@Default(SkillTriggerStyle.both) SkillTriggerStyle skillTriggerStyle` を追加し、SharedPreferences に保存する（既存の `indentSize` などと同じ方法）。
- 設定画面の入力関連のセクションに「スキル呼び出し記号」を追加する: 両方（エージェントに合わせる）／常に `/`／常に `$`。
- ja / en / ko / zh の arb に文言を追加する。

## 既知の制約とリスク

- Claude の組み込みコマンドの判定: `sdk-process` は説明文を持つコマンドをすべて `skills` として返すため、`/compact` なども skill に分類される。`knownCommands` に入っていない新しい組み込みにも `$` 版ができる可能性がある。ただし送信時に `/` に戻るので、実際の害は小さい。
- Claude で `$` の補完を有効にすると、`$` から始まる文字（金額、シェル変数）でも候補が出る可能性がある。一致する候補が無いときは出さない（今の `filtered.isNotEmpty` の判定）ことで抑える。
- アプリのプロンプト履歴（`PromptHistoryService.recordPrompt`）には、変換前の入力した形が残る（Codex で `/skill` と打てば `/skill`）。チャット履歴は変換後の形なので、両者で見た目が異なる。履歴から呼び出して別のエージェントで送っても、送信時にまた変換されるので動作上の問題はない。

## 最初のメッセージの変換（Bridge）

新規セッションの最初のメッセージ（`start.initialPrompt`）は、アプリのチャット送信処理を通らずに Bridge から最初の入力として渡される。アプリはこの時点でスキル一覧を持っていないため、Bridge 側で変換する。

- 実装: `packages/bridge/src/skill-triggers.ts`（規則は Dart 側と同じ。変更時は両方を揃える）。`websocket.ts` の `prepareInitialPrompt` から使う。
- スキル一覧は `SessionManager` のコマンドキャッシュ（プロジェクトの実行ディレクトリ単位）から作る。Codex は `skillMetadata`（無効なスキルと `/goal` などの組み込みを除く）、Claude は `slashCommands` から組み込みコマンドを除いたもの。
- 反対側の記号の候補が無ければ待たずにそのまま送る。候補があり一覧が未取得のとき（Bridge 起動後の最初のセッションなど）は、プロバイダーが一覧を報告するまで最大 5 秒待つ。時間切れならそのまま送る。
- Codex では、本文中のスキルを構造化入力 `skills[]` としても渡す。
- 古い Bridge は変換しないので、最初のメッセージはエージェント本来の記号で書いた場合だけ発動する（従来どおり）。

## 検証計画

- 単体テスト `test/skill_invocation_test.dart`（新規）: provider × 位置（先頭／途中）× 一致／不一致／組み込みと同名／コードブロック内／`$HOME`・`$5`・`/usr/bin`。`skills[]` が正しく付くかも確認する。
- `test/composer_tokens_test.dart`: style ごとのトリガーの有効／無効と、Claude での `$name` のハイライト。
- `test/slash_command_test.dart`: Claude でも `$` 版が作られること、挿入文字列が style で変わること。
- cubit テスト: `sendMessage` / `updateQueuedInput` / retry で、変換後のテキストと `skills` が `ClientMessage.input` に入ること。
- Widget テスト: Claude セッションで `$` を打つと補完が開くこと、Codex で `/skill` を選んだときの挿入文字列が style どおりになること。
- `dart analyze` / `dart format` / 上記テスト。
- 前提の確認（実施済み）: Claude（Agent SDK）で途中に置いた `/skill` は発動せず、先頭に置いた場合は発動することを実機で確かめた。
- シミュレーターでの E2E（`mobile-automation`、テスト用 Bridge 8766）: Claude と Codex の両方で、`/` と `$` の両方からスキルを呼び出して実際に発動するか確認し、設定を切り替えたときの挿入記号も確認する。

## 実装メモ

- 変換: `lib/utils/skill_invocation.dart`（`convertSkillTriggers` / `SkillTriggerCatalog`）。`ChatSessionCubit.toNativeSkillTriggers` から `sendMessage` と `updateQueuedInput` で呼ぶ。retry は送信済み（変換後）のテキストを使い、Codex の `skills[]` / `mentions[]` を付け直す。
- 設定: `SkillTriggerStyle`（`settings_skill_trigger_style`）。Claude の `$` ボタンは「常に `$`」のときだけ表示し、`$` 補完は「常に `/`」以外で有効。Codex の `$` 補完は app があるため常に有効。
- 名前の前後にある日本語などの非 ASCII 文字は区切りとして扱う（`これを/review-prして` も変換する）。
- `$skill.` のように末尾に記号が付いた場合も、Codex の構造化スキル入力に入るようにした。
- §3 の案と異なり、Claude の `$` 版は `_buildCommandList` ではなく入力欄ウィジェット側（`_dollarAlias`）で作る。cubit 側の変換は `/` のスキル一覧から判定する。
- 境界判定の共通化（§1）は未達。補完・ハイライトは `:` を区切りとして扱い、変換は扱わないため、`foo:/skill` のような入力ではハイライトと変換がずれる。
- retry では Codex の `skills[]` と app / plugin の `mentions[]` を付け直すが、プロジェクトファイルの `@` メンションは retry 時に候補パスが無いため付かない（従来どおり）。

## 検証結果（iPhone 18 Pro シミュレーター + テスト用 Bridge 8766）

- Claude: `$test-f` で補完が出て、選ぶと `/test-flutter` が入る。手入力の `$test-flutter …` は `/test-flutter …` で送られ、セッション記録でスキル本文の読み込みを確認した。途中に置いた場合は変換されるが発動しない。
- Codex: `/flutter-up` の補完から選ぶと `$flutter-upgrade` が入る。手入力の `/flutter-upgrade …` は `$flutter-upgrade …` で送られ、rollout で `<skill><name>flutter-upgrade</name>` の注入を確認した。
- 設定「常に /」: Codex で `$` 補完から選ぶと `/flutter-upgrade` が入る。
