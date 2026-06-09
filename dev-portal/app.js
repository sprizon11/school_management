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

function renderDashboard() {
  const overview = state.overview || {};
  const schools = state.schools.filter((school) => {
    const q = state.search.trim().toLowerCase();
    if (!q) return true;
    return (
      school.name.toLowerCase().includes(q) ||
      school.code.toLowerCase().includes(q) ||
      (school.city || '').toLowerCase().includes(q)
    );
  });

  return `
    <div class="app-layout">
      ${appNav()}
      <main class="shell">
        <section class="welcome-banner">
          <div class="welcome-banner-inner">
            <div>
              <span class="eyebrow" style="background:rgba(255,255,255,0.16);color:white">Platform overview</span>
              <h1>Your schools at a glance</h1>
              <p>Track registrations, monitor growth, and manage every institution from one premium control center.</p>
            </div>
            <div class="banner-actions">
              <button class="btn btn-ghost" id="refresh-btn">Refresh</button>
              <button class="btn btn-ghost" id="clear-demo-btn">Clear demo data</button>
              <button class="btn btn-ghost btn-danger" id="clear-all-btn">Clear all classes &amp; teachers</button>
              <button class="btn btn-primary" id="create-btn">+ Create school</button>
              <button class="btn btn-ghost" id="logout-btn">Sign out</button>
            </div>
          </div>
        </section>

        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

        <div class="section-head">
          <div>
            <h2>Platform metrics</h2>
            <p>Live totals across all registered schools</p>
          </div>
        </div>

        <div class="grid-stats">
          ${statCard('Schools', overview.schools?.total ?? 0, icons.school, 'blue')}
          ${statCard('Active schools', overview.schools?.active ?? 0, icons.active, 'green')}
          ${statCard('Students', overview.students ?? 0, icons.students, 'violet')}
          ${statCard('Teachers', overview.teachers ?? 0, icons.teachers, 'teal')}
        </div>
        <div class="grid-stats secondary">
          ${statCard('Admins', overview.admins ?? 0, icons.admins, 'amber')}
          ${statCard('Parent profiles', overview.parents ?? 0, icons.parents, 'slate')}
          ${statCard('Classes', overview.classes ?? 0, icons.classes, 'blue')}
        </div>

        <div class="section-head">
          <div>
            <h2>Registered schools</h2>
            <p>${schools.length} school${schools.length === 1 ? '' : 's'} on your platform</p>
          </div>
        </div>

        <div class="panel">
          <div class="panel-header">
            <h2>Browse schools</h2>
            <div class="search-wrap">
              ${icons.search}
              <input class="search" id="search" placeholder="Search by name, code, or city..." value="${esc(state.search)}" />
            </div>
          </div>
          ${
            state.loading
              ? '<div class="loading">Loading schools...</div>'
              : schools.length === 0
                ? '<div class="empty">No schools found.</div>'
                : `<ul class="school-list">
                    ${schools
                      .map(
                        (school) => `
                      <li class="school-item" data-school-id="${esc(school.id)}">
                        <div class="school-avatar">${esc(initials(school.name))}</div>
                        <div>
                          <div class="school-name">${esc(school.name)}</div>
                          <div class="school-meta">
                            <span class="badge ${school.isActive ? 'badge-active' : 'badge-inactive'}">
                              ${school.isActive ? 'Active' : 'Inactive'}
                            </span>
                            · Code <strong>${esc(school.code)}</strong>
                            ${school.city ? ` · ${esc(school.city)}` : ''}
                            <br />Created ${esc(formatDate(school.createdAt))}
                          </div>
                        </div>
                        <div>
                          <div class="pill-row">
                            <span class="pill"><strong>${school.stats?.students ?? 0}</strong> students</span>
                            <span class="pill"><strong>${school.stats?.teachers ?? 0}</strong> teachers</span>
                            <span class="pill"><strong>${school.stats?.parents ?? 0}</strong> parents</span>
                            <span class="pill"><strong>${school.stats?.classes ?? 0}</strong> classes</span>
                          </div>
                          <div class="school-arrow" style="text-align:right;margin-top:10px">${icons.arrow}</div>
                        </div>
                      </li>
                    `,
                      )
                      .join('')}
                  </ul>`
          }
        </div>
      </main>
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
      </div>
      <div class="grid-stats secondary" style="margin-bottom:24px">
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
  document.getElementById('create-btn')?.addEventListener('click', () => {
    state.error = null;
    state.success = null;
    navigate('/create');
    render();
  });

  document.getElementById('search')?.addEventListener('input', (event) => {
    state.search = event.target.value;
    render();
    bindCommon();
    bindDashboard();
  });

  document.querySelectorAll('[data-school-id]').forEach((item) => {
    item.addEventListener('click', () => {
      const id = item.getAttribute('data-school-id');
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
  } else {
    const schoolMatch = path.match(/^\/school\/([^/]+)$/);
    if (schoolMatch) loadSchoolDetail(schoolMatch[1]);
    else loadDashboard();
  }
} else {
  navigate('/login');
  render();
}
