#!/usr/bin/env python3
"""Validate generated store image formats, locale parity, and metadata limits."""
from pathlib import Path
import struct
import re
base=Path(__file__).resolve().parents[2] / 'apps/mobile/fastlane'
build=re.search(r'^version: .*\+(\d+)$', (base.parent/'pubspec.yaml').read_text(), re.M).group(1)
locales={'en-US':'en-US','ja':'ja-JP','zh-Hans':'zh-CN','ko':'ko-KR'}
count=0
for ios,android in locales.items():
 shots=sorted((base/'screenshots/store'/ios).glob('*.png'))
 assert len(shots)==13,(ios,len(shots))
 for p in shots:
  data=p.read_bytes();w,h,depth,color=struct.unpack('>IIBB',data[16:26])
  assert (w,h)==((2752,2064) if p.name.startswith('ipad_') else (1320,2868)),p
  assert color in [0,2,3],(p,'alpha channel',color)
  if not p.name.startswith('ipad_'):
   q=base/'metadata/android'/android/'images/phoneScreenshots'/p.name
   assert q.read_bytes()==data,p
  count+=1
 for filename,limit in [('name.txt',30),('subtitle.txt',30),('promotional_text.txt',170),('description.txt',4000),('release_notes.txt',4000)]:
  text=(base/'metadata'/ios/filename).read_text()
  assert text.strip() and len(text)<=limit,(ios,filename,len(text))
 for filename,limit in [('title.txt',30),('short_description.txt',80),('full_description.txt',4000),(f'changelogs/{build}.txt',500)]:
  text=(base/'metadata/android'/android/filename).read_text()
  assert text.strip() and len(text)<=limit,(android,filename,len(text))
 q=base/'metadata/android'/android/'images/featureGraphic.png';data=q.read_bytes()
 assert struct.unpack('>II',data[16:24])==(1024,500)
 assert data[25] in [0,2,3]
print(f'PASS: {count} App Store images, 32 identical Android images, 4 feature graphics; dimensions, no alpha, and all metadata limits.')
