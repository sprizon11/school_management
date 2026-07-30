# SmartUp — School Management Platform

A multi-tenant school management platform. One backend serves many schools; each
school has admins, teachers, students, and parents. This document is a
current-state reference: architecture, backend, mobile app, dev portal,
database, authentication/security, local dev, and deployment.

> For the original condensed overview see [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md).
> This file expands on it and reflects the current authentication system.

---

## 1. Surfaces

| Surface | Tech | Who uses it | Hosted on |
|---|---|---|---|
| **Mobile app** (`mobile/`) | Flutter | Admins, Teachers, Parents | Codemagic → Android/iOS |
| **Backend API** (`backend/`) | NestJS 10 + Prisma 6 | (serves all clients) | Google Cloud Run |
| **Dev portal** (`dev-portal/`) | Static HTML/JS/CSS | Platform owner only | Vercel |
| **Database** | PostgreSQL | — | Neon (prod) / portable Postgres (local) |

```
Flutter app ──► Cloud Run (NestJS /api) ──► Neon Postgres (Prisma)
Dev portal  ──►        (same backend)   ──►
```

- Backend base URL: `https://school-management-692069213021.asia-south1.run.app/api`
- Global route prefix `/api`; CORS open (`origin: true`); listens on `0.0.0.0:$PORT`.
- Roles: `ADMIN`, `TEACHER`, `PARENT` (`UserRole` enum). Role guard via `@Roles(...)` + `RolesGuard`.

---

## 2. Authentication & Security

Auth is JWT-based with server-side refresh tokens. `JWT_SECRET` is **required** —
the app refuses to boot without it (`src/auth/jwt-secret.ts`); the same secret
signs user sessions and dev-portal owner tokens.

### Tokens
- **Access token** — JWT, **15 min** lifetime (`JWT_EXPIRES_IN`, default `15m`).
  Carries `sub`, `schoolId`, `role`, `teacherId`, `parentId`.
- **Refresh token** — opaque random string, **30 days**, stored only as a
  SHA-256 hash in the `RefreshToken` table. **Rotated** on every use (the
  presented token is revoked and a new one issued) and **revocable** (logout,
  password change).

### Endpoints (`/api/auth`)
| Route | Purpose |
|---|---|
| `POST /login` | `{ schoolId, identifier, password }` → `{ accessToken, refreshToken, user }`. Rate-limited (10/min/IP). |
| `POST /refresh` | `{ refreshToken }` → new token pair (rotation). |
| `POST /logout` | Revoke a refresh token. |
| `POST /change-password` | Authenticated; verifies current password, sets new, clears `mustChangePassword`, revokes old sessions, returns a fresh session. |
| `POST /google` | `{ schoolId, idToken }` → verifies a Google ID token, matches an **already-provisioned** account by verified email within the school, links `googleId`, issues a session. Never self-registration. |
| `GET /me` | Current user profile. |

### Account protection
- **Per-user temporary passwords** — provisioning (teachers, parents) mints a
  random one-time password (`src/auth/password.util.ts`), sets
  `mustChangePassword`, and returns it once to the admin. No shared defaults.
- **Forced first-login change** — the mobile router traps `mustChangePassword`
  accounts on a change-password screen until they set a real password.
- **Brute-force lockout** — 5 consecutive failures lock the account for 15 min
  (`failedLoginCount` / `lockedUntil`); success resets them.
- **Rate limiting** — `@nestjs/throttler` scoped to the auth endpoints only (a
  global IP throttle would penalize whole schools behind one NAT).
- **Password policy** — min 8 chars with upper, lower, and a digit.

### Password storage
Per-user bcrypt hashes (`passwordHash`). Google sign-in offloads credentials to
Google for accounts whose provisioned email is a real Google address (mainly
teachers/admins; parents use synthetic `parent.<code>@school.parent` emails).

### Required env
`JWT_SECRET` (required), `JWT_EXPIRES_IN` (default `15m`),
`GOOGLE_CLIENT_IDS` (comma-separated web/Android/iOS client IDs; blank disables
Google sign-in). Dev portal: `DEV_PORTAL_EMAIL` / `DEV_PORTAL_PASSWORD`.

---

## 3. Backend (`backend/`, NestJS 10 + Prisma 6)

### Modules (`backend/src/`)
- **auth** — login, refresh, logout, change-password, Google sign-in, `me`.
- **schools** — `GET /schools/public` (unauthenticated; resolves a school
  domain/code → id for the login screen).
- **admin** — full school-admin surface: dashboard, students/teachers/classes
  CRUD, attendance, fees, examinations, timetable, reports, announcements,
  **events (calendar)**, **library (books + issue/return)**, profile, and a
  manual `POST admin/automation/run` trigger.
- **teacher** — dashboard, per-day timetable, homework, classes, class students,
  **attendance marking**, **student detail/edit** (narrower `TeacherUpdateStudentDto`,
  cannot change enrollment status or class), **leave approval**, chat, reports,
  announcements, notifications.
- **parent** — home summary, marks, report cards (with class rank by
  percentage), fees, events, homework, library, **leave requests**,
  notifications, chat.
- **chat** — shared teacher⇄parent messaging.
- **automation** — the "works while you sleep" layer (see below).
- **dev** — platform-owner console API (`/api/dev/*`): overview, schools CRUD,
  admin password reset, clear-demo, clear-all. Separate auth
  (`POST /api/dev/auth/login`) gated by env vars, not the user table.
- **common** — Prisma exception filter, parent-account helper.
- **health** — `GET /api/health`.

### Automation (`src/automation/automation.service.ts`)
A daily cron (7:00 AM `Asia/Kolkata`) derives reminders from existing data and
pushes `AppNotification`s. Every note carries a unique `dedupeKey`, so re-runs
never double-send. Rules: fee due/overdue, low attendance (<75% over a rolling
120-day window), homework due tomorrow, events tomorrow, library overdue,
birthdays. Also runnable on demand via `POST /api/admin/automation/run`.

Teachers also get **auto-alerts** riding on their normal work: marking a student
absent or publishing marks notifies the parent, with no extra teacher effort.

### Scripts (`backend/package.json`)
`build` (prisma generate + nest build), `start:dev`, `start:prod`,
`db:migrate`, `db:seed`, `db:clear-demo`, `db:clear-all`, `db:reset`.

---

## 4. Database (Prisma — `backend/prisma/schema.prisma`)

Core models: **School, User, Teacher, TimetableSlot, TeacherTeachingClass,
Class, Student, Parent, Subject, Mark, Homework, Announcement, AppNotification,
Event, AttendanceRecord**, fees (**FeeStructure, FeeAssignment, FeeInstallment,
FeePayment**), chat (**ChatConversation, ChatMessage**), **ActivityLog**.

Newer models: **LeaveRequest** (student leave workflow), **LibraryBook** /
**BookIssue** (library), **RefreshToken** (auth sessions).

Enums: `UserRole, Gender, StudentStatus, AttendanceStatus, FeeInstallmentStatus,
FeeStructureType, AnnouncementAudience, LeaveStatus`.

### Tenant scoping
`Teacher`, `ActivityLog`, `Event`, `LibraryBook` carry `schoolId`.
`Teacher.employeeCode` is unique **per school** (`@@unique([schoolId, employeeCode])`).
`User.googleId` is unique per school (`@@unique([schoolId, googleId])`; NULLs are
distinct in Postgres). `AppNotification.dedupeKey` is globally unique (nullable).

### Migrations
Versioned SQL under `backend/prisma/migrations/`. Recent:
- `20260715120000_tenant_scope_teacher_code_and_activity_log`
- `20260724120000_leave_library_events_and_dedupe`
- `20260724130000_auth_hardening` (User auth columns + `RefreshToken`)

**Local vs prod diverge on mechanism:** production (Neon) uses `migrate deploy`;
the local DB has **no migration history** (it was built with `db push`) — sync
local with `npx prisma db push`, never `migrate deploy`.

---

## 5. Mobile app (`mobile/`, Flutter)

- **State**: Riverpod. **Routing**: go_router. **HTTP**: dio.
  **Charts**: fl_chart. Secure token storage: flutter_secure_storage.
- **API base**: `lib/core/config/api_config.dart` (`ApiConfig.baseUrl`,
  overridable via `--dart-define=API_BASE_URL`). `cloud_api.dart` adds cold-start
  retry for Cloud Run.

### Auth flow
- **Login** (`features/auth/presentation/login_screen.dart`) — two-step card in
  one screen: domain step (resolves school code) → credentials. Persists the
  selected school. Has a **Continue with Google** button (enabled only when
  `GOOGLE_SERVER_CLIENT_ID` is defined).
- **Sessions** (`core/providers/auth_provider.dart`) — stores access + refresh
  tokens and `mustChangePassword` in secure storage.
- **Auto-refresh** (`core/network/api_client.dart`) — a single-flight interceptor
  catches `401`, silently refreshes via `/auth/refresh`, retries the request,
  and logs out cleanly if refresh fails.
- **Forced change** (`features/auth/presentation/change_password_screen.dart`) —
  router redirects temp-password accounts here until they reset.

### Role shells (`features/{admin,teacher,parent}/`)
Frosted-glass "liquid" bottom nav per role. Admin (blue), Teacher (purple),
Parent (chat + child-centric). Screens cover dashboards, students, classes,
attendance, fees, exams, timetable, reports, announcements, and the parent
surface (home, marks, report card, fees, events, homework, library, leave,
notifications).

### Build
Codemagic (`codemagic.yaml`), workflow **`ios-free-workflow`** — builds an
**unsigned** IPA (`working_directory: mobile`) for free-install via Sideloadly.
No `triggering:` block, so builds are **started manually** in the Codemagic UI.
Device builds hit **production** Cloud Run (no `API_BASE_URL` override).

---

## 6. Dev portal (`dev-portal/`, static)

Vanilla HTML/JS/CSS on Vercel
(`https://school-management-pearl-omega.vercel.app`). Owner-only, noindex.
Routes: `/login`, `/` (dashboard), `/schools`, `/create`, `/school/:id`.
Owner login → `POST /api/dev/auth/login` (owner: `sprizon1207@gmail.com`).
Can create/stop/resume/**delete** schools (delete requires typing the school
code), reset admin passwords, and clear demo/all data.

---

## 7. Local development

The dev machine has **no Docker and no system Postgres** — local dev uses a
portable Postgres under a scratchpad path (persists across sessions).

```bash
node <scratchpad>/pg.js        # Postgres on 5432, creates school_management
cd backend && node dist/main   # API on 3000 (dist/ prebuilt)
cd mobile && flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1 \
  --release --dart-define=API_BASE_URL=http://localhost:3000/api
```

Gotchas: Flutter web must be `--release`; Windows Defender locks `build/`
(rename, don't delete); PowerShell 5.1 has no `&&` (use `;` or run steps
separately). Local `backend/.env` `DATABASE_URL` points at `localhost:5432`, not
Neon.

---

## 8. Deployment & operations

- **Backend** — Google Cloud Run service `school-management` (region
  `asia-south1`, project `smartup-ee7ef`), built from GitHub `main`. Redeploy is
  **manual** in the Cloud Console (no `gcloud` locally). Set env
  (`JWT_SECRET`, `GOOGLE_CLIENT_IDS`, `DEV_PORTAL_*`, `DATABASE_URL`) there.
- **DB migrations** — prod: `npx prisma migrate deploy` against Neon; local:
  `npx prisma db push`.
- **Mobile** — Codemagic, manual build from `main`.
- **Dev portal** — Vercel auto-deploys from repo.
- **Payments** — Cashfree integration (native Android SDK).

---

## 9. Repo layout

```
school management/
├── backend/          NestJS API (src/ modules, prisma/ schema+seed+migrations)
├── mobile/           Flutter app (lib/features/{admin,teacher,parent,auth}, lib/core)
├── dev-portal/       Static owner console (Vercel)
├── scripts/          Cloud seed/migrate/clear helpers (PowerShell)
├── codemagic.yaml    Mobile CI/CD
├── docker-compose.yml / backend/Dockerfile
└── *.md              PROJECT_OVERVIEW, DEPLOY, DEMO_SETUP, README, this file
```

_Keep this file updated when architecture, endpoints, auth, or deploy flow change._
