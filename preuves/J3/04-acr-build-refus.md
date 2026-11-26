# J3 — `az acr build` : alternative comparée, refusée par l'abonnement

Date : 2026-11-26. Le mode `--acr-build` a été exécuté une fois pour vérifier
l'alternative sans démon Docker local.

```console
$ bash scripts/deploy.sh --acr-build
[13:04:31] Build déporté : quiz-backend:70251de (contexte backend/)
WARNING: Packing source code into tar to upload...
WARNING: Uploading archived source code from '/tmp/build_archive_....tar.gz'...
WARNING: Sending context (24.659 KiB) to registry: acrquizevaladam...
ERROR: (TasksOperationsNotAllowed) ACR Tasks requests for the registry acrquizevaladam and <subscription> are not permitted. Please file an Azure support request at http://aka.ms/azuresupport for assistance.
Code: TasksOperationsNotAllowed
Message: ACR Tasks requests for the registry acrquizevaladam and <subscription> are not permitted. Please file an Azure support request at http://aka.ms/azuresupport for assistance.
$ echo $?
1
```

(L'identifiant d'abonnement a été remplacé par `<subscription>`.)

## Conséquence

- L'alternative `az acr build` est **indisponible sur cet abonnement Azure for
  Students** : les ACR Tasks sont bloqués par la politique de l'abonnement.
- Le chemin retenu et validé pour J3 est le **build local + `docker push`**,
  exécuté deux fois avec succès (`02-deploy.md`).
- L'option `--acr-build` reste dans le script pour un abonnement où les ACR
  Tasks sont autorisés ; elle est documentée comme non validée ici, avec le
  message exact ci-dessus.
- Comparaison consignée dans `docs/deploiement-azure.md` : démon Docker requis
  ou non, cache, images locales, reproductibilité CI, coût.
