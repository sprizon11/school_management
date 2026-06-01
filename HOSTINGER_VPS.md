# Migrate to Hostinger VPS (After Demo)

Yes — demo on **Neon + Render/Railway** first, then move to **Hostinger VPS** for production.  
The Flutter app only needs a new API URL (`https://api.yourschool.com/api`).

---

## Architecture on VPS

```text
Flutter app  →  HTTPS (Nginx)  →  NestJS (PM2)  →  PostgreSQL (on VPS)
                  yourdomain.com      port 3000        localhost:5432
```

| Component | On VPS |
|-----------|--------|
| PostgreSQL | Same server (or Hostinger managed DB if offered) |
| NestJS API | Node.js + PM2 |
| HTTPS | Nginx + free Let's Encrypt SSL |
| Domain | Point `api.yourschool.com` → VPS IP |

---

## What you need from Hostinger

1. **VPS plan** (Ubuntu 22.04 recommended — 2 GB RAM minimum for Postgres + API)
2. **Domain** (optional but recommended): e.g. `yourschool.com`
3. **SSH access** (IP, root password or SSH key from Hostinger panel)

---

## Phase 1 — Demo (now)

- Database: Neon (free)
- API: Render / Railway (free)
- Flutter: `--dart-define=API_BASE_URL=https://demo-api.../api`

No VPS cost until you go live.

---

## Phase 2 — Production on Hostinger VPS

### Step 1: Connect to VPS

```bash
ssh root@YOUR_VPS_IP
```

### Step 2: Install software

```bash
apt update && apt upgrade -y
apt install -y curl git nginx postgresql postgresql-contrib

# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# PM2 (keeps API running after reboot)
npm install -g pm2
```

### Step 3: PostgreSQL on VPS

```bash
sudo -u postgres psql
```

```sql
CREATE USER school WITH PASSWORD 'YOUR_STRONG_PASSWORD';
CREATE DATABASE school_management OWNER school;
GRANT ALL PRIVILEGES ON DATABASE school_management TO school;
\q
```

### Step 4: Upload your project

**Option A — Git (recommended)**

```bash
cd /var/www
git clone https://github.com/YOUR_USER/school-management.git
cd school-management/backend
```

**Option B — ZIP from your PC**  
Upload `backend` folder via Hostinger File Manager or SFTP to `/var/www/school-management/backend`

### Step 5: Environment file

```bash
nano /var/www/school-management/backend/.env
```

```env
DATABASE_URL="postgresql://school:YOUR_STRONG_PASSWORD@localhost:5432/school_management?schema=public"
JWT_SECRET="generate-a-long-random-secret-32-chars-minimum"
JWT_EXPIRES_IN="7d"
PORT=3000
NODE_ENV=production
SEED_STUDENT_COUNT=250
```

### Step 6: Build and migrate

```bash
cd /var/www/school-management/backend
npm install
npx prisma generate
npm run build
npx prisma migrate deploy
npm run db:seed
```

For **real school data** later: skip seed and import your data, or use admin screens to add students.

### Step 7: Start API with PM2

```bash
pm2 start dist/main.js --name school-api
pm2 save
pm2 startup
```

Check:

```bash
curl http://localhost:3000/api/auth/login
```

### Step 8: Nginx + HTTPS

```bash
nano /etc/nginx/sites-available/school-api
```

```nginx
server {
    listen 80;
    server_name api.yourschool.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/school-api /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

apt install -y certbot python3-certbot-nginx
certbot --nginx -d api.yourschool.com
```

API URL: `https://api.yourschool.com/api`

### Step 9: DNS (Hostinger)

In **Hostinger → DNS**:

| Type | Name | Value |
|------|------|--------|
| A | api | YOUR_VPS_IP |

Wait 5–30 minutes for DNS.

### Step 10: Update Flutter app

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourschool.com/api
```

Rebuild and redistribute APK (or Play Store update).

---

## Migrate data from demo (Neon) to VPS

If demo already has data you want to keep:

**On your PC** (with `pg_dump` installed, or use Neon console export):

```bash
# Export from Neon
pg_dump "YOUR_NEON_CONNECTION_STRING" > backup.sql

# Import on VPS
psql "postgresql://school:PASSWORD@YOUR_VPS_IP:5432/school_management" < backup.sql
```

Or start fresh on VPS with `npm run db:seed` for empty production + real data entry.

---

## Firewall (important)

```bash
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable
```

Do **not** expose PostgreSQL port 5432 to the internet — only `localhost`.

---

## Updates after code changes

```bash
cd /var/www/school-management/backend
git pull
npm install
npm run build
npx prisma migrate deploy
pm2 restart school-api
```

---

## Demo vs Hostinger comparison

| | Demo (Neon + Render) | Hostinger VPS |
|---|----------------------|---------------|
| Cost | Free / low | Monthly VPS fee |
| Control | Limited | Full server control |
| Best for | Testing, demo | Real school production |
| SSL | Automatic | Let's Encrypt (free) |
| Scale | Platform limits | Upgrade VPS RAM/CPU |

---

## Checklist before going live on VPS

- [ ] Change all demo passwords; remove seed demo accounts if not needed
- [ ] Strong `JWT_SECRET` and DB password
- [ ] HTTPS working (`https://api.yourschool.com`)
- [ ] PM2 running + `pm2 startup` done
- [ ] Backups: schedule `pg_dump` daily (cron)
- [ ] Flutter APK built with production API URL

---

## Support

Hostinger VPS docs: https://www.hostinger.com/tutorials/vps  
If you get a specific Hostinger OS image (CyberPanel, etc.), say which one and steps can be adjusted.
