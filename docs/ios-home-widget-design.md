# iOS ホームウィジェット検討メモ

Status: 検討中（2026-11-08）。実装・プロトコル変更は未着手。

## 要望

- 表示: 接続中の Bridge 情報 / Claude・Codex の Limit / アクティブなセッションのサマリー
- 操作（任意）: 登録済み Bridge の切り替え

## 前提となる制約（ここから設計が決まる）

WidgetKit の extension は「常駐プロセス」ではない。

- タイムライン更新のたびに短時間だけ起動され、すぐ終了する。WebSocket の維持や SSH トンネルの確立はできない。
- 更新回数には日次バジェットがある（目安 1 日 40〜70 回 ≒ 15〜30 分間隔）。リアルタイム表示はできない。
- Flutter アプリは通常サスペンド中のため、アプリ側から最新値を書き込めるのはフォアグラウンド時と、通知などで起動された短い時間だけ。

このため、ウィジェットでいう「接続中の Bridge」は実際には **最後に選んだ（または接続した）Machine と、その到達確認結果** になる。現在の接続状態をそのまま表示するものではない。

### データの取得経路（3 案）

| 経路 | 内容 | 長所 | 短所 |
|---|---|---|---|
| A. アプリが書き込む | アプリが App Group の UserDefaults にスナップショットを書き、`WidgetCenter.reloadTimelines` を呼ぶ | 実装が単純。SSH 経由の Machine にも使える。認証情報を extension に渡さずに済む | アプリを開かないと古くなる |
| B. extension が直接取得 | `TimelineProvider` が Bridge の HTTP（`/health`, `/usage`）を取得する | アプリを開かなくても 15〜30 分間隔で更新できる | 到達できる Machine に限られる（後述）。API キーの共有が必要 |
| C. プッシュで更新 | 既存の push-relay（Firebase Functions → APNs）から更新を通知する | セッション状態の変化を即時に反映できる | relay と APNs の実装が必要。対応 iOS バージョンに制約がある |

推奨: **A を基本にし、到達できる Machine だけ B で補う。** C は「セッションのサマリー」を Live Activity で出す場合に検討する（後述）。

## 表示項目ごとの考慮点

### 1. Bridge 情報

- 表示候補: Machine 名（`name` がなければ `host:port`）、到達可否、稼働時間、セッション数、クライアント数、Bridge バージョンと更新の有無。`/health` と `/version` で取れる。
- **SSH トンネル経由の Machine（`sshEnabled`）は extension から到達できない。** アプリが書き込んだキャッシュを表示し、「最終更新: N 分前」のように鮮度を明示する必要がある。
- `useSsl` と自動判定済みの transport（`hasResolvedTransport`）も共有しないと、extension が URL を組み立てられない。
- Tailscale 経由の場合、VPN は端末全体に効くので extension からも届く。ただし VPN が切れているときは「到達不可」と「Bridge 停止」を区別できない。
- **ローカルネットワーク許可**: LAN 内 IP への通信で、extension の許可がアプリ本体の許可と共有されるかは要検証。extension 側では許可ダイアログを出せない。
- 複数 Bridge の扱い: 1 台だけ表示するのか（ウィジェットごとに設定）、複数台を一覧表示するのか（medium / large サイズ）を決める必要がある。
- デモモードやモック接続中は書き込まない、またはその旨を表示する。

### 2. Claude / Codex の Limit

- データ源は Bridge の `/usage`（`UsageInfoPayload`: provider ごとの `fiveHour` と `sevenDay` の `utilization` と `resetsAt`）。
- **Limit は Bridge ではなくアカウントの値。** 同じアカウントの Bridge が複数あれば値は同じ。アカウントが違えば Bridge ごとに値が異なる。どの Bridge の値かを表示しないと誤解を招く。
- **Bridge 側の負荷**: `fetchCodexUsage` はスナップショットをキャッシュせず、毎回 `CodexProcess` を起動して app-server に問い合わせる。Claude も都度取得する。ウィジェットのポーリングは「Mac 上でプロセスが定期的に起動する」ことを意味するので、Bridge 側に短い TTL のキャッシュを入れるか検討する。
- Claude の値は取得に失敗すると配列から消える（`claude ? [claude, codex] : [codex]`）。「未ログイン」「取得失敗」「Codex のみ利用」を見分けられない。
- 既存の表示モード設定（remaining / used: `settings_usage_display_mode`）と `usage_pace` のロジックを App Group 経由で共有し、アプリと同じ表示にする。
- `resetsAt` までのカウントダウンは `Text(date, style: .relative)` を使えば、タイムラインを更新しなくても進む。
- ロック画面用の accessory サイズ（circular / rectangular）のゲージと相性がよく、最も需要がありそうな項目。

### 3. アクティブなセッションのサマリー

- `/health` で取れるのはセッション数だけ。価値があるのはセッションごとの `status`（`running` / `waiting_approval` / `idle` …）、とくに **`waiting_approval`（承認待ち）**。
- B で取得する場合、セッション一覧を返す HTTP エンドポイントの新設が必要（プロトコル変更）。古い Bridge は 404 を返すので、その場合は A のキャッシュにフォールバックする。新設時は認証を必須にする。
- A なら既存の `SessionListCubit` / `recent_sessions` の結果をアプリが書き込めばよいが、アプリを閉じた後の変化は反映されない。セッションは分単位で状態が変わるので、15〜30 分間隔の更新では古い情報を表示しがち。
- **このユースケースはホームウィジェットより Live Activity（ロック画面と Dynamic Island）のほうが向いている。** 実行中の 1 セッションを push-relay から APNs の Live Activity push で更新すれば、実行中、承認待ち、完了をほぼリアルタイムに出せる（最大 8 時間）。既存の FCM 通知とも役割を分けやすい。
- タップ時は `ccpocket://` のディープリンクで該当セッションを開く。URL スキームは登録済みだが、セッション指定の経路が `deep_link_dispatcher` にあるかは要確認。
- **プライバシー**: `lastMessage` やプロジェクトパスがロック画面やホーム画面に出る。`.privacySensitive()` でロック中は伏せる、表示内容を設定で選べるようにする、といった対応が必要。

## 4. Bridge の切り替え

- ウィジェット自体は接続できないので、「切り替え」は次のどちらかになる。
  1. **ディープリンク**: Machine ごとのボタンから `ccpocket://connect?machine=<id>` でアプリを開き、接続する。iOS 15 でも使えて確実。
  2. **AppIntent ボタン（iOS 17+）**: App Group の「選択中の Machine ID」を書き換え、ウィジェットを再描画する。アプリ側の接続は次回起動時に反映される。
- 2 は「ウィジェットに表示する Machine の切り替え」としては自然だが、アプリの接続も切り替わると期待させる表現は避ける。
- 代わりに **ウィジェットの設定（`AppIntentConfiguration`、長押し →「ウィジェットを編集」）で Machine を選ぶ** 方式もある。Bridge ごとにウィジェットを並べられ、切り替えボタンが要らなくなる。
- `home_widget` パッケージのインタラクティブ callback は Dart のバックグラウンド isolate で動き、制約が多い。切り替えロジックは Swift 側に置くのが無難。

## 認証とセキュリティ

- **現状、`/health` `/version` `/usage` `/doctor` は `API_KEY` を設定していても認証なしで応答する**（`packages/bridge/src/index.ts`）。B の直接取得は今すぐ実装できる一方、これは既存のセキュリティ上の論点でもある。`/usage` はアカウントの利用状況、`/doctor` は環境情報を、到達できる誰にでも返す。
- Bridge の API キー必須化（`docs/bridge-auth-required.md`）を見据え、ウィジェットからのリクエストには最初から `Authorization` を付ける。そのためには extension が API キーを読める必要があり、`keychain-access-groups` の共有設定（現在は両 entitlements とも空）と `flutter_secure_storage` の accessGroup 指定が要る。既存キーの移行も考慮する。
- A だけで済ませれば、extension に認証情報を渡さずに済む。

## ビルド・配布の考慮点（見落としやすい部分）

- Xcode に Widget Extension ターゲットを追加し、App Group を `Runner.entitlements` と `RunnerRelease.entitlements` の両方に設定する。extension 用の App ID とプロビジョニングプロファイルも必要（`release-app` スキルの署名手順を更新）。
- **Shorebird の OTA パッチは Dart のみ対象。** Swift 側のウィジェット変更は毎回ストアリリースが必要になる。表示ロジックをできるだけ Swift の薄い描画層に留め、整形済みのデータをアプリから渡す設計にすると、OTA で直せる範囲が広がる。
- デプロイメントターゲットは iOS 15.0。WidgetKit 自体は使えるが、インタラクティブウィジェット（17+）、`containerBackground`（17+ で必須）、Control Center コントロール（18+）は `if #available` で分岐する。最低バージョンを上げるかどうかも判断材料になる。
- ローカライズ: ウィジェット用の文字列を ja / en / ko / zh-Hans で別途用意する（既存の lproj は Runner 用のみ）。
- extension 用の `PrivacyInfo.xcprivacy`（UserDefaults の利用理由など）と、App Store 掲載のスクリーンショット・説明文の更新。
- CI と worktree: ネイティブビルドはメインのチェックアウトでのみ行う運用なので、ウィジェットの検証はシミュレーターでの手動確認が中心になる。SwiftUI Preview とスナップショットテストの導入を検討する。
- Android: 将来 Glance ウィジェットを作る可能性を考え、スナップショットのスキーマ（JSON）はプラットフォーム非依存にする。

## UI と状態の網羅

- サイズ: small（1 Bridge + Limit の要約）/ medium（Bridge + Limit 2 本 + 承認待ちの件数）/ large（セッション一覧）/ accessory（ロック画面の Limit ゲージ）。
- 状態: 未設定（Machine 未登録）、未選択、到達不可、認証エラー、古い Bridge（エンドポイントなし）、取得失敗、デモ、データの古さ（`N 分前`）。
- ダークモード、tinted / clear のアイコン表示（iOS 18+ のホーム画面の色付け）、StandBy 表示。

## 段階案

1. **MVP**: A 方式。Limit と選択中 Bridge の概要（small / medium / accessory）。ウィジェット設定で Machine を選択。タップでアプリを開く。Bridge の変更なし。
2. **直接取得**: 到達できる Machine は B で更新する。Keychain を共有して `Authorization` を付ける。Bridge 側に usage のキャッシュを追加する。
3. **セッション**: Live Activity で実行中と承認待ちを表示（push-relay を拡張）。必要ならセッション一覧の HTTP エンドポイントを新設する（互換方針をこの文書に追記）。

## 要判断事項

- セッションのサマリーはホームウィジェットと Live Activity のどちらで出すか（または両方か）
- データ取得は A のみか、B も入れるか（API キー共有の要否が変わる）
- ロック画面やホーム画面にセッション名や最後のメッセージを出してよいか（伏せる場合の既定値）
- 切り替えはウィジェット設定、AppIntent ボタン、ディープリンクのどれにするか
- 最低 iOS バージョンを 17 に上げる余地はあるか
- `/usage` などが認証なしで応答する現状を、ウィジェットとは別に先に直すか
