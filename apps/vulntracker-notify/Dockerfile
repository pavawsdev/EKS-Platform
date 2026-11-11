# No production dependencies need native compilation - alpine's smaller
# footprint has no glibc-compatibility downside here, same choice as
# apps/backend/Dockerfile.
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
# Patches OS packages at build time regardless of how stale the node:24-alpine
# tag's last-published snapshot is - same reasoning as apps/backend/Dockerfile.
RUN apk update && apk upgrade --no-cache
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# npm/npx/corepack are unused at runtime (only `node src/index.js` runs)
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
COPY --from=build /app /app
USER appuser
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3001/health || exit 1
CMD ["node", "src/index.js"]
