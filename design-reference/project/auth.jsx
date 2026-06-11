// auth.jsx — tiny auth store backed by localStorage.
// Exports (to window): authStore, useAuth, validateEmail, validatePassword

const USERS_KEY = 'fmn_users';
const SESSION_KEY = 'fmn_session';

const authStore = {
  list() {
    try { return JSON.parse(localStorage.getItem(USERS_KEY) || '[]'); }
    catch { return []; }
  },
  save(users) {
    localStorage.setItem(USERS_KEY, JSON.stringify(users));
  },
  seedDemo() {
    const users = authStore.list();
    if (users.find(u => u.email === 'demo@fmn.app')) return;
    users.push({ name: 'Sam', email: 'demo@fmn.app', password: 'forget', createdAt: Date.now() });
    authStore.save(users);
  },
  current() {
    const email = localStorage.getItem(SESSION_KEY);
    if (!email) return null;
    return authStore.list().find(u => u.email === email) || null;
  },
  signIn(email, password) {
    const u = authStore.list().find(x => x.email.toLowerCase() === email.toLowerCase());
    if (!u) return { ok: false, error: 'No account with that email.' };
    if (u.password !== password) return { ok: false, error: 'Wrong password. Try again?' };
    localStorage.setItem(SESSION_KEY, u.email);
    return { ok: true, user: u };
  },
  signUp({ name, email, password }) {
    const users = authStore.list();
    if (users.find(x => x.email.toLowerCase() === email.toLowerCase())) {
      return { ok: false, error: 'That email is already in use.' };
    }
    const user = { name: name.trim(), email: email.trim().toLowerCase(), password, createdAt: Date.now() };
    users.push(user);
    authStore.save(users);
    localStorage.setItem(SESSION_KEY, user.email);
    return { ok: true, user };
  },
  signOut() {
    localStorage.removeItem(SESSION_KEY);
  },
};

function validateEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((v || '').trim());
}
function validatePassword(v) {
  return (v || '').length >= 6;
}

// React hook
function useAuth() {
  const [user, setUser] = React.useState(() => authStore.current());
  const signIn  = (email, password) => {
    const r = authStore.signIn(email, password);
    if (r.ok) setUser(r.user);
    return r;
  };
  const signUp  = (data) => {
    const r = authStore.signUp(data);
    if (r.ok) setUser(r.user);
    return r;
  };
  const signOut = () => { authStore.signOut(); setUser(null); };
  return { user, signIn, signUp, signOut };
}

Object.assign(window, { authStore, useAuth, validateEmail, validatePassword });
authStore.seedDemo();
