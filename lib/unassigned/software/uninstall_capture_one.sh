#!/bin/bash
#
# Désinstallation forcée de Capture One — version Fleet MDM
# Exécuté en root par orbit/fleetd. Pas de session GUI garantie.
#
# Codes de sortie :
#   0 = succès (qu'il y ait eu quelque chose à faire ou non)
#   1 = erreur fatale (rare — on essaie de finir le job quoi qu'il arrive)
#

# Pas de "set -e" ni "set -u" : on veut que le script aille au bout
# même si une cible n'existe pas. Fleet veut un exit 0 propre.

LOG_PREFIX="[capture-one-uninstall]"
log() { echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') $*"; }

log "=== Début désinstallation Capture One ==="
log "Hostname : $(hostname)"
log "User exécutant : $(whoami) (uid=$EUID)"

# --- 0. Sanity check : on doit être root ---
if [[ $EUID -ne 0 ]]; then
    log "ERREUR : ce script doit être lancé en root (Fleet le fait normalement)."
    exit 1
fi

# --- 1. Fermeture des processus ---
log "[1/6] Fermeture des processus Capture One..."
KILLED=0
if pgrep -f "Capture One" >/dev/null 2>&1; then
    pkill -9 -f "Capture One" 2>/dev/null && KILLED=$((KILLED+1))
fi
if pgrep -f "com.captureone" >/dev/null 2>&1; then
    pkill -9 -f "com.captureone" 2>/dev/null && KILLED=$((KILLED+1))
fi
[ "$KILLED" -gt 0 ] && sleep 2
log "  Processus tués : $KILLED groupe(s)"

# --- 2. Détecter les utilisateurs réels (pas système) ---
# On filtre les UID >= 500 et un home valide. Évite _spotlight, _mdmclient, etc.
REAL_USERS=()
while IFS= read -r user_home; do
    user=$(basename "$user_home")
    [[ "$user" == "Shared" || "$user" == "Guest" || "$user" == ".localized" ]] && continue
    [ ! -d "$user_home" ] && continue
    uid=$(id -u "$user" 2>/dev/null) || continue
    [ "$uid" -lt 500 ] && continue
    REAL_USERS+=("$user")
done < <(find /Users -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

log "  Utilisateurs détectés : ${REAL_USERS[*]:-aucun}"

# --- 3. Retrait du Dock pour chaque utilisateur ---
log "[2/6] Nettoyage du Dock..."
for user in "${REAL_USERS[@]}"; do
    user_home="/Users/$user"
    DOCK_PLIST="$user_home/Library/Preferences/com.apple.dock.plist"
    [ ! -f "$DOCK_PLIST" ] && continue

    USER_UID=$(id -u "$user" 2>/dev/null) || continue

    # Compter proprement les entrées persistent-apps
    PLIST_COUNT=0
    while sudo -u "$user" /usr/libexec/PlistBuddy \
            -c "Print :persistent-apps:$PLIST_COUNT" "$DOCK_PLIST" >/dev/null 2>&1; do
        PLIST_COUNT=$((PLIST_COUNT + 1))
        # Garde-fou : pas plus de 200 itérations
        [ "$PLIST_COUNT" -gt 200 ] && break
    done

    [ "$PLIST_COUNT" -eq 0 ] && continue

    REMOVED=0
    for ((i=PLIST_COUNT-1; i>=0; i--)); do
        APP_URL=$(sudo -u "$user" /usr/libexec/PlistBuddy \
            -c "Print :persistent-apps:$i:tile-data:file-data:_CFURLString" \
            "$DOCK_PLIST" 2>/dev/null || echo "")

        if [[ "$APP_URL" == *"Capture%20One"* ]] || [[ "$APP_URL" == *"Capture One"* ]]; then
            sudo -u "$user" /usr/libexec/PlistBuddy \
                -c "Delete :persistent-apps:$i" "$DOCK_PLIST" 2>/dev/null \
                && REMOVED=$((REMOVED + 1))
        fi
    done

    if [ "$REMOVED" -gt 0 ]; then
        log "  [$user] $REMOVED entrée(s) Capture One retirée(s) du Dock"

        # Recharger Dock + cfprefsd dans le contexte utilisateur SI session active
        # launchctl asuser échoue silencieusement si pas de session — c'est OK,
        # le plist est déjà modifié sur disque, ça s'appliquera au prochain login.
        if launchctl asuser "$USER_UID" sudo -u "$user" true 2>/dev/null; then
            sudo -u "$user" launchctl asuser "$USER_UID" killall cfprefsd 2>/dev/null || true
            sudo -u "$user" launchctl asuser "$USER_UID" killall Dock     2>/dev/null || true
            log "  [$user] Dock rechargé (session active)"
        else
            log "  [$user] Pas de session GUI — modifs prises au prochain login"
        fi
    fi
done

# --- 4. Suppression des dossiers temporaires système ---
log "[3/6] Nettoyage de /private/var/folders..."
VAR_REMOVED=$(find /private/var/folders -type d -name "*com.captureone*" -prune -print 2>/dev/null | wc -l | tr -d ' ')
find /private/var/folders -type d -name "*com.captureone*" -prune -exec rm -rf {} + 2>/dev/null
log "  $VAR_REMOVED dossier(s) supprimé(s)"

# --- 5. Suppression des cibles globales ---
log "[4/6] Suppression des fichiers globaux..."
GLOBAL_TARGETS=(
    /Applications/Capture\ One*.app
    "/Users/Shared/Capture One"
    /Library/LaunchDaemons/com.captureone.*
    /Library/LaunchAgents/com.captureone.*
    /Library/Application\ Support/Capture\ One
    "/Library/Application Support/Capture One"
)

GLOBAL_COUNT=0
for item in "${GLOBAL_TARGETS[@]}"; do
    if [ -e "$item" ]; then
        log "  Suppression : $item"
        rm -rf "$item" 2>/dev/null && GLOBAL_COUNT=$((GLOBAL_COUNT+1))
    fi
done
log "  $GLOBAL_COUNT élément(s) global(aux) supprimé(s)"

# --- 6. Suppression des données par utilisateur ---
log "[5/6] Suppression des données utilisateur..."
USER_COUNT=0
for user in "${REAL_USERS[@]}"; do
    user_home="/Users/$user"

    USER_TARGETS=(
        "$user_home/Library/Application Support/Capture One"
        "$user_home/Library/Caches/com.captureone.captureone"*
        "$user_home/Library/Containers/com.captureone."*
        "$user_home/Library/Group Containers/"*captureone*
        "$user_home/Library/Logs/com.captureone."*
        "$user_home/Library/Preferences/com.captureone."*.plist
        "$user_home/Library/Saved Application State/com.captureone."*
        "$user_home/Library/HTTPStorages/com.captureone."*
        "$user_home/Library/WebKit/com.captureone."*
    )

    for item in "${USER_TARGETS[@]}"; do
        if [ -e "$item" ]; then
            log "  [$user] $item"
            rm -rf "$item" 2>/dev/null && USER_COUNT=$((USER_COUNT+1))
        fi
    done
done
log "  $USER_COUNT élément(s) utilisateur supprimé(s)"

# --- 7. Oubli des reçus pkg ---
log "[6/6] Oubli des reçus pkg..."
PKG_COUNT=0
if command -v pkgutil >/dev/null 2>&1; then
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        log "  pkgutil --forget $pkg"
        pkgutil --forget "$pkg" >/dev/null 2>&1 && PKG_COUNT=$((PKG_COUNT+1))
    done < <(pkgutil --pkgs 2>/dev/null | grep -i "captureone")
fi
log "  $PKG_COUNT reçu(s) pkg oublié(s)"

# --- Vérification finale ---
log "=== Vérification finale ==="
REMAINING=$(find /Applications -maxdepth 2 -iname "Capture One*.app" 2>/dev/null | head -5)
if [ -n "$REMAINING" ]; then
    log "ATTENTION : restes détectés dans /Applications :"
    echo "$REMAINING" | while read -r r; do log "  $r"; done
else
    log "OK : aucun .app Capture One restant dans /Applications"
fi

log "=== Désinstallation terminée ==="
exit 0
