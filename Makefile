#
# EXEMPLE DE FICHIER MAKEFILE POUR DIVERS TESTS
#

toto:	toto.o
	touch toto
	echo toto est touche

toto.o:	toto.c
	touch toto.o
	echo toto.o est touche

#
# Ceci est un cas tordu (le "." de toto.o ci-dessus est un caractere generique)
#
totooo:	toto
	echo essai

#
# Un cas classique sans prerequis
#
clean:
	rm -f toto *.o

#
# Ne doit pas être exécuté, car la dépendence est inexistante
#
impossible:	inexistant
	touch impossible

#
# Pour tester l'option -k
#
testOptionK:
	echo "ceci doit toujours s'afficher"
	rm fichierInexistant
	echo "Ceci doit s'executer seulement si l'option -k est active"

