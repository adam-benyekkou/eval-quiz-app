# J3 — ShellCheck des scripts

Date : 2026-11-26. ShellCheck n'est pas installé sur l'hôte ; il est exécuté
dans le conteneur officiel. `-x` suit le `source` de `lib.sh` et `-P scripts`
résout le chemin relatif.

```console
$ docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable \
    -x -P scripts scripts/lib.sh scripts/deploy.sh scripts/destroy.sh
$ echo "exit=$?"
exit=0
```

Aucun avertissement, aucune erreur. Les seuls codes rencontrés au premier
passage (SC2034 sur les constantes de `lib.sh`, SC1091 sur le `source`) sont
traités : directive `# shellcheck disable=SC2034` documentée dans `lib.sh`
(constantes consommées par les scripts appelants) et résolution du `source`
par `-x -P scripts`.
