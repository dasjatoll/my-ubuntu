#!/usr/bin/env bash
#
# sysmon.sh – 🐝 System-Monitoring + Service-Dashboard
# Nutzung: ./sysmon.sh [--gui|--terminal]
# Oder als Nautilus-Skript
#

set -euo pipefail

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ---------- Parameter ----------
MODE="auto"
for arg in "$@"; do
    case "$arg" in
        --gui)      MODE="gui" ;;
        --terminal) MODE="terminal" ;;
    esac
done

# ---------- Hilfsfunktionen ----------
is_terminal() { [ -t 1 ]; }
has_gui() { command -v yad &>/dev/null || command -v zenity &>/dev/null; }
has_cmd() { command -v "$1" &>/dev/null; }

show_gui() {
    local content="$1"
    local title="🐝 sysmon – System-Monitoring"
    if has_cmd yad; then
        echo -e "$content" | yad --text-info \
            --title="$title" \
            --width=1150 --height=780 \
            --fontname="Monospace 10" \
            --button="Schließen":0 \
            --window-icon="utilities-terminal" \
            --center 2>/dev/null
    elif has_cmd zenity; then
        echo -e "$content" | zenity --text-info \
            --title="$title" \
            --width=1150 --height=780 \
            --font="Monospace 10" \
            --ok-label="Schließen" 2>/dev/null
    else
        echo "$content"
    fi
}

check_port() {
    local port="$1"
    if ss -tln 2>/dev/null | grep -q ":$port "; then
        echo "✅ Online"
    else
        echo "❌ Offline"
    fi
}

# ---------- Monitoring-Funktionen ----------
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
    ss -tan 2>/dev/null | awk 'NR>1 {count[$2]++} END {for(s in count) print s": "count[s]}' | sort
    echo ""
    ss -tulpn 2>/dev/null | head -10
}

open_files() {
    lsof 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | awk '{print $2": "$1" files"}'
}

# ---------- Daten sammeln ----------
collect_data() {
    {
        echo "🐝 System-Monitoring + Service-Dashboard"
        echo "════════════════════════════════════════════════"
        echo "Zeitstempel : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Host        : $(hostname)"
        echo "════════════════════════════════════════════════"
        echo

        # ── Performance ──
        echo "── PERFORMANCE ──"
        load=$(awk '{print $1}' /proc/loadavg)
        mem_used=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f", (t-a)/1048576}' /proc/meminfo 2>/dev/null || echo "?")
        mem_tot=$(awk '/MemTotal/{printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null || echo "?")
        echo "  Load: $load | RAM: ${mem_used} GB / ${mem_tot} GB"

        temps=""
        if [ -d /sys/class/thermal ]; then
            for t in /sys/class/thermal/thermal_zone*/temp; do
                [ -r "$t" ] && temps+="$(($(cat "$t")/1000))°C "
            done
        fi
        gpu="n/a"
        if has_cmd nvidia-smi; then
            gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "n/a")
        fi
        echo "  CPU Temp: ${temps:-n/a} | GPU: $gpu"
        echo

        # ── Storage ──
        echo "── STORAGE ──"
        df -h -x tmpfs -x devtmpfs 2>/dev/null | grep '^/' | awk '{printf "  %-12s %5s belegt  %s frei\n", $1, $5, $4}'
        echo

        # ── Memory-Hogs ──
        echo "── MEMORY-HOGS (Top 10) ──"
        mem_hogs
        echo

        # ── CPU-Hogs ──
        echo "── CPU-HOGS (Top 10) ──"
        cpu_hogs
        echo

        # ── Netzwerk ──
        echo "── NETZWERK-VERBINDUNGEN ──"
        conn_summary
        echo

        # ── Offene Dateien ──
        echo "── OFFENE DATEIHANDLES (Top 10) ──"
        open_files
        echo

        # ── Container ──
        echo "── CONTAINER ──"
        if has_cmd docker; then
            count=$(docker ps -q 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                echo "  $count Container laufen:"
                docker ps --format "    • {{.Names}}  ({{.Status}})" 2>/dev/null
            else
                echo "  Keine laufenden Container"
            fi
        else
            echo "  Docker nicht gefunden"
        fi
        echo

        # ── Services & Ports ──
        echo "── SERVICES & PORTS ──"
        echo "  Cockpit  (9090) : $(check_port 9090)"
        echo "  Netdata  (19999): $(check_port 19999)"
        echo "  RDP      (3389) : $(check_port 3389)"
        echo "  RDP      (3390) : $(check_port 3390)"
        echo "  SearXNG  (8080) : $(check_port 8080)"
        echo "  Odysseus (7000) : $(check_port 7000)"
        echo "  LM Studio(1234) : $(check_port 1234)"
        if has_cmd tailscale; then
            if tailscale status 2>/dev/null | grep -q '^[0-9]'; then
                echo "  Tailscale       : ✅ Aktiv"
            else
                echo "  Tailscale       : ❌ Inaktiv"
            fi
        else
            echo "  Tailscale       : nicht installiert"
        fi
        echo

        # ── Netzwerk / Links ──
        echo "── NETZWERK & LINKS ──"
        public_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "n/a")
        echo "  Öffentliche IP  : $public_ip"
        echo
        echo "  Quick Links:"
        echo "    SearXNG  → http://localhost:8080"
        echo "    Odysseus → http://localhost:7000"
        echo "    Cockpit  → http://localhost:9090"
        echo "    Netdata  → http://localhost:19999"
        echo
        echo "════════════════════════════════════════════════"
        echo "🐝 Fertig"
    }
}

# ---------- Ausgabe ----------
PLAIN_OUTPUT="$(collect_data)"

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

if [ "$USE_GUI" = true ]; then
    show_gui "$PLAIN_OUTPUT"
else
    # Terminal mit Farben
    RED=$'\033[31m'
    YEL=$'\033[33m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'

    echo "$PLAIN_OUTPUT" | awk -v RED="$RED" -v YEL="$YEL" -v BOLD="$BOLD" -v RESET="$RESET" '
    {
        if ($0 ~ /^──/ || $0 ~ /^🐝/ || $0 ~ /^═/ || $0 ~ /^Zeitstempel/ || $0 ~ /^Host/) {
            print BOLD $0 RESET
        }
        else if ($0 ~ /[0-9]+\.[0-9]%/) {
            gsub(/([0-9]+\.[0-9]%)/, YEL "&" RESET)
            print $0
        }
        else {
            print $0
        }
    }'
fi