# Déploiement Azure — J3 (resource group, ACR, images)

Ce document couvre le périmètre **J3** : création du resource group et du
registre Azure Container Registry (ACR), puis publication des images du
frontend et du backend avec un tag traçable. Les Container Apps, PostgreSQL
cloud et le déploiement automatisé sont traités en J4, J5 et J6.

## Prérequis

| Outil | Version / remarque |
|---|---|
| Azure CLI (`az`) | connecté à l'abonnement Azure for Students : `az login` puis `az account show` |
| Docker | démon accessible ; inutile avec `--acr-build` |
| Git | le tag d'image est dérivé du commit (`git rev-parse --short HEAD`) |
| Droits Azure | créer un resource group et un ACR (vérifié en J0) |
| Région | `francecentral` (région retenue en J0) |

Aucun secret n'est demandé ni stocké par les scripts : l'authentification
vient de la session `az` déjà ouverte, et les scripts ne lisent pas `.env`.

## Noms et paramètres

Tout est centralisé dans [`scripts/lib.sh`](../scripts/lib.sh), surchargeable
par variable d'environnement pour un test jetable :

| Variable | Valeur par défaut | Rôle |
|---|---|---|
| `RG` | `rg-quiz-eval` | resource group du projet |
| `LOCATION` | `francecentral` | région Azure |
| `ACR_NAME` | `acrquizevaladam` | nom global unique du registre |
| `ENV_NAME` | `cae-quiz-eval` | environnement Container Apps (J4) |
| `TAG` | `git rev-parse --short HEAD` | tag des images |

Le registre est en **sku Basic** et l'**admin user est désactivé** : les
identifiants d'administration ne sont ni créés ni utilisés. L'authentification
des agents (Container Apps en J4, GitHub Actions en J6) reposera sur une
identité managée / un rôle `AcrPull`, conformément au test J0.

## Commandes

```bash
# Build local des images, création RG + ACR, tag et push (mode par défaut)
./scripts/deploy.sh

# Rejouer sans reconstruire (images quiz-{backend,frontend}:local présentes)
./scripts/deploy.sh --skip-build

# Construire directement dans ACR, sans démon Docker local
./scripts/deploy.sh --acr-build
```

Déroulé du mode par défaut :

1. `az group create --name $RG --location $LOCATION`
2. `az acr create --name $ACR_NAME --resource-group $RG --sku Basic --admin-enabled false`
3. `docker build` des images `quiz-backend:local` et `quiz-frontend:local`
4. `az acr login --name $ACR_NAME` (jeton Azure AD, pas de mot de passe)
5. `docker tag` puis `docker push` vers
   `$ACR_NAME.azurecr.io/quiz-backend:$TAG` et `quiz-frontend:$TAG`
6. `az acr repository list` et `az acr repository show-tags` en preuve

### Idempotence

Relancer `deploy.sh` ne casse rien et ne duplique rien :

- `az group create` et `az acr create` convergent vers l'état voulu s'ils
  existent déjà (et réappliquent `--admin-enabled false`) ;
- le build réutilise le cache Docker ;
- le tag étant le SHA du commit, un second push du même contenu réutilise les
  couches déjà présentes dans le registre.

Le script a été exécuté deux fois de suite sans échec (voir
`preuves/J3/02-deploy.md`).

### Tag traçable

`TAG` vaut le SHA court du commit, jamais `latest` seul. Un tag `latest`
écraserait silencieusement la version précédente et rendrait impossible de
savoir quel code tourne. Le SHA permet de relier une image à un commit, ce qui
sera réutilisé en J6 pour publier l'image exacte validée par la CI.

## Vérifier les images publiées

```bash
az acr repository list -n acrquizevaladam -o table
az acr repository show-tags -n acrquizevaladam --repository quiz-backend -o table
az acr repository show-tags -n acrquizevaladam --repository quiz-frontend -o table
```

## `docker push` local ou `az acr build` ?

| Critère | Build local + push (défaut) | `az acr build` |
|---|---|---|
| Démon Docker | requis | non requis |
| Cache de build | local, immédiat | côté ACR, premier build plus lent |
| Images disponibles localement après coup | oui (utiles pour tester) | non |
| Reproductibilité CI | dépend de la machine | build exécuté par Azure |
| Coût | bande passante de push | tâche ACR (incluse dans Basic, durée limitée) |

Le mode local est le défaut car il laisse les images sur la machine pour les
tests de J1/J4. `--acr-build` est le repli sans Docker local (poste verrouillé,
CI). Il a été testé : **il est refusé sur cet abonnement Azure for Students**
par la politique de l'abonnement, avec l'erreur
`TasksOperationsNotAllowed` (les ACR Tasks ne sont pas autorisés). Le chemin
validé ici reste donc le build local suivi de `docker push`. L'option demeure
dans le script pour un abonnement où les ACR Tasks sont ouverts ; elle n'est
pas présentée comme validée sur ce compte. Voir
`preuves/J3/04-acr-build-refus.md`.

## Opérations sensibles

- **`destroy.sh` est destructif et irréversible.** Il supprime le resource
  group entier, donc l'ACR, toutes les images et (en J4) les Container Apps.
  Il exige la saisie manuelle du nom du groupe et n'accepte aucun argument
  permettant de cibler un autre groupe.
- **Admin user ACR** : laissé désactivé. Ne l'activer que si l'attribution
  `AcrPull` échoue, et le documenter ; ce n'est pas le cas (J0).
- **Secrets** : les scripts ne contiennent et n'affichent aucun secret. Les
  variables `POSTGRES_*`, `RESEND_API_KEY` et `JWT_SECRET` restent hors de ce
  périmètre et ne sont pas lues ici.
- **Sorties publiées** : les preuves sont expurgées ; pas d'ID d'abonnement,
  de tenant ni de jeton.

## Coûts et nettoyage

- ACR **Basic** : environ 5 USD/mois (quota de stockage inclus), facturé tant
  que le registre existe, même vide.
- Resource group vide : pas de coût en soi ; le stockage des images dans ACR
  est facturé.
- Les images poussées comptent dans le stockage ACR (quelques centaines de Mo
  pour ce projet).

Nettoyage complet :

```bash
./scripts/destroy.sh
# saisir exactement : rg-quiz-eval
az group show -n rg-quiz-eval   # doit répondre « not found » après suppression
```

La suppression est asynchrone (`--no-wait`) : vérifier ensuite que le groupe a
disparu. Le J4 a besoin de l'ACR : ne détruire qu'après validation du jalon et
conservation des preuves.

## Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `non connecté à Azure` | session `az` expirée | `az login` |
| `Login Succeeded` absent / 401 au push | `az acr login` a échoué | relancer `az acr login -n acrquizevaladam`, vérifier `az account show` |
| nom d'ACR déjà pris | les noms ACR sont uniques mondialement | changer `ACR_NAME` ou supprimer l'ancien registre |
| `az acr build` refuse (`TasksOperationsNotAllowed`) | ACR Tasks bloqués par l'abonnement (cas Azure for Students) | utiliser le mode local + `docker push` |
| `az acr build` refuse autrement | provider `Microsoft.ContainerRegistry` non enregistré | `az provider register --namespace Microsoft.ContainerRegistry` |
| `Temporary failure in name resolution` au push | DNS transient côté démon Docker/hôte | vérifier `getent hosts $ACR_NAME.azurecr.io`, relancer `deploy.sh` |
| build local très long | cache Docker vide | laisser le premier build se terminer, les suivants sont cachés |

## Références

- [J3 — plan](../plan/J3-azure-acr.md)
- [J0 — vérification Azure](../plan/J0-verification-azure.md)
- [Architecture locale](architecture-locale.md)
