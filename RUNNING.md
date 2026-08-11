# Running Solmove for real (end-to-end)

This guide takes you from an empty machine to the **native iOS app running
against the live backend** — not demo mode. It ties together the two repos:

- **`solmove-api`** — Node + TypeScript + Fastify + Prisma + PostgreSQL backend
- **`solmove-ios`** — SwiftUI iOS app (this repo)

> **Demo mode vs. real mode.** On the login screen, **Continue in demo mode**
> runs the app entirely offline with bundled seed data (no backend needed).
> **Logging in** (or **Sign up**) talks to the live API — that is "real mode".
> This guide sets up real mode.

---

## 0. Prerequisites

| Tool | Version | Install |
| ---- | ------- | ------- |
| macOS + Xcode | 26+ (iOS 17 target) | App Store |
| Node.js | ≥ 20 | `brew install node` |
| PostgreSQL | 14+ | `brew install postgresql@16` (or Docker) |
| XcodeGen | latest | `brew install xcodegen` |
| Docker Desktop | optional | for the zero-setup Postgres path |

Both repos should live side by side (the app's default API URL assumes this):

```
~/Downloads/
├── solmove-api/
└── solmove-ios/
```

---

## 1. Start the backend

### Option A — local PostgreSQL (what this project was verified with)

```bash
# 1. Start Postgres
brew services start postgresql@16
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

# 2. Create the role + database (one time)
createuser -s solmove 2>/dev/null || true
psql -d postgres -c "ALTER USER solmove WITH PASSWORD 'solmove';"
createdb -O solmove solmove 2>/dev/null || true

# 3. Configure + boot the API
cd ~/Downloads/solmove-api
cp .env.example .env                       # then set JWT_SECRET (see below)
# .env DATABASE_URL:
#   postgresql://solmove:solmove@localhost:5432/solmove?schema=public

npm install
npm run prisma:generate
npm run prisma:migrate                      # creates all tables (name it "init")
npm run db:seed                             # loads demo studios/instructors/member
npm run dev                                 # → http://localhost:4000
```

Generate a strong secret for `.env`:

```bash
echo "JWT_SECRET=$(openssl rand -hex 48)" >> .env
```

### Option B — Docker (zero Postgres setup)

```bash
cd ~/Downloads/solmove-api
cp .env.example .env
docker compose up -d db                     # Postgres on :5432
npm install && npm run prisma:generate
npm run prisma:migrate && npm run db:seed
npm run dev
```

Or run the **whole stack** in Docker:

```bash
JWT_SECRET=$(openssl rand -hex 48) docker compose up --build
docker compose exec api npx tsx prisma/seed.ts   # seed once
```

### Verify the API is up

```bash
curl localhost:4000/health
# {"status":"ok","time":"..."}

curl -s localhost:4000/api/v1/auth/login -H 'content-type: application/json' \
  -d '{"email":"member@solmove.app","password":"solmove123"}'
# {"token":"ey...","user":{...}}
```

> **Payments** run in **mock mode** with no Stripe keys — no account needed for
> local development. Set `STRIPE_SECRET_KEY` only when you want real charges.

---

## 2. Point the app at the backend

The app reads its base URL from **`Sources/APIClient.swift`**:

```swift
var baseURL = URL(string: "http://localhost:4000/api/v1")!
```

| Where you run the app | Set `baseURL` to |
| --------------------- | ---------------- |
| **iOS Simulator** (same Mac) | `http://localhost:4000/api/v1` (default — works as-is) |
| **Physical iPhone** on the same Wi‑Fi | `http://<your-mac-LAN-IP>:4000/api/v1` |
| **Deployed backend** | `https://api.yourdomain.com/api/v1` |

Find your Mac's LAN IP:

```bash
ipconfig getifaddr en0        # e.g. 192.168.1.42
```

Then set, e.g., `http://192.168.1.42:4000/api/v1`.

> **App Transport Security is already configured** for local dev in
> `project.yml` (`NSAllowsLocalNetworking` + a `localhost` HTTP exception), so
> cleartext HTTP to your Mac/LAN works during development. A production build
> should use **HTTPS**, at which point no exception is needed.

---

## 3. Build & run the app

```bash
cd ~/Downloads/solmove-ios
xcodegen generate                 # regenerates Solmove.xcodeproj (git-ignored)
open Solmove.xcodeproj            # ⌘R to run on a simulator or device
```

Command-line build for a simulator:

```bash
xcodebuild -project Solmove.xcodeproj -scheme Solmove \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

> Run `xcodegen generate` again any time you add/rename source files or change
> `project.yml` (Info.plist keys live there — editing `Sources/Info.plist`
> directly gets overwritten on the next generate).

---

## 4. Log in (real mode)

On the login screen, either **Sign up** a new account (pick Member / Studio /
Instructor) or use a seeded demo account — all with password **`solmove123`**:

| Email | Role | What you'll see |
| ----- | ---- | --------------- |
| `member@solmove.app` | Member | Home, discovery, live class booking |
| `studio@solmove.app` | Studio | Your classes, sub-shifts, economics |
| `maya@solmove.app` | Instructor | Gamified XP, leaderboard, sub-shifts |

After login the app calls `/auth/me`, resolves your persona (managed studio or
instructor id), and loads **live** studios, instructors, classes and messages.
Booking a class, claiming a sub-shift, rating, and messaging all POST to the API
— watch the `npm run dev` logs to see the requests land.

---

## 5. Reset / seed data

```bash
cd ~/Downloads/solmove-api
npm run db:reset        # drop + re-migrate + re-seed (fresh demo data)
npm run prisma:studio   # browse/edit the DB in a GUI
```

---

## 6. Going to production

**Backend**
- Provision managed Postgres (RDS / Cloud SQL / Neon) and set `DATABASE_URL`.
- Set a strong `JWT_SECRET` and real `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET`.
- Deploy the container (`Dockerfile` provided) to Fly.io / Render / ECS / Cloud Run.
- Apply migrations with `npm run prisma:deploy` (not `migrate dev`) in CI/CD.
- Terminate TLS in front of the API and restrict `CORS_ORIGIN` to your domains.

**iOS app**
- Set `baseURL` to your `https://…` API and remove the ATS localhost exception
  from `project.yml` (HTTPS needs no exception).
- Set a real Team / signing identity in Xcode, bump `MARKETING_VERSION`, archive,
  and upload to TestFlight / App Store Connect.

---

## 7. Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Login spins / "Could not connect" | Backend not running — `curl localhost:4000/health`. On device, use your **LAN IP**, not `localhost`. |
| Works on simulator, fails on device | Same Wi‑Fi? Mac firewall allowing port 4000? `baseURL` set to LAN IP? |
| `prisma generate` didn't run on install | Postinstall may be blocked — run `npm run prisma:generate` manually. |
| Map "locate me" does nothing | Location permission — the usage string lives in `project.yml`; re-run `xcodegen generate`. |
| Can't scroll in the Simulator | Click-and-drag or two-finger swipe — mouse-wheel flicks don't register (not a bug). |
| Ports busy | `lsof -ti:4000` then `kill <pid>`; Postgres on 5432. |

See [`solmove-api/README.md`](../solmove-api/README.md) for the full API
reference and data model.
