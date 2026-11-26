FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production

# Dépendances d'abord : cette couche n'est reconstruite que si le lock change
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Code applicatif ensuite
COPY server.js ./

# Utilisateur non privilégié : uid/gid 1000 = compte « node » de l'image officielle.
# Forme numérique : résolvable par l'hôte et les orchestrateurs (DL3066).
USER 1000:1000

EXPOSE 3007

CMD ["node", "server.js"]
