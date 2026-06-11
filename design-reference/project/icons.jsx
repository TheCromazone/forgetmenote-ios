// icons.jsx — SF Symbol-style outline icons, hand-tuned
// Exports: Icon (factory). All icons take { size=22, color='currentColor', weight=1.8 }

function Icon({ name, size = 22, color = 'currentColor', weight = 1.8, style = {} }) {
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: color, strokeWidth: weight, strokeLinecap: 'round',
    strokeLinejoin: 'round', style };
  switch (name) {
    case 'chevron-right': return <svg {...props}><path d="M9 6l6 6-6 6"/></svg>;
    case 'chevron-left':  return <svg {...props}><path d="M15 6l-6 6 6 6"/></svg>;
    case 'chevron-down':  return <svg {...props}><path d="M6 9l6 6 6-6"/></svg>;
    case 'chevron-up':    return <svg {...props}><path d="M6 15l6-6 6 6"/></svg>;
    case 'plus':          return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case 'x':             return <svg {...props}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'search':        return <svg {...props}><circle cx="11" cy="11" r="7"/><path d="M16 16l5 5"/></svg>;
    case 'camera':        return <svg {...props}><path d="M3 8h3l2-3h8l2 3h3v11H3z"/><circle cx="12" cy="13" r="3.5"/></svg>;
    case 'image':         return <svg {...props}><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="M5 18l5-5 4 4 3-3 3 3"/></svg>;
    case 'sparkle':       return <svg {...props}><path d="M12 3l1.8 5.4L19 10l-5.2 1.6L12 17l-1.8-5.4L5 10l5.2-1.6L12 3z"/></svg>;
    case 'flower-tag':    return <svg {...props}><circle cx="12" cy="12" r="2"/><circle cx="12" cy="7" r="3"/><circle cx="17" cy="12" r="3"/><circle cx="12" cy="17" r="3"/><circle cx="7" cy="12" r="3"/></svg>;
    case 'tag':           return <svg {...props}><path d="M4 13V4h9l7 7-9 9z"/><circle cx="8" cy="8" r="1.2" fill={color}/></svg>;
    case 'note':          return <svg {...props}><path d="M5 4h11l3 3v13H5z"/><path d="M16 4v3h3" strokeWidth={weight*0.85}/><path d="M9 12h7M9 16h5" strokeWidth={weight*0.85}/></svg>;
    case 'bookmark':      return <svg {...props}><path d="M6 3h12v18l-6-4-6 4z"/></svg>;
    case 'clock':         return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'ellipsis':      return <svg width={size} height={size} viewBox="0 0 24 24" style={style}><circle cx="5" cy="12" r="1.6" fill={color}/><circle cx="12" cy="12" r="1.6" fill={color}/><circle cx="19" cy="12" r="1.6" fill={color}/></svg>;
    case 'settings':      return <svg {...props}><circle cx="12" cy="12" r="3"/><path d="M19.4 14a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.9 2.9l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V20a2 2 0 01-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.9-2.9l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 010-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.9-2.9l.1.1a1.7 1.7 0 001.8.3h.1a1.7 1.7 0 001-1.5V3a2 2 0 014 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.9 2.9l-.1.1a1.7 1.7 0 00-.3 1.8v.1a1.7 1.7 0 001.5 1H21a2 2 0 010 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>;
    case 'home':          return <svg {...props}><path d="M3 11l9-7 9 7v9a2 2 0 01-2 2h-4v-7h-6v7H5a2 2 0 01-2-2z"/></svg>;
    case 'compass':       return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M15.5 8.5L13 13l-4.5 2.5L11 11z" fill={color} stroke="none"/></svg>;
    case 'mic':           return <svg {...props}><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>;
    case 'star':          return <svg {...props}><path d="M12 3l2.5 6.2L21 10l-5 4.4 1.5 6.6L12 17.5 6.5 21 8 14.4 3 10l6.5-.8z"/></svg>;
    case 'check':         return <svg {...props}><path d="M5 12l5 5L20 7"/></svg>;
    case 'check-circle':  return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg>;
    case 'bell-dot':      return <svg {...props}><path d="M6 9a6 6 0 1112 0v4l2 3H4l2-3z"/><path d="M10 19a2 2 0 004 0"/><circle cx="18" cy="6" r="2.5" fill={color} stroke="none"/></svg>;
    case 'reorder':       return <svg {...props}><path d="M4 7h16M4 12h16M4 17h16"/></svg>;
    case 'trash':         return <svg {...props}><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg>;
    case 'crown':         return <svg {...props}><path d="M3 8l4 3 5-6 5 6 4-3v10H3z"/><circle cx="3" cy="8" r="1" fill={color}/><circle cx="21" cy="8" r="1" fill={color}/><circle cx="12" cy="5" r="1" fill={color}/></svg>;
    case 'arrow-up-right':return <svg {...props}><path d="M7 17L17 7M9 7h8v8"/></svg>;
    case 'arrow-up':      return <svg {...props}><path d="M12 19V5M5 12l7-7 7 7"/></svg>;
    case 'pencil':        return <svg {...props}><path d="M16 4l4 4-12 12H4v-4z"/></svg>;
    case 'eye':           return <svg {...props}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>;
    case 'grid':          return <svg {...props}><rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/></svg>;
    case 'list':          return <svg {...props}><path d="M3 6h18M3 12h18M3 18h18"/></svg>;
    case 'corner-inward': return <svg {...props}><path d="M21 3v5h-5M3 21l13-13"/></svg>;
    case 'door':          return <svg {...props}><path d="M6 3v18h12V3zM10 12h.01"/><circle cx="14" cy="13" r="0.6" fill={color}/></svg>;
    default: return <svg {...props}><circle cx="12" cy="12" r="9"/></svg>;
  }
}

Object.assign(window, { Icon });
