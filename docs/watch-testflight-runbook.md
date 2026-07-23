# Apple Watch Internal TestFlight Runbook

Apple Watch版は一般公開せず、Internal TestFlightでドッグフーディングする。
通常のiOSリリースとWatch検証ビルドを同じソースから作りつつ、配布物を明確に分離する。

## 配布ポリシー

| ビルド経路 | Watch同梱 | 用途 |
|---|---:|---|
| ローカル Debug | Yes | シミュレーター・Xcode実機開発 |
| `Apple Watch Internal TestFlight` | Yes | Watch実機ドッグフーディング |
| `iOS Release (Shorebird)` | No | 一般向けiPhone/iPadリリース |
| `iOS Patch (Shorebird)` | No | 一般向けiPhone/iPad OTAパッチ |

通常のXcodeプロジェクトはWatchターゲットを含む。Internal TestFlightワークフローは
そのままビルドするため、Watch AppとWidgetがIPAへ同梱される。

一般向けのRelease/Patchワークフローは、CIの一時チェックアウトに対して
`scripts/configure-ios-watch-payload.rb exclude`を実行し、RunnerからWatchの
embed dependencyを外してWatchターゲットを削除してからビルドする。
この変更はCI内だけで行われ、リポジトリのXcodeプロジェクトには反映されない。

`scripts/verify-ios-watch-payload.sh` が成果物を検査するため、設定の意図しない
変更によって一般向けIPAへWatchアプリが混入するとCI/CDが失敗する。

## iPhone単体での安全性

iPhone側の`WatchConnectivity` relayは、Apple Watchが次の両方を満たす場合だけ
application contextを送信する。

- iPhoneとペアリング済み
- ccpocket Watchアプリがインストール済み

Watchがない、未ペア、またはWatchアプリ未インストールの場合は送信をno-opにする。
iPhone側のBridge接続、セッション一覧、通知、課金などの既存機能には依存しない。

一般向けRelease IPAにはWatchアプリ自体が含まれないが、iPhone側のrelayコードは
残る。これは将来TestFlight版Watchを同じFlutterコードから作るためで、未ペア環境では
上記のguardにより外部通信を行わない。

## 初回だけ必要なApp Store Connect設定

既存のGitHub Actions secretsを利用する。

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `CERTIFICATE_PRIVATE_KEY`
- `GOOGLE_SERVICE_INFO_PLIST_BASE64`
- `REVENUECAT_PUBLIC_KEY_IOS`
- `SHOREBIRD_TOKEN`

Apple Developer側に次のIdentifierとApp Groupが存在することを確認する。

- `com.k9i.ccpocket`
- `com.k9i.ccpocket.watchkitapp`
- `com.k9i.ccpocket.watchkitapp.widget`
- `group.com.k9i.ccpocket`

App Store ConnectのTestFlightで内部グループ（例: `Apple Watch Dogfood`）を作り、
自分をInternal Testerとして追加する。通常のiPhone-only buildも同じApp recordへ
アップロードされるため、そのグループの自動配信は無効にする。

## アップロード

1. mainが検証済みであることを確認する。
2. GitHubのActionsを開く。
3. `Apple Watch Internal TestFlight`を選ぶ。
4. `Run workflow`でmainを指定して実行する。main以外ではjobが実行されない。
5. ワークフローが成功した後、App Store Connectでprocessing完了を待つ。
6. 対象のWatch buildだけを`Apple Watch Dogfood`内部グループへ手動追加する。

ワークフローは次を自動実行する。

1. Dart解析とFlutterテスト
2. iOS native unit tests
3. iPhone、Watch App、WidgetのApp Store署名取得
4. Watch同梱Release IPAの作成
5. Watch App、Widget、App Group、production push entitlementの検査
6. TestFlightへのアップロード

build numberはpubspecのbuild numberを基準に、GitHub Actionsのrun numberと
run attemptから自動生成する。ワークフローの再実行でも同じbuild numberを
再利用しない。

## 実機へのインストール

1. iPhoneのTestFlightで対象ビルドをインストールする。
2. iPhoneのWatchアプリを開く。
3. `利用可能なApp`からccpocketをインストールする。
4. ccpocketのiPhoneアプリを一度起動し、Bridgeへ接続する。
5. Watchアプリを起動してセッションsnapshotを確認する。
6. 文字盤編集から`Session Summary` complicationを追加する。

TestFlight経由ではXcodeのデバイストンネルを使わないため、インストール確認と
継続利用をXcodeの接続状態から切り離せる。LLDB、SwiftUI preview、開発ログの
リアルタイム取得が必要な場合だけXcode Debugを使う。

## 一般向けリリース時の注意

`iOS Release (Shorebird)`はWatch payloadが存在しないことを検証してから
TestFlightへアップロードする。

Watch機能をmainへ初めてマージした後は、iOSのnativeコードが変わるため、最初に
通常のiOSフルリリースを作成する。Watch機能を含まない過去のiOS releaseへ
Shorebird patchを作成しない。以後のローカルiOS patchスクリプトは、Xcode projectを
一時的にiPhone-onlyへ変更し、終了時に復元する。native差分が残る場合は失敗させる。

App Store審査へ提出するときは、`Apple Watch Internal TestFlight`が作成した
ドッグフーディングbuildではなく、通常の`ios/v*`タグから作成されたbuildを選ぶ。
Watchドッグフーディングbuildを一般公開へ昇格しない。

## ローカル検証

Debugは常にWatchを含む。

通常のローカルビルドはWatchを含む。

```bash
(cd apps/mobile && flutter build ipa --release)
set -- apps/mobile/build/ios/ipa/*.ipa
test "$#" -eq 1
bash scripts/verify-ios-watch-payload.sh included "$1"
```

一般向けiPhone-onlyビルドはXcodeプロジェクトを書き換えるため、作業中の
チェックアウトではなく一時worktreeや使い捨てcheckoutで検証する。

```bash
ruby scripts/configure-ios-watch-payload.rb exclude
(cd apps/mobile && flutter build ipa --release)
set -- apps/mobile/build/ios/ipa/*.ipa
test "$#" -eq 1
bash scripts/verify-ios-watch-payload.sh excluded "$1"
```

## ロールバック

Watch機能に問題がある場合は、Internal TestFlightグループから対象buildを外すか
buildをexpireする。一般向けiOSビルドはWatch payloadを含まないため、Watch側の
停止がiPhoneアプリのリリースやShorebird patchを妨げない。
