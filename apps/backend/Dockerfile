# Node 22: Node 20 is past its LTS security-support window, 22 is in
# active LTS maintenance. Alpine, not slim: no native (compiled)
# dependencies in package.json, so alpine's smaller footprint has no
# glibc-compatibility downside here.
# --- build stage ---
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# --- runtime stage ---
FROM node:22-alpine
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build /app /app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["node", "index.js"]
