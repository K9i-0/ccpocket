# 停止ボタンでのプロンプト取り消し（Esc-to-edit）

Claude Code CLI で応答前に Esc を押すと、直前のプロンプトが会話から取り消されて入力欄に戻る。ccpocket では入力欄が空のときの停止ボタン（タップ）がこの動作を担う。Claude / Codex 共通。

## 参照した公式挙動

- **Claude Code CLI**（2.1.83〜）: "Interrupting a prompt before any response now automatically restores your input so you can edit and resubmit"。復元されるのは次の条件をすべて満たすときだけ。
  - ユーザー操作による中断である
  - 入力欄が空である
  - 最後のユーザーメッセージ以降に、assistant のテキストや tool_use が出ていない
  
  この場合、会話は `/rewind` と同じ処理で実際に巻き戻され、メッセージは無かったことになる。
- **Codex CLI**: Esc での中断ではプロンプトを戻さない（戻すのは未送信のキューや steer だけ）。Esc Esc の backtrack では `thread/fork` で分岐し、選んだプロンプトを入力欄に戻す。ccpocket では両プロバイダーで同じ体験にするため、Codex にも Claude と同じ規則を適用する。

## プロトコル

- Client → Bridge: `{ type: "interrupt", sessionId, retract: true }`
  - 古い Bridge は `retract` を無視して通常の中断だけを行う。`unsupported_message` は返らないので、新しいアプリと古い Bridge の組み合わせでも安全に劣化する（プロンプトが戻らないだけ）。
- Bridge → Client: `{ type: "input_retracted", sessionId, text }`
  - 取り消しが成功したときだけ送る。続けて既存の rewind と同じ `rewind_result` と `session_created`（`sourceSessionId` は元のセッション）を送る。
  - クライアントは `input_retracted` を受けた時点で元セッションの入力欄に文字を戻す。下書きは、続くセッション切り替えで新しいセッションへ移る。

## Bridge の判定（`websocket.ts` の `interruptAndRetract`）

1. 中断前に `SessionManager.retractableUserInput` で候補を確認し、そのうえで中断する。候補になる条件:
   - セッションが実行中である
   - 最新の非 meta `user_input` が synthetic でなく、画像を含まない
   - その後に表示可能な出力が出ていない
   - キューに次の入力がない
2. ターンが終わる（idle になる）まで最大 15 秒待つ。
3. 待っている間に出力が届いた場合は、何もしない。再判定のうえ、候補と同じ `historySeq` であることを確認してから進む。
4. 巻き戻しはプロバイダーごとに既存の処理を使う。
   - **Claude**: `rewindBeforeLastUserInput`。最新のプロンプトの位置から直前の assistant UUID を探し、`resumeSessionAt` で再開する。SDK が UUID を返す前に停止した場合でも動くように、UUID ではなく位置で探す。直前の assistant が見つからないのに以前のターンが存在する場合は、エラーにして何もしない。最初のターンだった場合は、空のセッションで作り直す。
   - **Codex**: 既存の `rewindCodexConversation` で、最新のユーザーターンの直前を `thread/fork` する。フォークした旧 app-server（stdio モード）は、終了するまでフォーク先スレッドの書き込みロックを持ち続ける。そのため、旧プロセスの終了を最大 5 秒待ってから新プロセスで resume する（`CodexProcess.waitForShutdown`）。中断直後は旧プロセスの終了が遅れやすく、待たずに resume すると "thread ... already has an active writer" で失敗していた。この待機は手動 rewind にも効く。

「表示可能な出力」（`isVisibleTurnOutput`）に含めるのは、空白以外の `stream_delta`、テキストまたは tool_use を含む `assistant`、`tool_result`、`permission_request`。thinking は含めない（CLI と同じ）。ターン途中の steer は同じターンに加わるだけなので、出力済みのフラグをリセットしない。

## セッション一覧への影響

- **Claude**: `resumeSessionAt` は同じ会話ファイルを途中から再開するため、一覧は1件のまま。
- **Codex**: `thread/fork` で新しいスレッドができる。取り消しも手動 rewind も、分岐ではなく置き換えとして扱う。成功時に元スレッドを `thread/archive`（とローカルのアーカイブ記録）で一覧から外し、元スレッドはアーカイブ一覧から復元できる。Codex App のメッセージ編集（指定以降のメッセージも消えて再投稿される）で古いセッションが履歴に残らない見え方に合わせた。Codex TUI の backtrack は fork するだけで元スレッドを archive しない。会話の分岐を残したい場合は、既存の fork 機能を使う。

## 既知の制約

- 画像付きのプロンプトは取り消さない。戻せるのはテキストだけで、通常の中断になる。
- 既存の rewind と同じく、取り消すたびにセッション ID が新しくなる。
- Claude で取り消した後に何も送らないと、一覧の「最後のプロンプト」表示に取り消した文が残る。会話ファイルに中断したブランチが残るためで、次に送信すれば更新される。
- 入力欄に文字があると、停止ボタンは送信ボタンに切り替わる。空白だけの入力は空として扱い、戻した文字で置き換える。
