# Smart School Management System

Flutter Android app + NestJS API + PostgreSQL for **Admin**, **Teacher**, and **Parent** roles.

## Project structure

```
school-management/
├── backend/          # NestJS REST API + Prisma
├── mobile/           # Flutter app
├── docker-compose.yml
└── README.md
```

## Prerequisites

- **Node.js** 18+
- **Flutter** 3.x
- **PostgreSQL** 16 (via Docker Desktop **or** local install)

## 1. Database

### Option A: Docker

```bash
docker compose up -d
```

### Option B: Local PostgreSQL

Create database `school_management` and user matching `backend/.env`:

```
DATABASE_URL="postgresql://school:school123@localhost:5432/school_management?schema=public"
```

## 2. Backend API

```bash
cd backend
npm install
npx prisma migrate deploy
npm run db:seed
npm run start:dev
```

API: `http://localhost:3000/api`

### Demo logins

| Role    | Email               | Password  |
|---------|---------------------|-----------|
| Admin   | admin@school.demo   | Admin@123 |
| Teacher | teacher@school.demo | Admin@123 |
| Parent  | parent@school.demo  | Admin@123 |

### Demo data volume

- **~250 students** (configurable `SEED_STUDENT_COUNT`, max 300)
- **~48 classes** (grades 1–12, sections A–D)
- **~70 teachers**
- Attendance, marks, fees, announcements seeded
- **Class 9A** + **Aryan Kumar** linked to parent demo account

## 3. Flutter app

```bash
cd mobile
flutter pub get
flutter run
```

**Android emulator** API URL (default): `http://10.0.2.2:3000/api`

**Physical device** (same Wi‑Fi):

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000/api
```

## Features implemented

- Login with role selection (Admin / Teacher / Parent)
- **Admin**: Dashboard, Students, Teachers, Classes, More
- **Teacher**: Dashboard, Students (class roster), Reports
- **Parent**: Home, Attendance, Results, Fees, Profile
- JWT auth, role-based API guards
- Paginated student/teacher lists from live DB counts

## Reset demo data

```bash
cd backend
npx prisma migrate reset
```

This drops the DB, re-applies migrations, and runs the seed.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Can't reach database` | Start Postgres (`docker compose up -d`) |
| App cannot login | Ensure API is running on port 3000 |
| Emulator network | Use `10.0.2.2` not `localhost` |
