# メッセージの編集・取り消し・フォーク（自分のメッセージ起点の操作）

Claude / Codex で同じ体験にそろえる。基準は Codex App。

## 操作一覧

| 操作 | UI | 動作 |
| --- | --- | --- |
| コピー | ユーザー吹き出し下のコピーアイコン（押すとチェックに変わる） | 本文をクリップボードへコピー |
| 編集して再送 | 吹き出し下の鉛筆 → 吹き出しがその場でエディタになる → 送信 | そのメッセージ以降を会話から消し、編集後の本文を同じセッションで送る |
| 取り消し（Esc 相当） | 入力欄が空のときに停止ボタンをタップ | 応答がまだ出ていなければ、プロンプトを会話から消し、本文を入力欄に戻す |
| ファイル復元（Claude のみ） | 吹き出し下の「…」→「この時点のファイルに戻す」 | `rewindFiles` でファイルだけを戻す。会話は変えない |
| フォーク | アシスタントのメッセージの分岐ボタン | その時点までを持つ新しいセッションを作る。元のセッションはそのまま |

編集は Codex App と同じく、ターンの実行中はできない（鉛筆を出さない）。画像付きのメッセージは、v1 では編集・取り消しの対象外。

## 公式の挙動（調査結果）

- **Claude Code CLI**（2.1.83〜）: 応答前に Esc を押すと、プロンプトが会話から巻き戻され、入力欄に戻る。条件は、最後のユーザーメッセージ以降に assistant のテキストや tool_use が出ていないこと。Esc を2回押すと `/rewind` になる。
- **Codex App**: 吹き出しの下にコピーと編集ボタンがある。編集はインラインのエディタで、Cancel / Send。Send すると `thread/revert`（ページング対応スレッドの場合。それ以外は `thread/rollback`）で同じスレッドをその場で巻き戻し、編集後の本文で新しいターンを始める。添付は保持する。実行中の編集は "Cannot edit a message while a turn is in progress." で拒否する。古いセッションは一覧に残らない。
- **Codex TUI**: Esc を2回押すと、`thread/fork {beforeTurnId}` で分岐して、選んだプロンプトを入力欄に戻す。

## 方式: その場での巻き戻し（in-place）

以前は rewind のたびにセッションを作り直して ID を切り替えていた。そのため次の不具合が出ていた。

- 取り消した吹き出しが画面に残る
- Claude を開き直すと過去の会話が消える
- 会話の途中に「Session started」のチップが入る
- セッション一覧に同じ会話が重複して並ぶ

現在は `SessionManager.rewindInPlace` で、セッションと ID を保ったまま巻き戻す。

- **Codex**: 稼働中の app-server で `CodexProcess.rewindBeforeUserTurn` を呼ぶ。`thread/revert` を使い、未対応なら `thread/rollback` にする。対象ターン以降を削除する。
- **Claude**: 同じ `SdkProcess` を、対象プロンプト直前の assistant UUID を `resumeSessionAt` にして `start()` し直す。リスナーはそのまま。最初のターンが対象の場合は空のセッションで始める。それより前のターンがあるのに再開位置が分からない場合は、エラーにして何もしない。
- Bridge 側の履歴（`history` / `pastMessages`）から対象以降を削除し、`historyResetSeq` を記録する。それより古い位置からの差分同期には、スナップショットを返す。
- クライアントへは `conversation_rewound` を送る。アプリは手元の履歴キャッシュを捨て、表示をクリアしてから履歴を取り直す。送信中の編集だけは残す。

## プロトコル

- `interrupt { sessionId, retract: true }`: 停止に加えて取り消しを依頼する。古い Bridge は `retract` を無視して通常の中断だけを行う。
  - 停止は送信直後、Bridge でターンが始まる前にタップされることがある。その状態で中断しても何も起きず、ターンはそのまま走ってしまう。そこで、取り消せるプロンプトがある場合は、ターン開始を最大3秒待ってから中断する。
  - 中断後、ターン終了を最大15秒待つ。そのうえでまだ出力がない（`retractableUserInput`）ことを確認してから巻き戻す。
- `input_retracted { sessionId, text }`: 取り消した本文。アプリはこれを入力欄に戻す。
- `edit_message { sessionId, targetUuid, text, clientMessageId? }`: その場で巻き戻した後、通常の `input` 経路で再送する。ack・エコー・配信追跡は通常の送信と同じ。実行中は `error { errorCode: "edit_message_failed" }` を返す。
- `conversation_rewound { sessionId }`: 会話がその場で巻き戻されたことの通知。
- capability `message_edit_v1`: これがある Bridge でだけ、アプリは鉛筆を出す。ない Bridge では従来の「ここまで巻き戻す」（セッションを作り直す方式）をメニューに残す。従来の `rewind` メッセージは、古いアプリのために Bridge に残している。

「表示可能な出力」（`isVisibleTurnOutput`）に含めるのは、空白以外の `stream_delta`、テキストまたは tool_use を含む `assistant`、`tool_result`、`permission_request`。thinking は含めない（CLI と同じ）。ターン途中の steer は同じターンに加わるだけなので、出力済みのフラグをリセットしない。

## 履歴の読み込み（巻き戻した会話のディスク表現）

- **Codex**: `thread/revert` を行うと、新しい rollout セグメント `rollout-…-<threadId>_<segmentId>.jsonl` ができる。その `session_meta.history_base` は「元セグメントの `end_byte_offset` までを引き継ぐ」ことを表す。一覧の要約（`getCodexSessionIndexMetadata`）とディスクからの履歴（`getCodexSessionHistory`）は、この連鎖を `readCodexRolloutChain` でたどって結合する。どのセグメントにも参照されていない末端を「現在」とみなす。巻き戻されたセグメントのほうが後から書き込まれることもあるため、更新時刻だけでは選ばない。
- **Claude**: `resumeSessionAt` で再開すると、同じ transcript に新しい枝ができる。`claudeAbandonedBranchUuids` で処理する。
  - 最新のエントリから `parentUuid` をたどった枝から外れたプロンプトと、その子孫を「捨てられた枝」として除外する。`claude --resume` と同じ考え方。
  - 並列ツール呼び出しによる枝分かれはプロンプトで起きないので、除外しない。
  - 親が見つからない場合や、`parentUuid` を持たない形式の場合は、何もフィルタしない。
- **Claude の制約**: 取り消した後に何も送らないと、transcript の最新の枝は取り消したプロンプトのままになる。そのため、Bridge 再起動後に開き直すと、取り消したプロンプトが戻って見える（一覧の「最後のプロンプト」も同じ）。CLI の「次のプロンプトを送るまで巻き戻しは保存されない」と同じ挙動。

## フォーク

- **Claude**: assistant の UUID までの transcript を新しいセッションにする。上記の枝フィルタが効くので、捨てられた枝はフォークに入らない。
- **Codex**: `thread/fork` を使い捨ての app-server で実行し、その終了を待ってから新しいセッションでフォーク先を resume する。stdio の app-server は、フォークや resume をしたスレッドの書き込みロックをプロセスが終了するまで保持する。そのため、元のセッションのプロセスでフォークすると、新しいプロセスが resume できない（"thread … already has an active writer"）。同じ理由で、古い rewind 経路も、置き換えるプロセスの終了を待つ（`CodexProcess.waitForShutdown`）。

## 既知の制約

- 画像付きメッセージの編集・取り消しはできない（v1）。
- Claude を巻き戻した直後は、SDK の再起動中に入力欄が数秒間無効になる。
- 再開したセッションの過去の assistant メッセージには、フォークボタンが出ない（既存の仕様）。
