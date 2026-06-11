// screens-secondary.jsx — DetailSheet (edit), CaptureSheet (quick capture), CreateSubScreen, SettingsScreen
// Exports: DetailSheet, CaptureSheet, CreateSubScreen, SettingsScreen

// ── Detail edit (half-sheet) ──────────────────────────────────
function DetailSheet({ palette, itemId, onClose }) {
  const item = getItem(itemId);
  const [name, setName] = React.useState(item.name);
  const [tags, setTags] = React.useState((item.tags || []).join(', '));
  const [notes, setNotes] = React.useState(item.notes || '');
  const [updated, setUpdated] = React.useState(!!item.isUpdated);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      display: 'flex', flexDirection: 'column',
    }}>
      {/* backdrop */}
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(20,22,28,0.45)',
        backdropFilter: 'blur(4px)', WebkitBackdropFilter: 'blur(4px)',
      }} />
      {/* sheet */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: palette.paper, borderRadius: '24px 24px 0 0',
        maxHeight: '88%', overflowY: 'auto',
        boxShadow: '0 -8px 32px rgba(20,22,28,0.18)',
      }}>
        {/* drag handle */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '10px 0 4px' }}>
          <div style={{ width: 44, height: 5, borderRadius: 999, background: palette.line }} />
        </div>
        {/* header */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '8px 18px 14px',
        }}>
          <button onClick={onClose} style={{
            background: 'none', border: 'none', padding: 0, cursor: 'pointer',
            fontSize: 15, color: palette.ink2, fontWeight: 500,
          }}>Cancel</button>
          <div style={{ fontSize: 15, fontWeight: 700, color: palette.ink, letterSpacing: '-0.01em' }}>
            Edit
          </div>
          <button onClick={onClose} style={{
            background: 'none', border: 'none', padding: 0, cursor: 'pointer',
            fontSize: 15, color: palette.accent, fontWeight: 700,
          }}>Save</button>
        </div>

        <div style={{ padding: '0 18px 32px' }}>
          {/* big name field */}
          <div style={{
            background: palette.surface, borderRadius: 22, padding: '20px 18px',
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
            marginBottom: 14,
          }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: palette.ink3, marginBottom: 8 }}>
              Name
            </div>
            <input value={name} onChange={e => setName(e.target.value)} style={{
              width: '100%', border: 'none', outline: 'none', background: 'transparent',
              fontFamily: '"Instrument Serif", Georgia, serif',
              fontSize: 32, fontWeight: 400, color: palette.ink,
              letterSpacing: '-0.02em', lineHeight: 1.1, padding: 0,
            }}/>
          </div>

          {/* tags */}
          <div style={{
            background: palette.surface, borderRadius: 22, padding: '16px 18px',
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
            marginBottom: 14,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: palette.ink3 }}>
                Tags
              </div>
              <button style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: palette.accent, display: 'flex' }}>
                <Icon name="mic" size={16} weight={2.0}/>
              </button>
            </div>
            <input value={tags} onChange={e => setTags(e.target.value)}
              placeholder="comma, separated, tags"
              style={{
                marginTop: 6, width: '100%', border: 'none', outline: 'none', background: 'transparent',
                fontSize: 15, color: palette.ink, letterSpacing: '-0.01em', padding: 0,
                fontFamily: 'inherit',
              }}/>
            {tags && (
              <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
                  <Chip key={t} palette={palette}>{t.startsWith('#') ? t : '#' + t}</Chip>
                ))}
              </div>
            )}
          </div>

          {/* notes */}
          <div style={{
            background: palette.surface, borderRadius: 22, padding: '16px 18px',
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
            marginBottom: 14,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: palette.ink3 }}>
                Notes
              </div>
              <button style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: palette.accent, display: 'flex' }}>
                <Icon name="mic" size={16} weight={2.0}/>
              </button>
            </div>
            <textarea value={notes} onChange={e => setNotes(e.target.value)}
              placeholder="Anything to remember about this?"
              rows={3}
              style={{
                marginTop: 6, width: '100%', border: 'none', outline: 'none', background: 'transparent',
                fontSize: 15, color: palette.ink, letterSpacing: '-0.01em', padding: 0,
                fontFamily: 'inherit', resize: 'none', lineHeight: 1.45,
              }}/>
          </div>

          {/* updated toggle */}
          <div style={{
            background: palette.surface, borderRadius: 22, padding: '4px 4px',
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
            marginBottom: 14,
          }}>
            <div onClick={() => setUpdated(!updated)} style={{
              display: 'flex', alignItems: 'center', padding: '14px 14px',
              cursor: 'pointer', gap: 12,
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: 10,
                background: updated ? palette.pollen : palette.accentBg,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Icon name="sparkle" size={16} color={updated ? '#3D2A0E' : palette.accent} weight={2.2}/>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: palette.ink, letterSpacing: '-0.01em' }}>
                  {updated ? 'Recently refreshed' : 'Mark as refreshed'}
                </div>
                <div style={{ fontSize: 12, color: palette.ink3, marginTop: 1 }}>
                  Highlights this place so you can find what changed.
                </div>
              </div>
              <Switch on={updated} palette={palette} />
            </div>
          </div>

          {/* danger */}
          <button style={{
            width: '100%', height: 50, borderRadius: 16, border: 'none', cursor: 'pointer',
            background: 'transparent', color: palette.danger,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em',
            border: `1px solid ${palette.danger}33`,
          }}>
            <Icon name="trash" size={17} weight={2.0}/>
            Delete this place
          </button>
        </div>
      </div>
    </div>
  );
}

function Switch({ on, palette }) {
  return (
    <div style={{
      width: 50, height: 30, borderRadius: 999,
      background: on ? palette.accent : palette.line,
      padding: 3, transition: 'background 200ms',
      position: 'relative',
    }}>
      <div style={{
        width: 24, height: 24, borderRadius: 999, background: '#fff',
        transform: on ? 'translateX(20px)' : 'translateX(0)',
        transition: 'transform 200ms',
        boxShadow: '0 1px 3px rgba(0,0,0,0.25)',
      }} />
    </div>
  );
}

// ── Quick capture sheet (FAB) ─────────────────────────────────
function CaptureSheet({ palette, onClose, onPickRoom, onSnap }) {
  const rooms = getRoots().filter(x => x.type === 'room');
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 100 }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(20,22,28,0.55)',
        backdropFilter: 'blur(6px)', WebkitBackdropFilter: 'blur(6px)',
      }} />
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: palette.paper, borderRadius: '24px 24px 0 0',
        padding: '14px 18px 32px',
        boxShadow: '0 -8px 32px rgba(20,22,28,0.18)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', padding: '0 0 14px' }}>
          <div style={{ width: 44, height: 5, borderRadius: 999, background: palette.line }} />
        </div>
        <div style={{
          fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 28, fontWeight: 400, color: palette.ink, letterSpacing: '-0.02em',
        }}>
          Capture <em style={{ fontStyle: 'italic', color: palette.accent }}>something.</em>
        </div>
        <div style={{ fontSize: 13, color: palette.ink2, marginTop: 4 }}>
          Where should this new memory live?
        </div>

        {/* Quick options */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 18 }}>
          <button onClick={onSnap} style={{
            padding: '16px 14px', borderRadius: 18, border: 'none', cursor: 'pointer',
            background: palette.ink, color: palette.paper, textAlign: 'left',
            display: 'flex', flexDirection: 'column', gap: 8,
          }}>
            <Icon name="camera" size={22} weight={2.0}/>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>Snap a photo</div>
              <div style={{ fontSize: 11, opacity: 0.7, marginTop: 2 }}>Use the camera</div>
            </div>
          </button>
          <button style={{
            padding: '16px 14px', borderRadius: 18, border: 'none', cursor: 'pointer',
            background: palette.surface, color: palette.ink, textAlign: 'left',
            display: 'flex', flexDirection: 'column', gap: 8,
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
          }}>
            <Icon name="image" size={22} weight={2.0} color={palette.accent}/>
            <div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>From library</div>
              <div style={{ fontSize: 11, color: palette.ink3, marginTop: 2 }}>Pick existing</div>
            </div>
          </button>
        </div>

        {/* Recent rooms — pick parent */}
        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: palette.ink3, letterSpacing: '0.06em', textTransform: 'uppercase', marginBottom: 8 }}>
            Or add to a room
          </div>
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto', scrollbarWidth: 'none', padding: '2px 0' }}>
            {rooms.map(r => {
              const hue = hueFor(r.id, palette);
              return (
                <button key={r.id} onClick={() => onPickRoom(r.id)} style={{
                  flex: '0 0 auto', display: 'flex', alignItems: 'center', gap: 8,
                  padding: '8px 14px 8px 8px', borderRadius: 999, border: 'none', cursor: 'pointer',
                  background: palette.surface, color: palette.ink,
                  boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
                }}>
                  <div style={{
                    width: 28, height: 28, borderRadius: 9, background: hue.bg, color: hue.fg,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontFamily: '"Instrument Serif", serif', fontSize: 18,
                  }}>{r.name.charAt(0).toUpperCase()}</div>
                  <span style={{ fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em' }}>{r.name}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Create sub-space (the rectangle-on-parent flow) ──────────
function CreateSubScreen({ palette, parentId, onClose, onSave }) {
  const parent = getItem(parentId);
  // initial rectangle in the center
  const [rect, setRect] = React.useState({ x: 0.25, y: 0.30, w: 0.50, h: 0.40 });
  const [name, setName] = React.useState('');
  const [autoTitle] = React.useState('Bay leaf tin');
  const [tags, setTags] = React.useState('');
  const [drag, setDrag] = React.useState(null);
  const imgRef = React.useRef(null);

  const onPointerDown = (mode, corner) => (e) => {
    e.preventDefault(); e.stopPropagation();
    const box = imgRef.current.getBoundingClientRect();
    setDrag({ mode, corner, box, start: { x: e.clientX, y: e.clientY }, startRect: rect });
    e.currentTarget.setPointerCapture?.(e.pointerId);
  };
  React.useEffect(() => {
    if (!drag) return;
    const onMove = (e) => {
      const dx = (e.clientX - drag.start.x) / drag.box.width;
      const dy = (e.clientY - drag.start.y) / drag.box.height;
      let r = { ...drag.startRect };
      if (drag.mode === 'move') {
        r.x = Math.max(0, Math.min(1 - r.w, r.x + dx));
        r.y = Math.max(0, Math.min(1 - r.h, r.y + dy));
      } else if (drag.mode === 'resize') {
        const c = drag.corner;
        if (c.includes('e')) r.w = Math.max(0.08, Math.min(1 - r.x, drag.startRect.w + dx));
        if (c.includes('s')) r.h = Math.max(0.08, Math.min(1 - r.y, drag.startRect.h + dy));
        if (c.includes('w')) { r.x = Math.max(0, drag.startRect.x + dx); r.w = drag.startRect.w - (r.x - drag.startRect.x); }
        if (c.includes('n')) { r.y = Math.max(0, drag.startRect.y + dy); r.h = drag.startRect.h - (r.y - drag.startRect.y); }
      }
      setRect(r);
    };
    const onUp = () => setDrag(null);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [drag]);

  const handles = ['nw','ne','sw','se'];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: palette.paper, overflow: 'auto' }}>
      {/* nav */}
      <NavHeader palette={palette}
        left={<NavBtn palette={palette} icon="x" onClick={onClose} />}
        right={<NavBtn palette={palette} label="Save" primary onClick={() => onSave({ name: name || autoTitle, tags, rect, parentId })} />}
        title="Mark a spot"
        subtitle={`in ${parent.name}`}
      />

      <div style={{ padding: '0 16px 32px' }}>
        {/* photo with selector */}
        <div ref={imgRef} style={{
          position: 'relative', borderRadius: 22, overflow: 'hidden',
          background: palette.paperEdge, aspectRatio: '4/5',
          boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 8px 24px rgba(26,29,38,0.10)',
          touchAction: 'none', userSelect: 'none',
        }}>
          {parent.img ? (
            <img src={parent.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', pointerEvents: 'none' }} draggable={false}/>
          ) : (
            <ImgFallback name={parent.name} palette={palette} style={{ width: '100%', height: '100%' }} />
          )}
          {/* darken outside the rect using 4 masking divs */}
          <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
            <div style={{ position: 'absolute', left: 0, top: 0, right: 0, height: `${rect.y * 100}%`, background: 'rgba(20,22,28,0.45)' }} />
            <div style={{ position: 'absolute', left: 0, top: `${(rect.y + rect.h) * 100}%`, right: 0, bottom: 0, background: 'rgba(20,22,28,0.45)' }} />
            <div style={{ position: 'absolute', left: 0, top: `${rect.y * 100}%`, width: `${rect.x * 100}%`, height: `${rect.h * 100}%`, background: 'rgba(20,22,28,0.45)' }} />
            <div style={{ position: 'absolute', left: `${(rect.x + rect.w) * 100}%`, top: `${rect.y * 100}%`, right: 0, height: `${rect.h * 100}%`, background: 'rgba(20,22,28,0.45)' }} />
          </div>
          {/* rectangle */}
          <div onPointerDown={onPointerDown('move')} style={{
            position: 'absolute',
            left: `${rect.x * 100}%`, top: `${rect.y * 100}%`,
            width: `${rect.w * 100}%`, height: `${rect.h * 100}%`,
            border: `2.5px solid ${palette.accent}`, borderRadius: 6,
            boxShadow: `0 0 0 4px ${palette.accent}25`,
            cursor: 'move', touchAction: 'none',
          }}>
            {/* grid 3x3 rule of thirds */}
            <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
              {[33.33, 66.66].map(p => (
                <React.Fragment key={p}>
                  <div style={{ position: 'absolute', left: `${p}%`, top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.4)' }} />
                  <div style={{ position: 'absolute', top: `${p}%`, left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.4)' }} />
                </React.Fragment>
              ))}
            </div>
            {/* corner handles */}
            {handles.map(c => {
              const t = c.includes('n') ? -7 : null;
              const b = c.includes('s') ? -7 : null;
              const l = c.includes('w') ? -7 : null;
              const r = c.includes('e') ? -7 : null;
              return (
                <div key={c} onPointerDown={onPointerDown('resize', c)} style={{
                  position: 'absolute', top: t ?? undefined, bottom: b ?? undefined,
                  left: l ?? undefined, right: r ?? undefined,
                  width: 18, height: 18, borderRadius: 999,
                  background: '#fff', border: `2.5px solid ${palette.accent}`,
                  cursor: `${c}-resize`, touchAction: 'none',
                  boxShadow: '0 2px 6px rgba(0,0,0,0.25)',
                }}/>
              );
            })}
            {/* label on top */}
            <div style={{
              position: 'absolute', top: -34, left: '50%',
              transform: 'translateX(-50%)', whiteSpace: 'nowrap',
              padding: '4px 10px', borderRadius: 999,
              background: palette.accent, color: '#fff',
              fontSize: 11, fontWeight: 600, letterSpacing: '-0.01em',
              boxShadow: `0 2px 8px ${palette.accent}66`,
            }}>{name || autoTitle}</div>
          </div>
        </div>

        <div style={{ marginTop: 8, fontSize: 12, color: palette.ink3, textAlign: 'center' }}>
          Drag the corners to fit the spot.
        </div>

        {/* name + tags inline */}
        <div style={{ marginTop: 20, background: palette.surface, borderRadius: 22,
          boxShadow: '0 1px 2px rgba(26,29,38,0.04)', padding: '4px 18px' }}>
          <div style={{ padding: '14px 0', borderBottom: `1px solid ${palette.line}` }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: palette.ink3 }}>Name</div>
            <input value={name} onChange={e => setName(e.target.value)}
              placeholder={autoTitle}
              style={{
                width: '100%', marginTop: 4, border: 'none', outline: 'none', background: 'transparent',
                fontFamily: '"Instrument Serif", Georgia, serif',
                fontSize: 24, fontWeight: 400, color: palette.ink,
                letterSpacing: '-0.02em', padding: 0,
              }}/>
            {!name && (
              <div style={{ fontSize: 11, color: palette.accent, marginTop: 4, display: 'flex', alignItems: 'center', gap: 4 }}>
                <Icon name="sparkle" size={11} weight={2.4}/>
                Suggested from photo · tap to keep
              </div>
            )}
          </div>
          <div style={{ padding: '14px 0' }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase', color: palette.ink3 }}>Tags</div>
            <input value={tags} onChange={e => setTags(e.target.value)}
              placeholder="optional · comma, separated"
              style={{
                width: '100%', marginTop: 4, border: 'none', outline: 'none', background: 'transparent',
                fontSize: 15, color: palette.ink, letterSpacing: '-0.01em', padding: 0,
                fontFamily: 'inherit',
              }}/>
          </div>
        </div>

        {/* re-take ghost */}
        <button style={{
          marginTop: 12, width: '100%', height: 46, borderRadius: 14,
          background: 'transparent', color: palette.ink2,
          border: `1px solid ${palette.line}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em',
        }}>
          <Icon name="camera" size={16} weight={2.0}/>
          Use a different photo
        </button>
      </div>
    </div>
  );
}

// ── Settings ─────────────────────────────────────────────────
function SettingsScreen({ palette, onBack, onShowWalkthrough, onSignOut }) {
  const user = authStore.current();
  const [fillOpac, setFillOpac] = React.useState(25);
  const [borderW, setBorderW] = React.useState(3);
  const [borderOpac, setBorderOpac] = React.useState(40);
  const [highlightOpac, setHighlightOpac] = React.useState(20);
  const [searchCollapsed, setSearchCollapsed] = React.useState(true);

  return (
    <div style={{ paddingBottom: 110 }}>
      <NavHeader palette={palette}
        left={<NavBtn palette={palette} icon="chevron-left" onClick={onBack} />}
        title="You"
      />
      <div style={{ padding: '0 22px' }}>
        {/* Profile header */}
        <div style={{
          padding: '18px 18px', borderRadius: 22,
          background: palette.surface, display: 'flex', alignItems: 'center', gap: 14,
          boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
        }}>
          <div style={{
            width: 52, height: 52, borderRadius: 999,
            background: palette.accent, color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: '"Instrument Serif", Georgia, serif', fontSize: 28,
          }}>{(user?.name || 'S').charAt(0).toUpperCase()}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 700, color: palette.ink, letterSpacing: '-0.01em' }}>{user?.name || 'Guest'}</div>
            <div style={{ fontSize: 13, color: palette.ink3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user?.email || `${FMN_DATA.length} places remembered`}</div>
          </div>
        </div>

        {/* Pro upsell */}
        <div style={{
          marginTop: 14, padding: '16px 16px', borderRadius: 22,
          background: `linear-gradient(135deg, ${palette.ink}, #2A2D38)`,
          color: '#fff', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', right: -20, top: -20 }}>
            <FlowerMark size={140} color={palette.accent} pollen={palette.pollen} style={{ opacity: 0.15 }}/>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6, position: 'relative' }}>
            <Icon name="crown" size={16} color={palette.pollen} weight={2.0}/>
            <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: palette.pollen }}>
              ForgetMeNote Pro
            </span>
          </div>
          <div style={{
            fontFamily: '"Instrument Serif", Georgia, serif', fontSize: 22,
            fontWeight: 400, letterSpacing: '-0.01em', lineHeight: 1.2, position: 'relative',
          }}>
            Unlimited places.<br/>Cloud sync. Smarter labels.
          </div>
          <button style={{
            marginTop: 14, padding: '10px 16px', borderRadius: 999, border: 'none', cursor: 'pointer',
            background: palette.pollen, color: '#3D2A0E',
            fontSize: 14, fontWeight: 700, letterSpacing: '-0.01em', position: 'relative',
          }}>Try free for 7 days</button>
        </div>

        {/* Sections */}
        <SettingsSection palette={palette} title="Walkthrough">
          <SettingsRow palette={palette} icon="sparkle" label="Show me the tour"
            onClick={onShowWalkthrough} accent />
        </SettingsSection>

        <SettingsSection palette={palette} title="Sub-space rectangles">
          <SliderRow palette={palette} label="Fill transparency" value={fillOpac} unit="%" onChange={setFillOpac} min={5} max={60}/>
          <SliderRow palette={palette} label="Border width" value={borderW} unit="px" onChange={setBorderW} min={1} max={10}/>
          <SliderRow palette={palette} label="Border transparency" value={borderOpac} unit="%" onChange={setBorderOpac} min={5} max={60}/>
        </SettingsSection>

        <SettingsSection palette={palette} title="Refreshed items">
          <ColorRow palette={palette} label="Highlight color" />
          <SliderRow palette={palette} label="Highlight strength" value={highlightOpac} unit="%" onChange={setHighlightOpac} min={0} max={100}/>
        </SettingsSection>

        <SettingsSection palette={palette} title="Search">
          <ToggleRow palette={palette} label="Search hidden items"
            sub="Include collapsed places when searching."
            value={searchCollapsed} onChange={setSearchCollapsed}/>
        </SettingsSection>

        <SettingsSection palette={palette} title="Your stuff">
          <SettingsRow palette={palette} icon="arrow-up-right" label="Export everything"
            detail="ZIP backup" />
          <SettingsRow palette={palette} icon="arrow-up" label="Import from backup" />
          <SettingsRow palette={palette} icon="check-circle" label="Check for orphans"
            detail="0 found" />
        </SettingsSection>

        <SettingsSection palette={palette} title="Account">
          <SettingsRow palette={palette} icon="x" label="Sign out"
            onClick={onSignOut} />
        </SettingsSection>

        <div style={{
          marginTop: 28, textAlign: 'center', fontSize: 12, color: palette.ink3,
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
        }}>
          <FlowerMark size={20} color={palette.accentSoft} pollen={palette.pollen} style={{ opacity: 0.7 }}/>
          <div>ForgetMeNote · v2.0</div>
        </div>
      </div>
    </div>
  );
}

function SettingsSection({ title, palette, children }) {
  return (
    <div style={{ marginTop: 26 }}>
      <div style={{
        fontSize: 11, fontWeight: 700, letterSpacing: '0.06em',
        textTransform: 'uppercase', color: palette.ink3, padding: '0 4px 8px',
      }}>{title}</div>
      <div style={{
        background: palette.surface, borderRadius: 18, overflow: 'hidden',
        boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
      }}>{children}</div>
    </div>
  );
}

function SettingsRow({ palette, icon, label, detail, accent, onClick }) {
  return (
    <div onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '14px 16px', cursor: onClick ? 'pointer' : 'default',
      borderBottom: `1px solid ${palette.line}`,
    }}>
      <div style={{
        width: 28, height: 28, borderRadius: 9,
        background: accent ? palette.accentBg : palette.paperEdge,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Icon name={icon} size={15} color={accent ? palette.accent : palette.ink2} weight={2.0}/>
      </div>
      <div style={{ flex: 1, fontSize: 15, color: accent ? palette.accent : palette.ink, fontWeight: accent ? 600 : 500, letterSpacing: '-0.01em' }}>
        {label}
      </div>
      {detail && <div style={{ fontSize: 13, color: palette.ink3 }}>{detail}</div>}
      <Icon name="chevron-right" size={16} color={palette.ink3} weight={2.0}/>
    </div>
  );
}

function SliderRow({ palette, label, value, unit, onChange, min, max }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ padding: '14px 16px', borderBottom: `1px solid ${palette.line}` }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ fontSize: 14, color: palette.ink, fontWeight: 500, letterSpacing: '-0.01em' }}>{label}</div>
        <div style={{ fontSize: 13, color: palette.ink3 }}>{value}{unit}</div>
      </div>
      <div style={{ position: 'relative', height: 24, display: 'flex', alignItems: 'center' }}>
        <div style={{ position: 'absolute', left: 0, right: 0, height: 4, borderRadius: 999, background: palette.line }} />
        <div style={{ position: 'absolute', left: 0, width: `${pct}%`, height: 4, borderRadius: 999, background: palette.accent }} />
        <input type="range" min={min} max={max} value={value}
          onChange={e => onChange(+e.target.value)}
          style={{ position: 'absolute', inset: 0, width: '100%', opacity: 0, cursor: 'pointer' }} />
        <div style={{
          position: 'absolute', left: `${pct}%`, transform: 'translateX(-50%)',
          width: 22, height: 22, borderRadius: 999, background: '#fff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.15), 0 4px 10px rgba(0,0,0,0.1)',
          border: `0.5px solid ${palette.line}`, pointerEvents: 'none',
        }}/>
      </div>
    </div>
  );
}

function ColorRow({ palette, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '14px 16px', gap: 12, borderBottom: `1px solid ${palette.line}` }}>
      <div style={{ flex: 1, fontSize: 14, color: palette.ink, fontWeight: 500 }}>{label}</div>
      <div style={{
        width: 26, height: 26, borderRadius: 999, background: palette.pollen,
        border: `2px solid ${palette.surface}`, boxShadow: `0 0 0 1px ${palette.line}`,
      }}/>
    </div>
  );
}

function ToggleRow({ palette, label, sub, value, onChange }) {
  return (
    <div onClick={() => onChange(!value)} style={{
      display: 'flex', alignItems: 'center', padding: '14px 16px', gap: 12, cursor: 'pointer',
    }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 14, color: palette.ink, fontWeight: 500 }}>{label}</div>
        {sub && <div style={{ fontSize: 12, color: palette.ink3, marginTop: 2 }}>{sub}</div>}
      </div>
      <Switch on={value} palette={palette} />
    </div>
  );
}

Object.assign(window, { DetailSheet, CaptureSheet, CreateSubScreen, SettingsScreen });
