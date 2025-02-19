#!/bin/bash
# Ce script copie les fichiers d'un type donné (par défaut .nef)
# depuis un dossier source vers un dossier destination, en évitant les doublons
# (basés sur le nom et la date de création).
#
# Arguments :
#   -ps : chemin source (ex: /Volumes/SD_CARD)
#   -pd : chemin destination (ex: /Volumes/SSD/photos)
#   -d  : (optionnel) date de création à appliquer (ex: "2025:02:19 12:34:56")
#   -f  : (optionnel) type de fichier à rechercher (ex: .jpg). Par défaut ".nef"
#   -e  : (optionnel) activer la recherche récursive dans les sous-dossiers
#
# Usage :
#   ./import_photos.sh -ps <chemin_source> -pd <chemin_destination> [-d "YYYY:MM:DD HH:MM:SS"] [-f <extension>] [-e]

set -euo pipefail

# Fonction d'affichage de l'usage
usage() {
    echo "Usage: $0 -ps <chemin_source> -pd <chemin_destination> [-d <date_creation>] [-f <extension>] [-e]"
    echo "Exemple : $0 -ps /Volumes/SD_CARD -pd /Volumes/SSD/photos -f .jpg -e"
    exit 1
}

# Vérifier la présence d'exiftool
if ! command -v exiftool >/dev/null 2>&1; then
    echo "Erreur : exiftool n'est pas installé. Veuillez l'installer." >&2
    exit 1
fi

# Initialisation des variables
SOURCE=""
DESTINATION=""
SPECIFIC_DATE=""
EXTENSION=".nef"  # Valeur par défaut
EXPLORE=0         # Par défaut, pas d'exploration récursive

# Traitement des arguments avec getopts
while getopts "ps:pd:d:f:e" opt; do
    case $opt in
        ps)
            SOURCE="$OPTARG"
            ;;
        pd)
            DESTINATION="$OPTARG"
            ;;
        d)
            SPECIFIC_DATE="$OPTARG"
            ;;
        f)
            EXTENSION="$OPTARG"
            ;;
        e)
            EXPLORE=1
            ;;
        *)
            usage
            ;;
    esac
done

# Vérifier que les arguments obligatoires sont fournis
if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
    echo "Erreur : les chemins source et destination sont obligatoires."
    usage
fi

# Vérification de l'existence du dossier source
if [[ ! -d "$SOURCE" ]]; then
    echo "Erreur : le dossier source '$SOURCE' n'existe pas." >&2
    exit 1
fi

# Créer le dossier destination s'il n'existe pas
if [[ ! -d "$DESTINATION" ]]; then
    echo "Le dossier destination '$DESTINATION' n'existe pas, création..."
    mkdir -p "$DESTINATION" || { echo "Erreur : impossible de créer '$DESTINATION'." >&2; exit 1; }
fi

# Fonction pour extraire la date de création d'un fichier via EXIF
get_creation_date() {
    local file="$1"
    local date
    date=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null || true)
    if [[ -z "$date" ]]; then
        date=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null || true)
    fi
    echo "$date"
}

# Gestion des signaux pour un nettoyage
cleanup() {
    echo "Interruption ou erreur détectée. Arrêt du script."
    exit 1
}
trap cleanup SIGINT SIGTERM

echo "Début de l'importation depuis '$SOURCE' vers '$DESTINATION'."
echo "Type de fichier recherché : $EXTENSION"
if [[ $EXPLORE -eq 1 ]]; then
    echo "Recherche récursive activée (exploration des sous-dossiers)."
else
    echo "Recherche non récursive (seulement le dossier source)."
fi
if [[ -n "$SPECIFIC_DATE" ]]; then
    echo "Utilisation de la date spécifique : $SPECIFIC_DATE"
fi

# Préparer l'option de recherche pour find (selon l'option -e)
if [[ $EXPLORE -eq 1 ]]; then
    FIND_DEPTH=""
else
    FIND_DEPTH="-maxdepth 1"
fi

# Recherche des fichiers avec l'extension donnée (insensible à la casse)
find "$SOURCE" $FIND_DEPTH -type f \( -iname "*${EXTENSION}" \) | while IFS= read -r file; do
    base=$(basename "$file")
    
    # Utilise la date spécifique si fournie, sinon extrait la date EXIF
    if [[ -n "$SPECIFIC_DATE" ]]; then
        creation_date="$SPECIFIC_DATE"
    else
        creation_date=$(get_creation_date "$file")
    fi

    if [[ -z "$creation_date" ]]; then
        echo "Aucune date de création trouvée pour $file. Fichier ignoré."
        continue
    fi

    dest_file="$DESTINATION/$base"

    if [[ -f "$dest_file" ]]; then
        dest_date=$(get_creation_date "$dest_file")
        if [[ "$creation_date" == "$dest_date" ]]; then
            echo "Doublon détecté pour '$base' (date : $creation_date). Fichier ignoré."
            continue
        else
            # Même nom mais date différente : renommer le nouveau fichier en y ajoutant la date formatée
            formatted_date=$(echo "$creation_date" | tr ':' '-' | sed 's/ /_/g')
            newname="${base%.*}_${formatted_date}${EXTENSION}"
            dest_file="$DESTINATION/$newname"
            echo "Conflit de nom : '$base' existe déjà mais avec une date différente. Copie en tant que '$newname'."
        fi
    else
        echo "Copie de '$base' vers destination."
    fi

    cp -v "$file" "$dest_file" || {
        echo "Erreur lors de la copie de '$file' vers '$dest_file'." >&2
        continue
    }
done

echo "Importation terminée."

# Lancer Darktable selon le système d'exploitation
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Ouverture de Darktable sur macOS..."
    open -a darktable
else
    if command -v darktable >/dev/null 2>&1; then
        echo "Ouverture de Darktable..."
        darktable &
    else
        echo "Darktable n'a pas été lancé car il n'est pas trouvé."
    fi
fi

exit 0
