# iOSの写真への保存

画像・動画の「写真に保存」は共有シートとは別の操作。Flutterから
`ccpocket/photo_library` の `save` を呼び、iOSのPhotoKitでライブラリへ追加する。

- 権限は `.addOnly`。既存写真の読み取りは行わない。
- メモリ上の画像は `bytes`、ダウンロード済みの画像・動画は `path` を渡す。
  動画は `isVideo: true` とし、Dartのメモリへ全体を読み込まない。
- PhotoKitの完了コールバック後に成功を返し、その後に一時ファイルを削除する。
- `permission_denied` は設定で追加を許可する案内、それ以外は保存失敗として表示。
- 元の形式を維持する。SVGの保存ボタンは表示せず、その他の形式や動画コーデックは
  PhotoKitの対応範囲に従う。形式変換はしない。
- ファイルプレビューは既存のファイル転送経路を再利用する。Bridgeプロトコルの追加はなく、
  古いBridgeの更新案内、進捗、ダウンロード中のキャンセルも既存処理を使う。
- iOS以外には写真保存ボタンを表示しない。既存の共有操作は維持する。
- Git画像差分の書き出し対象は既定で変更後。変更前も選択できる。削除ファイルは変更前を使う。

SwiftとInfo.plistの変更を含むため、新しいiOSアプリビルドが必要。
DartのみのOTAでは配布できない。

参考: [Apple PhotoKit](https://developer.apple.com/documentation/photos/phphotolibrary)
