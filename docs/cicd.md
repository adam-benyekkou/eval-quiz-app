# CI/CD — GitHub Actions (J6)

## Vue d'ensemble

| Workflow | Déclencheur | Rôle |
|---|---|---|
| `hadolint.yml` | `pull_request` → `main` | Lint de tous les Dockerfile |
| `trivy.yml` | `pull_request` → `main` | Scan du système de fichiers (vuln, secrets, misconfig), bloquant CRITICAL et HIGH |
| `ci.yml` | `pull_request` → `main` | Build des deux images, scan Trivy des images construites, bloquant CRITICAL |
| `cd.yml` | `push` → `main` | Build, scan, push dans l'ACR (tag SHA), mise à jour des Container Apps |

Les trois premiers ne se remplacent pas : le scan fichiers, le lint et le scan
d'images détectent des choses différentes. Seule la CD a accès à Azure.

## CI sur pull request (J6-A)

`ci.yml` n'a aucun secret (`permissions: contents: read`) et ne publie rien.

- `build-quiz-backend` / `build-quiz-frontend` : buildx, cache GHA, image
  exportée en archive pour le job suivant.
- `trivy-image-quiz-backend` / `trivy-image-quiz-frontend` : rapport JSON
  (CRITICAL + HIGH) conservé en artefact, puis étape **bloquante**
  `severity: CRITICAL`, `exit-code: 1`. Pas de `continue-on-error`.
- `ignore-unfixed: false` : un CRITICAL sans correctif publié bloque aussi, il
  est arbitré à la main plutôt que masqué. Contrepartie : une nouvelle CVE de
  l'image de base peut bloquer une PR sans que le code soit en cause ; on
  corrige alors par mise à jour de la base.

Contrôle du blocage : `preuves/J6/01-blocage-critical-local.txt` (même commande
que la CI ; `quiz-backend:baseline` → exit 1, images durcies → exit 0).

### Noms exacts des checks publiés

Relevés sur une exécution réelle (docs/04 B.5), pas devinés :

`build-quiz-backend`, `build-quiz-frontend`, `trivy-image-quiz-backend`,
`trivy-image-quiz-frontend`, `trivy`, `hadolint`.

(`Trivy` avec une majuscule est le contrôle créé par l'envoi SARIF vers l'onglet
Security ; il n'est pas exigé.)

## Protection de `main`

Dépôt public : la protection de branche est disponible sur le plan gratuit.
Règle sur `main` : pull request obligatoire avec une approbation, checks requis
ci-dessus, force-push et suppression interdits. Voir `preuves/J6/` pour l'état
relevé via l'API.

## CD après fusion (J6-B)

`cd.yml` ne se déclenche que sur `push` vers `main`. Aucune PR ne peut donc
atteindre les identifiants Azure.

### Authentification OIDC sans service principal

J0 a montré que la création de service principal est refusée
(`Insufficient privileges`). `scripts/setup-oidc.sh` utilise à la place une
**identité managée user-assigned** avec un **identifiant fédéré** GitHub :

- sujet exact : `repo:adam-benyekkou/eval-quiz-app:ref:refs/heads/main` ;
  un autre dépôt, une autre branche ou une PR ne peuvent pas obtenir de jeton ;
- rôles minimaux : `AcrPush` sur l'ACR, `Contributor` sur le seul resource group ;
- aucun mot de passe : GitHub échange un jeton OIDC court contre un jeton Azure ;
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` sont des secrets
  GitHub (masqués dans les logs). Ce ne sont pas des credentials, mais autant ne
  pas publier l'abonnement.

N'utiliser ni `environment:` ni un autre déclencheur dans `cd.yml` sans mettre à
jour le sujet fédéré : il changerait.

### Déroulé

1. Tag = SHA court du commit fusionné (`${GITHUB_SHA::7}`), jamais `latest`.
2. Build des deux images et **scan Trivy CRITICAL bloquant avant le push** : une
   image vulnérable n'atteint jamais l'ACR.
3. Push, puis digest de chaque image dans le résumé du job.
4. `az containerapp update` du backend puis du frontend : nouvelle révision.
5. Contrôle : liste des révisions et `GET /health` (200 attendu, sans SQL).

Choix **rebuild après fusion** plutôt que réutilisation de l'image de la PR : le
commit de fusion diffère de celui de la PR, et le tag SHA doit désigner le code
exact de `main`. Le coût est un second build, atténué par le cache.

### Retrouver la révision d'un commit

```bash
az containerapp show -n backend -g rg-quiz-eval \
  --query "properties.template.containers[0].image" -o tsv   # ...:<sha7>
git show <sha7>
```

## Limites

- `/health` ne prouve pas la base : il répond sans requête SQL.
- Environnement Container Apps « express » : voir `docs/deploiement-azure.md`.
- Une règle de protection affichée n'est une preuve que si un push direct ou
  une PR avec check en échec est effectivement refusé (voir `preuves/J6/`).
