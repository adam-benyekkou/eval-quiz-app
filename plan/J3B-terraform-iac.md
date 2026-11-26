# J3B — Infrastructure as Code avec Terraform (complément, non requis par les consignes)

**Branche(s)** : feature/terraform-iac
**Dépend de** : J0 (région, quotas) ; recouvre les mêmes ressources que J3 et J4
**Assigné** : Ulrich & Adam
**Statut** : à faire
**Livrables** : `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`, `terraform/backend.tf`, `terraform/README.md`, `preuves/J3B/`

## Pourquoi cette étape existe

`docs/02` et `docs/06` exigent des scripts Azure CLI (`scripts/deploy.sh`, `scripts/destroy.sh`) comme livrable officiel : **ils restent obligatoires et ne sont pas remplacés**. Terraform est ajouté en plus, pour disposer d'une version déclarative (IaC) du même provisioning, utile pour la démonstration technique et la reproductibilité. En cas de divergence de preuve demandée par le formateur, les scripts Azure CLI (J3/J4) font foi.

## Contraintes

- Même périmètre de ressources que J3 + J4 : resource group, ACR, environnement Container Apps, les deux Container Apps (images ACR via `image` paramétrée, pas de build dans Terraform).
- État Terraform **non commité** : backend distant (ex. Azure Storage + conteneur blob dédié, créé une fois à la main ou via un petit script d'amorçage) ou, à défaut documenté, état local ajouté à `.gitignore`. Jamais de `terraform.tfstate` dans le dépôt (il peut contenir des valeurs sensibles).
- Secrets (chaîne Neon, JWT, Resend) passés en variables Terraform marquées `sensitive = true`, jamais en valeur par défaut, jamais commités.
- Mêmes noms de ressources que J3/J4 pour éviter les doublons de coût ; prévoir une bascule claire entre « géré par script » et « géré par Terraform » (ne pas faire gérer la même ressource par les deux à la fois).

## Checklist

- [ ] `terraform/backend.tf` : backend d'état distant choisi et documenté (ou repli local justifié)
- [ ] Provider `azurerm`, version épinglée
- [ ] `azurerm_resource_group` (même nom que J0/J3)
- [ ] `azurerm_container_registry` (SKU Basic)
- [ ] `azurerm_container_app_environment` + Log Analytics workspace associé
- [ ] `azurerm_container_app` backend : ingress interne, port 3007, variables publiques en `env`, secrets en blocs `secret` + `env { secret_name = ... }`
- [ ] `azurerm_container_app` frontend : ingress externe, port 8080, `BACKEND_HOST`/`BACKEND_PORT` paramétrés
- [ ] Variables d'entrée (`variables.tf`) : région, tags d'image, noms, secrets marqués `sensitive`
- [ ] `outputs.tf` : FQDN du frontend, nom de l'ACR (rien de sensible en sortie)
- [ ] `terraform fmt -check` et `terraform validate`
- [ ] `terraform plan` relu avant tout apply ; `preuves/J3B/plan.txt` expurgé
- [ ] `terraform apply` sur un environnement **distinct** de celui déjà créé par les scripts CLI (ou après destruction propre de l'un des deux, pour éviter un double provisioning payant)
- [ ] Vérifier `curl -i https://<fqdn>/health` sur les ressources issues de Terraform
- [ ] `terraform destroy` testé et confirmé propre
- [ ] `terraform/README.md` : prérequis, backend d'état, variables à fournir, commandes, lien explicite avec `docs/deploiement-azure.md` et les scripts J3/J4

## Preuve

- [ ] `preuves/J3B/plan.txt` et sortie d'apply expurgées
- [ ] FQDN obtenu et test `/health`
- [ ] Sortie de `terraform destroy`

## Je sais expliquer (humain)

- [ ] Différence entre les scripts Azure CLI (impératif) et Terraform (déclaratif), et pourquoi les deux coexistent ici
- [ ] Où vit l'état Terraform et pourquoi il ne doit jamais être commité
- [ ] Comment un secret Terraform arrive dans Container Apps sans apparaître dans le `plan`/`apply` en clair
- [ ] Ce qui se passe si on relance `apply` deux fois (idempotence déclarative vs idempotence des scripts)
