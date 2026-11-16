# syntax=docker/dockerfile:1

# ---- deps: install npm dependencies reproducibly from the lockfile ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- builder: compile the app with standalone output ----
FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
# NOTE: `next/font` downloads Google Fonts at build time; the builder
# needs outbound HTTPS access to fonts.googleapis.com / fonts.gstatic.com.
RUN npm run build \
 && test -d .next/standalone \
 || { echo 'ERROR: .next/standalone not produced - add `output: "standalone"` to next.config.ts' >&2; exit 1; }

# ---- runner: minimal production image running the standalone server ----
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs

# Static assets are not copied into .next/standalone by default
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
