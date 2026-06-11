// theme.jsx — forget-me-not palette, type tokens, the flower mark
// Exports: PALETTES, useTheme, FlowerMark, RoomTile, PaperBg

const PALETTES = {
  // Forget-me-not — soft cornflower blue + warm cream paper
  forget: {
    name: 'Forget-me-not',
    accent: '#5B7FE0',      // forget-me-not blue
    accentSoft: '#A9BCF0',
    accentBg: '#E8EEFB',
    pollen: '#F5C76E',      // flower center
    paper: '#F7F2E8',       // warm cream
    paperEdge: '#EFE7D6',
    ink: '#1A1D26',
    ink2: '#5C5F6B',
    ink3: '#9B9EA9',
    line: 'rgba(26,29,38,0.08)',
    surface: '#FFFFFF',
    danger: '#D9594C',
    // room hues (pulled from a forget-me-not flower bed)
    hues: [
      { bg: '#5B7FE0', fg: '#FFFFFF', name: 'sky' },
      { bg: '#E8B86A', fg: '#3D2A0E', name: 'honey' },
      { bg: '#A89BC9', fg: '#FFFFFF', name: 'mauve' },
      { bg: '#7FA88C', fg: '#FFFFFF', name: 'sage' },
      { bg: '#E89A8E', fg: '#5A2218', name: 'peach' },
      { bg: '#D4C5A3', fg: '#3D2F12', name: 'wheat' },
    ],
  },
  // alt: forest / ink
  forest: {
    name: 'Forest',
    accent: '#3F7D5E',
    accentSoft: '#A6C8B5',
    accentBg: '#E5EFE9',
    pollen: '#E8B86A',
    paper: '#F4F1EA',
    paperEdge: '#EAE5DA',
    ink: '#1A1D1A',
    ink2: '#555A55',
    ink3: '#959994',
    line: 'rgba(26,29,26,0.08)',
    surface: '#FFFFFF',
    danger: '#C2543F',
    hues: [
      { bg: '#3F7D5E', fg: '#FFFFFF', name: 'forest' },
      { bg: '#A65A38', fg: '#FFFFFF', name: 'rust' },
      { bg: '#7A8A4D', fg: '#FFFFFF', name: 'moss' },
      { bg: '#C9A961', fg: '#3D2A0E', name: 'mustard' },
      { bg: '#5C8088', fg: '#FFFFFF', name: 'lake' },
      { bg: '#B89A7B', fg: '#3D2F12', name: 'birch' },
    ],
  },
  // alt: clay / terracotta
  clay: {
    name: 'Clay',
    accent: '#C2543F',
    accentSoft: '#E8B5A8',
    accentBg: '#F8E8E2',
    pollen: '#F0C25A',
    paper: '#F8F2E8',
    paperEdge: '#F0E5D2',
    ink: '#2A1A14',
    ink2: '#5C4940',
    ink3: '#998779',
    line: 'rgba(42,26,20,0.08)',
    surface: '#FFFFFF',
    danger: '#A6391E',
    hues: [
      { bg: '#C2543F', fg: '#FFFFFF', name: 'clay' },
      { bg: '#6B7FAE', fg: '#FFFFFF', name: 'denim' },
      { bg: '#D4A155', fg: '#3D2A0E', name: 'ochre' },
      { bg: '#7A6B8C', fg: '#FFFFFF', name: 'plum' },
      { bg: '#6B8C7A', fg: '#FFFFFF', name: 'sage' },
      { bg: '#C9A88E', fg: '#3D2F12', name: 'sand' },
    ],
  },
};

// pluck a deterministic hue index from a string
function hueFor(seed = '', palette) {
  let n = 0; for (let i = 0; i < seed.length; i++) n = (n * 31 + seed.charCodeAt(i)) | 0;
  return palette.hues[Math.abs(n) % palette.hues.length];
}

// the flower itself — 5 petals + pollen dot. Sizable, themable.
function FlowerMark({ size = 24, color, pollen, style = {} }) {
  const p = pollen || '#F5C76E';
  const c = color || '#5B7FE0';
  const r = size / 2;
  // petals at 0, 72, 144, 216, 288 degrees
  const petals = [];
  for (let i = 0; i < 5; i++) {
    const a = (i * 72 - 90) * Math.PI / 180;
    const cx = r + Math.cos(a) * size * 0.27;
    const cy = r + Math.sin(a) * size * 0.27;
    petals.push(
      <ellipse key={i} cx={cx} cy={cy} rx={size * 0.21} ry={size * 0.27}
        transform={`rotate(${i * 72} ${cx} ${cy})`}
        fill={c} />
    );
  }
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={style}>
      {petals}
      <circle cx={r} cy={r} r={size * 0.13} fill={p} />
      <circle cx={r} cy={r} r={size * 0.06} fill={c} opacity={0.4} />
    </svg>
  );
}

// a soft paper texture background — radial vignette + faint noise
function PaperBg({ palette, children, style = {} }) {
  return (
    <div style={{
      position: 'relative', width: '100%', minHeight: '100%',
      background: palette.paper, ...style,
    }}>
      {/* subtle warm gradient */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        background: `radial-gradient(140% 80% at 50% 0%, ${palette.surface}99 0%, transparent 60%)`,
      }} />
      {children}
    </div>
  );
}

// Room tile — for rooms without photos. Big colored card with a serif initial.
function RoomTile({ name, hue, size = 'md', style = {} }) {
  const dims = {
    sm: { p: 12, fs: 28, r: 16 },
    md: { p: 18, fs: 44, r: 22 },
    lg: { p: 24, fs: 64, r: 28 },
  }[size];
  const initial = (name || '?').trim().charAt(0).toUpperCase();
  return (
    <div style={{
      borderRadius: dims.r, background: hue.bg, color: hue.fg,
      padding: dims.p, position: 'relative', overflow: 'hidden',
      aspectRatio: '1 / 1', display: 'flex', flexDirection: 'column',
      justifyContent: 'space-between',
      ...style,
    }}>
      {/* big soft circle in corner — visual rhythm */}
      <div style={{
        position: 'absolute', right: '-30%', bottom: '-30%',
        width: '90%', height: '90%', borderRadius: '50%',
        background: hue.fg, opacity: 0.08,
      }} />
      <div style={{
        fontFamily: '"Instrument Serif", "Source Serif Pro", Georgia, serif',
        fontSize: dims.fs, lineHeight: 1, fontWeight: 400,
        letterSpacing: '-0.02em',
      }}>{initial}</div>
      <div style={{
        fontSize: size === 'sm' ? 12 : 14, fontWeight: 600,
        letterSpacing: '-0.01em', position: 'relative', zIndex: 1,
      }}>{name}</div>
    </div>
  );
}

Object.assign(window, { PALETTES, hueFor, FlowerMark, PaperBg, RoomTile });
