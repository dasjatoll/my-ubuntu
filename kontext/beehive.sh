#!/usr/bin/env bash
#
# beehive.sh – TreeSize im Bienenstock-Look
# Rechtsklick auf einen Ordner → Skripte → beehive.sh
# 

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

MAX_DEPTH=5

# ---------- GUI ----------
show_gui() {
    local content="$1"
    local title="🐝 BeeHive – TreeSize"

    if command -v yad &>/dev/null; then
        echo -e "$content" | yad --text-info \
            --title="$title" \
            --width=1150 --height=750 \
            --fontname="Monospace 10" \
            --button="Schließen":0 \
            --window-icon="folder" \
            --center
    elif command -v zenity &>/dev/null; then
        echo -e "$content" | zenity --text-info \
            --title="$title" \
            --width=1150 --height=750 \
            --font="Monospace 10" \
            --ok-label="Schließen"
    else
        echo "$content"
    fi
}

# ---------- Helpers ----------
human() {
    awk 'function h(n){
        if (n < 1024)        return n " B"
        if (n < 1048576)     return sprintf("%.1f KB", n/1024)
        if (n < 1073741824)  return sprintf("%.1f MB", n/1048576)
        return sprintf("%.1f GB", n/1073741824)
    } {print h($1)}'
}

# ---------- Main ----------
target="${1:-}"

if [ -z "$target" ] || [ ! -d "$target" ]; then
    show_gui "🐝 Kein gültiger Ordner ausgewählt.

Rechtsklick auf einen Ordner
→ Skripte → beehive.sh"
    exit 1
fi

target="$(realpath "$target" 2>/dev/null || echo "$target")"

# Daten in Bytes sammeln (sortiert, größte zuerst)
data="$(du -B1 --max-depth="$MAX_DEPTH" "$target" 2>/dev/null | sort -nr)"

if [ -z "$data" ]; then
    show_gui "🐝 Keine Daten für:\n$target"
    exit 1
fi

total="$(echo "$data" | head -1 | awk '{print $1}')"
count="$(echo "$data" | wc -l | tr -d ' ')"

report="$( {
    echo "🐝  BeeHive – TreeSize Analyse"
    echo "════════════════════════════════════════════════════════════"
    echo "📁  Ziel      : $target"
    echo "🔢  Tiefe     : $MAX_DEPTH"
    echo "📊  Einträge  : $count"
    echo "💾  Gesamt    : $(printf "%s" "$total" | human)"
    echo "════════════════════════════════════════════════════════════"
    echo
    printf "%-48s %10s %6s  %s\n" "Pfad" "Größe" "%" "Balken"
    echo "──────────────────────────────────────────────── ────────── ────── ──────────────────────────────"

    echo "$data" | awk -v MAX="$total" -v TOTAL="$total" -v TARGET="$target" '
        function h(n) {
            if (n < 1024)        return n " B"
            if (n < 1048576)     return sprintf("%.1f KB", n/1024)
            if (n < 1073741824)  return sprintf("%.1f MB", n/1048576)
            return sprintf("%.1f GB", n/1073741824)
        }
        {
            size = $1
            path = substr($0, index($0, $2))

            if (path == TARGET) {
                path = "/"
            } else {
                sub("^" TARGET "/", "", path)
                path = "/" path
            }

            # Einrückung
            n = split(path, a, "/")
            indent = ""
            for (i = 2; i < n; i++) indent = indent "  "

            # Prozent
            pct = (TOTAL > 0) ? (size / TOTAL) * 100 : 0
            pct_str = sprintf("%5.1f", pct)

            # Balken (max 28 Zeichen)
            blen = (MAX > 0) ? int((size / MAX) * 28 + 0.5) : 0
            if (blen < 1 && size > 0) blen = 1
            if (blen > 28) blen = 28

            bar = sprintf("%*s", blen, "")
            gsub(/ /, "█", bar)
            bar = sprintf("%-28s", bar)

            pdisp = indent path
            if (length(pdisp) > 48)
                pdisp = substr(pdisp, 1, 45) "..."

            printf "%-48s %10s %s  %s\n", pdisp, h(size), pct_str, bar
        }
    '

    echo
    echo "════════════════════════════════════════════════════════════"
    echo "🐝  Fertig – Bienenstock erfolgreich gescannt"
} )"

# Datei speichern (optional, aber praktisch)
echo "$report" > "$target/BeeHive_TreeSize_depth${MAX_DEPTH}.txt" 2>/dev/null || true

# Anzeigen
show_gui "$report"
