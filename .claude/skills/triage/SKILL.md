---
name: triage
description: "GitHub Issue・PRのトリアージ。番号を渡すと、要望の要約・実現難易度・既存機能との重複チェック・対応判断を調査してレポートする。Issue/PRの番号が出てきたとき、トリアージ、優先度判断、対応判断と言われたときに使用する。"
---

# Issue / PR トリアージ

GitHub Issue または PR の番号を受け取り、コードベースを調査して対応判断に必要な情報をレポートする。

## 使い方

```
/triage 42
/triage #8
```

## トリアージ手順

### Phase 1: 情報収集

#### 1-1. Issue/PR の取得

番号からIssueかPRかを自動判定する。

```bash
# まずIssueとして取得を試みる
gh issue view <番号> --json number,title,body,labels,state,comments,author,createdAt

# 404なら PRとして取得
gh pr view <番号> --json number,title,body,labels,state,files,comments,author,reviews,createdAt
```

#### 1-2. コメント・議論の確認

```bash
# Issueのコメント
gh issue view <番号> --json comments --jq '.comments[].body'

# PRのレビューコメント
gh pr view <番号> --json reviews --jq '.reviews[].body'
```

#### 1-3. 種別の判定

IssueテンプレートやラベルからIssueの種別を判定する:

| 種別 | 判定基準 |
|------|---------|
| Bug Report | `bug` ラベル、テンプレートのフィールド |
| Feature Request | `enhancement` ラベル、Proposal セクション |
| Prompt Request | テンプレートに「プロンプト」「AI tool」セクション |
| Dependabot | author が `dependabot[bot]` |
| 外部PR | authorがリポジトリオーナー以外 |

### Phase 2: コードベース調査

要望の内容に基づいて、関連するコードを調査する。
Explore サブエージェントを活用して並列に調査を進める。

#### 調査観点

1. **関連コード**: 変更が必要になりそうなファイル・モジュール
2. **既存機能**: 要望を既に満たしている（または部分的に満たしている）機能がないか
3. **影響範囲**: 変更した場合に影響を受ける他の機能・モジュール
4. **プロトコル変更**: WebSocketプロトコルの変更が必要か（Bridge + Flutter双方の変更が必要になる）

#### PRの場合の追加調査

```bash
# 変更ファイル一覧
gh pr view <番号> --json files --jq '.files[].path'

# diff の取得
gh pr diff <番号>
```

- 変更内容がプロジェクトの規約に沿っているか
- テストが追加されているか
- セキュリティ上の懸念はないか（特にBridge Serverのファイルシステムアクセス周り）

### Phase 3: 難易度・工数の見積もり

調査結果をもとに、実装の難易度を判定する。

| 難易度 | 基準 | 工数目安 |
|--------|------|---------|
| **Low** | 単一ファイルの修正、UIの微調整、既存パターンの踏襲 | ~1時間 |
| **Medium** | 複数ファイルの変更、新しいWidgetの追加、既存APIの拡張 | 数時間 |
| **High** | プロトコル変更（Bridge + Flutter両方）、新機能のフルスタック実装 | 1日以上 |
| **Very High** | アーキテクチャ変更、外部依存の追加、セキュリティモデルの変更 | 数日以上 |

判定の根拠を具体的なファイルパスや変更箇所とともに示す。

### Phase 4: レポート出力

以下のフォーマットで会話内にレポートを出力する。

```markdown
## Triage Report: #<番号> <タイトル>

### 概要
[1-2文で要望の要約]

### 種別
[Bug / Feature / Prompt Request / Dependabot / 外部PR]

### 既存機能チェック
- [既に実現済みの機能があれば記載]
- [部分的に実現されている場合はその旨と差分]
- [完全に新規の場合は「該当なし」]

### 実現難易度: [Low / Medium / High / Very High]

**根拠:**
- [変更が必要なファイル・モジュール]
- [プロトコル変更の有無]
- [影響範囲]

### 対応判断

| 観点 | 評価 |
|------|------|
| ユーザー価値 | [高/中/低] — [理由] |
| 実装コスト | [高/中/低] — [理由] |
| リスク | [高/中/低] — [理由] |
| 推奨 | [対応する / 保留 / 見送り] |

### 推奨アクション
- [具体的な次のステップ]
```

## 種別ごとの判断基準

### Bug Report
- 再現手順が明確か
- 影響範囲（全ユーザー vs 特定環境）
- ワークアラウンドの有無
- 上流（Claude Code / Codex）起因かccpocket起因か

### Feature Request
- プロジェクトの方向性と合致するか
- 実装コストに対するユーザー価値
- 代替手段（既存機能で賄えないか）

### Prompt Request
- プロンプトの再現性
- 変更がコードベースの規約に沿うか
- そのまま適用可能か、調整が必要か

### Dependabot PR
- breaking changesの有無
- CHANGELOGの確認
- CI が通っているか

### 外部PR
- CONTRIBUTING.md の手順に沿っているか（Issue先行が推奨）
- テストの追加
- プロジェクト規約への準拠
- セキュリティレビューの必要性

## 外部PRの取り込み運用

外部PRはそのままマージするのではなく、内容を精査してメンテナが取り込む方針を取っている。
これは、PRの意図は良くても実装の一部を修正・調整したいケースが多いため。

### 取り込みフロー

1. **トリアージ**: 本スキルでPRの内容・品質・方向性を評価
2. **取り込み判断**: レポートの推奨アクションに基づいて判断
3. **実装**: PRの変更を参考に、メンテナが自分のブランチで実装する
   - そのまま使える部分はチェリーピックまたはコピー
   - 修正が必要な部分はメンテナ側で調整
   - プロジェクト規約（Conventional Commits、コード構造等）に合わせる
4. **クレジット**: コミットに `Co-authored-by` を付与して貢献者をクレジットする
   ```
   Co-authored-by: username <email>
   ```
   - PRのauthorのGitHub情報から取得: `gh api users/<username> --jq '.name, .email'`
   - メールが非公開の場合は `<id>+<username>@users.noreply.github.com` を使用
5. **PRクローズ**: 取り込み完了後、感謝のコメントとともにPRをクローズ
   - 何を取り込み、何を変更したかを説明する
   - Co-authored-by でクレジットした旨を伝える

### レポートへの反映

外部PRのトリアージレポートでは、推奨アクションに取り込み方針を含める:

```markdown
### 推奨アクション
- **取り込み方針**: [そのままマージ / 一部修正して取り込み / 参考にして再実装]
- **修正が必要な点**: [具体的な修正箇所]
- **Co-authored-by**: `Co-authored-by: Name <email>`
```

## 返信コメントの言語ルール

Issue/PRにコメントを投稿する際は、投稿者の言語に合わせて対応する:

- **英語で書かれている場合**: 英語のみで返信
- **英語以外の言語で書かれている場合**: 元の言語 + 英語の両方で返信

Issue/PRのタイトル・本文・コメントから投稿者の言語を判定する。
バイリンガル返信の場合は、元言語を先に書き、`---` で区切って英語を後に続ける。

**例: 日本語のIssueへの返信**
```
ご提案ありがとうございます！この機能は v1.5.0 で実装済みです。
セッション一覧画面で未読インジケーターが表示されます。

---

Thank you for the suggestion! This feature has been implemented in v1.5.0.
You'll see unread indicators on the session list screen.
```

## コメント投稿時の注意

- `gh issue comment` / `gh pr comment` で複数段落の本文を投稿する場合は、シェルクォートで本文を直接 `--body` に埋め込まない
- 改行・バッククォート・引用記号が崩れやすいため、**必ず一時ファイルを作って `--body-file` で渡す**
- 既存コメントを修正する場合も同様に、本文ファイルを作ってから API 経由で更新する
- 投稿後は `gh issue view` / `gh pr view` で最新コメントを取得し、改行や Markdown が崩れていないか確認する

例:

```bash
cat <<'EOF' >/tmp/comment.md
First paragraph.

- bullet 1
- bullet 2
EOF

gh pr comment <number> --body-file /tmp/comment.md
```
