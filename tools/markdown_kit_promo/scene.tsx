import React from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {clamp, interpolate, settle, spring} from 'kasaneru/anim';

export const css = `
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
#root {
  width: 1920px;
  height: 1080px;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", "Helvetica Neue", Arial, sans-serif;
  font-synthesis: none;
  -webkit-font-smoothing: antialiased;
  text-rendering: geometricPrecision;
}
code, .mono {
  font-family: "SF Mono", "JetBrains Mono", Menlo, Monaco, Consolas, monospace;
}
`;

interface Timeline {
  fps: number;
  durationInFrames: number;
  heroEnd: number;
  mobileStart: number;
  selectionStart: number;
  mobileDarkFrame: number;
  editorStart: number;
  editorDarkFrame: number;
  showcaseStart: number;
  outroStart: number;
}

interface Props {
  timeline: Timeline;
}

interface SubtitleCue {
  from: number;
  to: number;
  text: string;
}

// Short, mobile-readable 1-line subtitle cues synced to measured WAV speech boundaries @ 30fps
const SUBTITLES: SubtitleCue[] = [
  {from: 8, to: 108, text: 'Meet markdown_kit — AI chat Markdown for Flutter.'},
  {from: 132, to: 200, text: 'When agents stream token by token,'},
  {from: 201, to: 243, text: 'finished blocks build once,'},
  {from: 244, to: 367, text: 'while unfinished syntax stays held back — zero flicker.'},
  {from: 472, to: 570, text: 'Drag touch handles across lists, code, and tables.'},
  {from: 572, to: 645, text: 'Scroll freely and your highlight stays anchored.'},
  {from: 647, to: 705, text: 'Copy plain text or Markdown.'},
  {from: 814, to: 872, text: 'Built-in dark theme included.'},
  {from: 904, to: 983, text: 'On desktop, it drives a live-preview editor.'},
  {from: 985, to: 1058, text: 'Every keystroke re-parses only the active block'},
  {from: 1059, to: 1124, text: 'in under half a millisecond.'},
  {from: 1200, to: 1287, text: 'Source and preview scroll in sync, block by block.'},
  {from: 1289, to: 1344, text: 'Tap any block to jump to its source,'},
  {from: 1345, to: 1400, text: 'and switch to dark mode instantly.'},
  {from: 1476, to: 1522, text: 'Pure Flutter widgets only —'},
  {from: 1523, to: 1624, text: 'slivers, alerts, math, custom rules, and RTL.'},
  {from: 1644, to: 1701, text: 'Battle-tested in CC Pocket.'},
  {from: 1703, to: 1762, text: 'Try the live web demo today.'},
];

function mixHex(a: string, b: string, t: number): string {
  const k = clamp(t, 0, 1);
  const pa = [parseInt(a.slice(1, 3), 16), parseInt(a.slice(3, 5), 16), parseInt(a.slice(5, 7), 16)];
  const pb = [parseInt(b.slice(1, 3), 16), parseInt(b.slice(3, 5), 16), parseInt(b.slice(5, 7), 16)];
  const r = Math.round(pa[0] + (pb[0] - pa[0]) * k);
  const g = Math.round(pa[1] + (pb[1] - pa[1]) * k);
  const bl = Math.round(pa[2] + (pb[2] - pa[2]) * k);
  return `rgb(${r}, ${g}, ${bl})`;
}

function darkAmount(f: number, tl: Timeline): number {
  if (f < tl.mobileDarkFrame) return 0;
  if (f < tl.editorStart - 6) {
    return interpolate(f, [tl.mobileDarkFrame, tl.mobileDarkFrame + 14], [0, 1], 'outCubic');
  }
  if (f < tl.editorStart + 10) {
    return interpolate(f, [tl.editorStart - 6, tl.editorStart + 6], [1, 0], 'outCubic');
  }
  if (f < tl.editorDarkFrame) return 0;
  return interpolate(f, [tl.editorDarkFrame, tl.editorDarkFrame + 14], [0, 1], 'outCubic');
}

function sectionFade(f: number, start: number, end: number, fadeIn = 8, fadeOut = 8): number {
  const i = fadeIn > 0 ? interpolate(f, [start, start + fadeIn], [0, 1], 'outCubic') : 1;
  const o = fadeOut > 0 ? interpolate(f, [end - fadeOut, end], [1, 0], 'outCubic') : 1;
  return clamp(Math.min(i, o), 0, 1);
}

function themeColors(dark: number) {
  return {
    bgTop: mixHex('#f5f8fc', '#0b1120', dark),
    bgBottom: mixHex('#eaf0f8', '#0f172a', dark),
    text: mixHex('#0f172a', '#f8fafc', dark),
    sub: mixHex('#475569', '#cbd5e1', dark),
    muted: mixHex('#64748b', '#94a3b8', dark),
    accent: mixHex('#1f6feb', '#58a6ff', dark),
    gridDot: dark > 0.5 ? 'rgba(148, 163, 184, 0.10)' : 'rgba(15, 23, 42, 0.06)',
    winBar: mixHex('#eef2f6', '#161b22', dark),
    winBorder: dark > 0.5 ? 'rgba(148, 163, 184, 0.22)' : 'rgba(15, 23, 42, 0.14)',
    winTitle: mixHex('#475569', '#94a3b8', dark),
  };
}

interface IPhoneSpec {
  screenX: number;
  screenY: number;
  screenW: number;
  screenH: number;
  statusH: number;
  homeH: number;
  bezel: number;
  screenRadius: number;
}

const HERO_IPHONE: IPhoneSpec = {
  screenX: 816,
  screenY: 224,
  screenW: 294,
  screenH: 696, // 34 (status) + 640 (video) + 22 (home) -> bottom edge 931 (clean gap above 38px subtitle)
  statusH: 34,
  homeH: 22,
  bezel: 11,
  screenRadius: 34,
};

const MAIN_IPHONE: IPhoneSpec = {
  screenX: 204,
  screenY: 48,
  screenW: 374,
  screenH: 882, // 44 (status) + 814 (video) + 24 (home) -> bottom edge 944 (clean gap above 38px subtitle)
  statusH: 44,
  homeH: 24,
  bezel: 14,
  screenRadius: 42,
};

const MacWindowChrome: React.FC<{
  x: number;
  y: number;
  width: number;
  height: number;
  barHeight: number;
  title: string;
  dark: number;
  opacity?: number;
}> = ({x, y, width, height, barHeight, title, dark, opacity = 1}) => {
  const c = themeColors(dark);
  return (
    <div
      style={{
        position: 'absolute',
        left: x - 2,
        top: y - 2,
        width: width + 4,
        height: height + 4,
        borderRadius: 14,
        background: c.winBar,
        border: `1.5px solid ${c.winBorder}`,
        boxShadow:
          dark > 0.5
            ? '0 28px 70px rgba(0, 0, 0, 0.55), 0 4px 16px rgba(0, 0, 0, 0.35)'
            : '0 24px 64px rgba(15, 23, 42, 0.14), 0 4px 14px rgba(15, 23, 42, 0.06)',
        opacity,
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          height: barHeight,
          padding: '0 16px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: `1px solid ${c.winBorder}`,
        }}
      >
        <div style={{display: 'flex', gap: 8, alignItems: 'center'}}>
          <span style={{width: 11, height: 11, borderRadius: '50%', background: '#ff5f57', display: 'inline-block'}} />
          <span style={{width: 11, height: 11, borderRadius: '50%', background: '#febc2e', display: 'inline-block'}} />
          <span style={{width: 11, height: 11, borderRadius: '50%', background: '#28c840', display: 'inline-block'}} />
        </div>
        <div className="mono" style={{fontSize: 13.5, fontWeight: 500, color: c.winTitle}}>
          {title}
        </div>
        <div style={{width: 48}} />
      </div>
    </div>
  );
};

const IPhoneChassis: React.FC<{
  spec: IPhoneSpec;
  appDark: boolean;
  studioDark: number;
  opacity?: number;
}> = ({spec, appDark, studioDark, opacity = 1}) => {
  const {screenX, screenY, screenW, screenH, statusH, homeH, bezel, screenRadius} = spec;
  const outerW = screenW + bezel * 2;
  const outerH = screenH + bezel * 2;
  const outerR = screenRadius + bezel - 1;
  const scale = screenW / 386;
  const chromeBg = appDark ? '#161b22' : '#f6f8fa';
  const bodyBg = appDark ? '#0d1117' : '#ffffff';

  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - bezel,
        top: screenY - bezel,
        width: outerW,
        height: outerH,
        borderRadius: outerR,
        background: 'linear-gradient(155deg, #3c424d 0%, #1d2129 22%, #13161c 68%, #2e3440 100%)',
        padding: 2.5,
        boxShadow:
          studioDark > 0.5
            ? '0 36px 88px rgba(0, 0, 0, 0.72), 0 12px 28px rgba(0, 0, 0, 0.50)'
            : '0 34px 80px rgba(15, 23, 42, 0.30), 0 10px 24px rgba(15, 23, 42, 0.14)',
        opacity,
      }}
    >
      <div
        style={{
          width: '100%',
          height: '100%',
          borderRadius: outerR - 2.5,
          background: '#0b0d11',
          border: '1px solid rgba(255, 255, 255, 0.14)',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: bezel - 3.5,
            top: bezel - 3.5,
            width: screenW,
            height: screenH,
            borderRadius: screenRadius,
            background: bodyBg,
            overflow: 'hidden',
          }}
        >
          <div style={{width: '100%', height: statusH + 2, background: chromeBg}} />
          <div
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              bottom: 0,
              height: homeH + 2,
              background: bodyBg,
            }}
          />
        </div>
      </div>

      {/* Hardware side buttons */}
      <div
        style={{
          position: 'absolute',
          right: -3.5,
          top: Math.round(212 * scale),
          width: 3.5,
          height: Math.round(78 * scale),
          borderRadius: '0 2.5px 2.5px 0',
          background: 'linear-gradient(180deg, #4b5260 0%, #242933 50%, #3d4350 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -3.5,
          top: Math.round(138 * scale),
          width: 3.5,
          height: Math.round(28 * scale),
          borderRadius: '2.5px 0 0 2.5px',
          background: 'linear-gradient(180deg, #4b5260 0%, #242933 50%, #3d4350 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -3.5,
          top: Math.round(188 * scale),
          width: 3.5,
          height: Math.round(54 * scale),
          borderRadius: '2.5px 0 0 2.5px',
          background: 'linear-gradient(180deg, #4b5260 0%, #242933 50%, #3d4350 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -3.5,
          top: Math.round(254 * scale),
          width: 3.5,
          height: Math.round(54 * scale),
          borderRadius: '2.5px 0 0 2.5px',
          background: 'linear-gradient(180deg, #4b5260 0%, #242933 50%, #3d4350 100%)',
        }}
      />
    </div>
  );
};

const IPhoneScreenOverlay: React.FC<{
  spec: IPhoneSpec;
  appDark: boolean;
  opacity?: number;
}> = ({spec, appDark, opacity = 1}) => {
  const {screenX, screenY, screenW, screenH, statusH, homeH, bezel, screenRadius} = spec;
  const s = screenW / 386;
  const fg = appDark ? '#f8fafc' : '#0f172a';
  const islandW = Math.round(108 * s);
  const islandH = Math.round(28 * s);
  const islandTop = Math.round((statusH - islandH) / 2);
  const lensD = Math.round(11 * s);
  const homeBarW = Math.round(134 * s);
  const homeBarH = Math.max(4, Math.round(5 * s));

  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - bezel,
        top: screenY - bezel,
        width: screenW + bezel * 2,
        height: screenH + bezel * 2,
        opacity,
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 3,
          borderRadius: screenRadius + bezel - 4,
          border: `${bezel - 3}px solid #0b0d11`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: bezel,
          top: bezel,
          width: screenW,
          height: screenH,
          borderRadius: screenRadius,
          boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.08)',
        }}
      />

      {/* iOS Status Bar (9:41 + Dynamic Island + Cellular / Wi-Fi / Battery) */}
      <div
        style={{
          position: 'absolute',
          left: bezel,
          top: bezel,
          width: screenW,
          height: statusH,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: `0 ${Math.round(24 * s)}px`,
        }}
      >
        <div
          style={{
            width: Math.round(64 * s),
            fontSize: Number((14.5 * s).toFixed(1)),
            fontWeight: 700,
            color: fg,
            letterSpacing: '-0.02em',
            fontVariantNumeric: 'tabular-nums',
            textAlign: 'left',
          }}
        >
          9:41
        </div>

        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: islandTop,
            transform: 'translateX(-50%)',
            width: islandW,
            height: islandH,
            borderRadius: 999,
            background: '#050608',
            boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.07)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            paddingRight: Math.round(9 * s),
          }}
        >
          <div
            style={{
              width: lensD,
              height: lensD,
              borderRadius: '50%',
              background: 'radial-gradient(circle at 35% 35%, #2c4a7c 0%, #0d1526 55%, #04060a 100%)',
              border: '1px solid rgba(148, 163, 184, 0.16)',
            }}
          />
        </div>

        <div style={{display: 'flex', alignItems: 'center', gap: Math.round(6 * s)}}>
          <svg width={Math.round(17 * s)} height={Math.round(12 * s)} viewBox="0 0 17 12" fill="none">
            <rect x="0.5" y="8" width="2.8" height="3.5" rx="0.8" fill={fg} />
            <rect x="4.8" y="5.8" width="2.8" height="5.7" rx="0.8" fill={fg} />
            <rect x="9.1" y="3.3" width="2.8" height="8.2" rx="0.8" fill={fg} />
            <rect x="13.4" y="0.8" width="2.8" height="10.7" rx="0.8" fill={fg} />
          </svg>
          <svg width={Math.round(16 * s)} height={Math.round(12 * s)} viewBox="0 0 16 12" fill="none">
            <path d="M1.2 3.8C4.9 0.5 11.1 0.5 14.8 3.8" stroke={fg} strokeWidth="1.65" strokeLinecap="round" />
            <path d="M3.7 6.5C6.1 4.4 9.9 4.4 12.3 6.5" stroke={fg} strokeWidth="1.65" strokeLinecap="round" />
            <circle cx="8" cy="10" r="1.45" fill={fg} />
          </svg>
          <svg width={Math.round(25 * s)} height={Math.round(12 * s)} viewBox="0 0 25 12" fill="none">
            <rect
              x="0.75"
              y="0.75"
              width="20.5"
              height="10.5"
              rx="3"
              stroke={fg}
              strokeOpacity="0.45"
              strokeWidth="1.2"
            />
            <rect x="2.4" y="2.4" width="17.2" height="7.2" rx="1.6" fill={fg} />
            <path
              d="M22.8 4.2C23.5 4.4 24 5.1 24 6C24 6.9 23.5 7.6 22.8 7.8V4.2Z"
              fill={fg}
              fillOpacity="0.5"
            />
          </svg>
        </div>
      </div>

      {/* Bottom iOS Home Indicator */}
      <div
        style={{
          position: 'absolute',
          left: bezel,
          top: bezel + screenH - homeH,
          width: screenW,
          height: homeH,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div
          style={{
            width: homeBarW,
            height: homeBarH,
            borderRadius: 999,
            background: fg,
            opacity: appDark ? 0.85 : 0.82,
          }}
        />
      </div>
    </div>
  );
};

/**
 * Mobile-readable yet understated narration subtitle pill (38px on 1080p ≈ 7.8pt on a 390pt phone feed).
 */
const SubtleSubtitle: React.FC<{frame: number; dark: number}> = ({frame, dark}) => {
  const cue = SUBTITLES.find((c) => frame >= c.from && frame <= c.to);
  if (!cue) return null;
  const op = Math.min(
    interpolate(frame, [cue.from, cue.from + 4], [0, 1], 'outCubic'),
    interpolate(frame, [cue.to - 4, cue.to], [1, 0], 'outCubic')
  );
  return (
    <div
      style={{
        position: 'absolute',
        left: 64,
        right: 64,
        bottom: 20,
        display: 'flex',
        justifyContent: 'center',
        opacity: op,
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          padding: '11px 30px',
          borderRadius: 999,
          background: dark > 0.5 ? 'rgba(15, 23, 42, 0.84)' : 'rgba(15, 23, 42, 0.80)',
          border: dark > 0.5 ? '1.5px solid rgba(148, 163, 184, 0.28)' : '1.5px solid rgba(255, 255, 255, 0.14)',
          color: 'rgba(248, 250, 252, 0.96)',
          fontSize: 38,
          fontWeight: 600,
          letterSpacing: '-0.005em',
          lineHeight: 1.25,
          whiteSpace: 'nowrap',
          boxShadow: '0 8px 26px rgba(0, 0, 0, 0.20)',
        }}
      >
        {cue.text}
      </div>
    </div>
  );
};

export const scenes = {
  bg: {
    render(frame: number, props: Props) {
      const tl = props.timeline;
      const dark = darkAmount(frame, tl);
      const c = themeColors(dark);

      const heroOp = frame < tl.heroEnd + 4 ? sectionFade(frame, 0, tl.heroEnd + 4, 0, 8) : 0;
      const mobileOp =
        frame >= tl.mobileStart - 4 && frame < tl.editorStart + 4
          ? sectionFade(frame, tl.mobileStart - 4, tl.editorStart + 4, 8, 8)
          : 0;
      const editorOp =
        frame >= tl.editorStart - 3 && frame < tl.showcaseStart + 4
          ? sectionFade(frame, tl.editorStart - 3, tl.showcaseStart + 4, 8, 8)
          : 0;
      const showcaseOp =
        frame >= tl.showcaseStart - 2 && frame < tl.outroStart + 2
          ? sectionFade(frame, tl.showcaseStart - 2, tl.outroStart + 2, 8, 10)
          : 0;

      return renderToStaticMarkup(
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: `linear-gradient(145deg, ${c.bgTop} 0%, ${c.bgBottom} 100%)`,
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              position: 'absolute',
              inset: 0,
              backgroundImage: `radial-gradient(${c.gridDot} 1.5px, transparent 1.5px)`,
              backgroundSize: '32px 32px',
            }}
          />
          <div
            style={{
              position: 'absolute',
              left: -180,
              top: -220,
              width: 980,
              height: 980,
              borderRadius: '50%',
              background:
                dark > 0.5
                  ? 'radial-gradient(circle, rgba(31,111,235,0.22) 0%, rgba(31,111,235,0) 68%)'
                  : 'radial-gradient(circle, rgba(31,111,235,0.12) 0%, rgba(31,111,235,0) 68%)',
            }}
          />
          <div
            style={{
              position: 'absolute',
              right: -120,
              bottom: -240,
              width: 860,
              height: 860,
              borderRadius: '50%',
              background:
                dark > 0.5
                  ? 'radial-gradient(circle, rgba(14,165,233,0.16) 0%, rgba(14,165,233,0) 68%)'
                  : 'radial-gradient(circle, rgba(14,165,233,0.10) 0%, rgba(14,165,233,0) 68%)',
            }}
          />

          {/* S0 Hero desktop window frame behind hero_desktop video */}
          {heroOp > 0 && (
            <MacWindowChrome
              x={910}
              y={144}
              width={904}
              height={570}
              barHeight={34}
              title="markdown_kit — Editor"
              dark={0}
              opacity={heroOp}
            />
          )}

          {/* S1 + S2 Main iPhone chassis */}
          {mobileOp > 0 && (
            <IPhoneChassis
              spec={MAIN_IPHONE}
              appDark={frame >= tl.mobileDarkFrame}
              studioDark={dark}
              opacity={mobileOp}
            />
          )}

          {/* S3 Centered large Desktop editor window */}
          {editorOp > 0 && (
            <MacWindowChrome
              x={272}
              y={104}
              width={1376}
              height={852}
              barHeight={34}
              title="markdown_kit — Live Editor"
              dark={dark}
              opacity={editorOp}
            />
          )}

          {/* S4 Centered large Desktop showcase window */}
          {showcaseOp > 0 && (
            <MacWindowChrome
              x={272}
              y={104}
              width={1376}
              height={852}
              barHeight={34}
              title="markdown_kit — SliverMarkdownView"
              dark={1}
              opacity={showcaseOp}
            />
          )}
        </div>
      );
    },
  },

  // S0 Hero iPhone chassis rendered ABOVE hero_desktop video so the iPhone overlaps the desktop cleanly
  heroPhone: {
    render(frame: number, props: Props) {
      const tl = props.timeline;
      if (frame >= tl.heroEnd + 4) return '';
      const heroOp = sectionFade(frame, 0, tl.heroEnd + 4, 0, 8);
      if (heroOp <= 0) return '';
      return renderToStaticMarkup(
        <div style={{position: 'absolute', inset: 0}}>
          <IPhoneChassis spec={HERO_IPHONE} appDark={false} studioDark={0} opacity={heroOp} />
        </div>
      );
    },
  },

  overlay: {
    render(frame: number, props: Props) {
      const tl = props.timeline;
      const dark = darkAmount(frame, tl);
      const c = themeColors(dark);

      // ================================================================
      // S0: HERO OPENER (0 - 120) — Mobile-legible large title
      // ================================================================
      if (frame < tl.heroEnd) {
        const outOp = interpolate(frame, [tl.heroEnd - 8, tl.heroEnd], [1, 0], 'outCubic');
        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div style={{position: 'absolute', inset: 0, opacity: outOp}}>
              <IPhoneScreenOverlay spec={HERO_IPHONE} appDark={false} opacity={1} />
              <div
                style={{
                  position: 'absolute',
                  left: 84,
                  top: 254,
                  width: 690,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 28,
                }}
              >
                <div>
                  <span
                    className="mono"
                    style={{
                      padding: '10px 20px',
                      borderRadius: 999,
                      background: '#1f6feb',
                      color: '#ffffff',
                      fontSize: 24,
                      fontWeight: 700,
                      letterSpacing: '0.07em',
                    }}
                  >
                    FLUTTER PACKAGE
                  </span>
                </div>

                <div
                  className="mono"
                  style={{
                    fontSize: 96,
                    fontWeight: 700,
                    color: '#0f172a',
                    letterSpacing: '-0.03em',
                    lineHeight: 1.02,
                  }}
                >
                  markdown_kit
                </div>

                <div
                  style={{
                    fontSize: 48,
                    fontWeight: 600,
                    color: '#475569',
                    lineHeight: 1.25,
                    letterSpacing: '-0.015em',
                  }}
                >
                  Markdown for AI chat
                  <br />
                  &amp; live editors.
                </div>
              </div>
            </div>

            <SubtleSubtitle frame={frame} dark={0} />
          </div>
        );
      }

      // ================================================================
      // S1 & S2: MOBILE CHAT (120 - 885) — Large iPhone + bold mobile-legible headline
      // ================================================================
      if (frame < tl.editorStart) {
        const isStreaming = frame < tl.selectionStart;
        const isDarkSection = frame >= tl.mobileDarkFrame;

        const blockStart = isStreaming
          ? tl.mobileStart
          : isDarkSection
            ? tl.mobileDarkFrame
            : tl.selectionStart;
        const blockEnd = isStreaming
          ? tl.selectionStart
          : isDarkSection
            ? tl.editorStart
            : tl.mobileDarkFrame;

        const local = frame - blockStart;
        const textOp = sectionFade(frame, blockStart, blockEnd, 8, 8);
        const slide = interpolate(local, [0, 12], [18, 0], 'outCubic');

        const tag = isStreaming ? 'STREAMING' : isDarkSection ? 'THEMING' : 'SELECTION';
        const headline = isStreaming
          ? ['Zero syntax', 'flicker.']
          : isDarkSection
            ? ['Built-in', 'Dark Mode.']
            : ['Survives', 'scrolling.'];
        const meta = isStreaming
          ? 'Token-by-token · Block cached'
          : isDarkSection
            ? 'Light & Dark · Ready out of the box'
            : 'Cross-block · Copy as Markdown';

        const phoneOp = Math.min(
          interpolate(frame, [tl.mobileStart - 4, tl.mobileStart + 4], [0, 1], 'outCubic'),
          interpolate(frame, [tl.editorStart - 6, tl.editorStart], [1, 0], 'outCubic')
        );

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <IPhoneScreenOverlay spec={MAIN_IPHONE} appDark={isDarkSection} opacity={phoneOp} />

            <div
              style={{
                position: 'absolute',
                left: 710,
                top: 280,
                width: 1120,
                opacity: textOp,
                transform: `translateY(${slide.toFixed(1)}px)`,
                display: 'flex',
                flexDirection: 'column',
                gap: 28,
              }}
            >
              <div
                className="mono"
                style={{
                  fontSize: 28,
                  fontWeight: 700,
                  color: c.accent,
                  letterSpacing: '0.12em',
                }}
              >
                {tag}
              </div>

              <div
                style={{
                  fontSize: 118,
                  fontWeight: 700,
                  color: c.text,
                  lineHeight: 1.04,
                  letterSpacing: '-0.03em',
                }}
              >
                {headline[0]}
                <br />
                {headline[1]}
              </div>

              <div
                style={{
                  fontSize: 40,
                  fontWeight: 500,
                  color: c.sub,
                  letterSpacing: '-0.01em',
                  marginTop: 6,
                }}
              >
                {meta}
              </div>
            </div>

            <SubtleSubtitle frame={frame} dark={dark} />
          </div>
        );
      }

      // ================================================================
      // S3: DESKTOP LIVE EDITOR (885 - 1470) — Centered window + large mobile-readable header
      // ================================================================
      if (frame < tl.showcaseStart) {
        const op = sectionFade(frame, tl.editorStart, tl.showcaseStart, 8, 8);
        const phase = frame < 1185 ? 0 : frame < tl.editorDarkFrame ? 1 : 2;
        const title = phase === 0 ? 'Live preview in < 0.5 ms.' : phase === 1 ? 'Synced scroll & tap to jump.' : 'Instant Dark Mode.';

        const parseCalloutOp =
          frame >= 945 && frame <= 1085
            ? Math.min(
                interpolate(frame, [945, 957], [0, 1], 'outCubic'),
                interpolate(frame, [1073, 1085], [1, 0], 'outCubic')
              )
            : 0;
        const parsePulse = settle(
          spring({frame: Math.max(0, frame - 945), fps: tl.fps, stiffness: 180, damping: 16}),
          1
        );

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div
              style={{
                position: 'absolute',
                left: 272,
                right: 272,
                top: 26,
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                opacity: op,
              }}
            >
              <div style={{display: 'flex', alignItems: 'baseline', gap: 22}}>
                <span
                  className="mono"
                  style={{fontSize: 24, fontWeight: 700, color: c.accent, letterSpacing: '0.10em'}}
                >
                  LIVE EDITOR
                </span>
                <span style={{fontSize: 52, fontWeight: 700, color: c.text, letterSpacing: '-0.025em'}}>
                  {title}
                </span>
              </div>
              <span className="mono" style={{fontSize: 24, fontWeight: 600, color: c.muted}}>
                markdown_kit
              </span>
            </div>

            {parseCalloutOp > 0 && (
              <div
                style={{
                  position: 'absolute',
                  left: 750,
                  top: 917,
                  opacity: parseCalloutOp,
                  transform: `scale(${(0.92 + 0.08 * parsePulse).toFixed(3)})`,
                  transformOrigin: 'left center',
                }}
              >
                <div
                  style={{
                    padding: '6px 18px',
                    borderRadius: 999,
                    background: '#1f6feb',
                    color: '#ffffff',
                    fontSize: 21,
                    fontWeight: 700,
                    boxShadow: '0 6px 20px rgba(31, 111, 235, 0.36)',
                  }}
                >
                  ← &lt; 0.5 ms per keystroke
                </div>
              </div>
            )}

            <SubtleSubtitle frame={frame} dark={dark} />
          </div>
        );
      }

      // ================================================================
      // S4: SHOWCASE (1470 - 1626) — Centered dark window + large mobile-readable header
      // ================================================================
      if (frame < tl.outroStart) {
        const op = sectionFade(frame, tl.showcaseStart, tl.outroStart, 8, 10);

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div
              style={{
                position: 'absolute',
                left: 272,
                right: 272,
                top: 26,
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                opacity: op,
              }}
            >
              <div style={{display: 'flex', alignItems: 'baseline', gap: 22}}>
                <span
                  className="mono"
                  style={{fontSize: 24, fontWeight: 700, color: '#58a6ff', letterSpacing: '0.10em'}}
                >
                  EXTENSIBLE
                </span>
                <span style={{fontSize: 52, fontWeight: 700, color: '#f8fafc', letterSpacing: '-0.025em'}}>
                  Pure flutter/widgets.dart.
                </span>
              </div>
              <span className="mono" style={{fontSize: 24, fontWeight: 600, color: '#94a3b8'}}>
                SliverMarkdownView
              </span>
            </div>

            <SubtleSubtitle frame={frame} dark={1} />
          </div>
        );
      }

      // ================================================================
      // S5: OUTRO CTA (1626 - 1800) — Stacked high-legibility pub.dev + GitHub cards
      // ================================================================
      const local = frame - tl.outroStart;
      const inOp = interpolate(local, [0, 14], [0, 1], 'outCubic');
      const endFade = interpolate(frame, [tl.durationInFrames - 18, tl.durationInFrames - 1], [1, 0.14], 'outCubic');
      const scale = interpolate(local, [0, 16], [0.96, 1], 'outCubic');

      return renderToStaticMarkup(
        <div style={{position: 'absolute', inset: 0}}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              textAlign: 'center',
              paddingBottom: 68,
              opacity: inOp * endFade,
              transform: `scale(${scale.toFixed(4)})`,
            }}
          >
            <div
              className="mono"
              style={{
                fontSize: 124,
                fontWeight: 700,
                color: '#f8fafc',
                letterSpacing: '-0.03em',
                lineHeight: 1.02,
              }}
            >
              markdown_kit
            </div>

            <div style={{display: 'flex', flexDirection: 'column', gap: 20, marginTop: 44, width: 1080}}>
              <div
                style={{
                  padding: '24px 44px',
                  borderRadius: 20,
                  background: 'rgba(31, 111, 235, 0.22)',
                  border: '2px solid rgba(88, 166, 255, 0.62)',
                  boxShadow: '0 18px 52px rgba(31, 111, 235, 0.24)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                }}
              >
                <span className="mono" style={{fontSize: 24, fontWeight: 700, color: '#93c5fd', letterSpacing: '0.08em'}}>
                  PUB.DEV
                </span>
                <span className="mono" style={{fontSize: 44, fontWeight: 700, color: '#f8fafc'}}>
                  pub.dev/packages/markdown_kit
                </span>
              </div>

              <div
                style={{
                  padding: '24px 44px',
                  borderRadius: 20,
                  background: 'rgba(30, 41, 59, 0.84)',
                  border: '2px solid rgba(148, 163, 184, 0.30)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                }}
              >
                <span className="mono" style={{fontSize: 24, fontWeight: 700, color: '#94a3b8', letterSpacing: '0.08em'}}>
                  GITHUB
                </span>
                <span className="mono" style={{fontSize: 44, fontWeight: 700, color: '#f8fafc'}}>
                  github.com/K9i-0/ccpocket
                </span>
              </div>
            </div>

            <div
              className="mono"
              style={{
                marginTop: 32,
                fontSize: 32,
                fontWeight: 500,
                color: '#94a3b8',
              }}
            >
              Demo: <span style={{color: '#58a6ff', fontWeight: 700}}>k9i-0.github.io/markdown_kit</span> · MIT
            </div>
          </div>

          <SubtleSubtitle frame={frame} dark={1} />
        </div>
      );
    },
  },
};
