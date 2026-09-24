# Node 24: Active LTS (Node 22 is now Maintenance LTS). Alpine, not
# slim: no native (compiled) dependencies in package.json, so alpine's
# smaller footprint has no glibc-compatibility downside here.
# --- build stage ---
FROM node:24-alpine AS build
WORKDIR /app
RUN apk update && apk upgrade --no-cache
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# --- runtime stage ---
FROM node:24-alpine
WORKDIR /app
# Patches OS packages (e.g. openssl/libcrypto3/libssl3 CVEs) at build time
# regardless of how stale the node:24-alpine tag's last-published snapshot
# is - Trivy gates the push on CRITICAL/HIGH findings, so an unpatched
# base image blocks every build until upstream catches up otherwise.
RUN apk update && apk upgrade --no-cache
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# npm/npx/corepack are unused at runtime (only `node index.js` runs) -
# removing them drops their bundled node_modules entirely, which is
# where CVE findings kept turning up regardless of Node version.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
COPY --from=build /app /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "index.js"]
