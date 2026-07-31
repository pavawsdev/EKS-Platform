# --- build stage ---
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
# npm install, not npm ci - see frontend-ci.yml for why
RUN npm install
COPY . .
RUN npm run build

# --- runtime stage ---
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/ || exit 1
