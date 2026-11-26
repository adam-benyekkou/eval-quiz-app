# J3 — `deploy.sh` exécuté deux fois sans échec

Date : 2026-11-26. Branche `feature/j3-azure-scripts`.

Le tag est dérivé du commit :

```console
$ git rev-parse --short HEAD
70251de
```

## Exécution A — 13:03:15 → 13:03:52, code de sortie 0

```console
$ bash scripts/deploy.sh
[13:03:15] Cible : RG=rg-quiz-eval LOCATION=francecentral ACR=acrquizevaladam TAG=70251de
[13:03:15] Création/vérification du resource group rg-quiz-eval (francecentral)
[13:03:19] OK resource group rg-quiz-eval
[13:03:19] Création/vérification de l'ACR acrquizevaladam (sku Basic, admin user désactivé)
[13:03:22] OK ACR acrquizevaladam (acrquizevaladam.azurecr.io)
[13:03:22] Build local : quiz-backend:local (contexte backend/)
...
[13:03:24] Build local : quiz-frontend:local (contexte racine)
...
[13:03:26] Connexion Docker à acrquizevaladam.azurecr.io (jeton Azure AD, pas de mot de passe)
Login Succeeded
[13:03:35] Tag et push acrquizevaladam.azurecr.io/quiz-backend:70251de
...
70251de: digest: sha256:52926f4766daf677505ab6df51aec055195249bf9b4eae2e09aca5b070a5a06e size: 856
[13:03:38] Tag et push acrquizevaladam.azurecr.io/quiz-frontend:70251de
...
70251de: digest: sha256:95b9749d54f77d26c0b43c30549a352faa924bf5430ff0ecc07eafb23634f241 size: 856
[13:03:40] Dépôts présents dans acrquizevaladam :
Result
-------------
quiz-backend
quiz-frontend
[13:03:43] Tags de quiz-backend :
Result
--------
70251de
62366af
[13:03:47] Tags de quiz-frontend :
Result
--------
70251de
62366af
[13:03:52] Terminé. Images publiées : acrquizevaladam.azurecr.io/quiz-backend:70251de et acrquizevaladam.azurecr.io/quiz-frontend:70251de
$ echo $?
0
```

## Exécution B — 13:05:02 → 13:05:32, code de sortie 0

Même commande, immédiatement après l'exécution A :

```console
[13:05:02] Cible : RG=rg-quiz-eval LOCATION=francecentral ACR=acrquizevaladam TAG=70251de
[13:05:05] OK resource group rg-quiz-eval
[13:05:08] OK ACR acrquizevaladam (acrquizevaladam.azurecr.io)
...
[13:05:12] Connexion Docker à acrquizevaladam.azurecr.io (jeton Azure AD, pas de mot de passe)
Login Succeeded
[13:05:16] Tag et push acrquizevaladam.azurecr.io/quiz-backend:70251de
...
70251de: digest: sha256:0d335c3f19bd8c2f043b9366ec7226fe708ab02946870fc44f614d4c473d2fd7 size: 856
[13:05:18] Tag et push acrquizevaladam.azurecr.io/quiz-frontend:70251de
...
70251de: digest: sha256:65fb824e59ec96c0b4bd2c2037a338da76edd706d8e67dd1630b1f9c374abc46 size: 856
[13:05:22] Dépôts présents dans acrquizevaladam :
quiz-backend
quiz-frontend
[13:05:26] Tags de quiz-backend : 70251de, 62366af
[13:05:29] Tags de quiz-frontend : 70251de, 62366af
[13:05:32] Terminé. Images publiées : acrquizevaladam.azurecr.io/quiz-backend:70251de et acrquizevaladam.azurecr.io/quiz-frontend:70251de
$ echo $?
0
```

## Verdict

Deux exécutions consécutives réussissent sans intervention : le resource
group et l'ACR existants sont réutilisés, les images sont reconstruites depuis
le cache, puis repoussées sous le même tag `70251de`. Les couches déjà
présentes affichent `Layer already exists` ; seules les attestations de build
changent de digest, ce qui est attendu.

### Incident réseau transitoire (sans effet sur l'idempotence)

Entre les deux exécutions retenues, un essai (13:02:57) a échoué au push sur :

```text
dial tcp: lookup acrquizevaladam.azurecr.io: Temporary failure in name resolution
```

Diagnostic : `getent hosts acrquizevaladam.azurecr.io` résolvait bien
(`20.43.46.65`) et un conteneur `alpine` également. La relance immédiate a
réussi, sans modification des scripts. Cause retenue : résolution DNS
transitoire côté démon Docker/hôte, pas un défaut du script. Risque résiduel
documenté dans `docs/deploiement-azure.md`.

Tag `62366af` : première publication effectuée avant le commit des scripts
(commit J2). Il reste dans le registre ; `70251de` est le tag du commit qui
contient `scripts/`.
