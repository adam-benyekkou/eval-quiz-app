# Rapport d'améliorations — J2 (sécurité des images)

Ce rapport résume ce que le durcissement J2 a changé, avec les chiffres mesurés, les
compromis assumés et les limites. Le détail CVE par CVE reste dans
[`securite-trivy.md`](securite-trivy.md) ; les sorties brutes dans `preuves/J2/`.

## 1. Périmètre

- Images concernées : `quiz-backend` (Node/Express) et `quiz-frontend` (Nginx + build Vite).
- Aucun changement de logique métier : `backend/server.js`, `main.js`, les questionnaires,
  `package.json`/`package-lock.json` et le schéma SQL sont **inchangés**.
- Contrat conservé : port hôte 8087, routes `/`, `/gestion-quiz`, `/api/`, `/health`,
  variables d'environnement, volume `pgdata`.

## 2. Synthèse chiffrée

| Indicateur | Avant (J1) | Après (J2) | Écart |
| --- | ---: | ---: | ---: |
| Backend — CRITICAL | 1 | 0 | −1 |
| Backend — HIGH | 28 | 0 | −28 |
| Backend — MEDIUM | 37 | 2 | −35 |
| Backend — total | 66 | 2 | −64 (−97 %) |
| Frontend — CRITICAL | 1 | 0 | −1 |
| Frontend — HIGH | 13 | 0 | −13 |
| Frontend — MEDIUM | 13 | 0 | −13 |
| Frontend — total | 27 | 0 | −27 (−100 %) |
| CRITICAL/HIGH sur les deux images | 43 | 0 | −43 |
| Misconfigurations Dockerfile | 2 LOW | 0 | −2 |
| Secrets détectés | 0 | 0 | — |

Versions : Node 20.20.2 → **24.22.3** ; Alpine backend 3.23.4 → **3.24.4** ; npm 10.8.2
**retiré** de l'image d'exécution. Nginx reste 1.31.7, mais ses paquets Alpine passent aux
versions corrigées (brotli 1.2.1, curl 8.23, expat 2.11, musl 1.2.6-r3, zlib 1.4).

## 3. Améliorations techniques

| Axe | Changement | Gain |
| --- | --- | --- |
| Base backend | `node:20-alpine` → `node:24-alpine` | Node 20 n'est plus maintenu ; la base 24 ne porte que 6 HIGH contre 1 CRITICAL + 28 HIGH pour la 20. |
| Paquets Alpine | `apk upgrade --no-cache` dans les deux étapes finales | Supprime toutes les CVE Alpine disposant d'un correctif (OpenSSL, musl, zlib, brotli, curl, expat, libxml2, libxslt). |
| Outils de build | `npm`/`corepack` supprimés de l'image backend | Supprime les 38 findings npm (dont `tar` 6.2.1 CRITICAL), sans toucher aux dépendances de `/app`. `node` et le shell restent disponibles. |
| Hygiène Docker | `HEALTHCHECK` sur les deux images | Corrige `DS-0026`, état `healthy` lisible dans Compose. |
| Exécution | `read_only`, `tmpfs`, `cap_drop: [ALL]`, `no-new-privileges` sur backend et frontend | Aucune écriture dans l'image, aucune capability, pas d'élévation de privilèges. `db` reste inchangé (init PostgreSQL). |

## 4. Améliorations de la documentation et des preuves

| Livrable | Contenu ajouté |
| --- | --- |
| `docs/securite-trivy.md` | Méthode reproductible, tableau avant/après par cible, origine des paquets (Alpine vs npm embarqué), pertinence de chaque CRITICAL/HIGH, durcissement retenu/écarté, résiduelles, parcours rejoué. |
| `preuves/J2/01-baseline-scans.md` | Commandes, codes de sortie, tailles, provenance npm, contrôle positif du scanner de secrets. |
| `preuves/J2/02-hardening.md` | Comparaison des bases Node, builds `:fixed`, preuve de retrait de npm, rescan, lecture seule/capabilities, parcours J1 et persistance. |
| `preuves/J2/trivy-{avant,apres}-*.{txt,json}` | Sorties brutes table et JSON des quatre scans d'image. |
| `preuves/J2/trivy-config-{avant,apres}.txt`, `trivy-secret-avant.{txt,json}` | Preuves de configuration et de secrets. |
| `plan/J2-securite-images.md` | Cases cochées au fur et à mesure ; statut à jour. |

Chaque affirmation du rapport de sécurité renvoie à un fichier de preuve : aucune valeur
n'est reprise de mémoire.

## 5. Vérifications réalisées

| Commande | Résultat |
| --- | --- |
| `docker build` backend + frontend | exit 0 |
| `hadolint` sur `Dockerfile` et `backend/Dockerfile` | exit 0 |
| `docker compose config -q` | exit 0 |
| `trivy image` (CRITICAL,HIGH,MEDIUM) | 0 CRITICAL, 0 HIGH |
| `trivy config` | 0 finding |
| `docker compose ps` | backend/db/frontend `healthy` |
| `curl /`, `/gestion-quiz`, `/health` | 200, 200, 200 |
| Inscription + résultat | 201, 201 ; `quiz_results` = 3 |
| `docker compose down` puis `up` | count 3, `/health` 200 |
| `docker compose exec backend sh` | shell et Node fonctionnels |

## 6. Compromis et limites

- **2 MEDIUM résiduels** : `glob` 10.5.0 et `minimatch` 9.0.9, transitifs via
  `resend → @react-email/render → js-beautify`. Correction = montées majeures sans test
  automatisé du rendu email ; non atteignables via les routes HTTP. Documentés, pas masqués
  (aucun `.trivyignore`).
- **Taille** : +53 Mo (backend) et +19,6 Mo (frontend). La couche `apk upgrade` conserve les
  anciens fichiers de la couche de base ; le gain CVE a été jugé prioritaire.
- **Reproductibilité** : `apk upgrade` fige les paquets au moment du build, pas dans le
  Dockerfile. Deux builds à des dates différentes peuvent différer ; c'est le prix d'un
  correctif continu. Un rebuild régulier est préférable à un pin qui vieillit.
- **Shell conservé** : distroless/Chainguard écartés pour garder `docker exec -it <ctn> sh`
  en démonstration ; compromis explicite, pas une omission.
- **Périmètre** : le scan couvre l'image et la configuration, pas les dépendances du stage
  de build Vite (absentes de l'image livrée) ni le serveur PostgreSQL.

## 7. Références

- Plan : `plan/J2-securite-images.md`
- Rapport détaillé : `docs/securite-trivy.md`
- Preuves : `preuves/J2/`
- PR : #11 (baseline) et #12 (durcissement, empilée sur #11)
