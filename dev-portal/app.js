const STORAGE_KEY = 'school_dev_portal_session';

const state = {
  apiBase: '',
  devKey: '',
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
    state.apiBase = data.apiBase || '';
    state.devKey = data.devKey || '';
    return Boolean(state.apiBase && state.devKey);
  } catch {
    return false;
  }
}

function saveSession() {
  sessionStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({ apiBase: state.apiBase, devKey: state.devKey }),
  );
}

function clearSession() {
  sessionStorage.removeItem(STORAGE_KEY);
  state.apiBase = '';
  state.devKey = '';
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
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'x-dev-key': state.devKey,
      ...(options.headers || {}),
    },
  });

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

function statCard(label, value) {
  return `
    <div class="stat-card">
      <div class="label">${esc(label)}</div>
      <div class="value">${esc(value)}</div>
    </div>
  `;
}

function renderLogin() {
  return `
    <div class="login-wrap">
      <div class="login-card">
        <h1>Private platform console</h1>
        <p>This site is for platform owners only. App users never see this page. Enter your API URL and developer key.</p>
        ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
        <form id="login-form">
          <div class="field">
            <label for="apiBase">API base URL</label>
            <input id="apiBase" name="apiBase" value="${esc(state.apiBase || 'https://school-management-9yzh.onrender.com/api')}" placeholder="https://your-api.onrender.com/api" required />
          </div>
          <div class="field">
            <label for="devKey">Developer key</label>
            <input id="devKey" name="devKey" type="password" value="${esc(state.devKey)}" placeholder="DEV_PLATFORM_KEY from server" required />
          </div>
          <button class="btn btn-primary" style="width:100%;margin-top:8px" type="submit">
            Unlock console
          </button>
        </form>
        <p class="muted-note" style="margin-top:16px">
          Session stays in this browser tab only. Deploy this folder as a private static site and do not link it from the mobile app.
        </p>
      </div>
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
    <div class="shell">
      <div class="topbar">
        <div class="brand">
          <h1>Platform overview</h1>
          <p>All schools on ${esc(state.apiBase)}</p>
        </div>
        <div class="actions">
          <button class="btn btn-ghost" id="refresh-btn">Refresh</button>
          <button class="btn btn-primary" id="create-btn">Create school</button>
          <button class="btn btn-danger" id="logout-btn">Lock</button>
        </div>
      </div>

      ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
      ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

      <div class="grid-stats">
        ${statCard('Schools', overview.schools?.total ?? 0)}
        ${statCard('Active schools', overview.schools?.active ?? 0)}
        ${statCard('Students', overview.students ?? 0)}
        ${statCard('Teachers', overview.teachers ?? 0)}
        ${statCard('Admins', overview.admins ?? 0)}
        ${statCard('Parents', overview.parents ?? 0)}
        ${statCard('Classes', overview.classes ?? 0)}
      </div>

      <div class="panel">
        <div class="panel-header">
          <h2>All schools</h2>
          <input class="search" id="search" placeholder="Search school..." value="${esc(state.search)}" />
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
                      <div>
                        <div class="school-name">${esc(school.name)}</div>
                        <div class="school-meta">
                          Code: ${esc(school.code)}
                          ${school.city ? ` · ${esc(school.city)}` : ''}
                          · Created ${esc(formatDate(school.createdAt))}
                        </div>
                      </div>
                      <div class="pill-row">
                        <span class="badge ${school.isActive ? 'badge-active' : 'badge-inactive'}">
                          ${school.isActive ? 'Active' : 'Inactive'}
                        </span>
                        <span class="pill"><strong>${school.stats?.students ?? 0}</strong> students</span>
                        <span class="pill"><strong>${school.stats?.teachers ?? 0}</strong> teachers</span>
                        <span class="pill"><strong>${school.stats?.classes ?? 0}</strong> classes</span>
                      </div>
                    </li>
                  `,
                    )
                    .join('')}
                </ul>`
        }
      </div>
    </div>
  `;
}

function renderSchoolDetail() {
  const detail = state.schoolDetail;
  if (!detail) {
    return '<div class="loading">Loading school...</div>';
  }

  const { school, stats, admins, classes } = detail;

  return `
    <div class="shell">
      <div class="topbar">
        <div class="brand">
          <h1>${esc(school.name)}</h1>
          <p>${esc(school.code)}${school.city ? ` · ${esc(school.city)}` : ''}</p>
        </div>
        <div class="actions">
          <button class="btn btn-ghost" id="back-btn">All schools</button>
          <button class="btn btn-danger" id="logout-btn">Lock</button>
        </div>
      </div>

      ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}

      <div class="grid-stats">
        ${statCard('Students', stats.students)}
        ${statCard('Teachers', stats.teachers)}
        ${statCard('Admins', stats.admins)}
        ${statCard('Parents', stats.parents)}
        ${statCard('Classes', stats.classes)}
      </div>

      <div class="detail-grid">
        <div class="panel">
          <div class="panel-header"><h2>School details</h2></div>
          <div style="padding: 8px 20px 18px">
            <ul class="info-list">
              <li><span>Status</span><span>${school.isActive ? 'Active' : 'Inactive'}</span></li>
              <li><span>School ID</span><span>${esc(school.id)}</span></li>
              <li><span>Code</span><span>${esc(school.code)}</span></li>
              <li><span>City</span><span>${esc(school.city || '—')}</span></li>
              <li><span>Address</span><span>${esc(school.address || '—')}</span></li>
              <li><span>Created</span><span>${esc(formatDate(school.createdAt))}</span></li>
            </ul>
          </div>
        </div>

        <div class="panel">
          <div class="panel-header"><h2>Admin accounts</h2></div>
          ${
            admins.length === 0
              ? '<div class="empty">No admin users yet.</div>'
              : `<div class="table-wrap"><table>
                  <thead><tr><th>Name</th><th>Email</th></tr></thead>
                  <tbody>
                    ${admins
                      .map(
                        (admin) => `
                      <tr>
                        <td>${esc(admin.fullName)}</td>
                        <td>${esc(admin.email)}</td>
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
    </div>
  `;
}

function renderCreateSchool() {
  return `
    <div class="shell">
      <div class="topbar">
        <div class="brand">
          <h1>Create school</h1>
          <p>Register a new school and its first admin account</p>
        </div>
        <div class="actions">
          <button class="btn btn-ghost" id="back-btn">All schools</button>
          <button class="btn btn-danger" id="logout-btn">Lock</button>
        </div>
      </div>

      ${state.error ? `<div class="error">${esc(state.error)}</div>` : ''}
      ${state.success ? `<div class="success">${esc(state.success)}</div>` : ''}

      <div class="panel" style="padding:20px">
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
          <button class="btn btn-primary" type="submit">Create school</button>
        </form>
      </div>
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

  if (path === '/login' || !state.apiBase || !state.devKey) {
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
    app.innerHTML = state.loading && !state.schoolDetail
      ? '<div class="loading">Loading school...</div>'
      : renderSchoolDetail();
    bindCommon();
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
    state.apiBase = String(data.get('apiBase') || '').trim();
    state.devKey = String(data.get('devKey') || '').trim();
    saveSession();

    try {
      await api('/dev/overview');
      state.success = null;
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

function bindDashboard() {
  document.getElementById('refresh-btn')?.addEventListener('click', loadDashboard);
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
  if (!state.apiBase || !state.devKey) {
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
