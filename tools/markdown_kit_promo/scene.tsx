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

function mixHex(a: string, b: string, t: number): string {
  const k = clamp(t, 0, 1);
  const pa = [parseInt(a.slice(1, 3), 16), parseInt(a.slice(3, 5), 16), parseInt(a.slice(5, 7), 16)];
  const pb = [parseInt(b.slice(1, 3), 16), parseInt(b.slice(3, 5), 16), parseInt(b.slice(5, 7), 16)];
  const r = Math.round(pa[0] + (pb[0] - pa[0]) * k);
  const g = Math.round(pa[1] + (pb[1] - pa[1]) * k);
  const bl = Math.round(pa[2] + (pb[2] - pa[2]) * k);
  return `rgb(${r}, ${g}, ${bl})`;
}

/**
 * Returns 0 for light studio theme, 1 for dark studio theme, smoothly transitioning
 * in sync with the recorded app's Dark toggle.
 */
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
    cardBg: dark > 0.5 ? 'rgba(30, 41, 59, 0.72)' : 'rgba(255, 255, 255, 0.88)',
    cardBgActive: dark > 0.5 ? 'rgba(30, 58, 138, 0.34)' : 'rgba(255, 255, 255, 0.98)',
    cardBorder: dark > 0.5 ? 'rgba(148, 163, 184, 0.18)' : 'rgba(15, 23, 42, 0.09)',
    cardBorderActive: dark > 0.5 ? 'rgba(96, 165, 250, 0.65)' : 'rgba(31, 111, 235, 0.45)',
    accent: mixHex('#1f6feb', '#58a6ff', dark),
    accentSoft: dark > 0.5 ? 'rgba(88, 166, 255, 0.16)' : 'rgba(31, 111, 235, 0.10)',
    codeBg: dark > 0.5 ? 'rgba(15, 23, 42, 0.8)' : 'rgba(15, 23, 42, 0.06)',
    gridDot: dark > 0.5 ? 'rgba(148, 163, 184, 0.10)' : 'rgba(15, 23, 42, 0.065)',
    winBar: mixHex('#eef2f6', '#161b22', dark),
    winBorder: dark > 0.5 ? 'rgba(148, 163, 184, 0.22)' : 'rgba(15, 23, 42, 0.14)',
    winTitle: mixHex('#475569', '#94a3b8', dark),
    phoneBezel: mixHex('#181c24', '#1e2430', dark),
    phoneRim: dark > 0.5 ? 'rgba(255, 255, 255, 0.16)' : 'rgba(255, 255, 255, 0.22)',
  };
}

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
        <div
          className="mono"
          style={{
            fontSize: 13,
            fontWeight: 500,
            color: c.winTitle,
            letterSpacing: '0.01em',
          }}
        >
          {title}
        </div>
        <div style={{width: 48}} />
      </div>
    </div>
  );
};

const PhoneFrameBg: React.FC<{
  x: number;
  y: number;
  width: number;
  height: number;
  bezel: number;
  radius: number;
  dark: number;
  opacity?: number;
}> = ({x, y, width, height, bezel, radius, dark, opacity = 1}) => {
  const c = themeColors(dark);
  return (
    <div
      style={{
        position: 'absolute',
        left: x - bezel,
        top: y - bezel,
        width: width + bezel * 2,
        height: height + bezel * 2,
        borderRadius: radius + bezel - 2,
        background: c.phoneBezel,
        border: `2px solid ${c.phoneRim}`,
        boxShadow:
          dark > 0.5
            ? '0 32px 80px rgba(0, 0, 0, 0.65), 0 8px 24px rgba(0, 0, 0, 0.4)'
            : '0 30px 72px rgba(15, 23, 42, 0.22), 0 8px 20px rgba(15, 23, 42, 0.10)',
        opacity,
      }}
    >
      {/* Subtle hardware side buttons */}
      <div
        style={{
          position: 'absolute',
          right: -4,
          top: 150,
          width: 4,
          height: 68,
          borderRadius: '0 3px 3px 0',
          background: '#2b3240',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -4,
          top: 130,
          width: 4,
          height: 44,
          borderRadius: '3px 0 0 3px',
          background: '#2b3240',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -4,
          top: 186,
          width: 4,
          height: 44,
          borderRadius: '3px 0 0 3px',
          background: '#2b3240',
        }}
      />
    </div>
  );
};

const Pill: React.FC<{text: string; accent?: boolean; dark: number}> = ({text, accent, dark}) => {
  const c = themeColors(dark);
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '8px 16px',
        borderRadius: 999,
        fontSize: 18,
        fontWeight: 600,
        letterSpacing: '0.01em',
        color: accent ? c.accent : c.sub,
        background: accent ? c.accentSoft : c.cardBg,
        border: `1px solid ${accent ? c.cardBorderActive : c.cardBorder}`,
        whiteSpace: 'nowrap',
      }}
    >
      {text}
    </span>
  );
};

const StepCard: React.FC<{
  num: string;
  title: string;
  desc: string;
  active: boolean;
  dark: number;
  compact?: boolean;
}> = ({num, title, desc, active, dark, compact}) => {
  const c = themeColors(dark);
  return (
    <div
      style={{
        padding: compact ? '16px 18px' : '22px 26px',
        borderRadius: 16,
        background: active ? c.cardBgActive : c.cardBg,
        border: `1.5px solid ${active ? c.cardBorderActive : c.cardBorder}`,
        boxShadow: active
          ? dark > 0.5
            ? '0 10px 30px rgba(31, 111, 235, 0.20)'
            : '0 12px 32px rgba(31, 111, 235, 0.10)'
          : 'none',
        opacity: active ? 1 : 0.62,
        display: 'flex',
        gap: compact ? 12 : 18,
        alignItems: 'flex-start',
      }}
    >
      <div
        className="mono"
        style={{
          minWidth: compact ? 32 : 40,
          height: compact ? 32 : 40,
          borderRadius: 10,
          background: active ? c.accent : c.codeBg,
          color: active ? '#ffffff' : c.muted,
          fontSize: compact ? 14 : 16,
          fontWeight: 700,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginTop: 2,
        }}
      >
        {num}
      </div>
      <div style={{flex: 1}}>
        <div
          style={{
            fontSize: compact ? 20 : 25,
            fontWeight: 700,
            color: c.text,
            lineHeight: 1.25,
            letterSpacing: '-0.01em',
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontSize: compact ? 15.5 : 19,
            fontWeight: 400,
            color: c.sub,
            lineHeight: 1.45,
            marginTop: compact ? 5 : 7,
          }}
        >
          {desc}
        </div>
      </div>
    </div>
  );
};

const ProgressFooter: React.FC<{f: number; tl: Timeline; dark: number}> = ({f, tl, dark}) => {
  if (f < tl.mobileStart - 4 || f >= tl.outroStart) return null;
  const c = themeColors(dark);
  const sections = [
    {label: '01 Streaming', start: tl.mobileStart, end: tl.selectionStart},
    {label: '02 Selection', start: tl.selectionStart, end: tl.editorStart},
    {label: '03 Live Editor', start: tl.editorStart, end: tl.showcaseStart},
    {label: '04 Extensible', start: tl.showcaseStart, end: tl.outroStart},
  ];
  const op = Math.min(
    interpolate(f, [tl.mobileStart, tl.mobileStart + 10], [0, 1], 'outCubic'),
    interpolate(f, [tl.outroStart - 10, tl.outroStart], [1, 0], 'outCubic')
  );
  return (
    <div
      style={{
        position: 'absolute',
        left: 96,
        right: 96,
        bottom: 36,
        height: 44,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 24,
        opacity: op,
      }}
    >
      <div style={{display: 'flex', alignItems: 'center', gap: 10}}>
        <span
          style={{
            width: 10,
            height: 10,
            borderRadius: '50%',
            background: c.accent,
            display: 'inline-block',
          }}
        />
        <span className="mono" style={{fontSize: 16, fontWeight: 700, color: c.text}}>
          markdown_kit
        </span>
        <span style={{fontSize: 15, color: c.muted}}>· Flutter</span>
      </div>

      <div style={{display: 'flex', alignItems: 'center', gap: 14, flex: 1, maxWidth: 920}}>
        {sections.map((s) => {
          const pct = clamp((f - s.start) / (s.end - s.start), 0, 1);
          const isCurrent = f >= s.start && f < s.end;
          return (
            <div key={s.label} style={{flex: 1, display: 'flex', flexDirection: 'column', gap: 5}}>
              <div
                style={{
                  fontSize: 13,
                  fontWeight: isCurrent ? 700 : 500,
                  color: isCurrent ? c.accent : c.muted,
                  letterSpacing: '0.02em',
                }}
              >
                {s.label}
              </div>
              <div
                style={{
                  height: 4,
                  borderRadius: 99,
                  background: c.cardBorder,
                  overflow: 'hidden',
                }}
              >
                <div
                  style={{
                    width: `${(pct * 100).toFixed(1)}%`,
                    height: '100%',
                    borderRadius: 99,
                    background: isCurrent ? c.accent : c.muted,
                  }}
                />
              </div>
            </div>
          );
        })}
      </div>

      <div className="mono" style={{fontSize: 14.5, color: c.muted}}>
        k9i-0.github.io/markdown_kit
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
          {/* Subtle architectural dot grid */}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              backgroundImage: `radial-gradient(${c.gridDot} 1.5px, transparent 1.5px)`,
              backgroundSize: '32px 32px',
            }}
          />
          {/* Soft ambient glow */}
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

          {/* S0 Hero device frames behind videos */}
          {heroOp > 0 && (
            <>
              <MacWindowChrome
                x={910}
                y={144}
                width={904}
                height={570}
                barHeight={34}
                title="markdown_kit — Desktop Editor"
                dark={0}
                opacity={heroOp}
              />
              <PhoneFrameBg
                x={822}
                y={334}
                width={304}
                height={660}
                bezel={11}
                radius={26}
                dark={0}
                opacity={heroOp}
              />
            </>
          )}

          {/* S1 + S2 Mobile phone frame */}
          {mobileOp > 0 && (
            <PhoneFrameBg
              x={150}
              y={80}
              width={414}
              height={900}
              bezel={14}
              radius={34}
              dark={dark}
              opacity={mobileOp}
            />
          )}

          {/* S3 Desktop editor window chrome */}
          {editorOp > 0 && (
            <MacWindowChrome
              x={96}
              y={148}
              width={1312}
              height={814}
              barHeight={36}
              title="markdown_kit — Live-Preview Editor (Desktop)"
              dark={dark}
              opacity={editorOp}
            />
          )}

          {/* S4 Desktop showcase window chrome */}
          {showcaseOp > 0 && (
            <MacWindowChrome
              x={96}
              y={148}
              width={1278}
              height={794}
              barHeight={36}
              title="markdown_kit — SliverMarkdownView Showcase"
              dark={1}
              opacity={showcaseOp}
            />
          )}
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
      // S0: HERO OPENER (0 - 120) — Full visibility at frame 0!
      // ================================================================
      if (frame < tl.heroEnd) {
        const outOp = interpolate(frame, [tl.heroEnd - 8, tl.heroEnd], [1, 0], 'outCubic');
        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0, opacity: outOp}}>
            <div
              style={{
                position: 'absolute',
                left: 96,
                top: 170,
                width: 680,
                display: 'flex',
                flexDirection: 'column',
                gap: 24,
              }}
            >
              <div style={{display: 'flex', gap: 12, alignItems: 'center'}}>
                <span
                  className="mono"
                  style={{
                    padding: '7px 14px',
                    borderRadius: 999,
                    background: '#1f6feb',
                    color: '#ffffff',
                    fontSize: 15,
                    fontWeight: 700,
                    letterSpacing: '0.06em',
                  }}
                >
                  FLUTTER PACKAGE
                </span>
                <span
                  style={{
                    padding: '7px 14px',
                    borderRadius: 999,
                    background: 'rgba(15, 23, 42, 0.06)',
                    color: '#334155',
                    fontSize: 15,
                    fontWeight: 600,
                  }}
                >
                  Pure flutter/widgets.dart
                </span>
              </div>

              <div
                className="mono"
                style={{
                  fontSize: 78,
                  fontWeight: 700,
                  color: '#0f172a',
                  letterSpacing: '-0.03em',
                  lineHeight: 1.05,
                }}
              >
                markdown_kit
              </div>

              <div
                style={{
                  fontSize: 34,
                  fontWeight: 600,
                  color: '#334155',
                  lineHeight: 1.32,
                  letterSpacing: '-0.015em',
                }}
              >
                Markdown for AI chat &amp; live editors in Flutter.
              </div>

              <div
                style={{
                  fontSize: 21,
                  color: '#475569',
                  lineHeight: 1.55,
                  maxWidth: 620,
                }}
              >
                Built for token-by-token replies, scroll-proof touch selection, and sub-millisecond incremental
                previews.
              </div>

              <div style={{display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 8}}>
                <Pill text="Token streaming" accent dark={0} />
                <Pill text="Scroll-proof selection" dark={0} />
                <Pill text="Sub-ms live editor" dark={0} />
                <Pill text="MIT · Battle-tested in CC Pocket" dark={0} />
              </div>
            </div>

            {/* Subtle labels under the two live hero previews */}
            <div
              style={{
                position: 'absolute',
                left: 1168,
                top: 748,
                padding: '12px 18px',
                borderRadius: 12,
                background: 'rgba(255,255,255,0.92)',
                border: '1px solid rgba(15,23,42,0.10)',
                boxShadow: '0 8px 24px rgba(15,23,42,0.08)',
                display: 'flex',
                flexDirection: 'column',
                gap: 4,
              }}
            >
              <div style={{fontSize: 15, fontWeight: 700, color: '#0f172a'}}>Real Flutter UI recordings</div>
              <div style={{fontSize: 14, color: '#475569'}}>Mobile AI Chat + Desktop Split Editor</div>
            </div>
          </div>
        );
      }

      // ================================================================
      // S1: MOBILE CHAT — STREAMING (120 - 450)
      // ================================================================
      if (frame < tl.selectionStart) {
        const local = frame - tl.mobileStart;
        const op = sectionFade(frame, tl.mobileStart, tl.selectionStart, 8, 8);
        const slide = interpolate(local, [0, 12], [18, 0], 'outCubic');
        const activeIdx = local < 105 ? 0 : local < 215 ? 1 : 2;

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div
              style={{
                position: 'absolute',
                left: 650,
                top: 112,
                width: 1170,
                opacity: op,
                transform: `translateY(${slide.toFixed(1)}px)`,
                display: 'flex',
                flexDirection: 'column',
                gap: 26,
              }}
            >
              <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
                <span
                  className="mono"
                  style={{
                    fontSize: 17,
                    fontWeight: 700,
                    color: c.accent,
                    letterSpacing: '0.08em',
                  }}
                >
                  01 / MOBILE AI CHAT
                </span>
                <span style={{width: 48, height: 2, background: c.accent, opacity: 0.4}} />
                <span style={{fontSize: 16, fontWeight: 600, color: c.muted}}>Real mobile recording · 402×874</span>
              </div>

              <div
                style={{
                  fontSize: 58,
                  fontWeight: 700,
                  color: c.text,
                  lineHeight: 1.12,
                  letterSpacing: '-0.025em',
                }}
              >
                Token-by-token streaming
                <br />
                without syntax flicker
              </div>

              <div style={{fontSize: 22, color: c.sub, lineHeight: 1.48, maxWidth: 980}}>
                Pass <code style={{background: c.codeBg, padding: '2px 8px', borderRadius: 6}}>isStreaming: true</code>{' '}
                to <code style={{background: c.codeBg, padding: '2px 8px', borderRadius: 6}}>MarkdownView</code> —
                earlier blocks stay cached while only the tail updates.
              </div>

              <div style={{display: 'flex', flexDirection: 'column', gap: 16, marginTop: 8}}>
                <StepCard
                  num="01"
                  title="Finished blocks are parsed & built once"
                  desc="Appending tokens to the tail never rebuilds earlier headings, lists, or code blocks."
                  active={activeIdx === 0}
                  dark={dark}
                />
                <StepCard
                  num="02"
                  title="Unfinished syntax is held back cleanly"
                  desc="Open **bold**, `code`, links, tables, and fences wait until closed — no raw punctuation flashes."
                  active={activeIdx === 1}
                  dark={dark}
                />
                <StepCard
                  num="03"
                  title="Rich blocks render seamlessly as tokens arrive"
                  desc="Dart code blocks, aligned GFM tables, GitHub alerts, and LaTeX math land smoothly."
                  active={activeIdx === 2}
                  dark={dark}
                />
              </div>
            </div>

            <ProgressFooter f={frame} tl={tl} dark={dark} />
          </div>
        );
      }

      // ================================================================
      // S2: MOBILE CHAT — SELECTION, SCROLL SURVIVAL, COPY & DARK (450 - 885)
      // ================================================================
      if (frame < tl.editorStart) {
        const local = frame - tl.selectionStart;
        const op = sectionFade(frame, tl.selectionStart, tl.editorStart, 8, 8);
        const slide = interpolate(local, [0, 12], [18, 0], 'outCubic');
        // Sync card highlights to real video events:
        // 450..595: drag selection across blocks
        // 595..740: scroll list up & down with selection kept
        // 740..806: Copy as Markdown
        // 806..885: Dark theme toggle
        const activeIdx = frame < 595 ? 0 : frame < 740 ? 1 : frame < tl.mobileDarkFrame ? 2 : 3;

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div
              style={{
                position: 'absolute',
                left: 650,
                top: 96,
                width: 1170,
                opacity: op,
                transform: `translateY(${slide.toFixed(1)}px)`,
                display: 'flex',
                flexDirection: 'column',
                gap: 20,
              }}
            >
              <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
                <span
                  className="mono"
                  style={{
                    fontSize: 17,
                    fontWeight: 700,
                    color: c.accent,
                    letterSpacing: '0.08em',
                  }}
                >
                  02 / SELECTION &amp; COPY
                </span>
                <span style={{width: 48, height: 2, background: c.accent, opacity: 0.4}} />
                <span style={{fontSize: 16, fontWeight: 600, color: c.muted}}>
                  {frame >= tl.mobileDarkFrame ? 'Built-in Dark Theme' : 'Model-anchored selection'}
                </span>
              </div>

              <div
                style={{
                  fontSize: 54,
                  fontWeight: 700,
                  color: c.text,
                  lineHeight: 1.12,
                  letterSpacing: '-0.025em',
                }}
              >
                Selection that survives
                <br />
                lazy list scrolling
              </div>

              <div style={{display: 'flex', flexDirection: 'column', gap: 13, marginTop: 6}}>
                <StepCard
                  num="01"
                  title="Drag across lists, code blocks & tables"
                  desc="Opaque 44pt touch handles never fight list scrolling or back swipes, with edge auto-scroll."
                  active={activeIdx === 0}
                  dark={dark}
                  compact
                />
                <StepCard
                  num="02"
                  title="Stays anchored through recycling & streaming"
                  desc="MarkdownSelectionScope tracks each documentId — scroll away and back with the highlight intact."
                  active={activeIdx === 1}
                  dark={dark}
                  compact
                />
                <StepCard
                  num="03"
                  title="Copy clean text or Copy as Markdown"
                  desc="Plain text omits bullet glyphs & code headers; Copy as Markdown rebuilds full Markdown structure."
                  active={activeIdx === 2}
                  dark={dark}
                  compact
                />
                <StepCard
                  num="04"
                  title="Built-in Light & Dark themes"
                  desc="Value-compared MarkdownThemeData switches cleanly with zero Material or Cupertino imports."
                  active={activeIdx === 3}
                  dark={dark}
                  compact
                />
              </div>
            </div>

            <ProgressFooter f={frame} tl={tl} dark={dark} />
          </div>
        );
      }

      // ================================================================
      // S3: DESKTOP LIVE-PREVIEW EDITOR (885 - 1470)
      // ================================================================
      if (frame < tl.showcaseStart) {
        const local = frame - tl.editorStart;
        const op = sectionFade(frame, tl.editorStart, tl.showcaseStart, 8, 8);
        const slide = interpolate(local, [0, 12], [14, 0], 'outCubic');
        // Video event alignment:
        // 885..1075: live typing & sub-ms parse
        // 1075..1285: synced block-by-block scroll
        // 1285..1388: tap block to jump caret
        // 1388..1470: dark theme
        const activeIdx = frame < 1075 ? 0 : frame < 1285 ? 1 : frame < tl.editorDarkFrame ? 2 : 3;

        // Subtle focus highlight box around the status bar's "parsed in 0.xx ms" during typing!
        const parseCalloutOp =
          frame >= 940 && frame <= 1070
            ? Math.min(
                interpolate(frame, [940, 952], [0, 1], 'outCubic'),
                interpolate(frame, [1058, 1070], [1, 0], 'outCubic')
              )
            : 0;
        const parsePulse = settle(
          spring({frame: Math.max(0, frame - 940), fps: tl.fps, stiffness: 180, damping: 16}),
          1
        );

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            {/* Top header band above desktop window */}
            <div
              style={{
                position: 'absolute',
                left: 96,
                right: 96,
                top: 46,
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                opacity: op,
                transform: `translateY(${slide.toFixed(1)}px)`,
              }}
            >
              <div style={{display: 'flex', alignItems: 'baseline', gap: 22}}>
                <span
                  className="mono"
                  style={{fontSize: 17, fontWeight: 700, color: c.accent, letterSpacing: '0.08em'}}
                >
                  03 / DESKTOP EDITOR
                </span>
                <span
                  style={{
                    fontSize: 40,
                    fontWeight: 700,
                    color: c.text,
                    letterSpacing: '-0.02em',
                  }}
                >
                  Live preview that keeps up with every keystroke
                </span>
              </div>
              <span className="mono" style={{fontSize: 16, color: c.muted}}>
                &lt; 1 ms incremental parse
              </span>
            </div>

            {/* Right sidebar live commentary (never covers editor UI) */}
            <div
              style={{
                position: 'absolute',
                left: 1440,
                top: 148,
                width: 384,
                opacity: op,
                display: 'flex',
                flexDirection: 'column',
                gap: 14,
              }}
            >
              <StepCard
                num="01"
                title="Sub-millisecond parsing"
                desc="Only the edited block re-parses and rebuilds on each keystroke — watch the status bar."
                active={activeIdx === 0}
                dark={dark}
                compact
              />
              <StepCard
                num="02"
                title="Synced block scrolling"
                desc="document.blockSourceRanges maps each preview block back to its source lines."
                active={activeIdx === 1}
                dark={dark}
                compact
              />
              <StepCard
                num="03"
                title="Active block & tap to jump"
                desc="blockWrapper highlights the caret's block and jumps source when tapped."
                active={activeIdx === 2}
                dark={dark}
                compact
              />
              <StepCard
                num="04"
                title="Seamless Dark Mode"
                desc="Editor syntax and preview theme switch instantly in one pass."
                active={activeIdx === 3}
                dark={dark}
                compact
              />
            </div>

            {/* Callout pill sitting cleanly in the blank right half of the editor status bar */}
            {parseCalloutOp > 0 && (
              <div
                style={{
                  position: 'absolute',
                  left: 560,
                  top: 932,
                  opacity: parseCalloutOp,
                  transform: `scale(${(0.92 + 0.08 * parsePulse).toFixed(3)})`,
                  transformOrigin: 'left center',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <div
                  style={{
                    padding: '4px 12px',
                    borderRadius: 999,
                    background: '#1f6feb',
                    color: '#ffffff',
                    fontSize: 13.5,
                    fontWeight: 700,
                    letterSpacing: '0.01em',
                    boxShadow: '0 6px 18px rgba(31, 111, 235, 0.32)',
                  }}
                >
                  ← Live incremental parse time (&lt; 0.5 ms)
                </div>
              </div>
            )}

            <ProgressFooter f={frame} tl={tl} dark={dark} />
          </div>
        );
      }

      // ================================================================
      // S4: SHOWCASE & ARCHITECTURE (1470 - 1660)
      // ================================================================
      if (frame < tl.outroStart) {
        const local = frame - tl.showcaseStart;
        const op = sectionFade(frame, tl.showcaseStart, tl.outroStart, 8, 10);
        const slide = interpolate(local, [0, 12], [14, 0], 'outCubic');

        const features = [
          {
            badge: 'ZERO DEPS',
            title: 'Pure flutter/widgets.dart',
            desc: 'No Material or Cupertino imports — drop into any design system.',
          },
          {
            badge: 'SLIVERS',
            title: 'SliverMarkdownView',
            desc: 'Builds only blocks near the viewport while keeping whole-doc selection.',
          },
          {
            badge: 'PLUGGABLE',
            title: 'Custom rules & builders',
            desc: 'Wire LaTeX math, syntax highlighters, alerts & inline pills (#42).',
          },
          {
            badge: 'TESTED',
            title: '~1,900 tests · CC Pocket',
            desc: 'CommonMark spec coverage, RTL, large text scales — shipped in production.',
          },
        ];

        return renderToStaticMarkup(
          <div style={{position: 'absolute', inset: 0}}>
            <div
              style={{
                position: 'absolute',
                left: 96,
                right: 96,
                top: 46,
                display: 'flex',
                alignItems: 'baseline',
                justifyContent: 'space-between',
                opacity: op,
                transform: `translateY(${slide.toFixed(1)}px)`,
              }}
            >
              <div style={{display: 'flex', alignItems: 'baseline', gap: 22}}>
                <span
                  className="mono"
                  style={{fontSize: 17, fontWeight: 700, color: '#58a6ff', letterSpacing: '0.08em'}}
                >
                  04 / BUILT TO EXTEND
                </span>
                <span style={{fontSize: 40, fontWeight: 700, color: '#f8fafc', letterSpacing: '-0.02em'}}>
                  Alerts, LaTeX math, details, RTL &amp; custom syntax
                </span>
              </div>
              <span className="mono" style={{fontSize: 16, color: '#94a3b8'}}>
                SliverMarkdownView
              </span>
            </div>

            <div
              style={{
                position: 'absolute',
                left: 1408,
                top: 148,
                width: 416,
                opacity: op,
                display: 'flex',
                flexDirection: 'column',
                gap: 14,
              }}
            >
              {features.map((item, idx) => {
                const enter = interpolate(local, [idx * 6, idx * 6 + 12], [0, 1], 'outCubic');
                return (
                  <div
                    key={item.title}
                    style={{
                      padding: '17px 20px',
                      borderRadius: 14,
                      background: 'rgba(30, 41, 59, 0.78)',
                      border: '1.5px solid rgba(148, 163, 184, 0.20)',
                      opacity: enter,
                      transform: `translateX(${((1 - enter) * 16).toFixed(1)}px)`,
                    }}
                  >
                    <div
                      className="mono"
                      style={{
                        fontSize: 12.5,
                        fontWeight: 700,
                        color: '#58a6ff',
                        letterSpacing: '0.08em',
                        marginBottom: 4,
                      }}
                    >
                      {item.badge}
                    </div>
                    <div style={{fontSize: 21, fontWeight: 700, color: '#f8fafc', lineHeight: 1.25}}>
                      {item.title}
                    </div>
                    <div style={{fontSize: 15.5, color: '#cbd5e1', lineHeight: 1.42, marginTop: 5}}>
                      {item.desc}
                    </div>
                  </div>
                );
              })}
            </div>

            <ProgressFooter f={frame} tl={tl} dark={1} />
          </div>
        );
      }

      // ================================================================
      // S5: OUTRO CTA CARD (1660 - 1800)
      // ================================================================
      const local = frame - tl.outroStart;
      const inOp = interpolate(local, [0, 14], [0, 1], 'outCubic');
      const endFade = interpolate(frame, [tl.durationInFrames - 18, tl.durationInFrames - 1], [1, 0.12], 'outCubic');
      const scale = interpolate(local, [0, 16], [0.96, 1], 'outCubic');

      return renderToStaticMarkup(
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
            padding: '0 160px',
            opacity: inOp * endFade,
            transform: `scale(${scale.toFixed(4)})`,
          }}
        >
          <div
            className="mono"
            style={{
              padding: '8px 18px',
              borderRadius: 999,
              background: 'rgba(88, 166, 255, 0.16)',
              border: '1px solid rgba(88, 166, 255, 0.45)',
              color: '#58a6ff',
              fontSize: 17,
              fontWeight: 700,
              letterSpacing: '0.08em',
              marginBottom: 28,
            }}
          >
            OPEN SOURCE · FLUTTER 3.50+
          </div>

          <div
            className="mono"
            style={{
              fontSize: 98,
              fontWeight: 700,
              color: '#f8fafc',
              letterSpacing: '-0.03em',
              lineHeight: 1.04,
            }}
          >
            markdown_kit
          </div>

          <div
            style={{
              fontSize: 34,
              fontWeight: 500,
              color: '#cbd5e1',
              marginTop: 22,
              lineHeight: 1.35,
            }}
          >
            Markdown for AI chat &amp; live editors in Flutter
          </div>

          <div
            style={{
              marginTop: 44,
              padding: '22px 42px',
              borderRadius: 18,
              background: 'rgba(30, 41, 59, 0.85)',
              border: '1.5px solid rgba(88, 166, 255, 0.5)',
              boxShadow: '0 20px 60px rgba(31, 111, 235, 0.24)',
              display: 'flex',
              flexDirection: 'column',
              gap: 8,
            }}
          >
            <div style={{fontSize: 17, fontWeight: 600, color: '#94a3b8', letterSpacing: '0.04em'}}>
              TRY THE INTERACTIVE WEB DEMO
            </div>
            <div className="mono" style={{fontSize: 32, fontWeight: 700, color: '#58a6ff'}}>
              k9i-0.github.io/markdown_kit
            </div>
          </div>

          <div style={{display: 'flex', gap: 16, marginTop: 42, flexWrap: 'wrap', justifyContent: 'center'}}>
            <Pill text="MIT License" dark={1} />
            <Pill text="Pure flutter/widgets.dart" dark={1} />
            <Pill text="Streaming + Selection + Editor" dark={1} />
            <Pill text="github.com/K9i-0/ccpocket" dark={1} />
          </div>
        </div>
      );
    },
  },
};
