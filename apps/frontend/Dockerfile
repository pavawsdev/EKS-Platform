# Node 24: Active LTS (Node 22 is now Maintenance LTS). Alpine, not
# slim: no native (compiled) dependencies in package.json, so alpine's
# smaller footprint has no glibc-compatibility downside here. (Runtime
# stage below is nginx, not node - this build stage's output gets
# discarded except /app/build.)
# --- build stage ---
FROM node:24-alpine AS build
WORKDIR /app
RUN apk update && apk upgrade --no-cache
COPY package*.json ./
# npm install, not npm ci - see frontend-ci.yml for why
RUN npm install
COPY . .
RUN npm run build

# --- runtime stage ---
FROM nginxinc/nginx-unprivileged:1.31-alpine
# Patches OS packages at build time regardless of how stale this tag's
# last-published snapshot is - see apps/backend/Dockerfile for why.
USER root
RUN apk update && apk upgrade --no-cache
USER 101
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/ || exit 1
