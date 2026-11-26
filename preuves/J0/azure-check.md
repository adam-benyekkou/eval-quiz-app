# J0 — Vérification préalable Azure

Date : 2026-11-26
Branche : `feature/j0-azure-check`
Sorties expurgées : identifiants d'abonnement et de tenant remplacés par `<SUB_ID>` / `<TENANT_ID>`, UPN partiellement masqué.

## 1. Connexion et abonnement

```
$ az account show
{
  "environmentName": "AzureCloud",
  "homeTenantId": "<TENANT_ID>",
  "id": "<SUB_ID>",
  "isDefault": true,
  "name": "Azure for Students",
  "state": "Enabled",
  "tenantId": "<TENANT_ID>",
  "user": { "name": "par2611-****@supdevinci.education", "type": "user" }
}
```

Détail de l'offre :

```
$ az rest --method get --url "https://management.azure.com/subscriptions/<SUB_ID>?api-version=2022-12-01"
{
  "displayName": "Azure for Students",
  "promotions": [ { "category": "freetier", "endDateTime": "2027-11-24T08:58:06Z" } ],
  "state": "Enabled",
  "subscriptionPolicies": { "quotaId": "AzureForStudents_2018-01-01", "spendingLimit": "On" }
}
```

Crédits : le solde restant n'est pas exposé par l'API pour cette offre — `Microsoft.Consumption/balances` répond `404 Not Found` et `az consumption usage list` renvoie `PretaxCost: None`. Seul le coût réel est interrogeable :

```
$ az rest --method post --url ".../Microsoft.CostManagement/query?api-version=2023-11-01" \
    --body '{"type":"ActualCost","timeframe":"MonthToDate", ...}'
Cost (EUR) : 4.35907688985319   (mois en cours, ressources existantes incluses)
```

À retenir : date de fin de promotion `2027-11-24` ; `spendingLimit: On` (la consommation s'arrête au plafond) ; solde exact à lire dans le portail Azure. **Résultat : OK** (solde non exposé en CLI, documenté).

## 2. Resource providers

Avant :

```
$ az provider list --query "[?namespace=='Microsoft.ContainerRegistry' || namespace=='Microsoft.App' || namespace=='Microsoft.OperationalInsights'].{ns:namespace,state:registrationState}" -o table
Ns                             State
-----------------------------  -------------
Microsoft.App                  NotRegistered
Microsoft.ContainerRegistry    NotRegistered
Microsoft.OperationalInsights  NotRegistered
```

Enregistrement :

```
$ az provider register --namespace Microsoft.ContainerRegistry --wait
$ az provider register --namespace Microsoft.App --wait
$ az provider register --namespace Microsoft.OperationalInsights --wait
```

Après :

```
Ns                             State
-----------------------------  ----------
Microsoft.ContainerRegistry    Registered
Microsoft.OperationalInsights  Registered
Microsoft.App                  Registered
```

**Résultat : OK** — les trois providers sont `Registered`.

## 3. Régions autorisées

```
$ az policy assignment list -o table
Name                   DisplayName                        Scope
---------------------  ---------------------------------  --------------------------------
sys.regionrestriction  Allowed resource deployment regions  /subscriptions/<SUB_ID>

$ az policy assignment show --name sys.regionrestriction --query parameters
{
  "listOfAllowedLocations": {
    "value": ["austriaeast", "spaincentral", "denmarkeast", "switzerlandnorth", "francecentral"]
  }
}
```

Support des services dans la région retenue :

```
$ az provider show -n Microsoft.App --query "resourceTypes[?resourceType=='managedEnvironments'].locations" ...
Austria East / France Central / France South / Spain Central / Switzerland North
$ az provider show -n Microsoft.ContainerRegistry --query "resourceTypes[?resourceType=='registries'].locations" ...
Austria East / Denmark East / France Central / France South / Spain Central / Switzerland North / Switzerland West
```

**Résultat : OK** — région retenue : `francecentral` (autorisée par la policy, supporte Container Apps et ACR ; déjà utilisée par les ressources existantes du compte).

## 4. Test de création d'un ACR Basic

```
$ az acr check-name -n acrquizevaladam
{ "available": true }

$ az acr create -n acrquizevaladam -g rg-j0-test -l francecentral --sku Basic --admin-enabled false -o table
NAME             RESOURCE GROUP    LOCATION       SKU    LOGIN SERVER                CREATION DATE         ADMIN ENABLED
---------------  ----------------  -------------  -----  --------------------------  --------------------  -------------
acrquizevaladam  rg-j0-test        francecentral  Basic  acrquizevaladam.azurecr.io  2026-11-26T10:19:12Z  False
```

Durée : 15 s. Aucune erreur. **Résultat : OK** — SKU Basic disponible, `admin user` désactivé, nom disponible. Supprimé avec le groupe de test (section 9).

## 5. Test de création d'un environnement Container Apps (quota)

Création d'un Log Analytics workspace puis de l'environnement dans le groupe jetable :

```
$ az monitor log-analytics workspace create -g rg-j0-test -n law-j0-test -l francecentral -o table
Name         Location       ProvisioningState  ResourceGroup
-----------  -------------  -----------------  -------------
law-j0-test  francecentral  Succeeded          rg-j0-test

$ az containerapp env create -g rg-j0-test -n cae-j0-test -l francecentral \
    --logs-destination log-analytics --logs-workspace-id <CUSTOMER_ID> --logs-workspace-key <KEY>
WARNING:
Container Apps environment created. To deploy a container app, use: az containerapp create --help
Location        Name         ResourceGroup
--------------  -----------  ---------------
France Central  cae-j0-test  rg-j0-test
```

Durée : 21 s. Aucun refus de quota, aucune erreur. **Résultat : OK**.

Note CLI 2.90 : l'ancienne option `--log-analytics-workspace` est refusée (`unrecognized arguments`) ; utiliser `--logs-workspace-id` + `--logs-workspace-key`.

## 6. Test de création d'un service principal

```
$ az ad sp create-for-rbac --name test-sp-j0-quiz --role Reader \
    --scopes /subscriptions/<SUB_ID> --years 1
ERROR: Directory permission is needed for the current user to register the application.
For how to configure, please refer 'https://learn.microsoft.com/azure/azure-resource-manager/resource-group-create-service-principal-portal'.
Original error: Insufficient privileges to complete the operation.
```

Code retour : 1. Aucune application ni service principal résiduel (`az ad app list` et `az ad sp list` sont vides).

**Résultat : REFUSÉ** — l'utilisateur Azure for Students n'a pas le droit d'enregistrer une application dans Entra ID, donc pas de service principal ni d'identifiant fédéré OIDC. Conséquence : **J6-B (CD) utilisera le repli documenté** (secrets CI protégés, environnement GitHub `production`, droits limités) au lieu de `azure/login` par OIDC.

## 7. Droit d'attribuer AcrPull

Le service principal étant indisponible, le test est fait avec une identité managée affectée par l'utilisateur — c'est aussi le mécanisme prévu en J4 (ACR tiré sans mot de passe).

```
$ az identity create -g rg-j0-test -n id-j0-test -l francecentral
{ "clientId": "2304****-****-****-****-************", "principalId": "64fd****-****-****-****-************", "id": "/subscriptions/<SUB_ID>/resourcegroups/rg-j0-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-j0-test" }

$ az role assignment create --assignee-object-id <MI_PRINCIPAL_ID> \
    --assignee-principal-type ServicePrincipal --role AcrPull --scope <ACR_ID>
{ "name": "dcf8****-****-****-****-************", "principalId": "64fd****-...", "principalType": "ServicePrincipal", "roleDefinitionId": ".../roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d", "scope": ".../registries/acrquizevaladam" }

$ az role assignment list --scope <ACR_ID> -o table
Role     Principal
-------  ------------------------------------
AcrPull  64fd****-****-****-****-************
```

**Résultat : OK** — l'utilisateur peut attribuer `AcrPull` au scope ACR, et une identité managée peut être créée malgré le refus de création d'application. **Pas besoin du repli « admin user » ACR.**

## 8. Décisions de nommage

| Objet | Valeur | Justification |
|---|---|---|
| Région | `francecentral` | seule région autorisée par la policy déjà utilisée par le compte, supporte ACR + Container Apps |
| Resource group | `rg-quiz-eval` | demandé par le plan |
| ACR | `acrquizevaladam` | unique (vérifié `check-name`), minuscules, alphanumérique, SKU Basic |
| Admin user ACR | désactivé | remplacé par identité managée + `AcrPull` (section 7) |
| Environnement Container Apps | `cae-quiz-eval` | cohérent avec le nom du projet |
| Log Analytics | `law-quiz-eval` | associé à l'environnement |
| Apps | `backend` (interne, 3007), `frontend` (externe, 8080) | cf. J4 |

## 9. Nettoyage

```
$ az group delete -n rg-j0-test --yes --no-wait
DELETE_EXIT=0
group gone after 210s
$ az group exists -n rg-j0-test
false
$ az acr show -n acrquizevaladam -g rg-j0-test
ERROR: (ResourceNotFound) The Resource 'Microsoft.ContainerRegistry/registries/acrquizevaladam' under resource group 'rg-j0-test' was not found.
$ az group list -o table
Name              Location       Status
----------------  -------------  ---------
rg-tfstate        francecentral  Succeeded
rg-demo-docker    francecentral  Succeeded
NetworkWatcherRG  francecentral  Succeeded
```

**Résultat : OK** — plus aucune ressource de test (ACR, environnement, workspace, identité managée) ; aucun SP résiduel ; `rg-quiz-eval` n'a pas été créé.

## À signaler au formateur (J0)

> Abonnement Azure for Students opérationnel, providers enregistrés, ACR Basic et environnement Container Apps créés puis supprimés sans erreur de quota en `francecentral`. Deux restrictions : (1) la création de service principal / app registration est refusée (`Insufficient privileges`), donc le CD J6-B utilisera des secrets protégés plutôt qu'OIDC ; (2) le solde de crédits n'est pas exposé par la CLI, seul le coût réel (4,36 EUR ce mois) est consultable — le plafond de dépense est actif.
