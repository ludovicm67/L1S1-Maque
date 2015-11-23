#!/bin/sh

                    #####################################
                    #                                   #
                    #   PROJET PSE : La commande make   #
                    #     Ludovic Muller (ludmuller)    #
                    #                                   #
                    #####################################


# MAKEFILE AVEC MAJUSCULE OU NON? (l'existance en minuscule sera testee + loin)
if [ -f "Makefile" ]; then
    MAKEFILE_NAME="Makefile"
else
    MAKEFILE_NAME="makefile"
fi


# INITIALISATION DE CERTAINES VARIABLES :
MAKEFILE_SCRIPTNAME=`basename -s .sh $0`    # Nom du script, pour les erreurs
MAKEFILE_EXECUTECMD=true                    # Pour l'opt -n, on la passe à false
MAKEFILE_CONTINUEIFERROR=false              # Pour l'opt -k, on la passe à true
MAKEFILE_CONTENT=""                         # Contiendra le contenu du makefile
LIST_CMDS=""                                # Contiendra l'ensemble des cmds


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

    LINE_CIBLE=`echo "$CIBLE" | grep -nm1 "^$1:" | sed s/:.*//`

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


# Fonction récursive qui va parcourir l'ensemble des cibles, etc...
## Args: $1=nom de la cible; $2=nom de la cible ayant besoin de $1 (optionel)
## Return: 0 si la cible ne doit pas être reconstruite, 1 sinon
walkCible () {

    local RETURN_CODE=0

    CIBLE_CONTENT="`findCible "$1"`"
    RETURN_VALUE="$?"

    local CMDS=""
    local DEPS=""

    if [ "$RETURN_VALUE" -eq 1 ]; then
        if [ -n "$2" ]; then
            if [ -f "$1" ]; then
                if [ -f "$2" ]; then
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

        if [ -n "$2" ]; then
            if [ -f "$1" ]; then
                if [ -f "$2" ]; then
                    IS_NEWER="`find "$1" -newer "$2" | wc -l`"
                    if [ $IS_NEWER -ne 0 ]; then
                        RETURN_CODE=1
                    fi
                fi
            fi
        fi

        CMDS="`echo "$CIBLE_CONTENT" | grep -P "^\t" | sed "s/^[[:space:]]*//"`"
        DEPS="`echo "$CIBLE_CONTENT" | sed "2,$"d | sed "s/^$1:[[:space:]]*//"`"

        if [ -z "$DEPS" ]; then
            RETURN_CODE=1
        else

            local DEP
            for DEP in $DEPS; do

                walkCible "$DEP" "$1"
                WALK_RETURN="$?"

                if [ "$WALK_RETURN" -eq 1 ]; then
                    RETURN_CODE=1
                fi

            done

        fi
    fi

    if [ -z "$2" ]; then
        RETURN_CODE=1
    fi

    if [ "$RETURN_CODE" -eq 1 ]; then

# On ajoute les commandes à exécuter plus tard
while read CMD; do
    addCmd "$CMD"
done <<EOT
$CMDS
EOT

    fi

    return "$RETURN_CODE"

}

walkCible "$1"
execCmds