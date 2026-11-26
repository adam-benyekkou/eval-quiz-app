# J2 — Sécurité des images (Trivy avant/après)

**Branche(s)** : feature/j2-trivy-baseline, feature/j2-hardening (une PR par branche, dans cet ordre)
**Dépend de** : J1
**Assigné** : _à renseigner_
**Statut** : à faire
**Livrables** : `docs/securite-trivy.md`, `preuves/J2/trivy-avant.*`, `preuves/J2/trivy-apres.*`, éventuel `.trivyignore` justifié

## Section 1 — feature/j2-trivy-baseline (aucune correction)

- [ ] Construire les images telles que livrées : `quiz-backend:baseline`, `quiz-frontend:baseline`
- [ ] `trivy image --severity CRITICAL,HIGH,MEDIUM --format table quiz-backend:baseline > preuves/J2/trivy-avant-backend.txt` (idem frontend)
- [ ] Même scan au format JSON
- [ ] `trivy config .` et `trivy fs --scanners secret .`
- [ ] Tableau récapitulatif dans `docs/securite-trivy.md` (nb CRITICAL/HIGH/MEDIUM par image, paquets, origine)
- [ ] Pour chaque CRITICAL/HIGH : pertinent ou non (exploitable, paquet utilisé à l'exécution)

## Section 2 — feature/j2-hardening

- [ ] Corrections candidates justifiées : image de base plus récente ou `-alpine`/`-slim`, MAJ des dépendances npm sans changer le comportement, `npm ci --omit=dev`, retirer les outils de build de l'image finale, non-root, FS en lecture seule si possible
- [ ] Ne pas modifier la logique métier ; une dépendance imposant un changement de code = résiduelle documentée
- [ ] Reconstruire (`:fixed`) et rescanner : `preuves/J2/trivy-apres-*.txt`
- [ ] Section « Vulnérabilités résiduelles » (CVE, sévérité, raison, mitigation) dans `docs/securite-trivy.md`
- [ ] Si `.trivyignore` : une ligne par CVE avec commentaire, date, justification ; jamais d'ignore global
- [ ] Aucun CRITICAL résiduel (sinon la CI de J6-A échouera)
- [ ] Rejouer le parcours J1 sur les images corrigées

## Preuve

- [ ] Sorties Trivy avant/après dans `preuves/J2/`
- [ ] Tableau récapitulatif et section « Vulnérabilités résiduelles » dans `docs/securite-trivy.md`
- [ ] Parcours J1 rejoué sur les images corrigées

## Je sais expliquer (humain)

- [ ] Ce que Trivy analyse et d'où vient sa base CVE
- [ ] Pourquoi alpine/slim réduit les CVE
- [ ] Pourquoi une résiduelle n'est pas acceptée aveuglément
- [ ] Différence entre scan fs, image et config
