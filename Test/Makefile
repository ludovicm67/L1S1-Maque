# A appeler pour executer l'ensemble des commandes
compile:	index.html clean index.html copyOtherFiles
		echo "Creation du site dans le repertoire dist, qui sera a envoyer sur votre serveur via FTP"

# Assemble les différentes parties de code html
index.html:	header.html indexContent.html footer.html
		cat header.html indexContent.html footer.html > ./index.html
		cp ./index.html ./dist

copyOtherFiles:
		cp -R ./js ./dist/js
		cp -R ./css ./dist/css
		cp -R ./font-awesome ./dist/font-awesome
		cp -R ./fonts ./dist/fonts
		cp -R ./img ./dist/img

# Permet de nettoyer le répertoire dist
clean:
		rm -rf ./dist
		mkdir ./dist
		cp ./index.html ./dist

# Permet de supprimer le répertoire dist ainsi que index.html
cleanAll:
		rm -rf ./dist ./index.html