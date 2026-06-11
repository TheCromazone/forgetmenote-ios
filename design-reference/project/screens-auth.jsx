// screens-auth.jsx — SignInScreen, SignUpScreen, with form fields + validation
// Exports: SignInScreen, SignUpScreen

function TextField({ palette, label, type = 'text', value, onChange, placeholder, autoFocus, error, icon, trailing }) {
  const [focused, setFocused] = React.useState(false);
  const showError = !!error;
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{
        background: palette.surface, borderRadius: 16,
        padding: '12px 14px',
        border: `1.5px solid ${showError ? palette.danger : (focused ? palette.accent : 'transparent')}`,
        boxShadow: showError ? 'none' : '0 1px 2px rgba(26,29,38,0.04)',
        transition: 'border-color 150ms',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        {icon && (
          <div style={{ color: palette.ink3, display: 'flex' }}>
            <Icon name={icon} size={18} weight={1.8}/>
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 10, fontWeight: 700, color: showError ? palette.danger : palette.ink3,
            letterSpacing: '0.08em', textTransform: 'uppercase',
          }}>{label}</div>
          <input type={type} value={value}
            onChange={e => onChange(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            autoFocus={autoFocus} autoComplete="off"
            placeholder={placeholder}
            style={{
              width: '100%', marginTop: 1, border: 'none', outline: 'none',
              background: 'transparent', fontSize: 16, color: palette.ink,
              letterSpacing: '-0.01em', padding: 0, fontFamily: 'inherit',
            }} />
        </div>
        {trailing}
      </div>
      {showError && (
        <div style={{
          fontSize: 12, color: palette.danger, marginTop: 6, marginLeft: 4,
          display: 'flex', alignItems: 'center', gap: 5, fontWeight: 500,
        }}>
          <span style={{ width: 4, height: 4, borderRadius: 999, background: palette.danger }} />
          {error}
        </div>
      )}
    </div>
  );
}

function PrimaryButton({ palette, label, onClick, loading, disabled }) {
  return (
    <button onClick={onClick} disabled={disabled || loading} style={{
      width: '100%', height: 54, borderRadius: 999, border: 'none',
      background: disabled ? palette.line : palette.accent, color: '#fff',
      fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em',
      cursor: disabled ? 'not-allowed' : 'pointer',
      boxShadow: disabled ? 'none' : `0 8px 24px ${palette.accent}55`,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      transition: 'background 150ms',
    }}>
      {loading ? (
        <div style={{
          width: 18, height: 18, borderRadius: 999,
          border: '2.5px solid rgba(255,255,255,0.35)',
          borderTopColor: '#fff', animation: 'fmnspin 0.7s linear infinite',
        }}/>
      ) : label}
    </button>
  );
}

function SocialButton({ kind, palette, onClick }) {
  const styles = {
    apple:  { bg: '#000', fg: '#fff', label: 'Continue with Apple',
              icon: <svg width="18" height="22" viewBox="0 0 18 22"><path d="M14.5 11.5c0-2.4 2-3.5 2.1-3.6-1.1-1.6-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.9C4.5 6.1 3 7 2.2 8.4c-1.7 3-.4 7.5 1.2 9.9.8 1.2 1.8 2.5 3 2.5 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.1.8 1.3 0 2.1-1.2 2.9-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.5-1-2.5-3.7zM11.7 4.4c.7-.8 1.1-1.9 1-3-.9 0-2 .6-2.7 1.4-.6.7-1.2 1.8-1 2.9 1 .1 2 -.5 2.7-1.3z" fill="#fff"/></svg> },
    google: { bg: '#fff', fg: palette.ink, label: 'Continue with Google',
              icon: <svg width="18" height="18" viewBox="0 0 18 18"><path d="M17.6 9.2c0-.6-.1-1.2-.2-1.8H9v3.4h4.8c-.2 1.1-.8 2-1.8 2.6v2.2h2.9c1.7-1.5 2.7-3.8 2.7-6.4z" fill="#4285F4"/><path d="M9 18c2.4 0 4.5-.8 6-2.2l-2.9-2.2c-.8.5-1.8.9-3.1.9-2.4 0-4.4-1.6-5.1-3.8H.9v2.3C2.4 15.9 5.5 18 9 18z" fill="#34A853"/><path d="M3.9 10.7c-.2-.5-.3-1.1-.3-1.7s.1-1.2.3-1.7V5h-3C.3 6.2 0 7.6 0 9s.3 2.8.9 4l3-2.3z" fill="#FBBC04"/><path d="M9 3.6c1.3 0 2.5.5 3.5 1.4l2.6-2.6C13.5.9 11.4 0 9 0 5.5 0 2.4 2.1.9 5l3 2.3C4.6 5.1 6.6 3.6 9 3.6z" fill="#EA4335"/></svg> },
  }[kind];
  return (
    <button onClick={onClick} style={{
      width: '100%', height: 50, borderRadius: 999, cursor: 'pointer',
      background: styles.bg, color: styles.fg,
      border: kind === 'google' ? `1px solid ${palette.line}` : 'none',
      fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
    }}>
      {styles.icon}
      {styles.label}
    </button>
  );
}

function AuthShell({ palette, children }) {
  return (
    <div style={{
      minHeight: '100%', display: 'flex', flexDirection: 'column',
      padding: '60px 28px 32px',
      background: `linear-gradient(180deg, ${palette.paper} 0%, ${palette.accentBg} 100%)`,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* corner flowers */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        {[
          { x: '-8%', y: '-4%', s: 90, o: 0.18 },
          { x: '85%', y: '-2%', s: 64, o: 0.14 },
          { x: '88%', y: '92%', s: 80, o: 0.16 },
        ].map((f, i) => (
          <div key={i} style={{ position: 'absolute', left: f.x, top: f.y, opacity: f.o }}>
            <FlowerMark size={f.s} color={palette.accent} pollen={palette.pollen} />
          </div>
        ))}
      </div>
      {children}
    </div>
  );
}

// ── Sign In ───────────────────────────────────────────────────
function SignInScreen({ palette, signIn, onSignedIn, onGoSignUp }) {
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [showPw, setShowPw] = React.useState(false);
  const [errors, setErrors] = React.useState({});
  const [loading, setLoading] = React.useState(false);

  const submit = () => {
    const errs = {};
    if (!validateEmail(email)) errs.email = 'That doesn\'t look like an email.';
    if (!password) errs.password = 'Need your password.';
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setLoading(true);
    // small delay for affordance
    setTimeout(() => {
      const r = signIn(email, password);
      setLoading(false);
      if (!r.ok) setErrors({ form: r.error });
      else onSignedIn();
    }, 400);
  };

  return (
    <AuthShell palette={palette}>
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', flex: 1 }}>
        <div style={{ marginBottom: 24, display: 'flex', alignItems: 'center', gap: 10 }}>
          <FlowerMark size={36} color={palette.accent} pollen={palette.pollen} />
          <div style={{
            fontFamily: '"Instrument Serif", Georgia, serif', fontSize: 22,
            color: palette.ink, letterSpacing: '-0.01em',
          }}>ForgetMeNote</div>
        </div>

        <div style={{
          fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 40, lineHeight: 1.05, color: palette.ink,
          letterSpacing: '-0.02em', fontWeight: 400,
        }}>
          Welcome <em style={{ fontStyle: 'italic', color: palette.accent }}>back.</em>
        </div>
        <div style={{ marginTop: 8, fontSize: 15, color: palette.ink2, marginBottom: 14 }}>
          Sign in to pick up where you left off.
        </div>

        <div onClick={() => { setEmail('demo@fmn.app'); setPassword('forget'); }} style={{
          marginBottom: 18, padding: '8px 12px', borderRadius: 12, cursor: 'pointer',
          background: palette.accentBg, border: `1px dashed ${palette.accentSoft}`,
          fontSize: 12, color: palette.accent, fontWeight: 500,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <Icon name="sparkle" size={13} weight={2.2}/>
          <span><strong style={{ fontWeight: 700 }}>Demo · </strong>tap to autofill — demo@fmn.app / forget</span>
        </div>

        <TextField palette={palette} label="Email" type="email"
          value={email} onChange={setEmail} icon="tag"
          placeholder="you@example.com" autoFocus
          error={errors.email} />
        <TextField palette={palette} label="Password" type={showPw ? 'text' : 'password'}
          value={password} onChange={setPassword} icon="bookmark"
          placeholder="••••••••"
          error={errors.password}
          trailing={
            <button onClick={() => setShowPw(s => !s)} style={{
              background: 'none', border: 'none', padding: 6, cursor: 'pointer',
              color: palette.ink3, display: 'flex',
            }}>
              <Icon name="eye" size={18} weight={1.8}/>
            </button>
          } />

        {errors.form && (
          <div style={{
            padding: '10px 14px', borderRadius: 12, marginBottom: 12,
            background: `${palette.danger}15`, color: palette.danger,
            fontSize: 13, fontWeight: 500, display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <Icon name="x" size={14} weight={2.4}/> {errors.form}
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 18, marginTop: -4 }}>
          <button style={{
            background: 'none', border: 'none', padding: 4, cursor: 'pointer',
            fontSize: 13, fontWeight: 600, color: palette.accent, letterSpacing: '-0.01em',
          }}>Forgot password?</button>
        </div>

        <PrimaryButton palette={palette} label="Sign in" onClick={submit} loading={loading}/>

        <div style={{
          display: 'flex', alignItems: 'center', gap: 12, margin: '24px 0',
          color: palette.ink3, fontSize: 12, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase',
        }}>
          <div style={{ flex: 1, height: 1, background: palette.line }}/>
          <span>or</span>
          <div style={{ flex: 1, height: 1, background: palette.line }}/>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <SocialButton kind="apple" palette={palette} onClick={onSignedIn}/>
          <SocialButton kind="google" palette={palette} onClick={onSignedIn}/>
        </div>

        <div style={{ flex: 1 }}/>

        <div style={{
          textAlign: 'center', marginTop: 24, fontSize: 14, color: palette.ink2,
        }}>
          New here?{' '}
          <button onClick={onGoSignUp} style={{
            background: 'none', border: 'none', padding: 0, cursor: 'pointer',
            fontSize: 14, fontWeight: 700, color: palette.accent, letterSpacing: '-0.01em',
          }}>Create an account</button>
        </div>
      </div>
    </AuthShell>
  );
}

// ── Sign Up ───────────────────────────────────────────────────
function SignUpScreen({ palette, signUp, onSignedUp, onGoSignIn }) {
  const [name, setName] = React.useState('');
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [showPw, setShowPw] = React.useState(false);
  const [errors, setErrors] = React.useState({});
  const [loading, setLoading] = React.useState(false);

  const submit = () => {
    const errs = {};
    if (!name.trim()) errs.name = 'What should we call you?';
    if (!validateEmail(email)) errs.email = 'That doesn\'t look like an email.';
    if (!validatePassword(password)) errs.password = 'Use at least 6 characters.';
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setLoading(true);
    setTimeout(() => {
      const r = signUp({ name, email, password });
      setLoading(false);
      if (!r.ok) setErrors({ form: r.error });
      else onSignedUp();
    }, 400);
  };

  // password strength
  const strength = (() => {
    if (!password) return 0;
    let s = 0;
    if (password.length >= 6) s++;
    if (password.length >= 10) s++;
    if (/[A-Z]/.test(password) && /[a-z]/.test(password)) s++;
    if (/\d/.test(password) || /[^\w]/.test(password)) s++;
    return s;
  })();
  const strengthLabels = ['', 'Weak', 'Okay', 'Good', 'Strong'];
  const strengthColors = [palette.line, '#E89A8E', palette.pollen, '#7FA88C', palette.accent];

  return (
    <AuthShell palette={palette}>
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <button onClick={onGoSignIn} style={{
            width: 38, height: 38, borderRadius: 999, border: 'none', cursor: 'pointer',
            background: palette.surface, color: palette.ink,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 1px 2px rgba(26,29,38,0.06)',
          }}>
            <Icon name="chevron-left" size={20} weight={2.2}/>
          </button>
          <FlowerMark size={28} color={palette.accent} pollen={palette.pollen} />
        </div>

        <div style={{
          fontFamily: '"Instrument Serif", Georgia, serif',
          fontSize: 38, lineHeight: 1.05, color: palette.ink,
          letterSpacing: '-0.02em', fontWeight: 400,
        }}>
          Make a place<br/>to <em style={{ fontStyle: 'italic', color: palette.accent }}>remember.</em>
        </div>
        <div style={{ marginTop: 8, fontSize: 15, color: palette.ink2, marginBottom: 24 }}>
          Free forever for up to 50 places.
        </div>

        <TextField palette={palette} label="Your name"
          value={name} onChange={setName} icon="flower-tag"
          placeholder="Sam" autoFocus
          error={errors.name} />
        <TextField palette={palette} label="Email" type="email"
          value={email} onChange={setEmail} icon="tag"
          placeholder="you@example.com"
          error={errors.email} />
        <TextField palette={palette} label="Password" type={showPw ? 'text' : 'password'}
          value={password} onChange={setPassword} icon="bookmark"
          placeholder="at least 6 characters"
          error={errors.password}
          trailing={
            <button onClick={() => setShowPw(s => !s)} style={{
              background: 'none', border: 'none', padding: 6, cursor: 'pointer',
              color: palette.ink3, display: 'flex',
            }}>
              <Icon name="eye" size={18} weight={1.8}/>
            </button>
          } />

        {/* password strength */}
        {password && (
          <div style={{ marginTop: -4, marginBottom: 14, padding: '0 2px' }}>
            <div style={{ display: 'flex', gap: 4, marginBottom: 4 }}>
              {[1,2,3,4].map(i => (
                <div key={i} style={{
                  flex: 1, height: 3, borderRadius: 999,
                  background: i <= strength ? strengthColors[strength] : palette.line,
                  transition: 'background 200ms',
                }}/>
              ))}
            </div>
            <div style={{ fontSize: 11, color: palette.ink3, fontWeight: 600, letterSpacing: '-0.01em' }}>
              {strength > 0 ? `Password strength · ${strengthLabels[strength]}` : 'Choose a strong password'}
            </div>
          </div>
        )}

        {errors.form && (
          <div style={{
            padding: '10px 14px', borderRadius: 12, marginBottom: 12,
            background: `${palette.danger}15`, color: palette.danger,
            fontSize: 13, fontWeight: 500, display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <Icon name="x" size={14} weight={2.4}/> {errors.form}
          </div>
        )}

        <PrimaryButton palette={palette} label="Create account" onClick={submit} loading={loading}/>

        <div style={{
          marginTop: 14, fontSize: 11, color: palette.ink3, textAlign: 'center', lineHeight: 1.5, padding: '0 8px',
        }}>
          By continuing, you agree to our <span style={{ color: palette.ink2, textDecoration: 'underline' }}>Terms</span> and <span style={{ color: palette.ink2, textDecoration: 'underline' }}>Privacy</span>.
        </div>

        <div style={{
          display: 'flex', alignItems: 'center', gap: 12, margin: '20px 0',
          color: palette.ink3, fontSize: 12, fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase',
        }}>
          <div style={{ flex: 1, height: 1, background: palette.line }}/>
          <span>or</span>
          <div style={{ flex: 1, height: 1, background: palette.line }}/>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <SocialButton kind="apple" palette={palette} onClick={onSignedUp}/>
          <SocialButton kind="google" palette={palette} onClick={onSignedUp}/>
        </div>

        <div style={{ flex: 1 }}/>

        <div style={{
          textAlign: 'center', marginTop: 20, fontSize: 14, color: palette.ink2,
        }}>
          Have an account?{' '}
          <button onClick={onGoSignIn} style={{
            background: 'none', border: 'none', padding: 0, cursor: 'pointer',
            fontSize: 14, fontWeight: 700, color: palette.accent, letterSpacing: '-0.01em',
          }}>Sign in</button>
        </div>
      </div>
    </AuthShell>
  );
}

Object.assign(window, { SignInScreen, SignUpScreen });
