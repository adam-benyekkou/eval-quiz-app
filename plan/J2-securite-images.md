# J2 — Sécurité des images (Trivy avant/après)

**Branche(s)** : feature/j2-trivy-baseline, feature/j2-hardening (une PR par branche, dans cet ordre)
**Dépend de** : J1
**Assigné** : Ulrich & Adam
**Statut** : fait (sections 1-2, PR #11 et #12 en revue)
**Livrables** : `docs/securite-trivy.md`, `preuves/J2/trivy-avant.*`, `preuves/J2/trivy-apres.*`, éventuel `.trivyignore` justifié

## Section 1 — feature/j2-trivy-baseline (aucune correction)

- [x] Construire les images telles que livrées : `quiz-backend:baseline`, `quiz-frontend:baseline`
- [x] `trivy image --severity CRITICAL,HIGH,MEDIUM --format table quiz-backend:baseline > preuves/J2/trivy-avant-backend.txt` (idem frontend)
- [x] Même scan au format JSON
- [x] `trivy config .` et `trivy fs --scanners secret .`
- [x] Tableau récapitulatif dans `docs/securite-trivy.md` (nb CRITICAL/HIGH/MEDIUM par image, paquets, origine)
- [x] Pour chaque CRITICAL/HIGH : pertinent ou non (exploitable, paquet utilisé à l'exécution)

## Section 2 — feature/j2-hardening

- [x] Corrections candidates justifiées : image de base plus récente ou `-alpine`/`-slim`, MAJ des dépendances npm sans changer le comportement, `npm ci --omit=dev`, retirer les outils de build de l'image finale, non-root, FS en lecture seule si possible
- [x] Distroless/Chainguard évalués et écartés : alpine est conservé pour garder le shell de débogage (`docker exec -it <ctn> sh`) ; documenter ce compromis (surface d'attaque légèrement plus large contre accès direct de diagnostic) dans `docs/securite-trivy.md`
- [x] Ne pas modifier la logique métier ; une dépendance imposant un changement de code = résiduelle documentée
- [x] Reconstruire (`:fixed`) et rescanner : `preuves/J2/trivy-apres-*.txt`
- [x] Section « Vulnérabilités résiduelles » (CVE, sévérité, raison, mitigation) dans `docs/securite-trivy.md`
- [x] Si `.trivyignore` : une ligne par CVE avec commentaire, date, justification ; jamais d'ignore global
- [x] Aucun CRITICAL résiduel (sinon la CI de J6-A échouera)
- [x] Rejouer le parcours J1 sur les images corrigées

## Preuve

- [x] Sorties Trivy avant/après dans `preuves/J2/`
- [x] Tableau récapitulatif et section « Vulnérabilités résiduelles » dans `docs/securite-trivy.md`
- [x] Parcours J1 rejoué sur les images corrigées

## Je sais expliquer (humain)

- [ ] Ce que Trivy analyse et d'où vient sa base CVE
- [ ] Pourquoi alpine/slim réduit les CVE, ce qu'apporterait en plus une image distroless/hardened (pas de shell, pas de gestionnaire de paquets), et pourquoi le groupe a choisi de garder le shell malgré ça
- [ ] Pourquoi une résiduelle n'est pas acceptée aveuglément
- [ ] Différence entre scan fs, image et config
