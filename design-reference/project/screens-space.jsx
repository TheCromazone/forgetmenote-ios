// screens-space.jsx — Room view (no-img container) + Space view (photo + sub-spaces) + Detail edit
// Exports: RoomScreen, SpaceScreen, DetailSheet

// ── Room (container w/o image) ────────────────────────────────
function RoomScreen({ palette, roomId, onBack, onOpenSpace, onOpenSettings, onAdd, onOpenDetail }) {
  const room = getItem(roomId);
  const places = getChildren(roomId);
  const hue = hueFor(roomId, palette);

  return (
    <div style={{ paddingBottom: 110 }}>
      {/* hero header — colored card stretching from top */}
      <div style={{
        background: hue.bg, color: hue.fg,
        padding: '54px 22px 28px', position: 'relative', overflow: 'hidden',
        borderRadius: '0 0 32px 32px',
      }}>
        <div style={{ position: 'absolute', right: '-15%', bottom: '-30%',
          width: '70%', height: '120%', borderRadius: '50%',
          background: hue.fg, opacity: 0.08 }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={onBack} style={{
            width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
            background: 'rgba(255,255,255,0.18)', color: hue.fg,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
          }}>
            <Icon name="chevron-left" size={20} weight={2.2} />
          </button>
          <button onClick={onOpenSettings} style={{
            width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
            background: 'rgba(255,255,255,0.18)', color: hue.fg,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
          }}>
            <Icon name="ellipsis" size={22} />
          </button>
        </div>
        <div style={{ marginTop: 28, position: 'relative' }}>
          <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', opacity: 0.75 }}>
            Room
          </div>
          <div style={{
            marginTop: 6, fontFamily: '"Instrument Serif", Georgia, serif',
            fontSize: 56, lineHeight: 1, fontWeight: 400, letterSpacing: '-0.02em',
          }}>{room.name}</div>
          <div style={{ marginTop: 12, fontSize: 14, opacity: 0.85, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span>{places.length} {places.length === 1 ? 'place' : 'places'}</span>
            {(room.tags || []).length > 0 && <>
              <span style={{ opacity: 0.5 }}>·</span>
              <span style={{ display: 'flex', gap: 6 }}>
                {(room.tags || []).map(t => (
                  <span key={t} style={{
                    fontSize: 11, padding: '3px 8px', borderRadius: 999,
                    background: 'rgba(255,255,255,0.18)',
                  }}>#{t}</span>
                ))}
              </span>
            </>}
          </div>
        </div>
      </div>

      {/* Add place — primary action band */}
      <div style={{ padding: '20px 22px 0' }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={onAdd} style={{
            flex: 1, height: 50, borderRadius: 16, border: 'none', cursor: 'pointer',
            background: palette.ink, color: palette.paper,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em',
          }}>
            <Icon name="camera" size={18} weight={2.2}/>
            Add a place
          </button>
          <button onClick={() => onOpenDetail(roomId)} style={{
            width: 50, height: 50, borderRadius: 16, border: 'none', cursor: 'pointer',
            background: palette.surface, color: palette.ink,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 4px 12px rgba(26,29,38,0.05)',
          }}>
            <Icon name="pencil" size={18} weight={2.0}/>
          </button>
        </div>
      </div>

      {/* Places grid */}
      <div style={{ marginTop: 26 }}>
        <SectionLabel palette={palette}>Places in this room</SectionLabel>
        {places.length === 0 ? (
          <div style={{ padding: '24px 22px' }}>
            <EmptyState palette={palette} kind="room" />
          </div>
        ) : (
          <div style={{
            padding: '0 22px',
            display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12,
          }}>
            {places.map(p => (
              <PlaceCard key={p.id} item={p} palette={palette}
                onClick={() => onOpenSpace(p.id)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function PlaceCard({ item, palette, onClick }) {
  const children = getChildren(item.id);
  return (
    <div onClick={onClick} style={{
      cursor: 'pointer', borderRadius: 18, overflow: 'hidden',
      background: palette.surface, position: 'relative',
      boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 6px 16px rgba(26,29,38,0.06)',
    }}>
      <div style={{ position: 'relative', aspectRatio: '1/1', background: palette.paperEdge }}>
        {item.img ? (
          <img src={item.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <ImgFallback name={item.name} palette={palette} style={{ width: '100%', height: '100%', fontFamily: '"Instrument Serif", serif', fontSize: 56 }}>
            {item.name.charAt(0).toUpperCase()}
          </ImgFallback>
        )}
        {item.isUpdated && (
          <div style={{
            position: 'absolute', top: 8, right: 8,
            width: 24, height: 24, borderRadius: 999,
            background: palette.pollen, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          }}>
            <Icon name="sparkle" size={12} weight={2.4} color="#3D2A0E"/>
          </div>
        )}
        {children.length > 0 && (
          <div style={{
            position: 'absolute', left: 8, bottom: 8,
            padding: '4px 9px', borderRadius: 999,
            background: 'rgba(20,22,28,0.55)', color: '#fff',
            backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
            fontSize: 11, fontWeight: 600,
            display: 'inline-flex', alignItems: 'center', gap: 4,
          }}>
            <Icon name="grid" size={10} weight={2.4}/>
            {children.length}
          </div>
        )}
      </div>
      <div style={{ padding: '10px 12px 12px' }}>
        <div style={{
          fontSize: 14, fontWeight: 600, color: palette.ink, letterSpacing: '-0.01em',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{item.name}</div>
        <div style={{ fontSize: 11, color: palette.ink3, marginTop: 2 }}>
          {timeAgo(item.updatedAt)}
        </div>
      </div>
    </div>
  );
}

// ── Space (photo with sub-space rectangles) ───────────────────
function SpaceScreen({ palette, spaceId, onBack, onOpenSpace, onOpenDetail, onAddSub, onToggleUpdated }) {
  const item = getItem(spaceId);
  const subs = getChildren(spaceId).filter(c => c.rect); // only positioned subs
  const ancestry = getAncestry(spaceId);
  const parent = ancestry[ancestry.length - 2];
  const [activeSub, setActiveSub] = React.useState(null);
  const [viewMode, setViewMode] = React.useState('photo'); // 'photo' | 'grid'

  return (
    <div style={{ paddingBottom: 110 }}>
      {/* nav header */}
      <NavHeader palette={palette}
        left={<NavBtn palette={palette} icon="chevron-left" onClick={onBack} />}
        right={<NavBtn palette={palette} icon="ellipsis" onClick={() => onOpenDetail(spaceId)} />}
        title={item.name}
        subtitle={ancestry.length > 1 ? ancestry.slice(0, -1).map(a => a.name).join(' › ') : null}
      />

      {/* hero photo with sub-space overlays */}
      <div style={{ padding: '0 16px' }}>
        <div style={{
          position: 'relative', borderRadius: 26, overflow: 'hidden',
          background: palette.paperEdge,
          aspectRatio: '4/5',
          boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 12px 32px rgba(26,29,38,0.10)',
        }}>
          {item.img ? (
            <img src={item.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <ImgFallback name={item.name} palette={palette} style={{ width: '100%', height: '100%' }} />
          )}
          {/* sub-space rectangles overlaid */}
          {subs.map((sub, idx) => {
            const isActive = activeSub === sub.id;
            return (
              <div key={sub.id} onClick={(e) => {
                e.stopPropagation();
                if (isActive) onOpenSpace(sub.id); else setActiveSub(sub.id);
              }} style={{
                position: 'absolute',
                left: `${sub.rect.x * 100}%`,
                top: `${sub.rect.y * 100}%`,
                width: `${sub.rect.w * 100}%`,
                height: `${sub.rect.h * 100}%`,
                border: `2px solid ${isActive ? palette.accent : '#fff'}`,
                borderRadius: 8, cursor: 'pointer',
                background: isActive ? `${palette.accent}33` : 'rgba(91,127,224,0.18)',
                boxShadow: isActive
                  ? `0 0 0 4px ${palette.accent}30, 0 8px 24px ${palette.accent}55`
                  : '0 2px 8px rgba(0,0,0,0.25)',
                transition: 'all 200ms ease',
              }}>
                {/* number badge */}
                <div style={{
                  position: 'absolute', top: -10, left: -10,
                  width: 24, height: 24, borderRadius: 999,
                  background: isActive ? palette.accent : '#fff',
                  color: isActive ? '#fff' : palette.ink,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontWeight: 700,
                  boxShadow: '0 2px 8px rgba(0,0,0,0.25)',
                }}>{idx + 1}</div>
                {/* label on active */}
                {isActive && (
                  <div style={{
                    position: 'absolute', bottom: -36, left: '50%',
                    transform: 'translateX(-50%)', whiteSpace: 'nowrap',
                    padding: '5px 10px', borderRadius: 999,
                    background: palette.accent, color: '#fff',
                    fontSize: 12, fontWeight: 600,
                    boxShadow: `0 4px 12px ${palette.accent}66`,
                  }}>
                    {sub.name} →
                  </div>
                )}
              </div>
            );
          })}
          {/* tap hint when no active */}
          {subs.length > 0 && !activeSub && (
            <div style={{
              position: 'absolute', bottom: 12, left: 12, right: 12,
              padding: '8px 14px', borderRadius: 999,
              background: 'rgba(20,22,28,0.55)', color: '#fff',
              backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
              fontSize: 12, fontWeight: 500, letterSpacing: '-0.01em',
              textAlign: 'center',
            }}>
              Tap a spot to peek inside ✦
            </div>
          )}
          {item.isUpdated && (
            <div style={{
              position: 'absolute', top: 14, right: 14,
              display: 'inline-flex', alignItems: 'center', gap: 5,
              padding: '5px 11px 5px 9px', borderRadius: 999,
              background: palette.pollen, color: '#3D2A0E',
              fontSize: 12, fontWeight: 700, letterSpacing: '-0.01em',
              boxShadow: '0 2px 8px rgba(0,0,0,0.18)',
            }}>
              <Icon name="sparkle" size={12} weight={2.4} />refreshed
            </div>
          )}
        </div>
      </div>

      {/* meta row — tags + actions */}
      <div style={{ padding: '20px 22px 0' }}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 14 }}>
          {(item.tags || []).map(t => (
            <Chip key={t} palette={palette}>{t.startsWith('#') ? t : '#' + t}</Chip>
          ))}
        </div>
        {item.notes && (
          <div style={{
            padding: '12px 14px', borderRadius: 14, marginBottom: 14,
            background: palette.surface, display: 'flex', gap: 10,
            boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
          }}>
            <div style={{
              width: 28, height: 28, borderRadius: 9,
              background: palette.accentBg, display: 'flex', flexShrink: 0,
              alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="note" size={14} color={palette.accent} weight={1.8} />
            </div>
            <div style={{ flex: 1, fontSize: 14, color: palette.ink, lineHeight: 1.4, letterSpacing: '-0.01em' }}>
              {item.notes}
            </div>
          </div>
        )}
      </div>

      {/* Sub-spaces — view-switchable scan section */}
      {(subs.length > 0 || true) && (
        <div style={{ marginTop: 20 }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '0 22px', marginBottom: 12,
          }}>
            <div style={{
              fontFamily: '"Instrument Serif", Georgia, serif',
              fontSize: 22, fontWeight: 400, color: palette.ink,
              letterSpacing: '-0.01em',
            }}>What's inside <em style={{ fontStyle: 'italic', color: palette.accent }}>·</em> {subs.length}</div>
            <div style={{ display: 'flex', gap: 4, background: palette.paperEdge, borderRadius: 999, padding: 3 }}>
              {[
                { id: 'photo', icon: 'eye' },
                { id: 'grid',  icon: 'grid' },
              ].map(v => (
                <button key={v.id} onClick={() => setViewMode(v.id)} style={{
                  width: 32, height: 28, borderRadius: 999, border: 'none', cursor: 'pointer',
                  background: viewMode === v.id ? palette.surface : 'transparent',
                  color: viewMode === v.id ? palette.ink : palette.ink3,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: viewMode === v.id ? '0 1px 2px rgba(26,29,38,0.08)' : 'none',
                }}>
                  <Icon name={v.icon} size={14} weight={2.0} />
                </button>
              ))}
            </div>
          </div>

          {subs.length === 0 ? (
            <div style={{ padding: '0 22px' }}>
              <EmptyState palette={palette} kind="subs" onAdd={onAddSub} />
            </div>
          ) : viewMode === 'photo' ? (
            // horizontal scan carousel — quickly cycle through sub-spaces
            <div style={{
              display: 'flex', gap: 10, overflowX: 'auto', padding: '0 22px 8px',
              scrollSnapType: 'x mandatory', scrollbarWidth: 'none',
            }}>
              {subs.map((sub, idx) => (
                <SubScanCard key={sub.id} sub={sub} idx={idx + 1} parent={item}
                  active={activeSub === sub.id}
                  onClick={() => setActiveSub(sub.id)}
                  onOpen={() => onOpenSpace(sub.id)}
                  palette={palette} />
              ))}
            </div>
          ) : (
            // grid
            <div style={{ padding: '0 22px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {subs.map(sub => (
                <PlaceCard key={sub.id} item={sub} palette={palette}
                  onClick={() => onOpenSpace(sub.id)} />
              ))}
            </div>
          )}

          {subs.length > 0 && (
            <div style={{ padding: '14px 22px 0' }}>
              <button onClick={onAddSub} style={{
                width: '100%', height: 46, borderRadius: 14, cursor: 'pointer',
                background: 'transparent', color: palette.ink2,
                border: `1.5px dashed ${palette.line}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em',
              }}>
                <Icon name="plus" size={16} weight={2.2}/>
                Add another spot
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// SubScanCard — shows the parent photo zoomed/cropped to the sub-space rect
function SubScanCard({ sub, idx, parent, active, onClick, onOpen, palette }) {
  // crop parent photo to rect by scaling background
  const r = sub.rect;
  const scaleX = 1 / r.w;
  const scaleY = 1 / r.h;
  const bgX = -r.x * 100 * scaleX;
  const bgY = -r.y * 100 * scaleY;
  return (
    <div onClick={active ? onOpen : onClick} style={{
      flex: '0 0 auto', width: 168, cursor: 'pointer',
      scrollSnapAlign: 'start',
    }}>
      <div style={{
        position: 'relative', width: '100%', aspectRatio: '3/4',
        borderRadius: 16, overflow: 'hidden',
        background: parent.img ? `url(${parent.img}) ${bgX}% ${bgY}% / ${scaleX*100}% ${scaleY*100}%` : palette.paperEdge,
        border: active ? `2px solid ${palette.accent}` : `1px solid ${palette.line}`,
        boxShadow: active
          ? `0 8px 24px ${palette.accent}55, 0 0 0 4px ${palette.accent}20`
          : '0 1px 2px rgba(26,29,38,0.06), 0 4px 12px rgba(26,29,38,0.05)',
        transition: 'all 200ms ease',
      }}>
        <div style={{
          position: 'absolute', top: 8, left: 8,
          width: 22, height: 22, borderRadius: 999,
          background: active ? palette.accent : 'rgba(20,22,28,0.6)',
          color: '#fff', backdropFilter: 'blur(6px)', WebkitBackdropFilter: 'blur(6px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 11, fontWeight: 700,
        }}>{idx}</div>
        {sub.isUpdated && (
          <div style={{
            position: 'absolute', top: 8, right: 8,
            width: 22, height: 22, borderRadius: 999,
            background: palette.pollen, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name="sparkle" size={11} weight={2.4} color="#3D2A0E"/>
          </div>
        )}
      </div>
      <div style={{ padding: '8px 4px 0' }}>
        <div style={{
          fontSize: 13, fontWeight: 600, color: palette.ink, letterSpacing: '-0.01em',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{sub.name}</div>
        {(sub.tags || []).length > 0 && (
          <div style={{ fontSize: 11, color: palette.ink3, marginTop: 2,
            whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {(sub.tags || []).slice(0, 2).join(' · ')}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Empty state ───────────────────────────────────────────────
function EmptyState({ palette, kind, onAdd }) {
  const copy = {
    room: { title: 'No places yet', body: 'Tap "Add a place" to snap your first photo. We\'ll remember it for you.' },
    subs: { title: 'No spots marked yet', body: 'Draw a box on the photo to mark a spot. Sub-spaces help you remember the small things.' },
    notes: { title: 'No notes yet', body: 'Anything to remember? Tap to jot it down.' },
  }[kind] || { title: 'Nothing yet', body: 'Add your first one.' };
  return (
    <div style={{
      padding: '28px 22px', borderRadius: 22, textAlign: 'center',
      background: palette.surface, border: `1px dashed ${palette.line}`,
    }}>
      <FlowerMark size={32} color={palette.accentSoft} pollen={palette.pollen} style={{ opacity: 0.7 }}/>
      <div style={{
        marginTop: 10, fontFamily: '"Instrument Serif", Georgia, serif',
        fontSize: 20, color: palette.ink, letterSpacing: '-0.01em',
      }}>{copy.title}</div>
      <div style={{ marginTop: 4, fontSize: 13, color: palette.ink2, maxWidth: 260, margin: '4px auto 0', lineHeight: 1.45 }}>
        {copy.body}
      </div>
      {onAdd && (
        <button onClick={onAdd} style={{
          marginTop: 14, padding: '10px 18px', borderRadius: 999, border: 'none', cursor: 'pointer',
          background: palette.accent, color: '#fff',
          fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em',
          display: 'inline-flex', alignItems: 'center', gap: 6,
        }}>
          <Icon name="camera" size={15} weight={2.2}/>
          Add now
        </button>
      )}
    </div>
  );
}

Object.assign(window, { RoomScreen, SpaceScreen, EmptyState });
