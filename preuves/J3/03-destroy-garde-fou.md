# J3 — `destroy.sh` refuse une confirmation incorrecte

Date : 2026-11-26. Le script n'a **pas** été exécuté avec la bonne
confirmation : l'ACR doit rester disponible pour J4. Ce test prouve le
garde-fou sans rien détruire.

```console
$ printf 'mauvais-nom\n' | bash scripts/destroy.sh
[13:04:22] ATTENTION : suppression définitive du resource group rg-quiz-eval
[13:04:22] Seront supprimés : l'ACR acrquizevaladam, les images publiées et toutes les ressources du groupe.
[13:04:22] Cette action est irréversible et asynchrone (--no-wait).
Pour confirmer, tapez le nom du groupe (rg-quiz-eval) : [erreur] confirmation refusée : saisie 'mauvais-nom' différente de 'rg-quiz-eval' ; rien n'a été supprimé
$ echo $?
1
```

Le groupe est toujours présent après le test :

```console
$ az group show -n rg-quiz-eval --query name -o tsv
rg-quiz-eval
```

Le script n'accepte aucun argument : le seul groupe ciblable est celui de
`scripts/lib.sh` (`rg-quiz-eval`). La suppression réelle se fait avec
`./scripts/destroy.sh` puis la saisie exacte du nom du groupe.
