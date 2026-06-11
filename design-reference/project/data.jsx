// data.jsx — mock hierarchy. Uses Unsplash for placeholder photos.

// Tree of items. Items can be 'room' (no image) or 'space' (image).
// Each item: { id, name, type, parentId, img, tags, notes, isUpdated, rect, updatedAt }
// rect is normalized {x,y,w,h} on parent — for sub-spaces.

const FMN_DATA = [
  // ── ROOMS (no image) at root ───────────────────────────────
  { id: 'home',     name: 'Home',          type: 'room', parentId: null, tags: ['everyday'], updatedAt: Date.now() - 1000*60*60*2 },
  { id: 'office',   name: 'Office',        type: 'room', parentId: null, tags: ['work'], updatedAt: Date.now() - 1000*60*60*24*3 },
  { id: 'garage',   name: 'Garage',        type: 'room', parentId: null, tags: ['tools', 'seasonal'], updatedAt: Date.now() - 1000*60*60*24*8 },
  { id: 'travel',   name: 'Travel kit',    type: 'room', parentId: null, tags: ['packed'], updatedAt: Date.now() - 1000*60*60*24*30 },

  // ── HOME → SPACES ─────────────────────────────────────────
  { id: 'kitchen',  name: 'Kitchen',  type: 'space', parentId: 'home',
    img: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=900&q=80',
    tags: ['cooking', 'pantry'], notes: 'Pantry is the cabinet to the left of the fridge.',
    updatedAt: Date.now() - 1000*60*60*4 },
  { id: 'bedroom',  name: 'Bedroom',  type: 'space', parentId: 'home',
    img: 'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=900&q=80',
    tags: ['clothes'], notes: '',
    isUpdated: true,
    updatedAt: Date.now() - 1000*60*60*30 },
  { id: 'closet',   name: 'Hall closet',  type: 'space', parentId: 'home',
    img: 'https://images.unsplash.com/photo-1558997519-83ea9252edf8?w=900&q=80',
    tags: ['linens', 'storage'], notes: 'Spare towels on the top shelf.',
    updatedAt: Date.now() - 1000*60*60*24*6 },
  { id: 'living',   name: 'Living room',  type: 'space', parentId: 'home',
    img: 'https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=900&q=80',
    tags: ['books'], notes: '',
    updatedAt: Date.now() - 1000*60*60*24*1 },

  // ── KITCHEN → SUB-SPACES ──────────────────────────────────
  { id: 'spice',    name: 'Spice drawer',   type: 'space', parentId: 'kitchen',
    img: 'https://images.unsplash.com/photo-1532336414038-cf19250c5757?w=700&q=80',
    rect: { x: 0.08, y: 0.55, w: 0.32, h: 0.30 },
    tags: ['#cumin', '#paprika', '#cinnamon'], notes: 'Bay leaves in the small tin at the back.',
    updatedAt: Date.now() - 1000*60*60*5 },
  { id: 'pantry',   name: 'Pantry',         type: 'space', parentId: 'kitchen',
    img: 'https://images.unsplash.com/photo-1591814468924-caf88d1232e1?w=700&q=80',
    rect: { x: 0.45, y: 0.15, w: 0.40, h: 0.65 },
    tags: ['#flour', '#rice', '#snacks'], notes: '',
    isUpdated: true,
    updatedAt: Date.now() - 1000*60*60*22 },
  { id: 'fridge',   name: 'Fridge',         type: 'space', parentId: 'kitchen',
    img: 'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=700&q=80',
    rect: { x: 0.55, y: 0.35, w: 0.32, h: 0.45 },
    tags: ['#cold'], notes: 'Eggs on the door, top shelf.',
    updatedAt: Date.now() - 1000*60*60*24*2 },
  { id: 'utensils', name: 'Utensil drawer', type: 'space', parentId: 'kitchen',
    img: 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=700&q=80',
    rect: { x: 0.12, y: 0.20, w: 0.28, h: 0.30 },
    tags: ['#whisk', '#peeler'], notes: '',
    updatedAt: Date.now() - 1000*60*60*24*10 },

  // ── SPICE DRAWER → SUB-SUB-SPACES ─────────────────────────
  { id: 'baybox',   name: 'Bay leaf tin',  type: 'space', parentId: 'spice',
    img: 'https://images.unsplash.com/photo-1599909533730-1ae6c95df0e1?w=600&q=80',
    rect: { x: 0.68, y: 0.10, w: 0.22, h: 0.30 },
    tags: ['#bayleaves'], notes: '',
    updatedAt: Date.now() - 1000*60*60*24*40 },

  // ── OFFICE → SPACES ───────────────────────────────────────
  { id: 'desk',     name: 'Desk drawer', type: 'space', parentId: 'office',
    img: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=900&q=80',
    tags: ['#cables', '#chargers'], notes: 'Lightning cables in the front pouch.',
    updatedAt: Date.now() - 1000*60*60*24*4 },
  { id: 'bookshelf',name: 'Bookshelf', type: 'space', parentId: 'office',
    img: 'https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=900&q=80',
    tags: ['#reference'], notes: '',
    updatedAt: Date.now() - 1000*60*60*24*60 },

  // ── GARAGE → SPACES ───────────────────────────────────────
  { id: 'toolbox',  name: 'Red toolbox', type: 'space', parentId: 'garage',
    img: 'https://images.unsplash.com/photo-1581244277943-fe4a9c777189?w=900&q=80',
    tags: ['#drillbits', '#sockets'], notes: 'Lid pops open with a slight pull on the left.',
    updatedAt: Date.now() - 1000*60*60*24*8 },
  { id: 'seasons',  name: 'Seasonal bin', type: 'space', parentId: 'garage',
    img: 'https://images.unsplash.com/photo-1572177812156-58036aae439c?w=900&q=80',
    tags: ['#christmas', '#halloween'], notes: '',
    isUpdated: true,
    updatedAt: Date.now() - 1000*60*60*24*120 },
];

// Helpers
function getItem(id, items = FMN_DATA) { return items.find(x => x.id === id); }
function getChildren(parentId, items = FMN_DATA) {
  return items.filter(x => x.parentId === parentId);
}
function getRoots(items = FMN_DATA) { return items.filter(x => x.parentId === null); }
function getAncestry(id, items = FMN_DATA) {
  const path = []; let cur = getItem(id, items);
  while (cur) { path.unshift(cur); cur = cur.parentId ? getItem(cur.parentId, items) : null; }
  return path;
}
function getRecent(n = 6, items = FMN_DATA) {
  return [...items].filter(x => x.type === 'space')
    .sort((a, b) => b.updatedAt - a.updatedAt).slice(0, n);
}
function searchItems(q, items = FMN_DATA) {
  if (!q) return [];
  const Q = q.toLowerCase();
  return items.filter(x => {
    if (x.name.toLowerCase().includes(Q)) return true;
    if ((x.notes || '').toLowerCase().includes(Q)) return true;
    if ((x.tags || []).some(t => t.toLowerCase().includes(Q))) return true;
    return false;
  });
}

function timeAgo(t) {
  const m = (Date.now() - t) / 60000;
  if (m < 60) return `${Math.max(1, Math.round(m))}m ago`;
  if (m < 60*24) return `${Math.round(m/60)}h ago`;
  if (m < 60*24*30) return `${Math.round(m/60/24)}d ago`;
  return `${Math.round(m/60/24/30)}mo ago`;
}

Object.assign(window, {
  FMN_DATA, getItem, getChildren, getRoots, getAncestry, getRecent, searchItems, timeAgo,
});
