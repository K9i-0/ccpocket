# Claude Ultracode

Claude Code の ultracode（タスクごとに dynamic workflow でマルチエージェント実行する常時モード）を、Claude セッションの設定として切り替えられるようにする。

## SDK の仕様（`@anthropic-ai/claude-agent-sdk` 0.3.316 時点）

- `Settings.ultracode?: boolean`。セッション単位で、Claude Code は永続化しない。
- `Query.applyFlagSettings({ ultracode })` で実行中に切り替える。
- `effortLevel` を ultracode キーなしで送り、effort が変わると ultracode は off になる。effort を変えて ultracode を維持するには両方のキーを送る。
- モデルやアカウントが dynamic workflow を使えない場合、`applyFlagSettings` は `ultracode is not available for this session (...)` で reject する。
- `ModelInfo` に ultracode の対応可否を示すフィールドはない。そのため事前に判定せず、拒否されたらその結果を表示する。

## Bridge

- `ClaudeSessionSettings.ultracode` / `StartOptions.ultracode` を追加した。
- 起動時は fast mode と同様に `query()` の後で `applyFlagSettings({ ultracode: true })` を実行する。失敗したら ultracode を off にして続行する。
- `SdkProcess.updateSettings` は、ultracode が on のままモデルか effort が変わるとき、`ultracode: true` を同じ `applyFlagSettings` 呼び出しに含める。
- プロトコルに以下を追加した。
  - `start` / `resume_session` の `claudeUltracode?: boolean`
  - `set_claude_settings` の `ultracode?: boolean`（これだけを送る更新も受け付ける）
  - `claude_settings` スナップショットの `ultracode: boolean`
- 拒否されたときは既存の `set_claude_settings_rejected` エラーを返し、現在の設定を再送する。

## アプリ

- Claude 設定パネルに、effort とは独立した Ultracode トグルを置く。クイック表示ではスイッチ、詳細表示では行として表示する。CLI の `/effort ultracode on|off` と同じ考え方。
- モデルチップと、セッションカードの設定概要に ultracode の状態を表示する。
- 実行中セッションの設定シートは `claude_settings` スナップショットに追従する。拒否されたときはトグルが off に戻る。
- resume では、そのセッションに保存した `claudeUltracode` を Bridge に渡して再適用する。Claude Code は ultracode を保存しないため。新規セッションの前回設定（SharedPreferences の start defaults）には保存しない。トークン消費が大きいため、意図せず引き継がないようにする。

## 古い Bridge との互換性

- 古い Bridge の parser は、`set_claude_settings` に model / effort / fastMode のどれもないと無効メッセージとして扱う。そのため、ultracode だけを切り替えるときもアプリは現在の effort を一緒に送る。古い Bridge は effort の変更なしとして受け付け、`ultracode` キーのない `claude_settings` を返す。アプリはこれを off として扱うので、トグルは自動で off に戻る。
- `start` / `resume_session` の `claudeUltracode` は、古い Bridge では無視される。返ってくるスナップショットに ultracode がないため、表示も off になる。
