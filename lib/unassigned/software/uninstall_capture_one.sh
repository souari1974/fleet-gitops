#!/bin/bash

# 1. Identification de l'utilisateur
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(dscl . -read "/Users/$CURRENT_USER" NFSHomeDirectory | awk '{print $2}')

echo "--- Désinstallation forcée de Capture One ---"

# 2. Fermeture agressive
pkill -9 -f "com.captureone"
sleep 2

# 3. Liste des cibles (Notez qu'on ne met pas de guillemets autour du tableau pour permettre l'expansion)
TARGETS=(
    "/Applications/Capture One"*.app
    "/Users/Shared/Capture One"
    "$USER_HOME/Library/Application Support/Capture One"
    "$USER_HOME/Library/Caches/com.captureone.captureone"*
    "$USER_HOME/Library/Logs/com.captureone."*
    "$USER_HOME/Library/Preferences/com.captureone.captureone"*".plist"
)

# 4. Suppression des dossiers système (Var Folders)
find /private/var/folders -type d -name "*com.captureone*" -exec rm -rf {} + 2>/dev/null

# 5. Suppression des fichiers avec gestion rigoureuse des espaces
for item in "${TARGETS[@]}"; do
    # On utilise un test d'existence sur chaque élément trouvé par le joker
    if [ -e "$item" ]; then
        echo "Suppression : $item"
        rm -rf "$item"
    fi
done

echo "--- Désinstallation terminée ---"