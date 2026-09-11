# メタデータ更新

**メタデータテキスト:**

| ファイル | 対象 |
|---------|------|
| `fastlane/metadata/en-US/release_notes.txt` | iOS リリースノート (EN) |
| `fastlane/metadata/ja/release_notes.txt` | iOS リリースノート (JA) |
| `fastlane/metadata/en-US/description.txt` | App Store 説明文 (EN) |
| `fastlane/metadata/ja/description.txt` | App Store 説明文 (JA) |
| `fastlane/metadata/en-US/promotional_text.txt` | プロモーションテキスト (EN) |
| `fastlane/metadata/android/en-US/full_description.txt` | Play Store 説明文 (EN) |
| `fastlane/metadata/android/ja-JP/full_description.txt` | Play Store 説明文 (JA) |
| `fastlane/metadata/android/en-US/changelogs/default.txt` | Play Store リリースノート (EN) |
| `fastlane/metadata/android/ja-JP/changelogs/default.txt` | Play Store リリースノート (JA) |

上記のファイルパスは `apps/mobile/` からの相対パス。

### Step 3: メタデータテキスト更新（選択された場合）

対象バージョンのCHANGELOGと実装差分をベースに:
- **release_notes** — 対象版の変更を簡潔にまとめる。審査用は公開版からの累積差分を使う
- **description** — 新機能に応じて追記・修正
- **promotional_text** — キャッチコピーを更新

指定された内容をローカルファイルに反映し、変更を提示する。既に指定済みの内容について再確認しない。
