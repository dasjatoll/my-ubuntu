#!/usr/bin/env bash
#
# mirror-sync.sh – Ordner spiegeln (rsync --delete)
# Rechtsklick auf einen oder mehrere Ordner → Skripte → mirror-sync.sh
#
# ⚠️  ACHTUNG: Dateien, die im Ziel existieren, aber in der Quelle fehlen,
#     werden GELÖSCHT. Das ist kein Backup!
#

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

LOG_DIR="$HOME/backup"
MAX_LOG_DAYS=7

# ---------- Hilfsfunktionen ----------
has_cmd() { command -v "$1" &>/dev/null; }

show_error() {
    local msg="$1"
    if has_cmd yad; then
        yad --error --title="🐝 Mirror Sync" --text="$msg" --button="OK":0 --width=420 2>/dev/null
    else
        echo "Fehler: $msg" >&2
    fi
}

show_info() {
    local msg="$1"
    if has_cmd yad; then
        yad --info --title="🐝 Mirror Sync" --text="$msg" --button="OK":0 --width=480 2>/dev/null
    else
        echo "$msg"
    fi
}

ask_question() {
    local msg="$1"
    if has_cmd yad; then
        yad --question --title="🐝 Mirror Sync – Warnung" \
            --text="$msg" \
            --button="Abbrechen":1 \
            --button="Ja, spiegeln":0 \
            --width=520 2>/dev/null
        return $?
    else
        echo "$msg"
        echo -n "Fortfahren? (j/N): "
        read -r answer
        [[ "$answer" =~ ^[JjYy]$ ]]
        return $?
    fi
}

# ---------- Voraussetzungen ----------
if [ $# -eq 0 ]; then
    show_error "Keine Ordner ausgewählt.\n\nRechtsklick auf einen oder mehrere Ordner\n→ Skripte → mirror-sync.sh"
    exit 1
fi

if ! has_cmd rsync; then
    show_error "Fehlendes Programm: rsync\n\nInstallieren mit:\nsudo apt install rsync"
    exit 1
fi

# ---------- Zielordner wählen ----------
if has_cmd yad; then
    TARGET=$(yad --file \
        --directory \
        --title="🐝 Zielordner für Mirror auswählen" \
        --filename="$HOME/" \
        --width=800 --height=500 \
        --button="Abbrechen":1 \
        --button="Auswählen":0 \
        2>/dev/null)
    # yad gibt bei Abbrechen Exit-Code 1 zurück
    if [ $? -ne 0 ] || [ -z "$TARGET" ]; then
        show_info "Kein Zielordner ausgewählt.\nVorgang abgebrochen."
        exit 0
    fi
elif has_cmd zenity; then
    TARGET=$(zenity --file-selection \
        --title="Zielordner für Mirror auswählen" \
        --directory \
        --filename="$HOME/" 2>/dev/null)
    if [ -z "$TARGET" ]; then
        show_info "Kein Zielordner ausgewählt.\nVorgang abgebrochen."
        exit 0
    fi
else
    show_error "Weder yad noch zenity gefunden.\nKann keinen Ordner-Dialog öffnen."
    exit 1
fi

# Zielordner anlegen falls nötig
if [ ! -d "$TARGET" ]; then
    if ask_question "Zielordner existiert nicht:\n$TARGET\n\nSoll er erstellt werden?"; then
        mkdir -p "$TARGET" || {
            show_error "Konnte Ordner nicht erstellen:\n$TARGET"
            exit 1
        }
    else
        exit 0
    fi
fi

# ---------- Starke Warnung ----------
folder_list=""
for f in "$@"; do
    folder_list+="• $(basename "$f")\n"
done

warning_text="Du bist dabei, folgende Ordner zu SPIEGELN:

$folder_list
Ziel: $TARGET

⚠️  WICHTIG:
• Dateien im Ziel, die in der Quelle fehlen, werden GELÖSCHT
• Existierende Dateien werden überschrieben
• Das ist KEIN Backup!

Wirklich fortfahren?"

if ! ask_question "$warning_text"; then
    show_info "Abgebrochen."
    exit 0
fi

# ---------- Log vorbereiten ----------
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${TIMESTAMP}-mirror-func.log"

{
    echo "════════════════════════════════════════"
    echo "🐝 Mirror Sync Log"
    echo "Datum : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Ziel  : $TARGET"
    echo "════════════════════════════════════════"
    echo
} > "$LOG_FILE"

# ---------- Synchronisation ----------
success=0
failed=0
result_text=""

for source in "$@"; do
    [ -d "$source" ] || {
        echo "Übersprungen (kein Ordner): $source" >> "$LOG_FILE"
        ((failed++)) || true
        continue
    }

    name="$(basename "$source")"
    dest="$TARGET/$name"

    echo "────────────────────────────────────────" >> "$LOG_FILE"
    echo "Sync: $name" >> "$LOG_FILE"
    echo "Von : $source" >> "$LOG_FILE"
    echo "Nach: $dest" >> "$LOG_FILE"
    echo "Start: $(date '+%H:%M:%S')" >> "$LOG_FILE"

    if rsync -a --delete --info=stats2 "$source/" "$dest/" >> "$LOG_FILE" 2>&1; then
        echo "Status: ✅ Erfolg" >> "$LOG_FILE"
        result_text+="✅  $name\n"
        ((success++)) || true
    else
        echo "Status: ❌ Fehler" >> "$LOG_FILE"
        result_text+="❌  $name\n"
        ((failed++)) || true
    fi

    echo "Ende : $(date '+%H:%M:%S')" >> "$LOG_FILE"
    echo >> "$LOG_FILE"
done

# ---------- Alte Logs aufräumen ----------
find "$LOG_DIR" -name "mirror_*.log" -type f -mtime +$MAX_LOG_DAYS -delete 2>/dev/null || true

# ---------- Ergebnis ----------
if [ $success -gt 0 ] && [ $failed -eq 0 ]; then
    title="🐝 Mirror Sync – Erfolgreich"
    msg="Alle Ordner wurden gespiegelt.\n\n$result_text\nZiel: $TARGET\nLog: $LOG_FILE"
elif [ $success -gt 0 ]; then
    title="🐝 Mirror Sync – Teilweise erfolgreich"
    msg="Erfolgreich: $success\nFehler: $failed\n\n$result_text\nLog: $LOG_FILE"
else
    title="🐝 Mirror Sync – Fehlgeschlagen"
    msg="Nichts konnte synchronisiert werden.\n\nLog: $LOG_FILE"
fi

show_info "$msg"