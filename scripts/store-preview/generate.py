#!/usr/bin/env python3
"""Build a local, read-only review page for the README and store assets."""
import argparse
import html
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / 'apps/mobile/fastlane/metadata'
SHOTS = ROOT / 'apps/mobile/fastlane/screenshots/store'
LOCALES = [('ja', 'ja-JP', 'README.ja.md', '日本語', 'screenshots-ja.png'),
           ('en-US', 'en-US', 'README.md', 'English', 'screenshots.png'),
           ('zh-Hans', 'zh-CN', 'README.zh-CN.md', '简体中文', 'screenshots-zh-CN.png'),
           ('ko', 'ko-KR', 'README.ko.md', '한국어', 'screenshots-ko.png')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('/private/tmp/ccpocket-mint-review'))
    args = parser.parse_args()
    out = args.output.resolve()
    if out == ROOT or ROOT in out.parents:
        parser.error('Use a temporary output directory outside the repository.')
    out.mkdir(parents=True, exist_ok=True)
    (out / 'assets').mkdir(exist_ok=True)
    submission = Path(__file__).with_name('submission.md')
    if submission.exists():
        shutil.copyfile(submission, out / 'submission.txt')

    def asset(path):
        filename = '-'.join(path.relative_to(ROOT).parts)
        shutil.copyfile(path, out / 'assets' / filename)
        return 'assets/' + filename

    def text(path):
        return html.escape(path.read_text().strip())

    def field(label, path, limit=None):
        value = path.read_text().strip()
        count = f'{len(value)} / {limit}文字' if limit else f'{len(value)}文字'
        return f'<div class="field"><h3>{label} <small>{count}</small></h3><pre>{html.escape(value)}</pre></div>'

    sections = []
    for locale, android, readme, label, banner in LOCALES:
        cards = []
        for p in sorted((SHOTS / locale).glob('*.png')):
            src = asset(p)
            cards.append(f'<a href="{src}" target="_blank"><img loading="lazy" src="{src}" alt="{p.stem}"><span>{p.stem}</span></a>')
        banner_src = asset(ROOT / 'docs/images' / banner)
        graphic_src = asset(META / 'android' / android / 'images/featureGraphic.png')
        sections.append(f'''<section id="{locale}" class="locale" {'hidden' if locale != 'ja' else ''}>
<h2>{label}</h2><h3>README</h3><img class="banner" src="{banner_src}" alt="README banner">
<p><a href="https://github.com/K9i-0/ccpocket/blob/feat/mint-readme-store/{readme}" target="_blank">GitHubでREADMEを見る ↗</a></p>
<details><summary>READMEの全文</summary><pre>{text(ROOT/readme)}</pre></details>
<h3>スマホ8枚・iPad5枚</h3><p>画像をクリックすると原寸で開きます。Androidには同じスマホ8枚を使用します。</p>
<div class="gallery">{''.join(cards[:8])}</div><div class="gallery tablet">{''.join(cards[8:])}</div>
<h3>Google Play フィーチャーグラフィック</h3><img class="graphic" src="{graphic_src}" alt="Feature graphic">
<h3>App Store</h3>{field('名前',META/locale/'name.txt',30)}{field('サブタイトル',META/locale/'subtitle.txt',30)}{field('プロモーション文',META/locale/'promotional_text.txt',170)}{field('説明文',META/locale/'description.txt',4000)}
<h3>Google Play</h3>{field('短い説明',META/'android'/android/'short_description.txt',80)}{field('説明文',META/'android'/android/'full_description.txt',4000)}
<h3>1.127.2（244）のリリースノート — 両ストア共通</h3>{field('変更点',META/locale/'release_notes.txt',500)}
</section>''')
    page = '''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CC Pocket — ストア更新の確認</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101212;color:#f3f5f4;font:16px/1.8 system-ui,sans-serif}main{max-width:1280px;margin:auto;padding:48px 24px 100px}h1{font-size:clamp(28px,5vw,48px);line-height:1.25}h2{color:#9bddc5}h3{margin-top:36px}p,small{color:#a6b0ad}a{color:#9bddc5}button{background:#1e2825;color:#eee;border:1px solid #456157;border-radius:24px;padding:12px 24px;cursor:pointer}button[aria-pressed=true]{background:#9bddc5;color:#10271f}nav{display:flex;gap:10px;flex-wrap:wrap;position:sticky;top:0;padding:15px 0;background:#101212;z-index:1}.banner{max-width:100%;width:900px}.graphic{max-width:100%;width:768px}.gallery{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px}.gallery img{width:100%;border:1px solid #28342f;border-radius:8px}.gallery span{font:12px system-ui;color:#a6b0ad}.gallery a{text-decoration:none}.tablet{margin-top:28px;grid-template-columns:repeat(2,minmax(0,1fr))}.field,details,.note{background:#17201d;border:1px solid #2a3932;border-radius:12px;padding:20px;margin:20px 0}.field h3{margin:0 0 12px}.field small{font-size:12px;font-weight:normal}pre{font:15px/1.9 system-ui,sans-serif;white-space:pre-wrap;overflow-wrap:anywhere}summary{cursor:pointer}.note strong{color:#9bddc5}@media(max-width:650px){.gallery{grid-template-columns:repeat(2,minmax(0,1fr))}.tablet{grid-template-columns:1fr}main{padding:24px 16px}button{padding:10px 16px}}</style>
<main><p>CC POCKET / REVIEW</p><h1>READMEとストアを、<br>Mintのスタイルに。</h1>
<div class="note"><strong>確認待ち — ストアへの反映・審査提出はまだ実行していません。</strong><p>提出候補：iOS / Android とも 1.127.1（243）→ 1.127.2（244）。既存ビルドを使います。iOSの公開方式はKEEP（現在設定を維持、新規バージョンなら手動公開）、審査対象はアプリバージョンのみ。Androidは承認後100%公開（Managed publishing有効時は別途手動公開）。</p><p>確認後、説明文・スクショ・Google Play画像を反映し、審査提出を続けて実行します。<a href="submission.txt" target="_blank">提出内容・対象ref・SHA・全言語リリースノート</a></p><p><a href="https://github.com/K9i-0/ccpocket/actions/runs/33927390316">iOS候補ビルド成功</a> · <a href="https://github.com/K9i-0/ccpocket/actions/runs/33927396035">Android候補ビルド成功</a></p></div>
<nav>'''+''.join(f'<button data-lang="{l}" aria-pressed="{str(l=="ja").lower()}">{label}</button>' for l,_,_,label,_ in LOCALES)+'''</nav>'''+''.join(sections)+'''
<script>document.querySelectorAll('[data-lang]').forEach(b=>b.onclick=()=>{document.querySelectorAll('.locale').forEach(s=>s.hidden=s.id!==b.dataset.lang);document.querySelectorAll('[data-lang]').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false'))});</script></main></html>'''
    (out / 'index.html').write_text(page)
    print(out / 'index.html')


if __name__ == '__main__':
    main()
