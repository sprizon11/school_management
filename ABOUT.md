# SmartUp — What This App Is & How It Works

> A plain-language walkthrough of the product: what problem it solves, who
> uses it, what each person can do, and how the pieces fit together.
> For deep technical/dev details, see [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md).

---

## 1. The pitch

**SmartUp is a school management platform** — one system that replaces the
scattered mix of paper registers, WhatsApp groups, and Excel sheets that
most small-to-mid-size schools use to run day-to-day operations.

It's built as **one product, many schools**: a single backend and a single
mobile app serve every school that signs up, with each school's data kept
completely separate from every other school's. You (the platform owner) can
onboard new schools yourself through a private console, without writing any
new code per school.

That "many schools, one codebase" design is what makes it a real **SaaS
business**, not a one-off app built for a single client.

---

## 2. The problem it solves

Small and mid-size schools typically juggle:

- Attendance taken on paper, or in a notebook, never digitized
- Marks/report cards done in Excel, one file per class per exam
- Homework and announcements sent over WhatsApp groups, easy to miss
- Parents with no visibility into their child's day-to-day progress
- No single place for admins to see the whole school at a glance

SmartUp puts all of that in one app, on everyone's phone, with each role
(admin, teacher, parent) seeing exactly the tools relevant to them.

---

## 3. Who uses it (the four roles)

| Role | Who this is | What they use |
|---|---|---|
| **Platform owner** (you) | Whoever runs SmartUp as a business | The **dev portal** — a private web console to create new schools, provision their first admin, and monitor the whole platform |
| **School admin** | The principal or office staff at a school | The mobile app's **admin** section — full control over that one school |
| **Teacher** | Teaching staff | The mobile app's **teacher** section — their classes, students, attendance, marks, homework, chat with parents |
| **Parent** | A student's parent/guardian | The mobile app's **parent** section — see their child's info and chat with the teacher |

Everyone logs into the **same mobile app** — what they see is determined by
their role and which school they belong to.

---

## 4. What each role can actually do

### Platform owner (dev portal)
- Create a new school (name, code/domain, address) — this is what generates
  the "school domain" a teacher/admin types on the login screen (e.g. `greenfield`)
- Provision that school's first admin account
- See platform-wide stats: how many schools, how much activity, subscription/growth trends
- Pause, resume, or delete a school's access
- Reset an admin's password if they're locked out

### School admin
- Dashboard: students, teachers, classes, attendance %, fee collection, recent activity — for **their school only**
- Manage teachers: add, view, remove
- Manage classes: create classes/sections, assign a class teacher
- Manage students: add, edit, view roll numbers, parent/guardian details
- Announcements: post to teachers, or to teachers + parents
- Fees: fee structures, installments, payment tracking (Cashfree integration)
- Reports: attendance overview, fee overview, exam/marks overview, timetable

### Teacher
- **Dashboard**: today's schedule at a glance, quick stats (students, attendance, classes, tasks), quick-access shortcuts
- **Timetable**: a real per-day schedule; teachers can edit their own periods (subject, room, class, time) instead of a fixed system-generated one
- **My Classes**: the classes they're assigned to, with rosters
- **Students**: search/browse their students, tap through to a detail view
- **Attendance / Marks / Performance / Assignments reports**: per-student breakdowns —
  attendance %, present/absent/leave counts, subject-wise marks, a combined
  performance ranking, and homework due dates
- **Add Assignment**: create homework for a class (title, description, due date)
- **Add Marks**: record exam results — pick a subject and an exam name (e.g.
  "Unit Test 1"), then enter every student's score in one screen; grades
  (A+ through F) are computed automatically
- **Messages**: a WhatsApp-style chat list with every parent in their classes
- **Announcements**: read what the school admin has posted

### Parent
- See their child's class, teacher, and basic profile
- Chat directly with their child's teacher

---

## 5. How it's built (architecture, in plain terms)

```
 Flutter mobile app  ──┐
                       ├──►  NestJS backend API  ──►  Postgres database
 Dev portal (web)   ───┘        (Cloud Run)              (Neon, managed)
```

- **Mobile app** (Flutter/Dart) — the only interface admins, teachers, and
  parents use. One codebase builds both the Android and iOS apps.
- **Backend API** (NestJS, a Node.js framework) — all business logic and
  data access goes through here. It's the single source of truth every
  screen in the app talks to.
- **Database** (PostgreSQL, hosted on Neon) — every school's records live in
  the same database, but every table that matters is tagged with a
  `schoolId` so one school's data is never returned to another school's
  request. (This isolation was recently audited and hardened — see §7.)
- **Dev portal** (plain HTML/JS, hosted on Vercel) — the only piece of the
  system that intentionally sees across schools, because that's its job:
  managing the whole platform.

### Why "one backend, many schools" instead of one deployment per school
It's dramatically cheaper and easier to operate: one server to monitor, one
codebase to update, one place to fix a bug. The tradeoff is that the
backend must be strict about only ever returning a school's own data — which
is the whole point of the tenant-isolation work described below.

---

## 6. The data model, briefly

Everything hangs off a `School`. A school has many `User`s (each tagged
with a role: Admin, Teacher, or Parent), `Class`es, and `Student`s. From
there:

- **Teacher ↔ Class** — a teacher can be a class's main teacher, or just
  teach a subject in it
- **Student ↔ Class ↔ School** — every student belongs to exactly one class,
  and a class belongs to exactly one school (this is how "which school does
  this data belong to" is always traceable)
- **Attendance, Marks, Homework** — all point back to a student or class,
  and therefore back to a school
- **Fees** — structured as FeeStructure → FeeAssignment (per student) →
  FeeInstallment → FeePayment, so partial/installment payments are tracked
- **Chat** — a conversation always ties one teacher to one parent, scoped to
  a specific student

---

## 7. Multi-tenancy: how "no school sees another school's data" is enforced

This was explicitly reviewed and fixed in this codebase (see git history:
*"Fix cross-school data isolation across admin and teacher APIs"*). What
was found and corrected:

- Several admin dashboard/report endpoints queried the database with **no
  school filter at all** — meaning one school's admin could see numbers
  that were actually a mix of every school's data.
- A few endpoints fetched a student/class **by raw ID with no ownership
  check** — meaning, in theory, one school's admin could view or edit
  another school's record if they knew (or guessed) its ID.
- One piece of leftover migration code would have **silently transferred an
  entire school's class list** to a different school the first time that
  school opened its (empty) dashboard — a serious bug, since it ran
  automatically, with no user action required. This was removed entirely.

All of these are now fixed: every query that touches student/class/teacher
data verifies the requesting user's `schoolId` matches before returning or
changing anything.

**One known open item:** the "recent activity" log on the admin dashboard
has no `schoolId` column in its underlying table yet, so it still shows
activity from all schools combined. Fixing that requires a small database
migration (adding a column + backfilling it), which hasn't been done yet
since schema changes are handled more carefully than regular code fixes.

---

## 8. Deployment (where it actually runs)

| Piece | Hosted on |
|---|---|
| Backend API | Google Cloud Run (`asia-south1` region) |
| Database | Neon (managed Postgres) |
| Dev portal | Vercel |
| Mobile app builds | Codemagic (builds from GitHub `main` → Android + iOS) |

Pushing to the `main` branch on GitHub is what triggers a backend redeploy
and a new mobile build — nothing ships automatically before that.

---

## 9. Where things stand right now

- Core teacher, admin, and parent flows are built and functional.
- The teacher side of the app went through a full UI redesign this session:
  a consistent header style across every screen, a redesigned dashboard,
  a WhatsApp-style messages screen, a redesigned students screen, and four
  new detailed report screens (attendance, marks, performance, assignments).
- Teachers can now actually **enter marks and create assignments** from the
  app — previously the reports screens existed but had no way to add data.
- The multi-tenancy/data-isolation issue described in §7 has been found and
  fixed at the code level.
- **Not yet deployed**: all of the above is committed to the local `main`
  branch but has not been pushed to GitHub yet, so none of it is live on
  the actual backend or in the app users have installed.

---

## 10. Why this matters as a business

Because the whole system was designed around `schoolId` as the tenant
boundary from the start, onboarding a new school doesn't require any new
code, servers, or app builds — just a new row in the dev portal. That's
what turns this from "an app for one school" into "a platform any school
can sign up for," which is the direction you said you're taking it.
