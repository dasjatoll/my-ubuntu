#!/usr/bin/env bash
#
# sysmon.sh – System-Monitoring im TreeSize‑Look
# Nutzung: ./sysmon.sh [--gui|--terminal]
#

# ---------- Sicherheitsoptionen ----------
set -euo pipefail

# ---------- Parameter einlesen ----------
MODE="auto"   # auto, gui, terminal

for arg in "$@"; do
    case "$arg" in
        --gui)      MODE="gui" ;;
        --terminal) MODE="terminal" ;;
    esac
done

# ---------- Hilfsfunktionen ----------
is_terminal() { [ -t 1 ]; }
has_gui() { command -v yad &>/dev/null || command -v zenity &>/dev/null; }

show_gui() {
    local content="$1"
    local title="🐝 sysmon.sh – System‑Monitoring"
    if command -v yad &>/dev/null; then
        echo -e "$content" | yad --text-info --title="$title" \
            --width=1100 --height=700 --fontname="Monospace 10" \
            --button="Schließen":0 --window-icon="utilities-terminal"
    elif command -v zenity &>/dev/null; then
        echo -e "$content" | zenity --text-info --title="$title" \
            --width=1100 --height=700 --font="Monospace 10" \
            --ok-label="Schließen"
    else
        echo "$content"
    fi
}

# ---------- System‑Monitoring‑Funktionen (aus deinem Snippet) ----------
mem_hogs() {
    ps aux --sort=-%mem | awk 'NR<=11 {
        if(NR==1) next;
        printf "%-8s %5s %s\n", $3"%", $4"%", $11
    }' | column -t
}

cpu_hogs() {
    ps aux --sort=-%cpu | awk 'NR<=11 {
        if(NR==1) next;
        printf "%-8s %8s %s\n", $3"%", $2, $11
    }' | column -t
}

conn_summary() {
    ss -tan | awk 'NR>1 {count[$2]++} END {for(s in count) print s": "count[s]}' | sort
    echo ""
    ss -tulpn | head -10
}

open_files() {
    lsof 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | awk '{print $2": "$1" files"}'
}

syscheck() {
    echo "=== $(date '+%H:%M:%S') ==="
    echo ""
    echo "CPU top:"
    ps aux --sort=-%cpu | awk 'NR<=4 && NR>1 {printf "  %-6s %s\n", $3"%", $11}'
    echo ""
    echo "MEM top:"
    ps aux --sort=-%mem | awk 'NR<=4 && NR>1 {printf "  %-6s %s\n", $4"%", $11}'
    echo ""
    echo "Connections: $(ss -tan | awk 'NR>1 && $2=="ESTAB" {count++} END {print count}')"
    echo "Load: $(uptime | sed 's/.*load average: //')"
}

# ---------- Daten sammeln (als Plain‑Text) ----------
collect_data() {
    {
        echo "🐝 System‑Monitoring – Übersicht"
        echo "================================"
        echo "Zeitstempel: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Host: $(hostname)"
        echo ""

        echo "─── Memory‑Hogs (Top 10) ───"
        mem_hogs
        echo ""

        echo "─── CPU‑Hogs (Top 10) ───"
        cpu_hogs
        echo ""

        echo "─── Netzwerk‑Verbindungen ───"
        conn_summary
        echo ""

        echo "─── Offene Dateihandles (Top 10) ───"
        open_files
        echo ""

        echo "─── Kurzcheck ───"
        syscheck
    }
}

# Rohdaten sammeln (für GUI und Terminal)
PLAIN_OUTPUT="$(collect_data)"

# ---------- Entscheidung: GUI oder Terminal? ----------
if [ "$MODE" = "terminal" ]; then
    USE_GUI=false
elif [ "$MODE" = "gui" ]; then
    USE_GUI=true
else
    if is_terminal && ! has_gui; then
        USE_GUI=false
    elif has_gui; then
        USE_GUI=true
    else
        USE_GUI=false
    fi
fi

# ---------- Ausgabe ----------
if [ "$USE_GUI" = true ]; then
    # GUI: einfacher Text (ohne Farben)
    show_gui "$PLAIN_OUTPUT"
else
    # Terminal: mit ANSI‑Farben für bessere Lesbarkeit
    # Farbdefinitionen
    RED=$'\033[31m'
    GRN=$'\033[32m'
    YEL=$'\033[33m'
    BLU=$'\033[34m'
    MAG=$'\033[35m'
    CYA=$'\033[36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'

    # Wir geben die gesammelten Daten aus, ersetzen aber bestimmte Schlüsselwörter
    # durch farbige Versionen (einfache Hervorhebung).
    # Dazu leiten wir PLAIN_OUTPUT durch sed/awk, um z.B. Prozessnamen farbig zu machen.
    # Hier ein einfacher Ansatz: Wir färben die Überschriften und Zahlen.
    echo "$PLAIN_OUTPUT" | awk -v RED="$RED" -v GRN="$GRN" -v YEL="$YEL" \
        -v BLU="$BLU" -v MAG="$MAG" -v CYA="$CYA" -v BOLD="$BOLD" -v RESET="$RESET" '
    BEGIN {
        # Farben für bestimmte Muster
    }
    {
        # Überschriften fett
        if ($0 ~ /^───/ || $0 ~ /^🐝/ || $0 ~ /^===/ || $0 ~ /^Zeitstempel/ || $0 ~ /^Host/) {
            print BOLD $0 RESET
        }
        # Spezifische Zahlen (z.B. Prozentsätze) hervorheben
        else if ($0 ~ /[0-9]+\.[0-9]%/) {
            # Ersetze jede Zahl mit Prozent durch gelb
            gsub(/([0-9]+\.[0-9]%)/, YEL "&" RESET);
            print $0
        }
        else {
            print $0
        }
    }'
fi