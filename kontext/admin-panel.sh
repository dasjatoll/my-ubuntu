#!/usr/bin/env bash
#
# admin-panel.sh – 🐝 Admin Special Panel
# Sammlung seltener, aber nützlicher Werkzeuge
#
# Nutzung:
#   • Aus Nautilus: Rechtsklick → Skripte → admin-panel.sh
#   • Aus Terminal: ./admin-panel.sh
#   • Optional Datei mitgeben: ./admin-panel.sh /pfad/zur/datei
#

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ---------- Hilfsfunktionen ----------
has_cmd() { command -v "$1" &>/dev/null; }

show_text() {
    local content="$1"
    local title="${2:-🐝 Admin Panel}"
    if has_cmd yad; then
        echo -e "$content" | yad --text-info \
            --title="$title" \
            --width=1000 --height=650 \
            --fontname="Monospace 10" \
            --button="Schließen":0 \
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

show_error() {
    local msg="$1"
    if has_cmd yad; then
        yad --error --title="🐝 Admin Panel" --text="$msg" --button="OK":0 --width=400 2>/dev/null
    else
        echo "Fehler: $msg" >&2
    fi
}

ask_input() {
    local prompt="$1"
    local default="${2:-}"
    if has_cmd yad; then
        yad --entry --title="🐝 Admin Panel" --text="$prompt" \
            --entry-text="$default" --width=450 2>/dev/null
    elif has_cmd zenity; then
        zenity --entry --title="Admin Panel" --text="$prompt" \
            --entry-text="$default" 2>/dev/null
    else
        echo -n "$prompt: "
        read -r answer
        echo "$answer"
    fi
}

# ---------- Die eigentlichen Funktionen ----------

# 1. Passwort generieren
do_genpass() {
    local len=128
    local marker="@@@@@@@@@"
    local body_len=$((len - ${#marker}))
    local raw_bytes=$((body_len * 3))
    local body=""

    while [ ${#body} -lt "$body_len" ]; do
        body+=$(openssl rand -base64 "$raw_bytes" 2>/dev/null | tr -dc 'a-zA-Z0-9!#$%^&*_-')
    done
    body="${body:0:$body_len}"
    local pos=$((RANDOM % (body_len + 1)))
    local pass="${body:0:$pos}${marker}${body:$pos}"

    show_text "🔐 Generiertes Passwort (${len} Zeichen)

$pass

(Mindestens ein Sonderzeichen-Block ist eingebaut)"
}

# 2. Checksumme einer Datei
do_checksum() {
    local file="$1"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        file=$(ask_input "Pfad zur Datei:")
    fi
    if [ ! -f "$file" ]; then
        show_error "Datei nicht gefunden:\n$file"
        return
    fi

    local out
    out="$( {
        echo "📄 $(basename "$file")"
        echo "📍 $(realpath "$file" 2>/dev/null || echo "$file")"
        echo
        echo "md5   : $(md5sum "$file"    | cut -d' ' -f1)"
        echo "sha1  : $(sha1sum "$file"   | cut -d' ' -f1)"
        echo "sha256: $(sha256sum "$file" | cut -d' ' -f1)"
        echo "sha512: $(sha512sum "$file" | cut -d' ' -f1)"
    } )"
    show_text "$out" "🐝 Checksumme"
}

# 3. Schneller Ping-Test
do_quick_ping() {
    local out
    out="$( {
        for target in 8.8.8.8 1.1.1.1 google.com; do
            echo "🔹 $target"
            ping -c 3 -W 1 "$target" 2>&1 | tail -3
            echo
        done
    } )"
    show_text "$out" "🐝 Quick Ping"
}

# 4. Port prüfen
do_port_check() {
    local host port
    host=$(ask_input "Host / IP:" "127.0.0.1")
    [ -z "$host" ] && return
    port=$(ask_input "Port:" "80")
    [ -z "$port" ] && return

    local result
    if timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        result="✅ Port $port ist OFFEN auf $host"
    else
        result="❌ Port $port ist GESCHLOSSEN auf $host"
    fi
    show_text "$result" "🐝 Port-Check"
}

# 5. Externe IP
do_external_ip() {
    local ip
    ip=$(curl -s -m 4 ifconfig.me 2>/dev/null || curl -s -m 4 icanhazip.com 2>/dev/null || echo "Nicht erreichbar")
    show_text "🌐 Externe IP-Adresse:

$ip" "🐝 External IP"
}

# 6. WLAN-Info
do_wifi_info() {
    if ! has_cmd nmcli; then
        show_error "nmcli nicht gefunden.\n(NetworkManager wird benötigt)"
        return
    fi
    local out
    out="$(nmcli -f ACTIVE,SSID,SIGNAL,SECURITY,CHAN device wifi list 2>/dev/null | head -20)"
    show_text "📡 WLAN-Übersicht

$out" "🐝 Wi-Fi Info"
}

# 7. System-Kurzcheck
do_syscheck() {
    local out
    out="$( {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo
        echo "── CPU Top ──"
        ps aux --sort=-%cpu | awk 'NR<=5 && NR>1 {printf "  %-6s %s\n", $3"%", $11}'
        echo
        echo "── MEM Top ──"
        ps aux --sort=-%mem | awk 'NR<=5 && NR>1 {printf "  %-6s %s\n", $4"%", $11}'
        echo
        echo "Connections ESTAB: $(ss -tan 2>/dev/null | awk 'NR>1 && $2=="ESTAB" {c++} END {print c+0}')"
        echo "Load: $(uptime | sed 's/.*load average: //')"
    } )"
    show_text "$out" "🐝 System-Check"
}

# 8. Text in Dateien suchen
do_find_in_file() {
    local pattern dir
    pattern=$(ask_input "Suchbegriff:")
    [ -z "$pattern" ] && return
    dir=$(ask_input "Verzeichnis (leer = aktuelles):" ".")
    [ -z "$dir" ] && dir="."

    local out
    out="$(grep -rniI \
        --exclude-dir={.git,node_modules,vendor,venv,.cache,__pycache__,dist,build,proc,sys,dev,run,snap} \
        --exclude=*.{png,jpg,jpeg,gif,svg,ico,exe,bin,o,so,pdf,zip,tar,gz} \
        "$pattern" "$dir" 2>/dev/null | head -200)"

    if [ -z "$out" ]; then
        out="Keine Treffer für „$pattern“ in $dir"
    fi
    show_text "$out" "🐝 Suche in Dateien"
}

# 9. Dateien nach Namen finden
do_find_files() {
    local pattern dir
    pattern=$(ask_input "Dateiname enthält:")
    [ -z "$pattern" ] && return
    dir=$(ask_input "Verzeichnis (leer = $HOME):" "$HOME")
    [ -z "$dir" ] && dir="$HOME"

    local out
    if has_cmd locate; then
        out="$(locate -i "*$pattern*" 2>/dev/null | head -150)"
    else
        out="$(find "$dir" \
            \( -path '*/.git' -o -path '*/node_modules' -o -path '*/vendor' \
               -o -path '*/venv' -o -path '*/__pycache__' -o -path '*/dist' \
               -o -path '*/build' -o -path '/proc' -o -path '/sys' \
               -o -path '/dev' -o -path '/run' -o -path '/snap' \) -prune -o \
            -type f -iname "*$pattern*" -print 2>/dev/null | head -150)"
    fi

    if [ -z "$out" ]; then
        out="Keine Dateien gefunden für „$pattern“"
    fi
    show_text "$out" "🐝 Dateien finden"
}

# ---------- Hauptmenü ----------
choice=$(yad --list \
    --title="🐝 Admin Special Panel" \
    --width=480 --height=420 \
    --column="Aktion" \
    --button="Abbrechen":1 \
    --button="Ausführen":0 \
    "🔐  Passwort generieren" \
    "📄  Checksumme einer Datei" \
    "🏓  Quick Ping (8.8.8.8 / 1.1.1.1 / google)" \
    "🔌  Port prüfen" \
    "🌐  Externe IP anzeigen" \
    "📡  WLAN-Info" \
    "📊  System-Kurzcheck" \
    "🔍  Text in Dateien suchen" \
    "📁  Dateien nach Namen finden" \
    2>/dev/null)

[ $? -ne 0 ] && exit 0
[ -z "$choice" ] && exit 0

# Datei, die von Nautilus mitgegeben wurde (für Checksumme)
SELECTED_FILE="${1:-}"

case "$choice" in
    *"Passwort"*)     do_genpass ;;
    *"Checksumme"*)   do_checksum "$SELECTED_FILE" ;;
    *"Ping"*)         do_quick_ping ;;
    *"Port"*)         do_port_check ;;
    *"Externe IP"*)   do_external_ip ;;
    *"WLAN"*)         do_wifi_info ;;
    *"System"*)       do_syscheck ;;
    *"Text in"*)      do_find_in_file ;;
    *"Dateien nach"*) do_find_files ;;
esac