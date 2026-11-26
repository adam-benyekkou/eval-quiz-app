FROM node:24-alpine

WORKDIR /app

ENV NODE_ENV=production

# Correctifs publiés dans Alpine après la sortie de l'image de base
# (OpenSSL, musl, zlib). Sans effet sur la version de Node, compilée hors apk.
RUN apk upgrade --no-cache

# Dépendances d'abord : cette couche n'est reconstruite que si le lock change
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Code applicatif ensuite
COPY server.js ./

# npm et corepack ne servent qu'à l'installation : ils sont retirés de l'image
# d'exécution, ce qui supprime les CVE de leurs dépendances (tar, pacote, sigstore…).
# Le shell et node restent disponibles pour `docker exec -it <ctn> sh`.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
    /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /root/.npm

# Utilisateur non privilégié : uid/gid 1000 = compte « node » de l'image officielle.
# Forme numérique : résolvable par l'hôte et les orchestrateurs (DL3066).
USER 1000:1000

EXPOSE 3007

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3007/health"]

CMD ["node", "server.js"]
