// screens-home.jsx — Welcome + Home (landing) + Search/Find tab
// Exports: WelcomeScreen, HomeScreen, FindScreen

// ── Welcome ───────────────────────────────────────────────────
function WelcomeScreen({ palette, onStart, onSkip }) {
  return (
    <div style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      padding: '80px 28px 40px', position: 'relative',
      background: `linear-gradient(180deg, ${palette.paper} 0%, ${palette.accentBg} 100%)`,
    }}>
      {/* a small scatter of flowers as decoration */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', overflow: 'hidden' }}>
        {[
          { x: '14%', y: '12%', s: 22, o: 0.5 },
          { x: '82%', y: '8%', s: 16, o: 0.4 },
          { x: '70%', y: '22%', s: 28, o: 0.6 },
          { x: '8%', y: '34%', s: 18, o: 0.5 },
          { x: '88%', y: '46%', s: 14, o: 0.4 },
          { x: '20%', y: '70%', s: 20, o: 0.4 },
          { x: '76%', y: '78%', s: 24, o: 0.5 },
        ].map((f, i) => (
          <div key={i} style={{ position: 'absolute', left: f.x, top: f.y, opacity: f.o }}>
            <FlowerMark size={f.s} color={palette.accent} pollen={palette.pollen} />
          </div>
        ))}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', textAlign: 'center', position: 'relative' }}>
        <FlowerMark size={84} color={palette.accent} pollen={palette.pollen} />
        <div style={{
          marginTop: 32, fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 48, lineHeight: 1.05, color: palette.ink,
          letterSpacing: '-0.02em', fontWeight: 400,
        }}>
          Remember<br/>where things <em style={{ fontStyle: 'italic' }}>live</em>.
        </div>
        <div style={{
          marginTop: 18, maxWidth: 280, fontSize: 16, lineHeight: 1.45,
          color: palette.ink2, letterSpacing: '-0.01em',
        }}>
          Snap a photo, draw a circle. ForgetMeNote keeps track so you don't have to.
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, position: 'relative' }}>
        <button onClick={onStart} style={{
          height: 54, borderRadius: 999, border: 'none', cursor: 'pointer',
          background: palette.accent, color: '#fff',
          fontSize: 17, fontWeight: 600, letterSpacing: '-0.01em',
          boxShadow: `0 8px 24px ${palette.accent}55`,
        }}>Start remembering</button>
        <button onClick={onSkip} style={{
          height: 50, borderRadius: 999, border: 'none', cursor: 'pointer',
          background: 'transparent', color: palette.ink2,
          fontSize: 15, fontWeight: 500, letterSpacing: '-0.01em',
        }}>I've used it before</button>
      </div>
    </div>
  );
}

// ── Home ──────────────────────────────────────────────────────
function HomeScreen({ palette, onOpenRoom, onOpenSpace, onSearchOpen, name = 'Sam' }) {
  const recent = getRecent(6);
  const rooms = getRoots().filter(x => x.type === 'room');
  const hour = new Date().getHours();
  const greeting = hour < 5 ? 'still up?' : hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';

  return (
    <div style={{ paddingBottom: 110 }}>
      {/* Greeting header */}
      <div style={{ padding: '64px 22px 8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontSize: 13, color: palette.ink3, fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase' }}>
            Good {greeting}
          </div>
          <button onClick={onSearchOpen} style={{
            width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
            background: palette.surface, color: palette.ink,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 4px 12px rgba(26,29,38,0.05)',
          }}>
            <Icon name="search" size={19} weight={2.0} />
          </button>
        </div>
        <div style={{
          marginTop: 6, fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 34, fontWeight: 400, color: palette.ink,
          letterSpacing: '-0.02em', lineHeight: 1.08,
        }}>
          Hi {name},<br/><em style={{ fontStyle: 'italic', color: palette.accent }}>welcome back.</em>
        </div>
        <div style={{
          marginTop: 12, fontSize: 13, color: palette.ink2,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <FlowerMark size={13} color={palette.accent} pollen={palette.pollen} />
          <span><strong style={{ color: palette.ink, fontWeight: 600 }}>{FMN_DATA.length} places</strong> across <strong style={{ color: palette.ink, fontWeight: 600 }}>{rooms.length} rooms</strong>.</span>
        </div>
      </div>

      {/* Lately remembered — horizontal carousel */}
      <div style={{ marginTop: 28 }}>
        <SectionLabel palette={palette} action={{ label: 'See all', onClick: () => {} }}>
          Lately remembered
        </SectionLabel>
        <div style={{
          display: 'flex', gap: 12, overflowX: 'auto',
          padding: '0 22px 8px', scrollSnapType: 'x mandatory',
          scrollbarWidth: 'none', msOverflowStyle: 'none',
        }}>
          {recent.map(item => {
            const parent = getItem(item.parentId);
            return (
              <div key={item.id} onClick={() => onOpenSpace(item.id)} style={{
                flex: '0 0 auto', width: 168, scrollSnapAlign: 'start',
                cursor: 'pointer',
              }}>
                <div style={{
                  position: 'relative', width: '100%', aspectRatio: '4/5',
                  borderRadius: 18, overflow: 'hidden',
                  background: palette.paperEdge,
                  boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 8px 20px rgba(26,29,38,0.08)',
                }}>
                  {item.img ? (
                    <img src={item.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }}/>
                  ) : (
                    <ImgFallback name={item.name} palette={palette} style={{ width: '100%', height: '100%' }} />
                  )}
                  {/* updated badge */}
                  {item.isUpdated && (
                    <div style={{
                      position: 'absolute', top: 10, right: 10,
                      display: 'inline-flex', alignItems: 'center', gap: 4,
                      padding: '4px 9px 4px 7px', borderRadius: 999,
                      background: palette.pollen, color: '#3D2A0E',
                      fontSize: 11, fontWeight: 700, letterSpacing: '-0.01em',
                    }}>
                      <Icon name="sparkle" size={11} weight={2.4} />new
                    </div>
                  )}
                  {/* parent crumb on photo */}
                  {parent && (
                    <div style={{
                      position: 'absolute', left: 10, bottom: 10,
                      padding: '5px 9px', borderRadius: 999,
                      background: 'rgba(20,22,28,0.55)', color: '#fff',
                      backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
                      fontSize: 11, fontWeight: 600, letterSpacing: '-0.01em',
                      display: 'inline-flex', alignItems: 'center', gap: 4,
                    }}>
                      {parent.name}
                    </div>
                  )}
                </div>
                <div style={{ padding: '10px 4px 0' }}>
                  <div style={{
                    fontSize: 14, fontWeight: 600, color: palette.ink,
                    letterSpacing: '-0.01em', whiteSpace: 'nowrap',
                    overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>{item.name}</div>
                  <div style={{ fontSize: 12, color: palette.ink3, marginTop: 1 }}>
                    {timeAgo(item.updatedAt)}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Your rooms — grid */}
      <div style={{ marginTop: 32 }}>
        <SectionLabel palette={palette} action={{ label: 'New room', onClick: () => {} }}>
          Your rooms
        </SectionLabel>
        <div style={{
          padding: '0 22px',
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12,
        }}>
          {rooms.map(room => {
            const children = getChildren(room.id);
            const hue = hueFor(room.id, palette);
            return (
              <RoomTileCard key={room.id} room={room} hue={hue} children={children}
                palette={palette} onClick={() => onOpenRoom(room.id)} />
            );
          })}
          {/* add new room ghost */}
          <button onClick={() => {}} style={{
            aspectRatio: '1/1', borderRadius: 22, cursor: 'pointer',
            background: 'transparent', border: `2px dashed ${palette.line}`,
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            justifyContent: 'center', gap: 8, color: palette.ink3,
          }}>
            <Icon name="plus" size={28} weight={1.8} />
            <span style={{ fontSize: 13, fontWeight: 600 }}>New room</span>
          </button>
        </div>
      </div>

      {/* Tip card */}
      <div style={{ padding: '32px 22px 0' }}>
        <Card palette={palette} soft style={{ padding: '14px 16px', display: 'flex', gap: 12, alignItems: 'center' }}>
          <div style={{
            width: 36, height: 36, borderRadius: 12,
            background: palette.accentBg, display: 'flex',
            alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <Icon name="sparkle" size={18} color={palette.accent} weight={2.0} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: palette.ink, letterSpacing: '-0.01em' }}>
              Tip · Quick capture
            </div>
            <div style={{ fontSize: 12, color: palette.ink2, marginTop: 1 }}>
              Tap the camera button anytime — we'll ask where it goes after.
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}

function RoomTileCard({ room, hue, children, palette, onClick }) {
  const previewImgs = children.filter(c => c.img).slice(0, 3);
  return (
    <button onClick={onClick} style={{
      aspectRatio: '1/1', borderRadius: 22, padding: 16, border: 'none',
      background: hue.bg, color: hue.fg, position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      textAlign: 'left', cursor: 'pointer',
      boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 8px 20px rgba(26,29,38,0.08)',
    }}>
      {/* decorative circle */}
      <div style={{
        position: 'absolute', right: '-25%', top: '-25%',
        width: '80%', height: '80%', borderRadius: '50%',
        background: hue.fg, opacity: 0.07,
      }} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', position: 'relative' }}>
        <div style={{
          fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 44, lineHeight: 1, fontWeight: 400, letterSpacing: '-0.02em',
          marginTop: -2,
        }}>{(room.name || '?').charAt(0).toUpperCase()}</div>
        {/* preview stack */}
        {previewImgs.length > 0 && (
          <div style={{ display: 'flex' }}>
            {previewImgs.map((c, i) => (
              <div key={c.id} style={{
                width: 26, height: 26, borderRadius: 8,
                marginLeft: i === 0 ? 0 : -10,
                border: `2px solid ${hue.bg}`,
                background: hue.fg, overflow: 'hidden',
              }}>
                <img src={c.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>
            ))}
          </div>
        )}
      </div>
      <div style={{ position: 'relative' }}>
        <div style={{
          fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em',
        }}>{room.name}</div>
        <div style={{
          fontSize: 12, marginTop: 2, opacity: 0.75,
        }}>{children.length} {children.length === 1 ? 'place' : 'places'}</div>
      </div>
    </button>
  );
}

// ── Find ──────────────────────────────────────────────────────
function FindScreen({ palette, onOpenSpace, onOpenRoom }) {
  const [q, setQ] = React.useState('');
  const allTags = React.useMemo(() => {
    const set = new Set();
    FMN_DATA.forEach(x => (x.tags || []).forEach(t => set.add(t)));
    return [...set];
  }, []);
  const results = q ? searchItems(q) : [];

  return (
    <div style={{ paddingBottom: 110 }}>
      <div style={{ padding: '64px 22px 0' }}>
        <div style={{
          fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 36, fontWeight: 400, color: palette.ink,
          letterSpacing: '-0.02em', lineHeight: 1.1,
        }}>
          Find a <em style={{ fontStyle: 'italic', color: palette.accent }}>thing</em>.
        </div>
        <div style={{ marginTop: 6, fontSize: 14, color: palette.ink2 }}>
          Search by name, tag, or anything you wrote in the notes.
        </div>

        {/* search input */}
        <div style={{
          marginTop: 20, height: 50, borderRadius: 999,
          background: palette.surface, display: 'flex', alignItems: 'center',
          padding: '0 16px', gap: 10,
          boxShadow: '0 1px 2px rgba(26,29,38,0.06), 0 4px 12px rgba(26,29,38,0.05)',
        }}>
          <Icon name="search" size={20} color={palette.ink3} weight={2.0} />
          <input value={q} onChange={e => setQ(e.target.value)}
            placeholder="bay leaves, #cables, charger…"
            style={{
              flex: 1, border: 'none', outline: 'none', background: 'transparent',
              fontSize: 16, color: palette.ink, letterSpacing: '-0.01em',
              fontFamily: 'inherit',
            }} />
          {q && <button onClick={() => setQ('')} style={{
            border: 'none', background: 'none', padding: 4, cursor: 'pointer',
            color: palette.ink3, display: 'flex',
          }}><Icon name="x" size={18} weight={2.2}/></button>}
        </div>
      </div>

      {!q && (
        <>
          {/* tag cloud */}
          <div style={{ marginTop: 28 }}>
            <SectionLabel palette={palette}>Popular tags</SectionLabel>
            <div style={{ padding: '0 22px', display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {allTags.slice(0, 16).map(t => (
                <Chip key={t} palette={palette} onClick={() => setQ(t)}>
                  {t}
                </Chip>
              ))}
            </div>
          </div>
          {/* recent searches */}
          <div style={{ marginTop: 28 }}>
            <SectionLabel palette={palette}>Recent searches</SectionLabel>
            <div style={{ padding: '0 22px' }}>
              <Card palette={palette} style={{ padding: 4 }}>
                {['lightning cable', '#christmas', 'bay leaves'].map((s, i, arr) => (
                  <div key={s} onClick={() => setQ(s)} style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '12px 14px', cursor: 'pointer',
                    borderBottom: i < arr.length - 1 ? `1px solid ${palette.line}` : 'none',
                  }}>
                    <Icon name="clock" size={18} color={palette.ink3} weight={1.8}/>
                    <span style={{ flex: 1, fontSize: 15, color: palette.ink }}>{s}</span>
                    <Icon name="corner-inward" size={16} color={palette.ink3} weight={1.8}/>
                  </div>
                ))}
              </Card>
            </div>
          </div>
        </>
      )}

      {q && (
        <div style={{ marginTop: 20, padding: '0 22px' }}>
          {results.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px 20px', color: palette.ink2 }}>
              <FlowerMark size={28} color={palette.ink3} pollen={palette.ink3} style={{ opacity: 0.5 }}/>
              <div style={{ marginTop: 12, fontSize: 15 }}>
                Nothing here for "<em>{q}</em>" yet.
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ fontSize: 12, color: palette.ink3, marginBottom: 4 }}>
                {results.length} {results.length === 1 ? 'match' : 'matches'}
              </div>
              {results.map(item => {
                const ancestry = getAncestry(item.id);
                return (
                  <div key={item.id} onClick={() => item.type === 'room' ? onOpenRoom(item.id) : onOpenSpace(item.id)} style={{
                    background: palette.surface, borderRadius: 16,
                    padding: '12px 14px', display: 'flex', gap: 12, cursor: 'pointer',
                    boxShadow: '0 1px 2px rgba(26,29,38,0.04)',
                  }}>
                    <div style={{ width: 48, height: 48, borderRadius: 12, overflow: 'hidden', flexShrink: 0 }}>
                      {item.img ? (
                        <img src={item.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      ) : (
                        <ImgFallback name={item.name} palette={palette} style={{ width: '100%', height: '100%', fontFamily: '"Instrument Serif", serif', fontSize: 24 }}>
                          {item.name.charAt(0).toUpperCase()}
                        </ImgFallback>
                      )}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 15, fontWeight: 600, color: palette.ink, letterSpacing: '-0.01em' }}>{item.name}</div>
                      <div style={{ fontSize: 12, color: palette.ink3, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {ancestry.slice(0, -1).map(a => a.name).join(' › ') || 'Root'}
                      </div>
                    </div>
                    <Icon name="chevron-right" size={18} color={palette.ink3} weight={2.0} style={{ alignSelf: 'center' }} />
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

Object.assign(window, { WelcomeScreen, HomeScreen, FindScreen });
