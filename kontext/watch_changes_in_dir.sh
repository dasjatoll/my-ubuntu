#!/usr/bin/env bash
#
# recent-files.sh – 🐝 Dateien der letzten 60 Minuten
# Rechtsklick auf einen Ordner → Skripte → recent-files.sh
#

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ---------- Zielordner bestimmen ----------
if [ -n "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}" ]; then
    TARGET=$(echo "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -n1 | tr -d '\r\n')
elif [ -n "${1:-}" ]; then
    TARGET="$1"
else
    TARGET="."
fi

# ---------- Hilfsfunktionen ----------
has_cmd() { command -v "$1" &>/dev/null; }

show_gui() {
    local content="$1"
    local title="${2:-🐝 Kürzlich geändert}"
    if has_cmd yad; then
        echo -e "$content" | yad --text-info \
            --title="$title" \
            --width=1000 --height=650 \
            --fontname="Monospace 10" \
            --button="Schließen":0 \
            --window-icon="folder" \
            --center 2>/dev/null
    elif has_cmd zenity; then
        echo -e "$content" | zenity --text-info \
            --title="$title" \
            --width=1000 --height=650 \
            --font="Monospace 10" \
            --ok-label="Schließen" 2>/dev/null
    else
        echo "$content"
    fi
}

# ---------- Prüfungen ----------
if [ ! -d "$TARGET" ]; then
    show_gui "❌ Fehler\n\n'$TARGET' ist kein gültiges Verzeichnis." "🐝 Fehler"
    exit 1
fi

TARGET="$(realpath "$TARGET" 2>/dev/null || echo "$TARGET")"

# ---------- Dateien finden (letzte 60 Minuten) ----------
# %T+ liefert ISO-Datum (besser sortier- und lesbar)
FILES=$(find "$TARGET" -type f -mmin -60 -printf "%T+\t%s\t%P\n" 2>/dev/null | sort -r)

if [ -z "$FILES" ]; then
    show_gui "🐝 Keine Dateien in den letzten 60 Minuten geändert.

Ordner: $TARGET
Zeitpunkt: $(date '+%Y-%m-%d %H:%M:%S')" "🐝 Kürzlich geändert"
    exit 0
fi

# ---------- Formatieren ----------
FORMATTED=$(echo "$FILES" | awk -F'\t' '
function human(n) {
    if (n < 1024)        return n " B"
    if (n < 1048576)     return sprintf("%.1f KB", n/1024)
    if (n < 1073741824)  return sprintf("%.1f MB", n/1048576)
    return sprintf("%.1f GB", n/1073741824)
}
{
    datetime = $1          # 2026-08-02+00:35:12.1234567890
    size     = $2
    path     = $3

    # Datum lesbar machen: 2026-08-02 00:35
    split(datetime, a, "+")
    date_part = a[1]
    time_part = substr(a[2], 1, 5)
    date_str = date_part " " time_part

    size_h = human(size)

    if (length(path) > 58)
        path = substr(path, 1, 55) "..."

    printf "%-58s  %10s  %s\n", path, size_h, date_str
}')

count=$(echo "$FILES" | wc -l | tr -d ' ')

HEADER="🐝 Dateien geändert in den letzten 60 Minuten
Ordner   : $TARGET
Zeitpunkt: $(date '+%Y-%m-%d %H:%M:%S')
Anzahl   : $count
════════════════════════════════════════════════════════════

Pfad                                                        Größe        Geändert
----                                                        -----        --------
"

OUTPUT="${HEADER}${FORMATTED}

════════════════════════════════════════════════════════════
🐝 Fertig"

# ---------- Anzeigen ----------
show_gui "$OUTPUT" "🐝 Kürzlich geändert – $(basename "$TARGET")"