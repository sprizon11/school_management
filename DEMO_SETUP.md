# Demo setup (cloud only — ~20 minutes)

No Docker. No local PostgreSQL. No local API.

---

## Checklist

- [ ] **Step 1** — Neon database (5 min)
- [ ] **Step 2** — Push code to GitHub (5 min)
- [ ] **Step 3** — Deploy API on Render (10 min)
- [ ] **Step 4** — Seed demo data (2 min)
- [ ] **Step 5** — Run Flutter app with cloud URL (2 min)

---

## Step 1 — Neon (database)

1. Open https://neon.tech → Sign up (free).
2. **New project** → name: `school-demo`.
3. **Connection string** → copy **Pooled** or **Direct** URL.  
   Must end with `?sslmode=require` (add it if missing).

Example:

```text
postgresql://user:password@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

Save as `NEON_URL` — you need it in Steps 3 and 4.

---

## Step 2 — GitHub

In PowerShell:

```powershell
cd "d:\school management"
git init
git add .
git commit -m "Smart School demo - initial"
```

Create empty repo on https://github.com/new (name: `school-management`), then:

```powershell
git remote add origin https://github.com/YOUR_USERNAME/school-management.git
git branch -M main
git push -u origin main
```

---

## Step 3 — Render (API)

1. https://render.com → Sign up → connect GitHub.
2. **New +** → **Web Service** → select `school-management` repo.
3. Settings:

| Field | Value |
|-------|--------|
| Name | `school-api-demo` |
| Root Directory | `backend` |
| Runtime | Node |
| Build Command | `npm install && npx prisma generate && npm run build` |
| Start Command | `npx prisma migrate deploy && npm run start:prod` |
| Instance type | Free |

4. **Environment** → Add variables:

| Key | Value |
|-----|--------|
| `DATABASE_URL` | Your Neon URL |
| `JWT_SECRET` | Any long random string (e.g. 64 chars) |
| `JWT_EXPIRES_IN` | `7d` |
| `NODE_ENV` | `production` |

5. **Create Web Service** → wait until **Live** (green).
6. Copy your URL, e.g. `https://school-api-demo.onrender.com`

**API base for Flutter:**

```text
https://school-api-demo.onrender.com/api
```

> Free Render apps sleep after ~15 min idle. First request may take 30–60 seconds to wake up.

---

## Step 4 — Seed demo data (from your PC)

```powershell
cd "d:\school management"
$env:DATABASE_URL="PASTE_YOUR_NEON_URL_HERE"
.\scripts\seed-cloud.ps1
```

Creates ~250 students, classes, teachers, demo logins.

---

## Step 5 — Flutter app

Replace with your real Render URL:

```powershell
cd "d:\school management\mobile"
flutter pub get
flutter run --dart-define=API_BASE_URL=https://school-api-demo.onrender.com/api
```

**Build APK to share:**

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-RENDER-URL.onrender.com/api
```

APK: `mobile\build\app\outputs\flutter-apk\app-release.apk`

---

## Demo logins

| Role | Email | Password |
|------|--------|----------|
| Admin | admin@school.demo | Admin@123 |
| Teacher | teacher@school.demo | Admin@123 |
| Parent | parent@school.demo | Admin@123 |

Tap the matching **role card** on login, then **Login**.

---

## Test API (optional)

```powershell
curl -X POST https://YOUR-RENDER-URL.onrender.com/api/auth/login `
  -H "Content-Type: application/json" `
  -d "{\"identifier\":\"admin@school.demo\",\"password\":\"Admin@123\",\"expectedRole\":\"ADMIN\"}"
```

Should return JSON with `"accessToken"`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Render build fails | Root Directory must be `backend` |
| Database error on deploy | `DATABASE_URL` must include `?sslmode=require` |
| Login: cannot reach server | URL must be `https://...` and end with `/api` |
| Render 502 / slow | Free tier waking up — wait 60s and retry |
| Seed fails | Run Step 4 again with correct Neon URL |

---

## After demo → Hostinger VPS

See [HOSTINGER_VPS.md](HOSTINGER_VPS.md).
