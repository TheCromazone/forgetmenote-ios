// App.jsx — top-level navigation + tweaks
// Hosts the iOS device frame + screen routing.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "paletteKey": "forget",
  "density": "regular",
  "iconStyle": "outline",
  "showFlowers": true,
  "showTabBar": true,
  "screen": "home"
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const palette = PALETTES[t.paletteKey] || PALETTES.forget;
  const { user, signIn, signUp, signOut } = useAuth();

  // auth screen state: 'signin' | 'signup' (only used when no user)
  const [authScreen, setAuthScreen] = React.useState('signin');

  // navigation state — a small stack with a tab
  const [tab, setTab]   = React.useState('home');
  const [stack, setStack] = React.useState([]); // [{ screen, id }]
  const [sheet, setSheet] = React.useState(null); // 'detail' | 'capture' | null
  const [sheetItemId, setSheetItemId] = React.useState(null);
  const [welcomed, setWelcomed] = React.useState(true); // false to show welcome first

  // sync `screen` tweak as a quick jump
  React.useEffect(() => {
    if (t.screen === 'signin')  { setAuthScreen('signin'); return; }
    if (t.screen === 'signup')  { setAuthScreen('signup'); return; }
    if (t.screen === 'welcome') { setWelcomed(false); setStack([]); setTab('home'); }
    else if (t.screen === 'home') { setWelcomed(true); setStack([]); setTab('home'); }
    else if (t.screen === 'room') { setWelcomed(true); setStack([{ screen: 'room', id: 'home' }]); setTab('home'); }
    else if (t.screen === 'space') { setWelcomed(true); setStack([{ screen: 'space', id: 'kitchen' }]); setTab('home'); }
    else if (t.screen === 'subspace') { setWelcomed(true); setStack([{ screen: 'space', id: 'spice' }]); setTab('home'); }
    else if (t.screen === 'create') { setWelcomed(true); setStack([{ screen: 'create', parentId: 'kitchen' }]); setTab('home'); }
    else if (t.screen === 'find') { setWelcomed(true); setStack([]); setTab('find'); }
    else if (t.screen === 'settings') { setWelcomed(true); setStack([]); setTab('you'); }
  }, [t.screen]);

  const push = (screen, payload) => setStack(s => [...s, { screen, ...payload }]);
  const pop = () => setStack(s => s.slice(0, -1));
  const top = stack[stack.length - 1];

  const navOpenRoom = (id) => push('room', { id });
  const navOpenSpace = (id) => {
    const it = getItem(id);
    if (!it) return;
    if (it.type === 'room') push('room', { id });
    else push('space', { id });
  };
  const navOpenDetail = (id) => { setSheetItemId(id); setSheet('detail'); };
  const navAddSub = (parentId) => push('create', { parentId });
  const navCapture = () => setSheet('capture');

  // render currently visible screen
  let body;
  if (!user) {
    body = authScreen === 'signup'
      ? <SignUpScreen palette={palette} signUp={signUp}
          onSignedUp={() => { setWelcomed(false); }}
          onGoSignIn={() => setAuthScreen('signin')} />
      : <SignInScreen palette={palette} signIn={signIn}
          onSignedIn={() => { setWelcomed(true); }}
          onGoSignUp={() => setAuthScreen('signup')} />;
  } else if (!welcomed) {
    body = <WelcomeScreen palette={palette}
      onStart={() => setWelcomed(true)}
      onSkip={() => setWelcomed(true)} />;
  } else if (top && top.screen === 'create') {
    body = <CreateSubScreen palette={palette} parentId={top.parentId}
      onClose={pop} onSave={() => pop()} />;
  } else if (top && top.screen === 'room') {
    body = <RoomScreen palette={palette} roomId={top.id}
      onBack={pop} onOpenSpace={navOpenSpace} onOpenSettings={() => navOpenDetail(top.id)}
      onAdd={() => navAddSub(top.id)}
      onOpenDetail={navOpenDetail} />;
  } else if (top && top.screen === 'space') {
    body = <SpaceScreen palette={palette} spaceId={top.id}
      onBack={pop} onOpenSpace={navOpenSpace}
      onOpenDetail={navOpenDetail}
      onAddSub={() => navAddSub(top.id)} />;
  } else if (tab === 'find') {
    body = <FindScreen palette={palette}
      onOpenSpace={navOpenSpace} onOpenRoom={navOpenRoom} />;
  } else if (tab === 'you') {
    body = <SettingsScreen palette={palette}
      onBack={() => setTab('home')}
      onShowWalkthrough={() => { setWelcomed(false); }}
      onSignOut={() => { signOut(); setTab('home'); setStack([]); }} />;
  } else {
    body = <HomeScreen palette={palette}
      onOpenRoom={navOpenRoom} onOpenSpace={navOpenSpace}
      onSearchOpen={() => setTab('find')}
      name={user.name.split(' ')[0]} />;
  }

  // hide tab bar on certain in-stack screens (create flow)
  const hideTabBar = !user || (top && top.screen === 'create') || !welcomed;

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'linear-gradient(180deg, #EFE7D6 0%, #E5DEC8 100%)',
      padding: '40px 16px',
      fontFamily: '-apple-system, system-ui, "SF Pro", sans-serif',
    }}>
      {/* font: Instrument Serif (warm italics/headings) */}
      <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap" rel="stylesheet" />

      <div style={{ position: 'relative' }}>
        <IOSDevice width={402} height={874}>
          <PaperBg palette={palette} style={{ minHeight: '100%' }}>
            {body}
            {!hideTabBar && (
              <TabBar palette={palette} tab={tab} setTab={(id) => { setStack([]); setTab(id); }}
                onCapture={navCapture} />
            )}
            {sheet === 'detail' && user && (
              <DetailSheet palette={palette} itemId={sheetItemId} onClose={() => setSheet(null)} />
            )}
            {sheet === 'capture' && user && (
              <CaptureSheet palette={palette}
                onClose={() => setSheet(null)}
                onPickRoom={(id) => { setSheet(null); push('create', { parentId: id }); }}
                onSnap={() => { setSheet(null); push('create', { parentId: 'kitchen' }); }} />
            )}
          </PaperBg>
        </IOSDevice>
      </div>

      <TweaksPanel>
        <TweakSection label="Theme" />
        <TweakColor label="Palette" value={t.paletteKey === 'forget' ? '#5B7FE0' : t.paletteKey === 'forest' ? '#3F7D5E' : '#C2543F'}
          options={['#5B7FE0', '#3F7D5E', '#C2543F']}
          onChange={(v) => setTweak('paletteKey', v === '#5B7FE0' ? 'forget' : v === '#3F7D5E' ? 'forest' : 'clay')} />
        <TweakToggle label="Show flowers" value={t.showFlowers} onChange={(v) => setTweak('showFlowers', v)} />

        <TweakSection label="Layout" />
        <TweakRadio label="Density" value={t.density}
          options={['compact', 'regular', 'comfy']}
          onChange={(v) => setTweak('density', v)} />
        <TweakToggle label="Show tab bar" value={t.showTabBar} onChange={(v) => setTweak('showTabBar', v)} />

        <TweakSection label="Jump to screen" />
        <TweakSelect label="Screen" value={t.screen}
          options={['signin', 'signup', 'welcome', 'home', 'find', 'room', 'space', 'subspace', 'create', 'settings']}
          onChange={(v) => setTweak('screen', v)} />
        <TweakButton label="Sign out" onClick={() => { signOut(); setTweak('screen', 'signin'); }} />
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
