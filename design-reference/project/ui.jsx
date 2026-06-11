// ui.jsx — shared building blocks: Card, Chip, BlurNav, TabBar, etc.
// Exports: Card, SectionLabel, Chip, BlurBar, TabBar, Pill, FAB, ImgFallback

function Card({ children, style = {}, palette, soft = false, onClick }) {
  return (
    <div onClick={onClick} style={{
      background: soft ? palette.paperEdge : palette.surface,
      borderRadius: 22,
      boxShadow: soft ? 'none'
        : '0 1px 0 rgba(26,29,38,0.04), 0 8px 24px rgba(26,29,38,0.06)',
      border: soft ? `1px solid ${palette.line}` : 'none',
      ...style,
    }}>{children}</div>
  );
}

function SectionLabel({ children, palette, style = {}, action }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      padding: '0 22px', marginBottom: 12, gap: 12, ...style,
    }}>
      <div style={{
        fontFamily: '"Instrument Serif", Georgia, serif',
        fontSize: 22, fontWeight: 400, color: palette.ink,
        letterSpacing: '-0.01em', whiteSpace: 'nowrap',
        overflow: 'hidden', textOverflow: 'ellipsis', flex: 1, minWidth: 0,
      }}>{children}</div>
      {action && (
        <button onClick={action.onClick} style={{
          background: 'none', border: 'none', padding: 0, cursor: 'pointer',
          fontSize: 14, fontWeight: 600, color: palette.accent,
          letterSpacing: '-0.01em',
        }}>{action.label}</button>
      )}
    </div>
  );
}

function Chip({ children, palette, active = false, onClick, icon, style = {} }) {
  return (
    <button onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: icon ? '6px 12px 6px 9px' : '6px 12px',
      borderRadius: 999, border: 'none',
      background: active ? palette.accent : palette.accentBg,
      color: active ? '#fff' : palette.accent,
      fontSize: 13, fontWeight: 600, letterSpacing: '-0.01em',
      cursor: 'pointer', whiteSpace: 'nowrap',
      ...style,
    }}>
      {icon}{children}
    </button>
  );
}

// floating glass tab bar — bottom of screen
function TabBar({ palette, dark, tab, setTab, onCapture }) {
  const items = [
    { id: 'home',     label: 'Places', icon: 'home' },
    { id: 'find',     label: 'Find',   icon: 'search' },
    { id: 'you',      label: 'You',    icon: 'settings' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 18, left: 16, right: 16, zIndex: 30,
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      <div style={{
        flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-around',
        height: 58, borderRadius: 999, position: 'relative', overflow: 'hidden',
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
        background: dark ? 'rgba(28,30,38,0.78)' : 'rgba(255,255,255,0.78)',
        boxShadow: '0 8px 28px rgba(26,29,38,0.12), inset 0 0 0 1px rgba(255,255,255,0.4)',
      }}>
        {items.map(it => {
          const active = tab === it.id;
          return (
            <button key={it.id} onClick={() => setTab(it.id)} style={{
              flex: 1, height: '100%', background: 'none', border: 'none',
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              justifyContent: 'center', gap: 2, cursor: 'pointer',
              color: active ? palette.accent : palette.ink3,
            }}>
              <Icon name={it.icon} size={22} weight={active ? 2.2 : 1.8} />
              <span style={{ fontSize: 10, fontWeight: 600, letterSpacing: '-0.01em' }}>
                {it.label}
              </span>
            </button>
          );
        })}
      </div>
      {/* quick capture FAB */}
      <button onClick={onCapture} style={{
        width: 58, height: 58, borderRadius: 999, border: 'none',
        background: palette.accent, color: '#fff', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: `0 8px 28px ${palette.accent}80, inset 0 0 0 1px rgba(255,255,255,0.2)`,
      }}>
        <Icon name="camera" size={26} weight={2.0} />
      </button>
    </div>
  );
}

// nav header pill (replaces big iOS title; matches our cream paper) 
function NavHeader({ palette, dark, left, right, title, subtitle }) {
  return (
    <div style={{
      position: 'sticky', top: 0, zIndex: 20,
      padding: '54px 16px 12px',
      background: `linear-gradient(180deg, ${palette.paper} 60%, ${palette.paper}00)`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        {left || <div style={{ width: 40 }} />}
        <div style={{ flex: 1, textAlign: 'center', minWidth: 0 }}>
          {title && <div style={{
            fontSize: 16, fontWeight: 600, color: palette.ink,
            letterSpacing: '-0.02em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>{title}</div>}
          {subtitle && <div style={{
            fontSize: 12, color: palette.ink3, marginTop: 1,
          }}>{subtitle}</div>}
        </div>
        {right || <div style={{ width: 40 }} />}
      </div>
    </div>
  );
}

function NavBtn({ palette, icon, onClick, label, primary = false }) {
  return (
    <button onClick={onClick} style={{
      height: 38, minWidth: 38, padding: label ? '0 14px 0 12px' : 0,
      borderRadius: 999, border: 'none', cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 4,
      background: primary ? palette.accent : palette.surface,
      color: primary ? '#fff' : palette.ink,
      boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 4px 12px rgba(26,29,38,0.05)',
      fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em',
    }}>
      {icon && <Icon name={icon} size={18} weight={2.0} />}
      {label}
    </button>
  );
}

// image fallback — colored gradient if no img
function ImgFallback({ name, palette, style = {}, children }) {
  const hue = hueFor(name || '', palette);
  return (
    <div style={{
      background: `linear-gradient(135deg, ${hue.bg}, ${hue.bg}cc)`,
      color: hue.fg, position: 'relative', overflow: 'hidden',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      ...style,
    }}>{children}</div>
  );
}

Object.assign(window, { Card, SectionLabel, Chip, TabBar, NavHeader, NavBtn, ImgFallback });
