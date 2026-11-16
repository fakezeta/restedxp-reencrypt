# Deploying RestedXP Re-Encrypt on your own infrastructure

This app is a **fully client-side** Next.js tool: all crypto runs in the
visitor's browser and there is no database, no API, and no secrets. That
makes self-hosting simple — you are essentially serving one static-ish page
from a small Node process.

## What was added for deployment

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build → minimal production image (`output: "standalone"`) |
| `.dockerignore` | Keeps the build context small |
| `docker-compose.yml` | `app` (hardened Node container) + `caddy` (reverse proxy w/ auto-HTTPS) |
| `Caddyfile` | Proxy config; Option A = plain HTTP for testing, Option B = auto-HTTPS |
| `next.config.ts` | Modified: added `output: "standalone"` |

## Requirements

- Linux host (VM, VPS, home server) with **Docker Engine ≥ 24 + Compose v2**
  (`docker compose version` should print a version)
- Ports **80 and 443** free
- Optional: a domain with an A/AAAA record pointing at the host (for HTTPS)

## Step 1 — Get everything onto the host

```bash
git clone https://github.com/mkccl/restedxp-reencrypt.git
cd restedxp-reencrypt
```

(or copy this folder to the host, e.g. with `rsync`.)

## Step 2 — Choose HTTP vs HTTPS

Edit `Caddyfile`:

- **Testing / LAN:** leave the `:80 { ... }` block as-is. Done.
- **Public with TLS:** uncomment the `rxp.example.com` block, replace the
  hostname with your real DNS name, and comment out the `:80` block.
  Caddy will obtain and renew a Let's Encrypt certificate automatically —
  ports 80 and 443 must be reachable from the internet.

## Step 3 — Build and start

```bash
docker compose up -d --build
```

Check that it came up:

```bash
docker compose ps          # app should show "healthy"
docker compose logs -f app # build/server output
```

Then visit `http://<your-server-ip>/` (or `https://yourdomain.com/`).

> The **first build takes a few minutes** (npm ci + next build).
> **Note:** `next/font` downloads Google Fonts (Geist, Cinzel) during the
> build, so the machine running `docker compose build` needs HTTPS access
> to `fonts.googleapis.com` / `fonts.gstatic.com`.

## Step 4 — Updating

```bash
git pull
docker compose up -d --build
```

Old images can be pruned with `docker image prune -f`.

## Running without the included compose stack

If you already have a reverse proxy (nginx, Traefik…) and just want the app
container:

```bash
docker build -t restedxp-reencrypt .
docker run -d --name rxp -p 127.0.0.1:3000:3000 --restart unless-stopped \
  restedxp-reencrypt
```

Then point your existing proxy at `127.0.0.1:3000` (localhost only, since
the app itself has no TLS).

### Bare Node (no Docker at all)

```bash
# needs Node.js >= 20.9
npm ci
npm run build
npm start        # serves on :3000
```

Wrap it in a systemd unit or use `pm2` to keep it alive on boot.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Build fails at font import, error fetching Geist/Cinzel | No internet in build step — allow egress to Google Fonts, or remove the three `next/font` imports in `app/layout.tsx` and use system fonts |
| `docker compose ps` shows app restarting | `docker compose logs app` — most often a port conflict or OOM during build |
| Caddy can't get a certificate | DNS doesn't point at the host yet, or port 80/443 blocked by firewall/hosting provider |
| Page loads without styling/images | You opened the standalone server directly on `:3000` — static assets are served fine; check your proxy passes `Host` header (Caddy does by default) |
| Browser console shows 404 for `/_vercel/insights/...` | Expected on self-hosting — `@vercel/analytics` is Vercel-only and harmless. Remove the `<Analytics />` import/usage in `app/layout.tsx` to silence it |

## Security notes

- The `app` container runs as a non-root user (uid 1001), with all Linux
  capabilities dropped and a read-only root filesystem (only `/tmp` writable).
- The app never sees user data: uploaded guide files are processed entirely
  in the browser (JS in `lib/rxp-crypto.ts`), so the server can be kept on
  an internal network if you prefer.
- Treat the served guide files (`public/guide_*.txt`) as the author's
  copyrighted content — you may want to restrict who can reach this server
  (e.g. Caddy `basic_auth`, VPN, or firewall allowlist) rather than running
  a public instance.

## Alternate deployment: static export (no Node in production)

Because there is zero server-side logic, you can also serve the site as
plain static files: remove `<Analytics />` from `app/layout.tsx`, set
`output: "export"` in `next.config.ts`, run `next build`, and copy `out/`
to any web server. The Docker route above is the safer default because the
upstream repo may grow server features later, but static export is the
lightest option if you only ever need the re-encrypt page.
