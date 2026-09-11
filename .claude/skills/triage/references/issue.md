## Issueフロー

### 情報収集

- タイトル、本文、ラベル、コメントからBug / Feature / Prompt Requestを判定する。
- 再現手順、期待結果、実際の結果、環境、ログを確認する。
- 関連コードはキーワードと機能単位で絞って調査する。
- 既存機能、重複Issue、上流のClaude Code / Codex起因を確認する。

### プラットフォーム判定

- 正式サポート: メンテナが日常的に検証できる
- experimental / best-effort: Windows Bridge、macOS mobileなど
- 未サポート: 再現・修正・保守を約束しない

experimental / 未サポート環境では次を追加で見る。

- 投稿者が対象環境で検証したか
- 純粋関数や自動テストで担保できるか
- spawn、shell、filesystem、GUI、OS APIに依存するか
- 正式サポート環境へ影響するか

### 難易度

| 難易度 | 基準 | 目安 |
| --- | --- | --- |
| Low | 単一ファイル、既存パターン | 〜1時間 |
| Medium | 複数ファイル、Widget/API拡張 | 数時間 |
| High | Bridge + Flutter、protocol変更 | 1日以上 |
| Very High | アーキテクチャ、外部依存、権限モデル | 数日以上 |

### Issueレポート

```markdown
## Triage Report: #<number> <title>

### 概要・種別・プラットフォーム
[要約]

### 推奨ラベル
- [labels]

### 既存機能・重複
[結果]

### 実現難易度: [Low / Medium / High / Very High]
[根拠となるファイル、protocol変更、影響範囲]

### 対応判断
| 観点 | 評価 |
| --- | --- |
| ユーザー価値 | [高/中/低 — 理由] |
| 実装コスト | [高/中/低 — 理由] |
| リスク | [高/中/低 — 理由] |
| 推奨 | [対応 / 外部PR待ち / 保留 / 見送り] |

### 推奨アクション
- [具体的な次の手順]
```

## 種別ごとの補足

### Bug

- 再現性、影響範囲、回避策、上流起因を確認する。
- 未サポート環境で再現不能なら`needs-repro`、`needs-test`、`help wanted`を検討する。
- 実環境依存の修正は投稿者側の検証結果を必須にする。

### Feature / Prompt Request

- 方向性、ユーザー価値、代替手段、プロンプトの再現性を確認する。
- 大規模なコードPRより、Issue / Prompt Requestでの合意を優先する。

### Dependabot

- breaking changes、upstream changelog、CIを確認する。
- major updateまたは高リスク依存だけ深掘りする。
