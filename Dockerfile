# Étape 1 — build statique Vite
FROM node:24-alpine AS build

WORKDIR /app

# Dépendances d'abord : cache préservé tant que le lock ne change pas
COPY package.json package-lock.json ./
RUN npm ci

# Code source ensuite (build multi-pages : index.html + gestion-quiz.html)
COPY . .
RUN npm run build

# Étape 2 — serveur Nginx non-root
FROM nginxinc/nginx-unprivileged:alpine

# Correctifs publiés dans Alpine après la sortie de l'image de base
# (brotli, curl, libexpat, libxml2, libxslt, musl, zlib) : l'utilisateur de
# l'image est non-root, on repasse root le temps de la mise à jour.
USER 0:0
RUN apk upgrade --no-cache

# Modèle rendu par envsubst au démarrage (docker-entrypoint.d/20-envsubst-on-templates.sh)
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Valeurs par défaut, surchargées par Compose / Azure Container Apps
ENV BACKEND_SCHEME=http \
    BACKEND_HOST=backend \
    BACKEND_PORT=3007

COPY --from=build /app/dist /usr/share/nginx/html

# Défense en profondeur : l'image non-root tourne déjà en uid 101 (nginx),
# mais l'instruction explicite satisfait les contrôles statiques (Trivy DS-0002).
USER 101:101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/"]
