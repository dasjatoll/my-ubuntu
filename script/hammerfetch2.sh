#!/bin/bash
# ============================================================
#  AO – Ubuntu System Information Script
#  need proof
#  Ausgabe in Datei: ao_sysinfo_YYYYMMDD_HHMMSS.txt
# ============================================================

OUT="ao_sysinfo_$(date +%Y%m%d_%H%M%S).txt"

# ---- Hilfsfunktionen ----
section() {
    echo -e "\n════════════════════════════════════════════════════════════" | tee -a "$OUT"
    echo "▸ $1" | tee -a "$OUT"
    echo "════════════════════════════════════════════════════════════" | tee -a "$OUT"
}

# Prüft, ob ein Befehl existiert
has_cmd() { command -v "$1" &>/dev/null; }

# Führt einen Befehl mit sudo aus, wenn möglich, sonst ohne
try_sudo() {
    if has_cmd sudo && sudo -n true 2>/dev/null; then
        sudo "$@"
    else
        "$@" 2>/dev/null || echo "  (keine Berechtigung oder Befehl fehlgeschlagen)"
    fi
}

# ---- Bedingte Aliase (nur bei interaktiver Shell oder Sourcen)
if [[ $- == *i* ]] || [ "${0}" != "${BASH_SOURCE}" ]; then
    has_cmd lshw && alias hardware_short='lshw -short'
    if has_cmd lshw; then
        if has_cmd sudo && sudo -n true 2>/dev/null; then
            alias hardware_full='sudo lshw'
        else
            alias hardware_full='lshw'
        fi
    fi
    has_cmd lspci && alias pci_devices='lspci'
    has_cmd lsusb && alias usb_devices='lsusb'
    has_cmd lsblk && alias block_devices='lsblk'
    has_cmd hdparm && alias drive_info='hdparm -I /dev/sda'
    if has_cmd smartctl; then
        if has_cmd sudo && sudo -n true 2>/dev/null; then
            alias smart_info='sudo smartctl -a /dev/sda'
        else
            alias smart_info='smartctl -a /dev/sda'
        fi
    fi
fi

# ---- Monitoring-Funktionen (kompakt)
function mem_hogs() {
    if ! has_cmd ps; then echo "ps nicht verfügbar"; return; fi
    echo "=== Top 10 Memory Consumers ==="
    if has_cmd column; then
        ps aux --sort=-%mem 2>/dev/null | awk 'NR==1{printf "%-8s %-6s %s\n","%MEM","PID","COMMAND"} NR>1 && NR<=11{printf "%6.2f %-6s %s\n",$4,$2,$11}' | column -t
    else
        ps aux --sort=-%mem 2>/dev/null | awk 'NR==1{printf "%-8s %-6s %s\n","%MEM","PID","COMMAND"} NR>1 && NR<=11{printf "%6.2f %-6s %s\n",$4,$2,$11}'
    fi
}

function cpu_hogs() {
    if ! has_cmd ps; then echo "ps nicht verfügbar"; return; fi
    echo "=== Top 10 CPU Consumers ==="
    if has_cmd column; then
        ps aux --sort=-%cpu 2>/dev/null | awk 'NR==1{printf "%-8s %-6s %s\n","%CPU","PID","COMMAND"} NR>1 && NR<=11{printf "%6.2f %-6s %s\n",$3,$2,$11}' | column -t
    else
        ps aux --sort=-%cpu 2>/dev/null | awk 'NR==1{printf "%-8s %-6s %s\n","%CPU","PID","COMMAND"} NR>1 && NR<=11{printf "%6.2f %-6s %s\n",$3,$2,$11}'
    fi
}

function conn_summary() {
    if ! has_cmd ss; then echo "ss nicht verfügbar"; return; fi
    echo "=== Active Connections (by state) ==="
    ss -tan 2>/dev/null | awk 'NR>1{count[$1]++}END{for(s in count) print s": "count[s]}' | sort
    echo ""
    echo "=== Listening Ports ==="
    ss -tulpn 2>/dev/null
}

function open_files() {
    if ! has_cmd lsof; then echo "lsof nicht verfügbar"; return; fi
    echo "=== Processes with most open files ==="
    lsof 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 | awk '{print $2": "$1" files"}'
}

function check_cmds() {
    local miss=()
    for cmd in "$@"; do
        if ! has_cmd "$cmd"; then
            miss+=("$cmd")
        fi
    done
    if [ ${#miss[@]} -eq 0 ]; then
        echo "Alle überprüften Befehle sind vorhanden."
    else
        echo "Fehlende Befehle: ${miss[*]}"
        echo "Installationshinweis: unter Debian/Ubuntu: sudo apt install <paket>" 
    fi
}

function usage() {
    cat <<'USAGE'
Verwendung: sysinfo.sh [--extras|--monitor] [--help]

  --extras, --monitor   Führe kompakte Monitoring-Funktionen aus (mem/cpu/connections/open files).
  --help                Zeigt diese Hilfe.

Hinweis: Aliase werden nur definiert, wenn das Skript gesourced oder interaktiv ausgeführt wird.
USAGE
}

function handle_extras() {
    section "MONITORING - Extras"
    mem_hogs
    echo ""
    cpu_hogs
    echo ""
    conn_summary
    echo ""
    open_files
}

# ---- CLI-Argumente verarbeiten
MODE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --extras|--monitor) MODE=extras; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unbekannte Option: $1"; usage; exit 1 ;;
    esac
done

if [ "$MODE" = "extras" ]; then
    exec > >(tee -a "$OUT") 2>&1
    handle_extras
    echo ""
    echo "✓ Extras-Bericht abgeschlossen — gespeichert unter: $OUT"
    exit 0
fi

# Leitet alle Ausgaben in Datei und Terminal um
exec > >(tee -a "$OUT") 2>&1

echo "System Report – $(date)"
echo "Ausgabe: $OUT"
echo ""

# ============================================================
section "SYSTEMÜBERBLICK"
hostnamectl 2>/dev/null || {
    echo "Hostname: $(hostname)"
    echo "Betriebssystem: $(lsb_release -d 2>/dev/null | cut -f2-)"
}
echo "Uptime: $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}')"
timedatectl 2>/dev/null | grep -E 'Time zone|Local time' || echo "Zeitzone: $(cat /etc/timezone 2>/dev/null)"
last reboot | head -n1 | awk '{print "Letzter Reboot: " $1" "$2" "$3" "$4" "$5" "$6" "$7}'

# ============================================================
section "HARDWARE"
if has_cmd lscpu; then
    lscpu | awk -F': +' '/Model name|CPU\(s\)|Architecture|MHz/ {printf "%-20s: %s\n", $1, $2}'
else
    echo "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)"
    echo "Kerne: $(nproc)"
fi

echo ""
free -h | awk 'NR==1{print "Speicher:"} NR==2{printf "  Gesamt: %s  Belegt: %s  Frei: %s  Puffer/Cache: %s\n", $2,$3,$4,$6} NR==3{printf "  Swap:   %s  Belegt: %s  Frei: %s\n", $2,$3,$4}'

echo ""
if has_cmd dmidecode && sudo -n true 2>/dev/null; then
    sudo dmidecode -t memory 2>/dev/null | grep -E "Size|Speed" | head -12 | awk '{print "  " $0}'
else
    echo "  Detaillierte RAM-Infos nicht verfügbar (kein sudo oder dmidecode fehlt)"
fi

echo ""
lsblk -f | awk 'NR==1{print "  Blockgeräte:"} NR>1{printf "  %-10s %-10s %-10s %-s\n", $1, $2, $3, $4}'

df -h | awk 'NR==1{printf "%-20s %8s %8s %8s %5s %s\n", "Dateisystem", "Größe", "Belegt", "Frei", "Nutzung", "Einhängepunkt"} NR>1{printf "%-20s %8s %8s %8s %5s %s\n", $1, $2, $3, $4, $5, $6}'

# ============================================================
section "NETZWERK"
ip -br addr show 2>/dev/null || ip addr show
echo ""
ip route show | head -5
echo ""
cat /etc/resolv.conf 2>/dev/null | grep -v '^#' | grep .
echo ""
ss -tulnp 2>/dev/null | awk 'NR==1{print "  Aktive Verbindungen (Ports):"} NR>1{printf "  %-8s %-8s %-8s %-8s %-s\n", $1, $2, $3, $4, $6}' | head -20
lspci 2>/dev/null | grep -i ethernet | sed 's/^/  /'
has_cmd sensors && sensors | head -10 || echo "  Sensoren nicht verfügbar (lm-sensors?)"

# ============================================================
section "PROZESSE & DIENSTE"
echo "--- Top 10 CPU ---"
ps aux --sort=-%cpu | awk 'NR==1{printf "%-10s %-5s %-5s %-s\n", "USER", "PID", "%CPU", "COMMAND"} NR>1 && NR<=11{printf "%-10s %-5s %5.1f  %-s\n", $1, $2, $3, $11}' | head -11

echo ""
echo "--- Top 10 RAM ---"
ps aux --sort=-%mem | awk 'NR==1{printf "%-10s %-5s %-5s %-s\n", "USER", "PID", "%MEM", "COMMAND"} NR>1 && NR<=11{printf "%-10s %-5s %5.1f  %-s\n", $1, $2, $4, $11}' | head -11

echo ""
systemctl list-units --type=service --state=running 2>/dev/null | head -15 | awk '{printf "  %-30s %s\n", $1, $2}'
echo ""
systemctl --failed 2>/dev/null | grep -v "0 loaded" || echo "  Keine fehlgeschlagenen Dienste"

# ============================================================
section "SICHERHEIT"
echo "Aktueller Nutzer: $(whoami)"
echo "Shell-Benutzer:"
grep -E "/bin/bash|/bin/sh" /etc/passwd 2>/dev/null | cut -d: -f1 | awk '{printf "  %s\n", $1}'
echo ""
echo "Gruppen: $(groups)"
echo ""
last | head -5 | awk '{printf "  %-10s %-20s %s\n", $1, $3, $4" "$5" "$6}'
echo ""
if has_cmd sudo && sudo -n true 2>/dev/null; then
    sudo chage -Q root 2>/dev/null || echo "  Passwortrichtlinie nicht abrufbar"
else
    echo "  Passwortrichtlinie nicht abrufbar (kein sudo)"
fi
echo ""
[ -f /etc/ssh/sshd_config ] && grep -v "^#" /etc/ssh/sshd_config | grep -v "^$" | head -10 | awk '{print "  " $0}'

# ============================================================
section "DATEISYSTEM & FESTPLATTEN"
df -T | awk 'NR==1{printf "%-20s %-8s %8s %8s %8s %5s %s\n", "Dateisystem", "Typ", "Größe", "Belegt", "Frei", "Nutzung", "Einhängepkt"} NR>1{printf "%-20s %-8s %8s %8s %8s %5s %s\n", $1, $2, $3, $4, $5, $6, $7}'
echo ""
df -i | awk 'NR==1{printf "%-20s %8s %8s %8s %5s %s\n", "Dateisystem", "Inodes", "Belegt", "Frei", "Nutzung", "Einhängepkt"} NR>1{printf "%-20s %8s %8s %8s %5s %s\n", $1, $2, $3, $4, $5, $6}'
echo ""
has_cmd iostat && iostat 2>/dev/null | grep -A1 "avg-cpu" || echo "  iostat nicht verfügbar (sysstat?)"
echo ""
findmnt -v 2>/dev/null | head -15 | awk '{printf "  %-20s %-10s %-10s %-s\n", $1, $2, $3, $4}'

# ============================================================
section "SPEICHERDETAILS"
vmstat 2>/dev/null | awk 'NR==1{print "  " $0} NR==2{print "  " $0} NR==3{print "  " $0}'
echo ""
cat /proc/meminfo | head -12 | awk '{printf "  %-20s %s\n", $1, $2" "$3}'
echo ""
swapon --show 2>/dev/null | awk 'NR==1{printf "  %-15s %-10s %-10s %-s\n", $1, $2, $3, $4} NR>1{printf "  %-15s %-10s %-10s %-s\n", $1, $2, $3, $4}'

# ============================================================
section "LOGS & CRON"
echo "Load Average: $(cat /proc/loadavg | awk '{print $1" "$2" "$3" (Prozesse: "$4" / "$5")"}')"
echo ""
systemctl status rsyslog 2>/dev/null | head -5 | awk '{print "  " $0}'
echo ""
journalctl -n 15 --no-pager 2>/dev/null | awk '{print "  " $0}'
echo ""
echo "Cron-Verzeichnis:"
ls -la /etc/cron.d/ 2>/dev/null | grep -v '^total' | awk '{print "  " $0}'
crontab -l 2>/dev/null | head -5 | sed 's/^/  /'

# ============================================================
section "NETZWERKDIENSTE"
ss -tulnp 2>/dev/null | awk 'NR==1{print "  " $0} NR>1{printf "  %-8s %-8s %-8s %-8s %-s\n", $1, $2, $3, $4, $6}' | head -15
echo ""
systemctl list-unit-files --type=service 2>/dev/null | grep -E "ssh|apache|nginx|mysql|postgres|docker" | head -10 | awk '{printf "  %-30s %s\n", $1, $2}'

# ============================================================
section "SOFTWARE & PAKETE"
if has_cmd apt; then
    echo "Installierte Pakete: $(dpkg --list 2>/dev/null | wc -l)"
    echo "Letzte Installationen:"
    grep " install " /var/log/dpkg.log 2>/dev/null | tail -5 | awk '{printf "  %s %s %s\n", $1, $2, $3}'
    echo ""
    echo "Kernel-Pakete:"
    dpkg --list 2>/dev/null | grep linux-image | awk '{printf "  %-30s %s\n", $2, $3}'
    echo ""
    echo "Sicherheits-Updates:"
    apt list --upgradable 2>/dev/null | grep -i security | head -10 | awk '{printf "  %s\n", $0}'
else
    echo "  apt nicht verfügbar"
fi

# ============================================================
section "BACKUP"
for tool in rsync tar gzip bzip2 pigz; do
    has_cmd "$tool" && echo "  $tool: $(which $tool)" || echo "  $tool: nicht installiert"
done
echo ""
[ -f /etc/backup.conf ] && cat /etc/backup.conf | sed 's/^/  /' || echo "  Keine backup.conf gefunden"

# ============================================================
section "PERFORMANCE"
echo "Load: $(cat /proc/loadavg | awk '{print $1" "$2" "$3}')"
echo "Prozesse: $(ps aux 2>/dev/null | wc -l)"
echo ""
has_cmd iostat && iostat 1 2 2>/dev/null | tail -6 | awk '{print "  " $0}' || echo "  iostat nicht verfügbar"

# ============================================================
section "ZUSÄTZLICHES"
ulimit -a | head -8 | awk '{printf "  %-25s %s\n", $1, $3}'
echo ""
env | grep -E "(PATH|HOME|USER|SHELL)" | awk '{printf "  %s\n", $0}'
echo ""
locale 2>/dev/null | head -5 | awk '{printf "  %s\n", $0}'
echo ""
if has_cmd apparmor_status; then
    apparmor_status 2>/dev/null | head -5 | awk '{print "  " $0}'
elif has_cmd getenforce; then
    getenforce 2>/dev/null | awk '{print "  SELinux: " $0}'
else
    echo "  Kein AppArmor/SELinux erkannt"
fi

# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════"
echo "✓ Bericht abgeschlossen – gespeichert unter: $OUT"
echo "════════════════════════════════════════════════════════════"