const STORAGE_KEY = 'school_dev_portal_session';
const API_BASE =
  window.PORTAL_CONFIG?.apiBase ||
  'https://school-management-9yzh.onrender.com/api';

const state = {
  apiBase: API_BASE,
  token: '',
  userEmail: '',
  overview: null,
  schools: [],
  schoolDetail: null,
  loading: false,
  error: null,
  success: null,
  search: '',
  schoolsFilter: { status: '', city: '', type: '', search: '', page: 1 },
};

function loadSession() {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return false;
    const data = JSON.parse(raw);
    state.apiBase = data.apiBase || API_BASE;
    state.token = data.token || '';
    state.userEmail = data.userEmail || '';
    return Boolean(state.token);
  } catch {
    return false;
  }
}

function saveSession() {
  sessionStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      apiBase: state.apiBase,
      token: state.token,
      userEmail: state.userEmail,
    }),
  );
}

function clearSession() {
  sessionStorage.removeItem(STORAGE_KEY);
  state.token = '';
  state.userEmail = '';
}

function route() {
  const hash = location.hash.replace(/^#/, '') || '/';
  return hash.startsWith('/') ? hash : `/${hash}`;
}

function navigate(path) {
  location.hash = path;
}

async function api(path, options = {}) {
  const base = state.apiBase.replace(/\/$/, '');
  const url = `${base}${path.startsWith('/') ? path : `/${path}`}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }

  const res = await fetch(url, { ...options, headers });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!res.ok) {
    const message =
      (data && data.message) ||
      (Array.isArray(data?.message) ? data.message.join(', ') : null) ||
      `Request failed (${res.status})`;
    throw new Error(message);
  }

  return data;
}

function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function formatDate(value) {
  if (!value) return '—';
  return new Date(value).toLocaleString();
}

function initials(text) {
  return String(text || '?')
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || '')
    .join('');
}

const icons = {
  school: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 10l9-6 9 6"/><path d="M5 10v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8"/><path d="M9 20v-6h6v6"/></svg>',
  active: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6 9 17l-5-5"/></svg>',
  students: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  teachers: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 14l9-5-9-5-9 5 9 5z"/><path d="M12 14l6.16-3.422A12.083 12.083 0 0 1 21 13.5c0 2.485-4.03 4.5-9 4.5s-9-2.015-9-4.5c0-1.042.39-2.016 1.16-2.878L12 14z"/></svg>',
  admins: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3l2.2 4.5 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5L4.8 8.2l5-.7L12 3z"/></svg>',
  parents: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  classes: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 8h10"/><path d="M7 12h10"/><path d="M7 16h6"/></svg>',
  search: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
  arrow: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>',
  logo: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 10l9-6 9 6"/><path d="M5 10v8a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-8"/></svg>',
};

const dashIcons = {
  grid: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
  report: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v18h18"/><rect x="7" y="11" width="3" height="6"/><rect x="13" y="7" width="3" height="10"/></svg>',
  activity: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>',
  gear: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
  cap: '<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c0 1 2.7 2.5 6 2.5s6-1.5 6-2.5v-5"/></svg>',
  menu: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M3 12h18M3 18h18"/></svg>',
  bell: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
  signout: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/></svg>',
  spark: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
  shield: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
  broom: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19.4 4.6 14 10"/><path d="M5 21c-1-3 0-6 2-8l5 5c-2 2-5 3-8 3z"/><path d="m13 9 2 2"/></svg>',
  check: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 6 9 17l-5-5"/></svg>',
  plus: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>',
  upload: '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M17 8l-5-5-5 5"/><path d="M12 3v12"/></svg>',
  db: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.7 4 3 9 3s9-1.3 9-3V5"/><path d="M3 12c0 1.7 4 3 9 3s9-1.3 9-3"/></svg>',
  eye: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
  edit: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>',
  dots: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="5" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="19" r="1.2" fill="currentColor"/></svg>',
  pin: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
  filter: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>',
  import: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M7 10l5 5 5-5"/><path d="M12 15V3"/></svg>',
  chevLeft: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m15 18-6-6 6-6"/></svg>',
  chevRight: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>',
  inactive: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M10 15V9M14 15V9"/></svg>',
  clock: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></svg>',
};

function statCard(label, value, icon, tone = 'blue') {
  return `
    <div class="stat-card tone-${tone}">
      <div class="stat-icon">${icon}</div>
      <div class="stat-body">
        <div class="label">${esc(label)}</div>
        <div class="value">${esc(value)}</div>
      </div>
    </div>
  `;
}

function appNav() {
  const email = state.userEmail || 'Owner';
  return `
    <header class="top-nav">
      <div class="top-nav-inner">
        <div class="brand-lockup">
          <div class="brand-mark">${icons.logo}</div>
          <div>
            <strong>School Platform</strong>
            <span>Private owner console</span>
          </div>
        </div>
        <div class="user-chip">
          <div class="user-avatar">${esc(initials(email))}</div>
          <div>
            <small>Signed in</small>
            <strong>${esc(email)}</strong>
          </div>
        </div>
      </div>
    </header>
  `;
}

function pageToolbar(title, subtitle, actionsHtml = '') {
  return `
    <div class="page-toolbar">
      <div>
        <h1>${esc(title)}</h1>
        <p>${subtitle}</p>
      </div>
      ${actionsHtml ? `<div class="actions">${actionsHtml}</div>` : ''}
    </div>
  `;
}

function renderLogin() {
  return `
    <div class="login-page">
      <section class="login-visual">
        <span class="eyebrow" style="background:rgba(255,255,255,0.14);color:white">Platform owner only</span>
        <h1>Manage every school from one place</h1>
        <p>Monitor registrations, review school performance, and onboard new institutions securely.</p>
        <ul class="feature-list">
          <li><span class="feature-dot"></span> School-wise students, teachers, and classes</li>
          <li><span class="feature-dot"></span> Create new schools with admin accounts</li>
          <li><span class="feature-dot"></span> Not visible to mobile app users</li>
        </ul>
      </section>
      <section class="login-panel">
        <div class="login-card">
          <h2>Welcome back</h2>
          <p class="sub">Sign in with your platform owner credentials.</p>
          ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
          <form id="login-form">
            <div class="field">
              <label for="email">Email address</label>
              <input id="email" name="email" type="email" autocomplete="username" placeholder="you@example.com" required />
            </div>
            <div class="field">
              <label for="password">Password</label>
              <input id="password" name="password" type="password" autocomplete="current-password" placeholder="Enter your password" required />
            </div>
            <button class="btn btn-primary" style="width:100%;margin-top:6px" type="submit">
              Sign in to console
            </button>
          </form>
          <p class="muted-note" style="margin-top:18px">
            This website is private. Session stays in this browser tab only.
          </p>
        </div>
      </section>
    </div>
  `;
}

function dashSidebar(active = 'Overview') {
  const items = [
    ['Overview', dashIcons.grid],
    ['Schools', icons.school],
    ['Classes', icons.classes],
    ['Teachers', icons.teachers],
    ['Students', icons.students],
    ['Parents', icons.parents],
    ['Admins', icons.admins],
    ['Reports', dashIcons.report],
    ['Activity Log', dashIcons.activity],
    ['Settings', dashIcons.gear],
  ];
  return `
    <aside class="sb" id="sidebar">
      <div class="sb-brand">
        <div class="sb-logo">${icons.logo}</div>
        <div>
          <strong>School Platform</strong>
          <span>Private owner console</span>
        </div>
      </div>
      <nav class="sb-nav">
        ${items
          .map(
            ([label, icon]) => `
          <a class="sb-link ${label === active ? 'active' : ''}" data-nav="${esc(label)}">
            <span class="sb-ic">${icon}</span>${esc(label)}
          </a>`,
          )
          .join('')}
      </nav>
      <div class="sb-promo">
        <div class="sb-promo-ic">${dashIcons.cap}</div>
        <strong>Manage smarter.<br/>Grow faster.</strong>
        <p>Powerful tools to manage your institutions from one place.</p>
        <button class="btn btn-primary sb-promo-btn" id="create-btn">＋ Create School</button>
      </div>
    </aside>
  `;
}

function dashTopbar(title, subtitle) {
  const email = state.userEmail || 'Owner';
  const titleHtml = title
    ? `<div class="tb-page-title"><h1>${esc(title)}</h1><p>${esc(subtitle || '')}</p></div>`
    : `<div class="tb-greeting"><h1>Welcome back! 👋</h1><p>Here's what's happening with your schools today.</p></div>`;
  return `
    <header class="tb">
      <button class="tb-burger" id="sb-toggle" aria-label="Menu">${dashIcons.menu}</button>
      ${titleHtml}
      <div class="tb-search">${icons.search}
        <input id="search" type="search" placeholder="Search by name, code, or city..." value="${esc(state.search)}" />
      </div>
      <button class="tb-icon-btn" id="refresh-btn" title="Refresh">
        ${dashIcons.bell}<span class="tb-badge">3</span>
      </button>
      <div class="tb-user">
        <div class="tb-user-avatar">${esc(initials(email))}</div>
        <span class="tb-user-email">${esc(email)}</span>
        <button class="tb-user-caret" id="logout-btn" title="Sign out">${dashIcons.signout}</button>
      </div>
    </header>
  `;
}

function statCardBig(label, value, sub, subTone, icon, tone, spark) {
  return `
    <div class="bigstat tone-${tone}">
      <div class="bigstat-top">
        <div class="bigstat-ic">${icon}</div>
        <div class="bigstat-spark">${spark}</div>
      </div>
      <div class="bigstat-label">${esc(label)}</div>
      <div class="bigstat-value">${esc(value)}</div>
      <div class="bigstat-sub ${subTone || ''}">${sub}</div>
    </div>
  `;
}

function sparkline(color, points) {
  return `<svg viewBox="0 0 110 40" preserveAspectRatio="none" class="spark">
    <defs><linearGradient id="sg-${color.replace('#','')}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${color}" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
    </linearGradient></defs>
    <polyline fill="none" stroke="${color}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points="${points}"/>
  </svg>`;
}

function miniMetric(label, value, icon, tone) {
  return `
    <div class="mini-metric tone-${tone}">
      <div class="mini-ic">${icon}</div>
      <div>
        <div class="mini-label">${esc(label)}</div>
        <div class="mini-value">${esc(value)}</div>
      </div>
    </div>
  `;
}

function activityRow(icon, tone, title, desc, time) {
  return `
    <li class="act-row">
      <div class="act-ic tone-${tone}">${icon}</div>
      <div class="act-body">
        <strong>${esc(title)}</strong>
        <span>${esc(desc)}</span>
      </div>
      <span class="act-time">${esc(time)}</span>
    </li>
  `;
}

function healthRow(icon, label, status, dotTone) {
  return `
    <div class="health-row">
      <span class="health-ic">${icon}</span>
      <div class="health-body">
        <strong>${esc(label)}</strong>
        <span>${esc(status)}</span>
      </div>
      <span class="health-dot tone-${dotTone}"></span>
    </div>
  `;
}

function healthBar(icon, label, pct, tone) {
  return `
    <div class="health-row">
      <span class="health-ic">${icon}</span>
      <div class="health-body health-body-bar">
        <strong>${esc(label)}</strong>
        <div class="health-track"><div class="health-fill tone-${tone}" style="width:${pct}%"></div></div>
      </div>
      <span class="health-pct">${pct}%</span>
    </div>
  `;
}

function quickAction(icon, label, tone, attr = '') {
  return `
    <button class="qa-tile tone-${tone}" ${attr}>
      <span class="qa-ic">${icon}</span>
      <span class="qa-label">${esc(label)}</span>
    </button>
  `;
}

function renderDashboard() {
  const overview = state.overview || {};
  const totalSchools = overview.schools?.total ?? 0;
  const activeSchools = overview.schools?.active ?? 0;
  const students = overview.students ?? 0;
  const teachers = overview.teachers ?? 0;
  const activePct = totalSchools > 0 ? Math.round((activeSchools / totalSchools) * 100) : 0;

  const q = state.search.trim().toLowerCase();
  const schools = state.schools.filter((school) => {
    if (!q) return true;
    return (
      school.name.toLowerCase().includes(q) ||
      school.code.toLowerCase().includes(q) ||
      (school.city || '').toLowerCase().includes(q)
    );
  });

  const previewSchools = schools.slice(0, 5);

  return `
    <div class="dash">
      ${dashSidebar('Overview')}
      <div class="dash-overlay" id="sb-overlay"></div>
      <div class="dash-main">
        ${dashTopbar()}
        <div class="dash-body">
          ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
          ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

          <!-- Row 1: Stat cards -->
          <section class="stat-row">
            ${statCardBig('Total Schools', totalSchools, `<b>${totalSchools}</b> registered`, 'muted', icons.school, 'blue', sparkline('#1b5fff', '0,30 18,22 36,26 54,14 72,18 90,6 110,2'))}
            ${statCardBig('Active Schools', activeSchools, `<b>${activePct}%</b> active`, 'green', icons.active, 'green', sparkline('#16a34a', '0,32 20,24 40,28 60,16 80,20 100,8 110,6'))}
            ${statCardBig('Students', students, `${students} enrolled`, 'muted', icons.students, 'violet', sparkline('#7c3aed', '0,20 20,22 40,18 60,24 80,16 100,20 110,18'))}
            ${statCardBig('Teachers', teachers, `${teachers} active`, 'muted', icons.teachers, 'amber', sparkline('#d97706', '0,22 20,18 40,24 60,16 80,22 100,14 110,18'))}
          </section>

          <!-- Row 2: Overview chart (left) + Recent Activity (right) -->
          <section class="dash-grid-top">
            <div class="panel pv-panel">
              <div class="panel-head">
                <div><h2>Platform Overview</h2><p>Live performance metrics</p></div>
                <span class="pill-select">This Month ▾</span>
              </div>
              <div class="pv-mini">
                ${miniMetric('Schools', totalSchools, icons.school, 'blue')}
                ${miniMetric('Active', activeSchools, dashIcons.spark, 'green')}
                ${miniMetric('Students', students, icons.students, 'violet')}
                ${miniMetric('Teachers', teachers, icons.teachers, 'amber')}
              </div>
              ${platformChart()}
            </div>

            <div class="panel act-panel">
              <div class="panel-head">
                <div><h2>Recent Activity</h2><p>Latest platform updates</p></div>
                <a class="link-sm">View all</a>
              </div>
              <ul class="act-list">
                ${activityRow(icons.school, 'blue', 'New school registered', 'A new school has been added', '2h ago')}
                ${activityRow(icons.admins, 'violet', 'User logged in', 'Admin login from 103.21.24.5', '5h ago')}
                ${activityRow(dashIcons.broom, 'amber', 'Demo data cleared', 'All demo data removed', '1d ago')}
                ${activityRow(dashIcons.gear, 'slate', 'System update', 'Platform updated successfully', '2d ago')}
                ${activityRow(dashIcons.check, 'green', 'Backup completed', 'Daily backup completed', '3d ago')}
              </ul>
              <button class="btn btn-soft act-viewall">View all activity →</button>
            </div>
          </section>

          <!-- Row 3: Quick Actions + Health + Help (3-col balanced) -->
          <section class="dash-grid-bottom">
            <div class="panel">
              <div class="panel-head"><div><h2>Quick Actions</h2><p>Common platform tasks</p></div></div>
              <div class="qa-grid">
                ${quickAction(dashIcons.plus, 'Create School', 'blue', 'data-create')}
                ${quickAction(dashIcons.upload, 'Import Data', 'green')}
                ${quickAction(icons.teachers, 'Add Teacher', 'violet', 'data-create')}
                ${quickAction(dashIcons.report, 'View Reports', 'amber')}
              </div>
            </div>

            <div class="panel">
              <div class="panel-head"><div><h2>Platform Health</h2><p>System status at a glance</p></div></div>
              ${healthRow(dashIcons.gear, 'System Status', 'All systems operational', 'green')}
              ${healthRow(dashIcons.db, 'Database', 'Healthy · Neon PostgreSQL', 'green')}
              ${healthBar(dashIcons.spark, 'Server Load', 23, 'green')}
              ${healthBar(dashIcons.db, 'Storage Usage', 18, 'blue')}
              <button class="btn btn-soft act-viewall" style="margin-top:12px">View system status →</button>
            </div>

            <div class="panel help-panel">
              <strong>Need Help?</strong>
              <p>Our support team is here to help you 24/7 with any questions about the platform.</p>
              <button class="btn btn-soft">Contact Support</button>
            </div>
          </section>

          <!-- Row 4: Schools table (full width, preview 5 rows) -->
          <section class="panel schools-panel">
            <div class="panel-head">
              <div><h2>Registered Schools</h2><p>${schools.length} school${schools.length === 1 ? '' : 's'} on your platform</p></div>
              <div class="panel-head-actions">
                <button class="btn btn-soft btn-xs" id="clear-demo-btn">Clear demo</button>
                <button class="btn btn-soft btn-xs btn-danger-soft" id="clear-all-btn">Clear all</button>
                <a class="link-sm" data-goto="/schools">View all schools →</a>
              </div>
            </div>
            ${
              state.loading && schools.length === 0
                ? '<div class="loading">Loading schools...</div>'
                : schools.length === 0
                  ? '<div class="empty">No schools found.</div>'
                  : `<div class="tbl-wrap"><table class="tbl">
                      <thead><tr>
                        <th>School Name</th><th>Code</th><th>Location</th><th>Status</th><th>Registered On</th><th></th>
                      </tr></thead>
                      <tbody>
                        ${previewSchools
                          .map(
                            (s) => `
                          <tr data-school-id="${esc(s.id)}">
                            <td><div class="tbl-school"><span class="tbl-avatar">${esc(initials(s.name))}</span>${esc(s.name)}</div></td>
                            <td class="muted-cell">${esc(s.code)}</td>
                            <td class="muted-cell">${esc(s.city || '—')}</td>
                            <td><span class="badge ${s.isActive ? 'badge-active' : 'badge-inactive'}">${s.isActive ? 'Active' : 'Inactive'}</span></td>
                            <td class="muted-cell">${esc(formatDate(s.createdAt))}</td>
                            <td class="tbl-chev">${icons.arrow}</td>
                          </tr>`,
                          )
                          .join('')}
                      </tbody>
                    </table></div>
                    ${schools.length > 5 ? `<div class="tbl-viewall"><a class="link-sm" data-goto="/schools">View all ${schools.length} schools →</a></div>` : ''}`
            }
          </section>
        </div>
      </div>
    </div>
  `;
}

function platformChart() {
  // Static illustrative line chart (no time-series API yet).
  const pts = '20,150 70,110 120,130 170,95 220,120 270,140 320,105 370,120 420,40 470,80 520,60 570,95';
  const labels = ['May 17','May 20','May 23','May 26','May 29','Jun 1','Jun 4','Jun 7','Jun 10','Jun 13'];
  return `
    <div class="pv-chart">
      <svg viewBox="0 0 600 200" preserveAspectRatio="none" class="pv-svg">
        <defs>
          <linearGradient id="pvFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#1b5fff" stop-opacity="0.18"/>
            <stop offset="100%" stop-color="#1b5fff" stop-opacity="0"/>
          </linearGradient>
        </defs>
        ${[0,50,100,150].map((y) => `<line x1="20" y1="${y+20}" x2="580" y2="${y+20}" stroke="#eef2f9" stroke-width="1" stroke-dasharray="4 4"/>`).join('')}
        <polygon fill="url(#pvFill)" points="20,180 ${pts} 570,180"/>
        <polyline fill="none" stroke="#1b5fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points="${pts}"/>
        ${pts.split(' ').map((p) => { const [x,y]=p.split(','); return `<circle cx="${x}" cy="${y}" r="3.5" fill="#fff" stroke="#1b5fff" stroke-width="2"/>`; }).join('')}
      </svg>
      <div class="pv-xlabels">${labels.map((l) => `<span>${l}</span>`).join('')}</div>
    </div>
  `;
}

function schoolType(name) {
  const n = (name || '').toLowerCase();
  if (n.includes('matric')) return ['Matric School', 'pink'];
  if (n.includes('primary') || n.includes('junior') || n.includes('elementary')) return ['Primary School', 'amber'];
  if (n.includes('international') || n.includes('global')) return ['International', 'teal'];
  if (n.includes('cbse') || n.includes('central')) return ['CBSE School', 'green'];
  if (n.includes('high')) return ['High School', 'blue'];
  if (n.includes('convent') || n.includes('girls') || n.includes('boys')) return ['Convent School', 'violet'];
  return ['School', 'slate'];
}

function scStatCard(icon, title, value, sub, tone) {
  return `
    <div class="sc-stat tone-${tone}">
      <div class="sc-stat-ic">${icon}</div>
      <div>
        <div class="sc-stat-label">${esc(title)}</div>
        <div class="sc-stat-value">${esc(String(value))}</div>
        <div class="sc-stat-sub">${esc(sub)}</div>
      </div>
    </div>
  `;
}

function renderSchoolsPage() {
  const totalSchools = state.schools.length;
  const activeSchools = state.schools.filter((s) => s.isActive).length;
  const inactiveSchools = totalSchools - activeSchools;

  const now = new Date();
  const newThisMonth = state.schools.filter((s) => {
    if (!s.createdAt) return false;
    const d = new Date(s.createdAt);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;

  const sf = state.schoolsFilter;
  const cities = [...new Set(state.schools.map((s) => s.city).filter(Boolean))].sort();

  let filtered = state.schools;
  if (sf.status === 'active') filtered = filtered.filter((s) => s.isActive);
  if (sf.status === 'inactive') filtered = filtered.filter((s) => !s.isActive);
  if (sf.city) filtered = filtered.filter((s) => s.city === sf.city);
  if (sf.type) filtered = filtered.filter((s) => schoolType(s.name)[0].toLowerCase().includes(sf.type));
  if (sf.search) {
    const q = sf.search.toLowerCase();
    filtered = filtered.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.code.toLowerCase().includes(q) ||
        (s.city || '').toLowerCase().includes(q),
    );
  }

  const total = filtered.length;
  const perPage = 10;
  const totalPages = Math.max(1, Math.ceil(total / perPage));
  const curPage = Math.min(sf.page || 1, totalPages);
  const start = (curPage - 1) * perPage;
  const pageSchools = filtered.slice(start, start + perPage);

  const pageNums = [];
  for (let i = 1; i <= totalPages; i++) {
    if (totalPages <= 6 || i === 1 || i === totalPages || Math.abs(i - curPage) <= 1) {
      pageNums.push(i);
    } else if (pageNums[pageNums.length - 1] !== '…') {
      pageNums.push('…');
    }
  }

  const paginationHtml =
    total === 0
      ? ''
      : `<div class="sc-pagination">
          <span class="sc-pagination-info">Showing ${start + 1}–${Math.min(start + perPage, total)} of ${total} school${total === 1 ? '' : 's'}</span>
          <button class="pg-btn" data-page="${curPage - 1}" ${curPage <= 1 ? 'disabled' : ''}>${dashIcons.chevLeft}</button>
          ${pageNums
            .map((n) =>
              n === '…'
                ? `<span class="pg-dots">…</span>`
                : `<button class="pg-btn ${n === curPage ? 'active' : ''}" data-page="${n}">${n}</button>`,
            )
            .join('')}
          <button class="pg-btn" data-page="${curPage + 1}" ${curPage >= totalPages ? 'disabled' : ''}>${dashIcons.chevRight}</button>
          <select class="per-page-select"><option>10 per page</option></select>
        </div>`;

  const tableHtml =
    state.loading && pageSchools.length === 0
      ? '<div class="loading">Loading schools…</div>'
      : pageSchools.length === 0
        ? '<div class="empty">No schools match your filters.</div>'
        : `<div class="tbl-wrap"><table class="tbl">
            <thead><tr>
              <th>School Name</th><th>Code</th><th>Location</th><th>Type</th><th>Status</th><th>Registered On</th><th>Actions</th>
            </tr></thead>
            <tbody>
              ${pageSchools
                .map((s) => {
                  const [typeName, typeColor] = schoolType(s.name);
                  const regDate = s.createdAt
                    ? new Date(s.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                    : '—';
                  const isActive = s.isActive;
                  return `<tr data-school-id="${esc(s.id)}" style="cursor:pointer">
                    <td>
                      <div class="tbl-school" style="align-items:flex-start">
                        <span class="tbl-avatar" style="margin-top:2px">${esc(initials(s.name))}</span>
                        <div>
                          <div style="font-weight:700">${esc(s.name)}</div>
                          <div class="tbl-school-sub">${esc(s.code.toUpperCase())}</div>
                        </div>
                      </div>
                    </td>
                    <td class="muted-cell">${esc(s.code.toUpperCase())}</td>
                    <td>
                      <div class="loc-cell">${dashIcons.pin}<span>${esc(s.city || '—')}</span></div>
                    </td>
                    <td><span class="type-badge ${typeColor}">${esc(typeName)}</span></td>
                    <td>
                      <div class="status-badge ${isActive ? 's-active' : 's-inactive'}">
                        <span class="status-dot ${isActive ? 'active' : 'inactive'}"></span>
                        ${isActive ? 'Active' : 'Inactive'}
                      </div>
                    </td>
                    <td class="muted-cell">${regDate}</td>
                    <td>
                      <div class="tbl-actions" onclick="event.stopPropagation()">
                        <button class="tbl-action-btn sc-view-btn" data-school-id="${esc(s.id)}" title="View">${dashIcons.eye}</button>
                        <button class="tbl-action-btn" title="Edit">${dashIcons.edit}</button>
                        <button class="tbl-action-btn" title="More">${dashIcons.dots}</button>
                      </div>
                    </td>
                  </tr>`;
                })
                .join('')}
            </tbody>
          </table></div>`;

  return `
    <div class="dash">
      ${dashSidebar('Schools')}
      <div class="dash-overlay" id="sb-overlay"></div>
      <div class="dash-main">
        ${dashTopbar('Schools', 'Manage and monitor all registered schools on your platform.')}
        <div class="dash-body">
          ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}

          <div class="sc-header-row">
            <div class="sc-stats">
              ${scStatCard(icons.school, 'Total Schools', totalSchools, 'All registered schools', 'blue')}
              ${scStatCard(icons.active, 'Active Schools', activeSchools, 'Active and running', 'green')}
              ${scStatCard(dashIcons.inactive, 'Inactive Schools', inactiveSchools, 'Currently inactive', 'amber')}
              ${scStatCard(dashIcons.clock, 'New This Month', newThisMonth, 'Recently added', 'violet')}
            </div>
            <div class="sc-actions-col">
              <button class="btn btn-primary" id="create-btn">${dashIcons.plus} Create School</button>
              <button class="btn btn-soft" id="import-btn">${dashIcons.import} Import Schools</button>
            </div>
          </div>

          <div class="panel">
            <div class="sc-filter-bar">
              <select class="sc-filter-select" id="sc-status-filter">
                <option value="">All Status</option>
                <option value="active" ${sf.status === 'active' ? 'selected' : ''}>Active</option>
                <option value="inactive" ${sf.status === 'inactive' ? 'selected' : ''}>Inactive</option>
              </select>
              <select class="sc-filter-select" id="sc-city-filter">
                <option value="">All Cities</option>
                ${cities.map((c) => `<option value="${esc(c)}" ${sf.city === c ? 'selected' : ''}>${esc(c)}</option>`).join('')}
              </select>
              <select class="sc-filter-select" id="sc-type-filter">
                <option value="">All Types</option>
                <option value="high" ${sf.type === 'high' ? 'selected' : ''}>High School</option>
                <option value="cbse" ${sf.type === 'cbse' ? 'selected' : ''}>CBSE School</option>
                <option value="matric" ${sf.type === 'matric' ? 'selected' : ''}>Matric School</option>
                <option value="primary" ${sf.type === 'primary' ? 'selected' : ''}>Primary School</option>
                <option value="international" ${sf.type === 'international' ? 'selected' : ''}>International</option>
              </select>
              <div class="sc-search-wrap">
                ${icons.search}
                <input type="search" id="sc-search" placeholder="Search schools…" value="${esc(sf.search || '')}" />
              </div>
              <button class="sc-filter-icon-btn" title="More filters">${dashIcons.filter}</button>
            </div>

            ${tableHtml}
            ${paginationHtml}
          </div>
        </div>
      </div>
    </div>
  `;
}

function renderSchoolDetail() {
  const detail = state.schoolDetail;
  if (!detail) {
    return '<div class="loading">Loading school...</div>';
  }

  const { school, stats, admins, classes, guardians = [] } = detail;

  return `
    <div class="app-layout">
      ${appNav()}
      <main class="shell">
      ${pageToolbar(
        school.name,
        `${school.code}${school.city ? ` · ${school.city}` : ''}`,
        `
          <button class="btn btn-ghost-light" id="back-btn">← All schools</button>
          <button class="btn btn-ghost-light" id="edit-school-btn">Edit</button>
          ${
            school.isActive
              ? '<button class="btn btn-warning" id="stop-service-btn">Stop service</button>'
              : '<button class="btn btn-success" id="resume-service-btn">Resume service</button>'
          }
          <button class="btn btn-danger" id="delete-school-btn">Delete</button>
          <button class="btn btn-danger" id="logout-btn">Sign out</button>
        `,
      )}

      ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
      ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

      <div class="grid-stats" style="margin-bottom:24px">
        ${statCard('Students', stats.students, icons.students, 'violet')}
        ${statCard('Teachers', stats.teachers, icons.teachers, 'teal')}
        ${statCard('Admins', stats.admins, icons.admins, 'amber')}
        ${statCard('Parent profiles', stats.parents, icons.parents, 'slate')}
        ${statCard('Classes', stats.classes, icons.classes, 'blue')}
      </div>

      <div class="detail-grid">
        <div class="panel">
          <div class="panel-header">
            <h2>School details</h2>
            <button class="btn btn-ghost-light btn-sm" id="edit-school-btn-2" type="button">Edit</button>
          </div>
          <ul class="info-list">
            <li><span>Status</span><span class="badge ${school.isActive ? 'badge-active' : 'badge-inactive'}">${school.isActive ? 'Active' : 'Service stopped'}</span></li>
            <li><span>School ID</span><span>${esc(school.id)}</span></li>
            <li><span>Code</span><span>${esc(school.code)}</span></li>
            <li><span>City</span><span>${esc(school.city || '—')}</span></li>
            <li><span>Phone</span><span>${esc(school.phone || '—')}</span></li>
            <li><span>Address</span><span>${esc(school.address || '—')}</span></li>
            <li><span>Created</span><span>${esc(formatDate(school.createdAt))}</span></li>
          </ul>
        </div>

        <div class="panel">
          <div class="panel-header"><h2>Admin accounts</h2></div>
          ${
            admins.length === 0
              ? '<div class="empty">No admin users yet.</div>'
              : `<div class="table-wrap"><table>
                  <thead><tr><th>Name</th><th>Email</th><th></th></tr></thead>
                  <tbody>
                    ${admins
                      .map(
                        (admin) => `
                      <tr>
                        <td>${esc(admin.fullName)}</td>
                        <td>${esc(admin.email)}</td>
                        <td>
                          <button
                            class="btn btn-ghost-light btn-sm change-password-btn"
                            type="button"
                            data-admin-id="${esc(admin.id)}"
                            data-admin-name="${esc(admin.fullName)}"
                          >Change password</button>
                        </td>
                      </tr>
                    `,
                      )
                      .join('')}
                  </tbody>
                </table></div>`
          }
        </div>
      </div>

      <div class="panel" style="margin-top:18px">
        <div class="panel-header">
          <h2>Parent / guardian details</h2>
        </div>
        ${
          guardians.length === 0
            ? '<div class="empty">No parent or guardian details added for students yet.</div>'
            : `<div class="table-wrap"><table>
                <thead>
                  <tr>
                    <th>Student</th>
                    <th>Class</th>
                    <th>Father</th>
                    <th>Mother</th>
                    <th>Contact</th>
                  </tr>
                </thead>
                <tbody>
                  ${guardians
                    .map(
                      (g) => `
                    <tr>
                      <td>${esc(g.studentName)}</td>
                      <td>${esc(g.classLabel)}</td>
                      <td>${esc(g.fatherName || '—')}${g.fatherPhone ? `<br><span class="muted-note">${esc(g.fatherPhone)}</span>` : ''}</td>
                      <td>${esc(g.motherName || '—')}${g.motherPhone ? `<br><span class="muted-note">${esc(g.motherPhone)}</span>` : ''}</td>
                      <td>${esc(g.emergencyPhone || g.fatherPhone || g.motherPhone || '—')}</td>
                    </tr>
                  `,
                    )
                    .join('')}
                </tbody>
              </table></div>`
        }
      </div>

      <div class="panel" style="margin-top:18px">
        <div class="panel-header"><h2>Classes</h2></div>
        ${
          classes.length === 0
            ? '<div class="empty">No classes created yet.</div>'
            : `<div class="table-wrap"><table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th>Grade</th>
                    <th>Section</th>
                    <th>Year</th>
                    <th>Students</th>
                  </tr>
                </thead>
                <tbody>
                  ${classes
                    .map(
                      (cls) => `
                    <tr>
                      <td>${esc(cls.name)}</td>
                      <td>${esc(cls.grade)}</td>
                      <td>${esc(cls.section)}</td>
                      <td>${esc(cls.academicYear)}</td>
                      <td>${esc(cls.students)}</td>
                    </tr>
                  `,
                    )
                    .join('')}
                </tbody>
              </table></div>`
        }
      </div>

      <div id="modal-root"></div>
      </main>
    </div>
  `;
}

function renderEditSchoolModal(school) {
  return `
    <div class="modal-backdrop" id="modal-backdrop">
      <div class="modal" role="dialog" aria-labelledby="edit-school-title">
        <div class="modal-header">
          <h2 id="edit-school-title">Edit school</h2>
          <button class="modal-close" type="button" id="modal-close-btn" aria-label="Close">×</button>
        </div>
        <form id="edit-school-form" class="form-grid">
          <div class="field">
            <label>School name</label>
            <input name="name" required value="${esc(school.name)}" />
          </div>
          <div class="field">
            <label>City</label>
            <input name="city" value="${esc(school.city || '')}" />
          </div>
          <div class="field">
            <label>Address</label>
            <input name="address" value="${esc(school.address || '')}" />
          </div>
          <p class="muted-note">School code <strong>${esc(school.code)}</strong> cannot be changed.</p>
          <div class="modal-actions">
            <button class="btn btn-ghost-light" type="button" id="modal-cancel-btn">Cancel</button>
            <button class="btn btn-primary" type="submit" style="background:linear-gradient(135deg,#1b5fff,#3d7bff);color:white;border:none">Save changes</button>
          </div>
        </form>
      </div>
    </div>
  `;
}

function renderPasswordModal(adminId, adminName) {
  return `
    <div class="modal-backdrop" id="modal-backdrop">
      <div class="modal" role="dialog" aria-labelledby="password-modal-title">
        <div class="modal-header">
          <h2 id="password-modal-title">Change password</h2>
          <button class="modal-close" type="button" id="modal-close-btn" aria-label="Close">×</button>
        </div>
        <p class="muted-note" style="margin:0 0 14px">Set a new password for <strong>${esc(adminName)}</strong>.</p>
        <form id="password-form" class="form-grid" data-admin-id="${esc(adminId)}">
          <div class="field">
            <label>New password</label>
            <input name="newPassword" type="password" minlength="6" required placeholder="At least 6 characters" />
          </div>
          <div class="modal-actions">
            <button class="btn btn-ghost-light" type="button" id="modal-cancel-btn">Cancel</button>
            <button class="btn btn-primary" type="submit" style="background:linear-gradient(135deg,#1b5fff,#3d7bff);color:white;border:none">Update password</button>
          </div>
        </form>
      </div>
    </div>
  `;
}

function renderDeleteSchoolModal(school) {
  return `
    <div class="modal-backdrop" id="modal-backdrop">
      <div class="modal modal-danger" role="dialog" aria-labelledby="delete-school-title">
        <div class="modal-header">
          <h2 id="delete-school-title">Delete school</h2>
          <button class="modal-close" type="button" id="modal-close-btn" aria-label="Close">×</button>
        </div>
        <p class="muted-note" style="margin:0 0 14px">
          This permanently removes <strong>${esc(school.name)}</strong>, all users, classes, and student data.
          Type the school code <strong>${esc(school.code)}</strong> to confirm.
        </p>
        <form id="delete-school-form" class="form-grid">
          <div class="field">
            <label>Confirm school code</label>
            <input name="confirmCode" required placeholder="${esc(school.code)}" autocomplete="off" />
          </div>
          <div class="modal-actions">
            <button class="btn btn-ghost-light" type="button" id="modal-cancel-btn">Cancel</button>
            <button class="btn btn-danger" type="submit">Delete permanently</button>
          </div>
        </form>
      </div>
    </div>
  `;
}

function closeModal() {
  const root = document.getElementById('modal-root');
  if (root) root.innerHTML = '';
}

function openModal(html) {
  const root = document.getElementById('modal-root');
  if (!root) return;
  root.innerHTML = html;
  document.getElementById('modal-close-btn')?.addEventListener('click', closeModal);
  document.getElementById('modal-cancel-btn')?.addEventListener('click', closeModal);
  document.getElementById('modal-backdrop')?.addEventListener('click', (event) => {
    if (event.target?.id === 'modal-backdrop') closeModal();
  });
}

function renderCreateSchool() {
  return `
    <div class="app-layout">
      ${appNav()}
      <main class="shell">
      ${pageToolbar(
        'Create school',
        'Register a new school and its first admin account',
        `
          <button class="btn btn-ghost-light" id="back-btn">← All schools</button>
          <button class="btn btn-danger" id="logout-btn">Sign out</button>
        `,
      )}

      ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
      ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

      <div class="panel" style="padding:22px">
        <form id="create-form" class="form-grid">
          <div class="form-grid two">
            <div class="field">
              <label>School name</label>
              <input name="name" required />
            </div>
            <div class="field">
              <label>School code</label>
              <input name="code" pattern="[a-z0-9-]+" required placeholder="greenfield" />
            </div>
          </div>
          <div class="form-grid two">
            <div class="field">
              <label>City</label>
              <input name="city" />
            </div>
            <div class="field">
              <label>Address</label>
              <input name="address" />
            </div>
          </div>
          <div class="form-grid two">
            <div class="field">
              <label>Admin full name</label>
              <input name="adminFullName" required />
            </div>
            <div class="field">
              <label>Admin email</label>
              <input name="adminEmail" type="email" required />
            </div>
          </div>
          <div class="field">
            <label>Admin password</label>
            <input name="adminPassword" type="password" minlength="6" required />
          </div>
          <button class="btn btn-primary" type="submit" style="background:linear-gradient(135deg,#1b5fff,#3d7bff);color:white;border:none">Create school</button>
        </form>
      </div>
      </main>
    </div>
  `;
}

function render() {
  const app = document.getElementById('app');
  const path = route();

  if (!loadSession() && path !== '/login') {
    navigate('/login');
    return;
  }

  if (path === '/login' || !state.token) {
    app.innerHTML = renderLogin();
    bindLogin();
    return;
  }

  if (path === '/create') {
    app.innerHTML = renderCreateSchool();
    bindCommon();
    bindCreateForm();
    return;
  }

  if (path === '/schools') {
    app.innerHTML = renderSchoolsPage();
    bindSchoolsPage();
    return;
  }

  const schoolMatch = path.match(/^\/school\/([^/]+)$/);
  if (schoolMatch) {
    app.innerHTML =
      state.loading && !state.schoolDetail
        ? '<div class="loading">Loading school...</div>'
        : renderSchoolDetail();
    bindCommon();
    bindSchoolDetail();
    return;
  }

  app.innerHTML = renderDashboard();
  bindCommon();
  bindDashboard();
}

async function loadDashboard() {
  state.loading = true;
  state.error = null;
  render();
  try {
    const [overview, schools] = await Promise.all([
      api('/dev/overview'),
      api('/dev/schools'),
    ]);
    state.overview = overview;
    state.schools = schools;
  } catch (error) {
    state.error = error.message;
  } finally {
    state.loading = false;
    render();
  }
}

async function loadSchoolDetail(id) {
  state.loading = true;
  state.error = null;
  state.schoolDetail = null;
  render();
  try {
    state.schoolDetail = await api(`/dev/schools/${id}`);
  } catch (error) {
    state.error = error.message;
  } finally {
    state.loading = false;
    render();
  }
}

async function loadSchoolsPage() {
  if (state.schools.length === 0) {
    state.loading = true;
    state.error = null;
    render();
    try {
      const [overview, schools] = await Promise.all([api('/dev/overview'), api('/dev/schools')]);
      state.overview = overview;
      state.schools = schools;
    } catch (error) {
      state.error = error.message;
    } finally {
      state.loading = false;
    }
  }
  render();
}

function bindLogin() {
  const form = document.getElementById('login-form');
  form?.addEventListener('submit', async (event) => {
    event.preventDefault();
    state.error = null;
    const data = new FormData(form);

    try {
      const result = await api('/dev/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: String(data.get('email') || '').trim(),
          password: String(data.get('password') || ''),
        }),
      });
      state.token = result.accessToken;
      state.userEmail = result.user?.email || '';
      saveSession();
      navigate('/');
      await loadDashboard();
    } catch (error) {
      clearSession();
      state.error = error.message;
      render();
    }
  });
}

function bindCommon() {
  document.getElementById('logout-btn')?.addEventListener('click', () => {
    clearSession();
    state.overview = null;
    state.schools = [];
    state.schoolDetail = null;
    navigate('/login');
    render();
  });

  document.getElementById('back-btn')?.addEventListener('click', () => {
    navigate('/');
    loadDashboard();
  });
}

async function clearAllClassesAndTeachers() {
  const ok = confirm(
    'Remove ALL classes, ALL teachers, and ALL students?\n\nAdmin accounts will be kept. This cannot be undone.',
  );
  if (!ok) return;

  state.error = null;
  state.success = null;
  state.loading = true;
  render();
  bindCommon();
  bindDashboard();

  try {
    const result = await api('/dev/clear-all-classes-teachers', { method: 'POST' });
    const r = result.removed;
    state.success = `Removed ${r.classesRemoved} classes, ${r.teachersRemoved} teachers, ${r.studentsRemoved} students.`;
    await loadDashboard();
  } catch (error) {
    state.error = error.message;
    state.loading = false;
    render();
    bindCommon();
    bindDashboard();
  }
}

async function clearDemoData() {
  const ok = confirm(
    'Remove all seeded demo teachers, students, classes, and demo announcements?\n\nYour main admin account (admin@school.demo) will be kept.',
  );
  if (!ok) return;

  state.error = null;
  state.success = null;
  state.loading = true;
  render();
  bindCommon();
  bindDashboard();

  try {
    const result = await api('/dev/clear-demo', { method: 'POST' });
    const r = result.removed;
    state.success = `Demo cleared: ${r.teachers} teachers, ${r.students} students, ${r.classes} classes removed.`;
    await loadDashboard();
  } catch (error) {
    state.error = error.message;
    state.loading = false;
    render();
    bindCommon();
    bindDashboard();
  }
}

function bindDashboard() {
  document.getElementById('refresh-btn')?.addEventListener('click', loadDashboard);
  document.getElementById('clear-demo-btn')?.addEventListener('click', clearDemoData);
  document.getElementById('clear-all-btn')?.addEventListener('click', clearAllClassesAndTeachers);

  const goCreate = () => {
    state.error = null;
    state.success = null;
    navigate('/create');
    render();
  };
  document.getElementById('create-btn')?.addEventListener('click', goCreate);
  document.querySelectorAll('[data-create]').forEach((el) =>
    el.addEventListener('click', goCreate),
  );

  // Mobile sidebar toggle
  const sb = document.getElementById('sidebar');
  const overlay = document.getElementById('sb-overlay');
  const closeSb = () => {
    sb?.classList.remove('open');
    overlay?.classList.remove('show');
  };
  document.getElementById('sb-toggle')?.addEventListener('click', () => {
    sb?.classList.toggle('open');
    overlay?.classList.toggle('show');
  });
  overlay?.addEventListener('click', closeSb);

  // Sidebar nav: "Schools" jumps to the table; others are visual for now.
  document.querySelectorAll('[data-nav]').forEach((el) => {
    el.addEventListener('click', () => {
      const label = el.getAttribute('data-nav');
      closeSb();
      if (label === 'Schools') {
        navigate('/schools');
      }
    });
  });

  document.getElementById('search')?.addEventListener('input', (event) => {
    state.search = event.target.value;
    render();
    bindCommon();
    bindDashboard();
    const s = document.getElementById('search');
    if (s) {
      s.focus();
      const v = s.value;
      s.value = '';
      s.value = v;
    }
  });

  document.querySelectorAll('[data-goto]').forEach((el) => {
    el.addEventListener('click', () => navigate(el.getAttribute('data-goto')));
  });

  document.querySelectorAll('[data-school-id]').forEach((item) => {
    item.addEventListener('click', () => {
      const id = item.getAttribute('data-school-id');
      navigate(`/school/${id}`);
      loadSchoolDetail(id);
    });
  });
}

function bindSchoolsPage() {
  const sb = document.getElementById('sidebar');
  const overlay = document.getElementById('sb-overlay');
  const closeSb = () => {
    sb?.classList.remove('open');
    overlay?.classList.remove('show');
  };
  document.getElementById('sb-toggle')?.addEventListener('click', () => {
    sb?.classList.toggle('open');
    overlay?.classList.toggle('show');
  });
  overlay?.addEventListener('click', closeSb);

  // Sidebar nav links
  document.querySelectorAll('[data-nav]').forEach((el) => {
    el.addEventListener('click', () => {
      const label = el.getAttribute('data-nav');
      closeSb();
      if (label === 'Overview') {
        navigate('/');
        loadDashboard();
      } else if (label === 'Schools') {
        // already here
      }
    });
  });

  // Logout via user caret
  document.querySelector('.tb-user-caret')?.addEventListener('click', () => {
    clearSession();
    state.overview = null;
    state.schools = [];
    state.schoolDetail = null;
    navigate('/login');
    render();
  });

  // Create / import buttons
  document.getElementById('create-btn')?.addEventListener('click', () => {
    state.error = null;
    state.success = null;
    navigate('/create');
    render();
  });

  // Filters
  const applyFilter = (updates) => {
    Object.assign(state.schoolsFilter, updates, { page: 1 });
    render();
    bindSchoolsPage();
  };

  document.getElementById('sc-status-filter')?.addEventListener('change', (e) =>
    applyFilter({ status: e.target.value }),
  );
  document.getElementById('sc-city-filter')?.addEventListener('change', (e) =>
    applyFilter({ city: e.target.value }),
  );
  document.getElementById('sc-type-filter')?.addEventListener('change', (e) =>
    applyFilter({ type: e.target.value }),
  );
  document.getElementById('sc-search')?.addEventListener('input', (e) => {
    state.schoolsFilter.search = e.target.value;
    state.schoolsFilter.page = 1;
    render();
    bindSchoolsPage();
    const inp = document.getElementById('sc-search');
    if (inp) {
      inp.focus();
      const v = inp.value;
      inp.value = '';
      inp.value = v;
    }
  });

  // Pagination
  document.querySelectorAll('[data-page]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const p = parseInt(btn.getAttribute('data-page'), 10);
      if (!isNaN(p) && p >= 1) {
        state.schoolsFilter.page = p;
        render();
        bindSchoolsPage();
        document.querySelector('.dash-body')?.scrollTo({ top: 0, behavior: 'smooth' });
      }
    });
  });

  // View button → school detail
  document.querySelectorAll('.sc-view-btn').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const id = btn.getAttribute('data-school-id');
      navigate(`/school/${id}`);
      loadSchoolDetail(id);
    });
  });

  // Row click → school detail
  document.querySelectorAll('tr[data-school-id]').forEach((row) => {
    row.addEventListener('click', () => {
      const id = row.getAttribute('data-school-id');
      navigate(`/school/${id}`);
      loadSchoolDetail(id);
    });
  });
}

function bindSchoolDetail() {
  const school = state.schoolDetail?.school;
  if (!school) return;

  const openEdit = () => {
    openModal(renderEditSchoolModal(school));
    const form = document.getElementById('edit-school-form');
    form?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const data = new FormData(form);
      try {
        await api(`/dev/schools/${school.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            name: String(data.get('name') || '').trim(),
            city: String(data.get('city') || '').trim(),
            address: String(data.get('address') || '').trim(),
          }),
        });
        closeModal();
        state.success = 'School details updated.';
        state.error = null;
        await loadSchoolDetail(school.id);
      } catch (error) {
        state.error = error.message;
        render();
        bindCommon();
        bindSchoolDetail();
      }
    });
  };

  document.getElementById('edit-school-btn')?.addEventListener('click', openEdit);
  document.getElementById('edit-school-btn-2')?.addEventListener('click', openEdit);

  document.getElementById('stop-service-btn')?.addEventListener('click', async () => {
    const ok = confirm(
      `Stop service for "${school.name}"?\n\nUsers of this school will not be able to log in to the mobile app until you resume service.`,
    );
    if (!ok) return;
    try {
      await api(`/dev/schools/${school.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ isActive: false }),
      });
      state.success = 'Service stopped. School users cannot log in.';
      state.error = null;
      await loadSchoolDetail(school.id);
    } catch (error) {
      state.error = error.message;
      render();
      bindCommon();
      bindSchoolDetail();
    }
  });

  document.getElementById('resume-service-btn')?.addEventListener('click', async () => {
    try {
      await api(`/dev/schools/${school.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ isActive: true }),
      });
      state.success = 'Service resumed. School users can log in again.';
      state.error = null;
      await loadSchoolDetail(school.id);
    } catch (error) {
      state.error = error.message;
      render();
      bindCommon();
      bindSchoolDetail();
    }
  });

  document.getElementById('delete-school-btn')?.addEventListener('click', () => {
    openModal(renderDeleteSchoolModal(school));
    const form = document.getElementById('delete-school-form');
    form?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const data = new FormData(form);
      try {
        await api(`/dev/schools/${school.id}`, {
          method: 'DELETE',
          body: JSON.stringify({
            confirmCode: String(data.get('confirmCode') || '').trim(),
          }),
        });
        closeModal();
        state.schoolDetail = null;
        state.success = `School "${school.name}" deleted.`;
        state.error = null;
        navigate('/');
        await loadDashboard();
      } catch (error) {
        state.error = error.message;
        render();
        bindCommon();
        bindSchoolDetail();
      }
    });
  });

  document.querySelectorAll('.change-password-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      const adminId = btn.getAttribute('data-admin-id');
      const adminName = btn.getAttribute('data-admin-name') || 'Admin';
      openModal(renderPasswordModal(adminId, adminName));
      const form = document.getElementById('password-form');
      form?.addEventListener('submit', async (event) => {
        event.preventDefault();
        const data = new FormData(form);
        try {
          await api(`/dev/schools/${school.id}/admins/${adminId}/password`, {
            method: 'PATCH',
            body: JSON.stringify({
              newPassword: String(data.get('newPassword') || ''),
            }),
          });
          closeModal();
          state.success = `Password updated for ${adminName}.`;
          state.error = null;
          render();
          bindCommon();
          bindSchoolDetail();
        } catch (error) {
          state.error = error.message;
          render();
          bindCommon();
          bindSchoolDetail();
        }
      });
    });
  });
}

function bindCreateForm() {
  const form = document.getElementById('create-form');
  form?.addEventListener('submit', async (event) => {
    event.preventDefault();
    state.error = null;
    state.success = null;
    const data = new FormData(form);
    const payload = Object.fromEntries(data.entries());
    payload.code = String(payload.code || '').trim().toLowerCase();

    try {
      const result = await api('/dev/schools', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      state.success = `School "${result.school.name}" created. Admin: ${result.admin.email}`;
      form.reset();
      setTimeout(() => {
        navigate('/');
        loadDashboard();
      }, 1200);
    } catch (error) {
      state.error = error.message;
      render();
      bindCommon();
      bindCreateForm();
    }
  });
}

window.addEventListener('hashchange', async () => {
  const path = route();
  if (!state.token) {
    render();
    return;
  }

  if (path === '/') {
    await loadDashboard();
    return;
  }

  if (path === '/schools') {
    await loadSchoolsPage();
    return;
  }

  if (path === '/create') {
    state.error = null;
    render();
    return;
  }

  const schoolMatch = path.match(/^\/school\/([^/]+)$/);
  if (schoolMatch) {
    await loadSchoolDetail(schoolMatch[1]);
  }
});

if (loadSession()) {
  const path = route();
  if (path === '/' || path === '/login' || path === '') {
    loadDashboard();
  } else if (path === '/create') {
    render();
  } else if (path === '/schools') {
    loadSchoolsPage();
  } else {
    const schoolMatch = path.match(/^\/school\/([^/]+)$/);
    if (schoolMatch) loadSchoolDetail(schoolMatch[1]);
    else loadDashboard();
  }
} else {
  navigate('/login');
  render();
}
