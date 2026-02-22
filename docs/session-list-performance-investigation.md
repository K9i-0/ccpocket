# セッション一覧取得のパフォーマンス調査

**日付**: 2026-02-22
**対象**: `getAllRecentSessions()` in `packages/bridge/src/sessions-index.ts`

## 計測環境

- Claude JSONL: 424ファイル (681MB), 14プロジェクトディレクトリ
- Codex JSONL: 69ファイル (116MB)
- sessions-index.json: 3ファイル (10KB, 18エントリ)

## 全体: ~2000ms

### 内訳

| 処理 | 時間 | 詳細 |
|---|---|---|
| Claude orphan JSONL パース | **~920ms** | 406 orphanファイル (681MB) を readFile + 全行パース |
| Codex JSONL パース | **~340ms** | 69ファイル (116MB) を readFile + 全行パース |
| Claude sessions-index.json | ~1ms | 3ファイル (10KB) の読み込み+パース |
| readdir + stat | ~6ms | ディレクトリ走査 |
| その他 (ソート等) | ~730ms | |

### 最大のボトルネック: Claude orphan スキャン

`scanJsonlDir()` が毎回全JONLファイルをフルパースしている。

- sessions-index.json には18セッションしか登録されていない
- 424個のJSONLのうち **406個がorphan** として毎回フルパースされる
- Claude CLI の `/resume` は sessions-index.json だけ読むので高速

## 検討した最適化案

### 案A: mtime ベースキャッシュ (実装・ベンチ済み)

ファイルの mtime + size をキーにキャッシュ。変更のないファイルは readFile + パースをスキップ。

**Codex部分の結果**:
- キャッシュなし: 340ms
- キャッシュあり: 4ms
- **81.6x 高速化**

**Claude orphan部分** (未実装だが同じ手法で適用可能):
- キャッシュなし: 920ms
- stat のみ: ~6ms
- 推定 **~150x 高速化**

両方適用すれば **~2000ms → ~740ms** (1260ms削減)。

### 案B: 先頭+末尾パース最適化 (実装・ベンチ済み)

ファイル全体は読むが JSON.parse する行数を削減。先頭でメタデータ取得後、中間は文字列チェックのみでカウント。

**結果: 効果なし (むしろ遅い)**
- 100ターン: Original 0.19ms/file vs Fast 0.29ms/file (0.66x)
- 500ターン: Original 0.97ms/file vs Fast 1.42ms/file (0.68x)
- 原因: V8 の JSON.parse が非常に高速で、文字列チェック + インデックス管理のオーバーヘッドの方が大きい

## 今後の改善優先度

1. **Claude orphan に mtime キャッシュ適用** — 最大効果 (~920ms削減)。Codexと同じパターンを `scanJsonlDir` に適用するだけ
2. **Codex に mtime キャッシュ適用** — ~340ms削減。実装済みのコードを再利用可能
3. **並列 readFile** — `Promise.all` でI/O並列化。キャッシュミス時の改善
4. **orphan スキャン自体のスキップ** — sessions-index.json が全件含むなら不要だが CLI の挙動に依存
