# Étape 1 — build statique Vite
FROM node:20-alpine AS build

WORKDIR /app

# Dépendances d'abord : cache préservé tant que le lock ne change pas
COPY package.json package-lock.json ./
RUN npm ci

# Code source ensuite (build multi-pages : index.html + gestion-quiz.html)
COPY . .
RUN npm run build

# Étape 2 — serveur Nginx non-root
FROM nginxinc/nginx-unprivileged:alpine

# Modèle rendu par envsubst au démarrage (docker-entrypoint.d/20-envsubst-on-templates.sh)
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Valeurs par défaut, surchargées par Compose / Azure Container Apps
ENV BACKEND_HOST=backend \
    BACKEND_PORT=3007

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
