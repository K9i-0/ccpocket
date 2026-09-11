---
name: update-store
description: ccpocketのストア掲載用スクリーンショットや説明文・リリースノートを作成・更新するときに使う。
---

# Update Store

依頼されたストア素材を更新する。対象・言語・デバイスが指定済みなら再質問しない。不足情報が成果物に影響するときだけ確認する。

- 説明文・リリースノート等: [references/metadata.md](references/metadata.md)。文章だけの更新にシミュレーターは不要。
- スクリーンショット撮影・合成: [references/screenshots.md](references/screenshots.md)。必要なデバイスの節を使い、既存シミュレーターを再利用する。
- 審査提出まで依頼されている場合: [../submit-store-review/SKILL.md](../submit-store-review/SKILL.md) の対象選択・累積差分・提出境界に従う。

更新内容は対象バージョンのCHANGELOGと実装差分に基づける。審査用のリリースノートは公開版からの累積差分を使う。

文章は内容・対象言語を、画像は生成後の見た目・解像度・配置先を検証し、修正が必要なら再生成する。素材作成の依頼だけでストアへのアップロードや審査提出まで広げない。
