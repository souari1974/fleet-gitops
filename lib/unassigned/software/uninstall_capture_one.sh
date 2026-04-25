#!/bin/bash

# 1. Identification de l'utilisateur actif et de son Home
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(dscl . -read "/Users/$CURRENT_USER" NFSHomeDirectory | awk '{print $2}')

echo "--- Début du processus de nettoyage Capture One (User: $CURRENT_USER) ---"

# 2. Fermeture de l'application via son identifiant (Bundle ID)
# pkill -f cherche le motif dans le nom du processus ou ses arguments
echo "Fermeture de toutes les instances de Capture One..."
pkill -9 -f "com.captureone"

# Petite pause pour s'assurer que les descripteurs de fichiers sont libérés
sleep 2

# 3. Liste des cibles (Utilisateur, Application et Partagé)
TARGETS=(
    "/Applications/Capture One*.app"
    "/Users/Shared/Capture One"
    "$USER_HOME/Library/Application Support/Capture One"
    "$USER_HOME/Library/Caches/com.captureone.captureone*"
    "$USER_HOME/Library/Logs/com.captureone.*"
    "$USER_HOME/Library/Preferences/com.captureone.captureone*.plist"
)

# 4. Nettoyage /private/var/folders (Caches système/WebKit/GPU)
echo "Nettoyage des dossiers temporaires système..."
find /private/var/folders -type d -name "*com.captureone*" -exec rm -rf {} + 2>/dev/null

# 5. Nettoyage des dossiers de la liste TARGETS
echo "Nettoyage des fichiers Application, User et Shared..."
for item in "${TARGETS[@]}"; do
    # On laisse le shell étendre les jokers (*)
    for found in $item; do
        if [ -e "$found" ]; then
            echo "Suppression : $found"
            rm -rf "$found"
        fi
    done
done

echo "--- Nettoyage terminé avec succès ---"
exit 0