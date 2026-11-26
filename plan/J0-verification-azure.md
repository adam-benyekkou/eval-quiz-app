# J0 — Vérification préalable Azure (non notée)

**Branche(s)** : feature/j0-azure-check
**Dépend de** : — (à faire en premier : risque principal de planning)
**Assigné** : Ulrich & Adam
**Statut** : à faire
**Livrables** : `preuves/J0/azure-check.md` (expurgé : pas d'ID d'abonnement complet ni de tenant)

## Tâches

- [ ] `az login` puis `az account show` : abonnement Azure for Students ; noter crédits restants et date d'expiration (sans capture d'identifiants)
- [ ] `az provider list --query "[?namespace=='Microsoft.ContainerRegistry' || namespace=='Microsoft.App' || namespace=='Microsoft.OperationalInsights'].{ns:namespace,state:registrationState}" -o table`
- [ ] Enregistrer les providers manquants : `az provider register --namespace Microsoft.App` (idem ContainerRegistry, OperationalInsights)
- [ ] Lister les régions autorisées (`az policy assignment list` ou création d'un resource group jetable) ; noter la région
- [ ] Tester la création d'un ACR Basic, puis le supprimer
- [ ] Tester la création d'un environnement Container Apps (quota) ; noter l'erreur exacte en cas de refus
- [ ] Tester la création d'un service principal (`az ad sp create-for-rbac --name test-sp --role Reader --scopes /subscriptions/<id>`) puis le supprimer ; si refusé, OIDC/SP indisponible → fallback en J6 (branche cd-azure, feature/j6-cd-azure)
- [ ] Vérifier le droit d'attribuer AcrPull (`az role assignment create`) ; sinon prévoir ACR admin user
- [ ] Décider et noter : région, resource group (`rg-quiz-eval`), nom ACR (unique, minuscules), nom d'environnement
- [ ] Signaler au formateur tout blocage avant toute dépense (docs/03)
- [ ] Supprimer toute ressource de test (`az group delete -n <rg-test> --yes --no-wait`) et le confirmer

## Preuve

- [ ] Commandes exécutées et sorties (expurgées) consignées dans `preuves/J0/azure-check.md`
- [ ] Pour chaque test : résultat OK ou refusé, avec le message d'erreur exact en cas de refus
- [ ] Décisions de nommage et de région consignées

## Je sais expliquer (humain)

- [ ] Ce qu'est un resource provider et pourquoi l'enregistrer
- [ ] Pourquoi ACR Basic et une taille d'app minimale (coûts)
- [ ] Différence entre service principal, identité managée et admin user ACR
