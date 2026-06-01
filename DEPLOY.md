# Deploy to Cloud (No Local Server)

You do **not** need Docker or PostgreSQL on your PC. Everything runs online.

---

## Overview

```
Flutter app (phone)  →  HTTPS  →  Railway API  →  Neon PostgreSQL
```

| Step | Service | Free tier |
|------|---------|-------------|
| 1 | [Neon](https://neon.tech) – database | Yes |
| 2 | [Railway](https://railway.app) – API | Yes (limited) |
| 3 | Build Flutter APK with cloud URL | — |

---

## Step 1: Cloud database (Neon) – 5 min

1. Go to https://neon.tech and sign up.
2. **New project** → name: `school-management`.
3. Open **Connection details** → copy the **connection string** (with password).
   - It looks like:  
     `postgresql://user:pass@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require`
4. Keep this safe — you will paste it into Railway.

**No Docker. No local install.**

---

## Step 2: Deploy API (Railway) – 10 min

### A. Push code to GitHub

1. Create a repo on GitHub.
2. Push your `school-management` folder (include `backend/`, `mobile/`, `docker-compose.yml` is optional).

### B. Deploy on Railway

1. https://railway.app → **Login with GitHub**.
2. **New Project** → **Deploy from GitHub repo** → select your repo.
3. Click the service → **Settings**:
   - **Root Directory:** `backend`
   - **Watch Paths:** `backend/**`
4. **Variables** tab → add:

| Variable | Value |
|----------|--------|
| `DATABASE_URL` | Your Neon connection string |
| `JWT_SECRET` | Long random string (32+ chars) |
| `JWT_EXPIRES_IN` | `7d` |
| `NODE_ENV` | `production` |
| `SEED_STUDENT_COUNT` | `250` |

5. **Settings** → **Networking** → **Generate Domain**  
   You get a URL like: `https://school-management-production.up.railway.app`

6. Wait until deploy is **Success**. API base URL:

```
https://YOUR-RAILWAY-DOMAIN.up.railway.app/api
```

### C. Seed demo data (one time, from your PC)

You only run this **once** against the cloud database (no local server):

```powershell
cd "d:\school management\backend"
$env:DATABASE_URL="postgresql://YOUR-NEON-URL-HERE"
npx prisma migrate deploy
npm run db:seed
```

Replace with your real Neon URL. This creates tables + demo users.

---

## Step 3: Connect Flutter app to cloud

### Run on phone/emulator

```powershell
cd "d:\school management\mobile"
flutter run --dart-define=API_BASE_URL=https://YOUR-RAILWAY-DOMAIN.up.railway.app/api
```

### Build APK for distribution

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-RAILWAY-DOMAIN.up.railway.app/api
```

APK path: `mobile\build\app\outputs\flutter-apk\app-release.apk`

Share this APK with users — they install it; no local server needed.

---

## Demo logins (after seed)

| Role | Email | Password |
|------|--------|----------|
| Admin | admin@school.demo | Admin@123 |
| Teacher | teacher@school.demo | Admin@123 |
| Parent | parent@school.demo | Admin@123 |

---

## Test API in browser

Open (should not crash; may show 404):

`https://YOUR-RAILWAY-DOMAIN.up.railway.app/api`

Login test with Postman or curl:

```powershell
curl -X POST https://YOUR-RAILWAY-DOMAIN.up.railway.app/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"identifier":"admin@school.demo","password":"Admin@123","expectedRole":"ADMIN"}'
```

You should get JSON with `accessToken`.

---

## Alternative: Render instead of Railway

1. https://render.com → **New Web Service** → connect GitHub repo.
2. **Root Directory:** `backend`
3. **Build:** `npm install && npx prisma generate && npm run build`
4. **Start:** `npx prisma migrate deploy && npm run start:prod`
5. Add same env vars as Railway.
6. Use Render URL in Flutter `--dart-define=API_BASE_URL=...`

---

## What you can stop doing locally

- No `docker compose`
- No local PostgreSQL
- No `npm run start:dev` for daily use (only optional for coding)

Your PC is only used to: edit code, run `flutter run` with cloud URL, and occasional `prisma migrate` / `seed`.

---

## Google Play (optional later)

1. `flutter build appbundle --dart-define=API_BASE_URL=https://your-api/api`
2. Upload to [Google Play Console](https://play.google.com/console)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Login: cannot reach server | Check `API_BASE_URL` uses `https://` and ends with `/api` |
| Railway build fails | Check **Root Directory** = `backend` |
| Database error | `DATABASE_URL` must include `?sslmode=require` for Neon |
| Empty app data | Run `npm run db:seed` with cloud `DATABASE_URL` |
