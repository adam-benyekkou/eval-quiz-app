# Sécurité des images — Trivy avant / après (J2)

Ce document recense l'état de vulnérabilités des images livrées par J1, les corrections
retenues, puis les vulnérabilités résiduelles assumées. Il s'appuie uniquement sur des
sorties Trivy versionnées dans `preuves/J2/`.

## 1. Méthode

- Outil : Trivy **0.76.2**, exécuté dans le conteneur officiel `aquasec/trivy:latest`
  (pas d'installation sur l'hôte), avec un cache de base CVE partagé
  (`docker volume trivy-cache`).
- Base CVE : `mirror.gcr.io/aquasec/trivy-db` (mise à jour téléchargée le 2026-11-26,
  visible dans les logs de scan).
- Périmètre des scans d'image : `CRITICAL,HIGH,MEDIUM` ; secrets et misconfigurations
  scannés séparément.
- Images « avant » construites depuis l'état J1 (commit `456077a`, branche `main`) :
  `quiz-backend:baseline` et `quiz-frontend:baseline`, **sans aucune correction**.

Commandes reproductibles (depuis la racine du dépôt) :

```bash
docker build -t quiz-backend:baseline backend
docker build -t quiz-frontend:baseline .

# Vulnérabilités (table + JSON)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH,MEDIUM \
  --format table quiz-backend:baseline > preuves/J2/trivy-avant-backend.txt
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH,MEDIUM \
  --format json quiz-backend:baseline > preuves/J2/trivy-avant-backend.json
# idem quiz-frontend:baseline -> preuves/J2/trivy-avant-frontend.{txt,json}

# Configuration (Dockerfiles)
docker run --rm -v "$PWD":/src aquasec/trivy:latest config --severity CRITICAL,HIGH,MEDIUM,LOW /src \
  > preuves/J2/trivy-config-avant.txt

# Secrets (dépôt)
docker run --rm -v "$PWD":/src -w /src aquasec/trivy:latest \
  fs --scanners secret --skip-dirs node_modules --skip-dirs .git . \
  > preuves/J2/trivy-secret-avant.txt
```

## 2. Résultats avant durcissement (images J1)

| Image | Base | Cible Trivy | CRITICAL | HIGH | MEDIUM | Total |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `quiz-backend:baseline` | `node:20-alpine` (Node 20.20.2, Alpine 3.23.4) | paquets Alpine | 0 | 7 | 21 | 28 |
| `quiz-backend:baseline` | idem | npm embarqué (`/usr/local/lib/node_modules/npm`, npm 10.8.2) | 1 | 21 | 16 | 38 |
| **backend (total)** | | | **1** | **28** | **37** | **66** |
| `quiz-frontend:baseline` | `nginxinc/nginx-unprivileged:alpine` (nginx 1.31.7, Alpine 3.24.2) | paquets Alpine | 1 | 13 | 13 | 27 |

### 2.1 Origine des paquets vulnérables

- **Backend — paquets Alpine** : `openssl` (`libcrypto3`, `libssl3`), `musl`, `zlib`.
  Ce sont les bibliothèques de l'image de base `node:20-alpine`, liées à l'exécution de
  Node (TLS, libc, compression).
- **Backend — paquets npm** : `tar`, `pacote`, `sigstore`, `glob`, `minimatch`,
  `brace-expansion`, `cross-spawn`, `ip-address`, `@sigstore/core`,
  `postcss-selector-parser`. Ils appartiennent au **npm embarqué dans l'image Node**
  (`/usr/local/lib/node_modules/npm/node_modules/...`), pas aux dépendances applicatives.
  Vérifié dans l'image : pour les paquets présents des deux côtés, la copie de `/app` est
  déjà à une version corrigée, seule celle de npm est vulnérable.

  | Paquet | Version dans `/app` (dépendances de l'app) | Version dans npm (vulnérable) |
  | --- | --- | --- |
  | `tar` | absent | 6.2.1 |
  | `pacote` | absent | 18.0.6 |
  | `sigstore` | absent | 2.3.1 |
  | `ip-address` | absent | 9.0.5 |
  | `brace-expansion` | 2.1.8 (corrigée) | 2.0.1 |
  | `minimatch` | 9.0.9 (corrigée) | 9.0.5 |
  | `glob` | 10.5.0 (corrigée) | 10.4.2 |
  | `cross-spawn` | 7.0.6 (corrigée) | 7.0.3 |

- **Frontend — paquets Alpine** : `brotli-libs`, `curl`/`libcurl`, `libexpat`,
  `libxml2`, `libxslt`, `musl`/`musl-utils`, `zlib`. Tous proviennent de l'image
  `nginx-unprivileged`. `nginx -V` confirme qu'aucun module `brotli` ni `xslt` n'est
  compilé : ces bibliothèques sont présentes dans l'image mais pas chargées par Nginx.

### 2.2 CRITICAL et HIGH — pertinence à l'exécution

**Backend — paquets Alpine**

| Paquet | CVE | Sév. | Versions | Pertinence pour cette application |
| --- | --- | --- | --- | --- |
| `libcrypto3`, `libssl3` | CVE-2026-14456 | HIGH | 3.5.6-r0 → 3.5.8-r0 | DoS QUIC : Node 20 n'expose pas QUIC. Bibliothèque chargée à l'exécution (TLS sortant vers Resend) → **corriger par mise à jour**, pas d'exploitation directe connue. |
| `libcrypto3`, `libssl3` | CVE-2026-45447 | HIGH | 3.5.6-r0 → 3.5.7-r0 | UAF dans `PKCS7_verify()` : non appelé par Node ni par l'application. Bibliothèque à l'exécution → **corriger**. |
| `musl`, `musl-utils` | CVE-2026-107891 | HIGH | 1.2.5-r23 → 1.2.5-r24 | Débordement dans `regcomp` ; l'application ne compile aucune expression régulière fournie par l'utilisateur (routes et validation statiques dans `backend/server.js`) → non atteignable, **corriger** car libc commune. |
| `zlib` | CVE-2026-85091 | HIGH | 1.3.2-r0 → 1.3.2-r1 | Débordement dans `gz_vacate()` ; l'API n'accepte que du JSON, aucune décompression gzip de données client → non atteignable, **corriger**. |

**Backend — npm embarqué** (aucun de ces chemins n'est appelé par `node server.js`)

| Paquet | CVE | Sév. | Pertinence |
| --- | --- | --- | --- |
| `tar` | CVE-2026-59873 | CRITICAL | Gzip bomb dans l'extraction d'archives. `tar` n'est utilisé que par le CLI npm (`npm install/pack`), jamais par le processus applicatif. **Non exploitable en exécution** ; supprimé en retirant npm de l'image finale. |
| `tar` | CVE-2026-23745, -23950, -24842, -26960, -29786, -31802 | HIGH | Écriture/lecture arbitraire de fichiers via archives malveillantes. Même chemin : CLI npm uniquement, non atteignable par les routes HTTP. |
| `tar` | CVE-2026-59874, -73566 | HIGH | DoS via archives malformées, même chemin npm. |
| `pacote` | CVE-2026-9496 | HIGH | DoS via `spec.rawSpec` ; résolution de paquets npm, jamais appelée à l'exécution. |
| `sigstore` | CVE-2026-48815 | HIGH | Vérification de signatures npm ; non appelée à l'exécution. |
| `glob` | CVE-2025-64756 | HIGH | Injection de commande via noms de fichiers ; utilisé par les commandes npm (`npm pack`, scripts), pas par l'app. |
| `minimatch` | CVE-2026-26996, -27903, -27904 | HIGH | DoS par motifs glob ; npm uniquement. |
| `brace-expansion` | CVE-2026-102276, -102278, -13149, -14257, -69152 | HIGH | DoS par expansion d'accolades ; npm uniquement (la copie de `/app` est en 2.1.8, corrigée). |
| `cross-spawn` | CVE-2024-21538 | HIGH | ReDoS ; npm uniquement (la copie de `/app` est en 7.0.6, corrigée). |
| `ip-address` | CVE-2026-69192 | HIGH | SSRF par parsing IP incohérent ; npm uniquement. |

**Frontend — paquets Alpine**

| Paquet | CVE | Sév. | Pertinence pour ce conteneur |
| --- | --- | --- | --- |
| `brotli-libs` | CVE-2026-111497 | CRITICAL | Écriture hors bornes dans le **décodeur** Brotli. Nginx ne décode pas de flux Brotli entrants (module non compilé, `nginx -V`), il sert des fichiers statiques → non atteignable, mais **aucun CRITICAL n'est toléré** : corrigé par mise à jour Alpine. |
| `curl`, `libcurl` | CVE-2026-92392 | HIGH | UAF HTTP/2 à l'upload ; Nginx n'utilise pas libcurl, le binaire `curl` n'est qu'un outil de diagnostic. Non atteignable par HTTP. |
| `libexpat` | CVE-2026-113351, -115506, -117610, -118370 | HIGH | DoS XML ; aucun parsing XML (module XSLT absent). Non atteignable. |
| `libxml2` | CVE-2026-86144 | HIGH | SSRF/DoS XML ; module XSLT absent, non atteignable. |
| `libxslt` | CVE-2026-125350, -87636, -9947 | HIGH | UAF/type confusion XSLT ; module non compilé, non atteignable. |
| `musl`, `musl-utils` | CVE-2026-107891 | HIGH | `regcomp` : Nginx compile des regex de configuration fixes, pas d'entrée utilisateur → non atteignable, corrigé car libc. |
| `zlib` | CVE-2026-85091 | HIGH | `gz_vacate()` : Nginx compresse (`gzip`) mais ne décompresse pas de contenu client → non atteignable, corrigé. |

**Conclusion de l'analyse avant** : aucun CRITICAL/HIGH n'est directement exploitable via
les surfaces HTTP de l'application ; les findings npm sont des outils de build embarqués
par l'image Node. Ils restent néanmoins dans l'image livrée et seraient trouvés par un
scanner d'infrastructure : ils sont corrigés, pas ignorés.

### 2.3 Scan de configuration

`preuves/J2/trivy-config-avant.txt` : 0 CRITICAL/HIGH/MEDIUM, 1 LOW par Dockerfile
(`DS-0026` : pas de `HEALTHCHECK`). Aucune misconfiguration grave ; détail du traitement
en section 3.

### 2.4 Scan de secrets

`preuves/J2/trivy-secret-avant.txt` / `.json` : aucun secret détecté dans le dépôt
(`node_modules` et `.git` exclus). Contrôle positif effectué avec un jeton GitHub et une
clé Stripe factices dans un répertoire temporaire : les deux sont détectés, donc le scan
n'est pas silencieusement inopérant. Les secrets réels restent hors du dépôt (`.env`
ignoré, vérifié en J1).

## 3. Durcissement appliqué

_(section complétée dans la branche `feature/j2-hardening`)_
