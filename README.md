# Script d'import des photos

Ce script permet d'importer les photos et ouvrir votre éditeur de photo préféré (par défaut ici Darktable) en 2 clics.

## Pré-requis
- Installation de Exifreader


## Exécution
Usage: import_photos.sh -ps <chemin_source> -pd <chemin_destination> [-d <date_creation>] [-f <extension>] [-e]

### Arguments
-ps : chemin source (ex: /Volumes/SD_CARD)
-pd : chemin destination (ex: /Volumes/SSD/photos)
-d  : (optionnel) date de création à appliquer (ex: "2025:02:19 12:34:56")
-f  : (optionnel) type de fichier à rechercher (ex: .jpg). Par défaut ".nef"
-e  : (optionnel) activer la recherche récursive dans les sous-dossiers
