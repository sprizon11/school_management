# SmartUp — School Management Platform · Full Overview

> Single source of truth for the whole system. Read this first when picking up
> the project. Covers architecture, backend, mobile app, dev-portal, database,
> deployment, and local-dev gotchas.

---

## 1. What it is

A multi-tenant school management platform. One backend serves many schools;
each school has admins, teachers, students, and parents. Three surfaces:

| Surface | Tech | Who uses it | Hosted on |
|---|---|---|---|
| **Mobile app** (`mobile/`) | Flutter | Admins, Teachers, Parents | Built via Codemagic → Android/iOS |
| **Backend API** (`backend/`) | NestJS + Prisma | (serves both apps) | Google Cloud Run |
| **Dev portal** (`dev-portal/`) | Static HTML/JS/CSS | Platform owner only (you) | Vercel |
| **Database** | PostgreSQL | — | Neon |

The **dev portal** is the platform-owner console: create schools, provision the
first admin per school, view platform-wide stats, stop/resume/delete schools.
It is private (noindex) and gated by owner credentials — not visible to app users.

---

## 2. Architecture at a glance

```
Flutter app ──► Cloud Run (NestJS /api) ──► Neon Postgres (Prisma)
Dev portal  ──►        (same backend)   ──►
```

- Backend base URL: `https://school-management-692069213021.asia-south1.run.app/api`
- Global route prefix: `/api` (set in `backend/src/main.ts`)
- CORS: `origin: true` (open); listens on `0.0.0.0:$PORT` (Cloud Run injects PORT)
- Auth: JWT (`@nestjs/jwt` + passport-jwt). Role guard via `@Roles(...)` +
  `RolesGuard`. Roles: `ADMIN`, `TEACHER`, `PARENT` (see `UserRole` enum).

---

## 3. Backend (`backend/`, NestJS 10 + Prisma 6)

### Modules (`backend/src/`)
- **auth** — `POST /api/auth/login`, `GET /api/auth/me`. Login takes
  `{ schoolId, identifier, password }`, returns `{ accessToken, user }`.
- **schools** — `GET /api/schools/public` (unauthenticated list used by the app
  login screen to resolve a school domain/code → id).
- **admin** — full school-admin surface: dashboard summary, students/teachers/
  classes CRUD, attendance, fees, examinations, timetable, reports,
  announcements, profile.
- **teacher** — dashboard summary, **per-day timetable** (`GET/POST
  /api/teacher/dashboard/schedule?day=0..6`), homework, classes, class students,
  chat, reports, announcements, notifications.
- **parent** — chat conversations + messages.
- **chat** — shared chat service (teacher⇄parent messaging).
- **dev** — platform-owner console API (`/api/dev/*`): overview, schools CRUD,
  admin password reset, clear-demo, clear-all. Separate auth
  (`POST /api/dev/auth/login`) gated by `DEV_PORTAL_EMAIL` / `DEV_PORTAL_PASSWORD`
  env vars, NOT the normal user table.
- **common** — Prisma exception filter, parent-account helper.
- **health** — `GET /api/health`.

### Notable domain logic
- **Teacher timetable** (`teacher.service.ts`): `schedule(teacherId, day)` returns
  teacher-saved `TimetableSlot` rows for that weekday if any exist, else generates
  a deterministic default from the teacher's assigned classes/subjects. Sunday
  (day 0) is a holiday (empty). `current` period is computed from the real clock.
  `saveSchedule()` replaces a day's slots in a transaction; empty slots array
  clears the override back to the generated default.

### Prisma models (`backend/prisma/schema.prisma`)
School, User, Teacher, **TimetableSlot**, TeacherTeachingClass, Class, Student,
Parent, ChatConversation, ChatMessage, AttendanceRecord, Subject, Mark, Homework,
Announcement, AppNotification, Event, FeeStructure, FeeAssignment, FeeInstallment,
FeePayment, ActivityLog. Enums: UserRole, Gender, StudentStatus, AttendanceStatus,
FeeInstallmentStatus, FeeStructureType, AnnouncementAudience.

### Scripts (`backend/package.json`)
`build` (prisma generate + nest build), `start:dev`, `start:prod`,
`db:migrate`, `db:seed`, `db:clear-demo`, `db:clear-all`, `db:reset`.

---

## 4. Mobile app (`mobile/`, Flutter)

- **State**: Riverpod. **Routing**: go_router. **HTTP**: dio. **Charts**: fl_chart.
  Secure token storage: flutter_secure_storage. Prefs: shared_preferences.
- **API base**: `mobile/lib/core/network/` (`api_client.dart`, `cloud_api.dart`,
  `ApiConfig.baseUrl`). `cloud_api.dart` has cold-start retry logic for cloud
  hosts (`run.app`, etc.) since Cloud Run min-instances can cold start.

### Login (`features/auth/presentation/login_screen.dart`)
Two-step card in ONE screen (no separate route):
1. **Domain step** — user types their school domain (= school `code`, e.g.
   `greenfield`), matched locally against `GET /schools/public` (exact code, then
   code-prefix / name-contains). No dropdown.
2. **Credentials step** — email + password. A "Change" chip returns to step 1.

Selected school persists (shared_preferences), so returning users skip straight to
step 2. Layout is a flex column (header / card / footer) so header and card can't
overlap; the header's top gap is **derived from the logo's baked-in position** in
the 473×1024 background PNG (logo bottom ≈ y=149) projected via BoxFit.cover scale,
so it clears the logo on any screen incl. web.

### Role shells & screens
- **admin** (`features/admin/`) — `AdminShell` with a floating frosted-glass
  "liquid" bottom nav. Screens: dashboard, students, teachers, classes, more,
  plus add/edit flows, attendance, fees, examinations, timetable, reports,
  announcements, subscription, profile.
- **teacher** (`features/teacher/`) — `TeacherShell` (same liquid nav style,
  purple theme). Dashboard has: gradient profile/stats hero, **weekly timetable
  card** (Mon–Sat day chips + vertical period timeline + edit pencil → bottom-sheet
  editor to add/remove periods, set times via native picker, subject/room/class),
  quick actions, my classes, upcoming assignments. Other screens: chat, students,
  reports, more, announcements.
- **parent** (`features/parent/`) — `ParentShell` (chat-focused).
- Shared teacher widgets in `features/teacher/presentation/widgets/teacher_ui.dart`
  (`TeacherPageHeader` with decorative circles, cards, section titles).

### Theme
`mobile/lib/core/theme/app_colors.dart` — primary blue `#2D68FF`,
teacherPrimary `#635BFF`, etc.

### Build
Codemagic (`codemagic.yaml`) from GitHub `main`. iOS enabled for the owner's
personal phone. App name "SmartUp", icons via flutter_launcher_icons.

---

## 5. Dev portal (`dev-portal/`, static)

Vanilla HTML/JS/CSS, no framework. Deployed to Vercel
(`https://school-management-pearl-omega.vercel.app`).
- `app.js` — SPA router + all views. `config.js` — `apiBase`. `styles.css` +
  `dash.css` — styling. `vercel.json` — build/headers (noindex).
- Routes: `/login`, `/` (dashboard: sidebar + topbar, stat cards, platform
  overview chart from real school-registration data, subscription activity,
  platform health, schools table preview), `/schools` (full paginated schools
  page with filters, type/status badges, actions), `/create` (create school),
  `/school/:id` (school detail).
- Owner login → `POST /api/dev/auth/login`. Owner email: sprizon1207@gmail.com.

---

## 6. Deployment & operations

See memory notes `deployment-topology` and `flutter-windows-dev-gotchas`, plus:

- **Backend deploy**: Google Cloud Console → Cloud Run → service
  `school-management` (region `asia-south1`, project `smartup-ee7ef`). Builds from
  GitHub `main`. `gcloud` CLI is NOT installed locally — redeploy in the browser.
- **DB migrations**: `npx prisma db push` / `prisma migrate`. **Local
  `backend/.env` `DATABASE_URL` points at `localhost:5432`, not Neon** — to run
  against production, prefix with the real Neon `DATABASE_URL` (from Neon console
  or the Cloud Run env var). Prisma prod changes are blocked in Claude "auto mode".
- **Dev portal**: Vercel auto-deploys from repo. Owner creds are Cloud Run env
  vars `DEV_PORTAL_EMAIL` / `DEV_PORTAL_PASSWORD`.
- **Payments**: Cashfree integration exists (native Android SDK; payment links
  include customer_email) — see git history around v1.2.3.

### Windows local-dev gotchas
- Windows Defender locks `build\flutter_assets` → `flutter run` fails to delete it.
  Fix: **rename** the folder (delete fails, rename works), then re-run.
- Web preview must use `--release` (`flutter run -d web-server --release`); the
  debug web-server device needs the Dart Debug Chrome extension and renders black.
- PowerShell 5.1: no `&&` (use `;` or the Bash tool).

---

## 7. Repo layout

```
school management/
├── backend/          NestJS API (src/ modules, prisma/ schema+seed)
├── mobile/           Flutter app (lib/features/{admin,teacher,parent,auth}, lib/core)
├── dev-portal/       Static owner console (Vercel)
├── scripts/          Cloud seed/migrate/clear helpers (PowerShell)
├── codemagic.yaml    Mobile CI/CD
├── render.yaml       (legacy Render config)
├── docker-compose.yml / backend/Dockerfile
└── *.md              DEPLOY, DEMO_SETUP, HOSTINGER_VPS, README, this file
```

---

_Keep this file updated when architecture, endpoints, or deploy flow change._
