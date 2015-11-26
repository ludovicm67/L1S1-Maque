#!/bin/sh

                    #####################################
                    #                                   #
                    #   PROJET PSE : La commande make   #
                    #           Ludovic Muller          #
                    #                                   #
                    #####################################


# MAKEFILE AVEC MAJUSCULE OU NON? (l'existance en minuscule sera testee + loin)
if [ -f "Makefile" ]; then
    MAKEFILE_NAME="Makefile"
else
    MAKEFILE_NAME="makefile"
fi


# INITIALISATION DE CERTAINES VARIABLES :
## Nom du script, pour les erreurs
MAKEFILE_SCRIPTNAME=`basename -s .sh $0`
## Pour l'opt -n, on la passe à false
MAKEFILE_EXECUTECMD=true
## Pour l'opt -k, on la passe à true
MAKEFILE_CONTINUEIFERROR=false
## Contiendra le contenu du makefile
MAKEFILE_CONTENT=""
## Contiendra l'ensemble des cmds
LIST_CMDS=""


# INITIALISATION DE CERTAINES FONCTIONS :
# Permet à l'utilisateur de voir comment utiliser la commande (--help)
showUsage () {

    echo "Utilisation : $MAKEFILE_SCRIPTNAME [OPTIONS] cible

OPTIONS :
    -f FICHIER, --file=FICHIER, --makefile=FICHIER
                        Lire le FICHIER comme un makefile
                        (par defaut : Makefile, makefile).
    -h, --help          Afficher ce message et quitter.
    -k, --keep-going    Continuer meme si une commande retourne une erreur.
    -n, --just-print    Lister seulement les commandes, sans les executer.

    "

    exit 0

}

# Permet d'afficher les messages d'erreur
showError () {

    case $1 in
        errorParsingOptions)
            ERROR_ISFATAL=true
            ERROR_MSG="Erreur lors de l'analyse des options";;

        noFile)
            ERROR_ISFATAL=false
            ERROR_MSG="$2: Aucun fichier ou dossier de ce type";;

        noRule)
            ERROR_ISFATAL=true
            ERROR_MSG="Aucune regle pour creer '$2'";;

        noRuleWithDependency)
            ERROR_ISFATAL=true
            ERROR_MSG="Aucune regle pour creer '$2', dont depend '$3'";;

        noCible)
            ERROR_ISFATAL=false
            ERROR_MSG="Aucune cible n'a ete specifiee";;

        errorInCommand)
            ERROR_ISFATAL=true
            ERROR_MSG="Une erreur est survenue dans la commande précédente";;

        *)
            ERROR_ISFATAL=true
            ERROR_MSG="Une erreur inconnue est survenue"
    esac

    if $ERROR_ISFATAL; then
        echo "$MAKEFILE_SCRIPTNAME: *** $ERROR_MSG. Arret." >&2
        exit 1
    else
        echo "$MAKEFILE_SCRIPTNAME: $ERROR_MSG" >&2
    fi

}

# Permet d'ajouter des commandes à la variable $LIST_CMDS
addCmd () {

    if [ -z "$LIST_CMDS" ]; then
        LIST_CMDS="$1"
    elif [ -n "$1" ]; then
        LIST_CMDS="$LIST_CMDS
$1"
    fi

}

# Permet d'executer les commandes contenues dans la variable $LIST_CMDS
execCmds () {

    echo "$LIST_CMDS" | while read CMD; do
        echo "$CMD"
        if $MAKEFILE_EXECUTECMD; then
            sh -c "$CMD"
            if [ $? -ne 0 ] && ! $MAKEFILE_CONTINUEIFERROR; then
                showError errorInCommand
            fi
        fi
    done

}

# Permet de trouver une cible dans le makefile
## ARG1 = nom de la cible
## Return: 0 si cible trouvée, 1 si inexistante
findCible () {

    CIBLE="$MAKEFILE_CONTENT"

    CIBLE_NAME=`echo "$1" | sed 's/\./\\\./g'`
    LINE_CIBLE=`echo "$CIBLE" | grep -nm1 "^$CIBLE_NAME:" | sed s/:.*//`

    if [ -z "$LINE_CIBLE" ]; then
        return 1
    fi

    # On enlève ce qui précède la cible
    if [ $LINE_CIBLE -ne 1 ]; then
        CIBLE=`echo "$CIBLE" | sed 1,$(($LINE_CIBLE - 1))'d'`
    fi

    # On elève ce qui suit la cible
    LINE_NEXTCIBLE=`echo "$CIBLE" | sed 1d | grep -nvPm1 "^\t" | sed s/:.*//`
    if [ -n "$LINE_NEXTCIBLE" ]; then
        CIBLE=`echo "$CIBLE" | sed $(($LINE_NEXTCIBLE + 1)),'$d'`
    fi

    echo "$CIBLE"

    return 0

}


# ANALYSE DES DIFFERENTES OPTIONS
OPTS=`getopt --options hknf: --long help,keep-going,just-print,file:,makefile: \
        -n "$MAKEFILE_SCRIPTNAME" -- "$@"`

if [ $? -ne 0 ]
    then showError errorParsingOptions
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -h | --help)                showUsage;;
        -k | --keep-going)          MAKEFILE_CONTINUEIFERROR=true; shift;;
        -n | --just-print)          MAKEFILE_EXECUTECMD=false; shift;;
        -f | --file | --makefile)   MAKEFILE_NAME="$2"; shift; shift;;
        -- )                        shift; break;;
        *)                          break
    esac
done


# ON VERIFIE SI UNE CIBLE A BIEN ETE SPECIFIEE EN ARGUMENT (car arg obligatoire)
if [ $# -ne 1 ]; then
    showError noCible
    showUsage
fi


# ON TESTE L'EXISTENCE DU MAKEFILE
if [ ! -f "$MAKEFILE_NAME" ]; then
    showError noFile "$MAKEFILE_NAME"
    showError noRule "$MAKEFILE_NAME"
fi


# ON ENLEVE LES COMMENTAIRES EN DEBUT DE LIGNE AINSI QUE LES LIGNES VIDES
MAKEFILE_CONTENT=`grep -v '^ *$' "$MAKEFILE_NAME" | grep -v '^#'`


# FONCTION RECURSIVE QUI VA PARCOURIR L'ENSEMBLE DES CIBLES, ETC...
## Args: $1=nom de la cible; $2=nom de la cible ayant besoin de $1 (optionel)
## Return: 0 si la cible ne doit pas être reconstruite, 1 sinon
walkCible () {

    local RETURN_CODE=0

    CIBLE_CONTENT="`findCible "$1"`"
    RETURN_VALUE="$?"

    local CMDS=""
    local DEPS=""

    # Si la cible n'a pas été trouvée dans le fichier Makefile
    if [ "$RETURN_VALUE" -eq 1 ]; then
        # On verifie si walkCible a été appelé à partir d'une autre cible
        if [ -n "$2" ]; then
            # On vérifie si la cible appelée est un fichier
            if [ -f "$1" ]; then
                # On vérifie si la cible appelante est un fichier
                if [ -f "$2" ]; then
                    # Vérifie si la cible appelée est plus récente que la cible
                    # appelante.
                    IS_NEWER="`find "$1" -newer "$2" | wc -l`"
                    if [ $IS_NEWER -ne 0 ]; then
                        RETURN_CODE=1
                    fi
                else
                    RETURN_CODE=1
                fi
            else
                showError noRuleWithDependency "$1" "$2"
            fi
        else
            showError noRule "$1"
        fi
        
    else

        # Si c'est une dépendence (ou sous-dependence) de la première cible, et
        # que la cible courante et la cible dont elle dépend sont des fichiers
        if [ -n "$2" ] && [ -f "$1" ] && [ -f "$2" ]; then
            IS_NEWER="`find "$1" -newer "$2" | wc -l`"
            if [ $IS_NEWER -ne 0 ]; then
                RETURN_CODE=1
            fi
        fi

        # On initialise les variables contenant les commandes et les dépendences
        CMDS="`echo "$CIBLE_CONTENT" | grep -P "^\t" | sed "s/^[[:space:]]*//"`"
        DEPS="`echo "$CIBLE_CONTENT" | sed "2,$"d | sed "s/^$1:[[:space:]]*//"`"

        # S'il n'y a pas de dépendences, il faudra exécuter les commandes
        if [ -z "$DEPS" ]; then
            RETURN_CODE=1
        else

            local DEP
            # On parcourt l'ensemble des dépendences
            for DEP in $DEPS; do

                walkCible "$DEP" "$1"
                WALK_RETURN="$?"

                if [ "$WALK_RETURN" -eq 1 ]; then
                    RETURN_CODE=1
                fi

            done

        fi
    fi

    # Si c'est la première dépendence et que tout est à jour...
    if [ -z "$2" ] && [ "$RETURN_CODE" -eq 0 ]; then
		echo "La cible '$1' est deja a jour !"
    fi

    # On ajoute les commandes de la cible si $RETURN_CODE vaut 1
    if [ "$RETURN_CODE" -eq 1 ]; then

        local IFS='\n'
        for CMD in "$CMDS"; do
            addCmd "$CMD"
        done

    fi

    return "$RETURN_CODE"

}

walkCible "$1"
execCmds
