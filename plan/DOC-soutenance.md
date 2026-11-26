# DOC — Documentation, preuves, soutenance

**Branche(s)** : feature/docs (une seule branche, une seule PR pour les trois sections)
**Dépend de** : au fil des jalons ; finalisation après J6
**Assigné** : _à renseigner_
**Statut** : à faire
**Livrables** : sections du README (« Usage de l'IA », prérequis, lancement, déploiement, nettoyage), schémas d'architecture locale et cloud, support de soutenance (6 diapositives max), vérification finale avant remise

## Section 1 — README et usage de l'IA

- [ ] Section README « Usage de l'IA » (docs/09) : outils, types de tâches assistées, comment chaque proposition a été vérifiée ; aucune clé, chaîne ni donnée personnelle
- [ ] README : prérequis, lancement local, déploiement cloud, nettoyage, liens vers `docs/` et `preuves/`
- [ ] `.env.example` sans secret, et `git ls-files | grep -E '(^|/)\.env$'` ne renvoie rien

## Section 2 — Schémas d'architecture

- [ ] Schéma d'architecture locale (J1) réalisé par le groupe
- [ ] Schéma cloud : GitHub Actions, ACR, Container Apps frontend externe / backend interne, Neon, flux de secrets
- [ ] Chaque schéma accompagné de quelques lignes d'explication

## Section 3 — Soutenance (docs/06 : 15 min, 6 diapositives max)

- [ ] D1 : contexte et mission
- [ ] D2 : conteneurisation locale (Compose, volume, persistance)
- [ ] D3 : sécurité (Trivy avant/après, résiduelles)
- [ ] D4 : architecture Azure
- [ ] D5 : CI/CD (PR, Trivy bloquant, approbation, merge, ACR, révision)
- [ ] D6 : difficultés et bilan
- [ ] Démo de référence répétée (question modifiée, branche, PR, Trivy, approbation, fusion, ACR, révision)
- [ ] Plan B : captures et sorties de `preuves/` si ressources Azure supprimées
- [ ] Chaque membre prépare sa contribution et 2 justifications techniques
- [ ] Répétition sans IA : modifier un Dockerfile, diagnostiquer un conteneur qui plante, expliquer un step du workflow

## Preuve (vérification finale avant remise)

- [ ] `preuves/J0` à `J6` présents et expurgés : `grep -rniE "password|secret|token|postgres://|re_[A-Za-z0-9]{10,}" preuves/` ne renvoie rien de réel
- [ ] `scripts/deploy.sh` et `destroy.sh` versionnés, shellcheck propre
- [ ] Workflows verts sur `main` du fork
- [ ] URL du fork, liens PR et exécutions CI/CD transmis au formateur
- [ ] Ressources Azure supprimées après accord du formateur, et sauvegarde des preuves

## Je sais expliquer (humain)

- [ ] Les 6 diapositives et les 2 justifications techniques de chaque membre, réexpliquées sans aide (docs/09)
