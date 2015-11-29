# Maque.sh
Projet de PSE pour l'université : recréer la commande make en version simplifiée

## Utilisation
Il suffit d'appeler le script en passant en argument la cible que l'on souhaite construire, de la façon suivante :
`./maque.sh maCible`

## Options
De plus, il est possible de passer des options, qui sont les suivantes :
 * `-f FICHIER` ou `--file=FICHIER` ou `--makefile=FICHIER` pour lire le FICHIER comme un makefile. (par défaut : Makefile, makefile).
 * `-h` ou `--help` pour afficher les options disponibles.
 * `-k` ou `--keep-going` pour continuer même si une commande retourne une erreur.
 * `-n` ou `--just-print` pour lister seulement les commandes, sans les exécuter.

