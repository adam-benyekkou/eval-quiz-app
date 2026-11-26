# J0 — Vérification préalable Azure (non notée)

**Branche(s)** : feature/j0-azure-check
**Dépend de** : — (à faire en premier : risque principal de planning)
**Assigné** : IA:DeepSeek (relecture Adam)
**Statut** : en cours
**Livrables** : `preuves/J0/azure-check.md` (expurgé : pas d'ID d'abonnement complet ni de tenant)

## Tâches

- [x] `az login` puis `az account show` : abonnement Azure for Students ; noter crédits restants et date d'expiration (sans capture d'identifiants) — fin de promotion 2027-11-24, solde non exposé par la CLI (portail requis), coût MTD 4,36 EUR (voir preuve)
- [x] `az provider list --query "[?namespace=='Microsoft.ContainerRegistry' || namespace=='Microsoft.App' || namespace=='Microsoft.OperationalInsights'].{ns:namespace,state:registrationState}" -o table`
- [x] Enregistrer les providers manquants : `az provider register --namespace Microsoft.App` (idem ContainerRegistry, OperationalInsights)
- [x] Lister les régions autorisées (`az policy assignment list` ou création d'un resource group jetable) ; noter la région — `francecentral`
- [x] Tester la création d'un ACR Basic, puis le supprimer — créé en 15 s, supprimé avec `rg-j0-test`
- [x] Tester la création d'un environnement Container Apps (quota) ; noter l'erreur exacte en cas de refus — créé en 21 s, aucun refus
- [x] Tester la création d'un service principal (`az ad sp create-for-rbac --name test-sp --role Reader --scopes /subscriptions/<id>`) puis le supprimer ; si refusé, OIDC/SP indisponible → fallback en J6 (branche cd-azure, feature/j6-cd-azure) — **REFUSÉ** (`Insufficient privileges`), repli J6-B retenu
- [x] Vérifier le droit d'attribuer AcrPull (`az role assignment create`) ; sinon prévoir ACR admin user — OK avec identité managée ; pas d'admin user
- [x] Décider et noter : région, resource group (`rg-quiz-eval`), nom ACR (unique, minuscules), nom d'environnement — `francecentral`, `rg-quiz-eval`, `acrquizevaladam`, `cae-quiz-eval`
- [ ] Signaler au formateur tout blocage avant toute dépense (docs/03) — message prêt dans `preuves/J0/azure-check.md` (action humaine)
- [x] Supprimer toute ressource de test (`az group delete -n <rg-test> --yes --no-wait`) et le confirmer — groupe absent, ACR introuvable

## Preuve

- [x] Commandes exécutées et sorties (expurgées) consignées dans `preuves/J0/azure-check.md`
- [x] Pour chaque test : résultat OK ou refusé, avec le message d'erreur exact en cas de refus
- [x] Décisions de nommage et de région consignées

## Je sais expliquer (humain)

- [ ] Ce qu'est un resource provider et pourquoi l'enregistrer
- [ ] Pourquoi ACR Basic et une taille d'app minimale (coûts)
- [ ] Différence entre service principal, identité managée et admin user ACR
