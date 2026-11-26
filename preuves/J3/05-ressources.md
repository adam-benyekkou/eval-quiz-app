# J3 — Ressources Azure créées (sortie expurgée)

Date : 2026-11-26. Aucun identifiant d'abonnement, de tenant ou de jeton dans
ces sorties.

```console
$ az group show -n rg-quiz-eval \
    --query "{nom:name,emplacement:location,etat:properties.provisioningState}" -o table
Nom           Emplacement    Etat
------------  -------------  ---------
rg-quiz-eval  francecentral  Succeeded

$ az acr show -n acrquizevaladam \
    --query "{nom:name,sku:sku.name,admin:adminUserEnabled,loginServer:loginServer,emplacement:location,etat:provisioningState}" -o table
Nom              Sku    Admin    LoginServer                 Emplacement    Etat
---------------  -----  -------  --------------------------  -------------  ---------
acrquizevaladam  Basic  False    acrquizevaladam.azurecr.io  francecentral  Succeeded

$ az acr repository list -n acrquizevaladam -o table
Result
-------------
quiz-backend
quiz-frontend
```

Points vérifiés : resource group `Succeeded`, ACR en `Basic`, **admin user
désactivé** (`False`), deux dépôts publiés. Les tags sont dans
`02-deploy.md` (`70251de` pour les deux images).
