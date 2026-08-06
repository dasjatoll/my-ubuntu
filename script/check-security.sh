#!/bin/bash
# AO – Compact Ubuntu Security Hardening Check

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
OUT="ao_security_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee -a "$OUT") 2>&1

check() {
    local s=$1; local m=$2; local e=$3
    case $s in PASS) C=$GREEN;; FAIL) C=$RED;; WARN) C=$YELLOW;; INFO) C=$BLUE;; esac
    echo -e "${C}[$s]${NC} $m"; echo "  $e"
}

echo "=== Ubuntu Security Check – $(date) ==="

# === SSH SECURITY ===
echo -e "\n${BLUE}=== SSH SECURITY ===${NC}"

grep -q "^PermitRootLogin.*yes" /etc/ssh/sshd_config &&
    check FAIL "Root SSH login enabled" "Root login increases attack surface." ||
    check PASS "Root SSH login disabled" "Prevents brute-force attacks on root."

grep -q "^PasswordAuthentication.*yes" /etc/ssh/sshd_config &&
    check WARN "Password auth enabled" "Use SSH keys for stronger protection." ||
    check PASS "Password auth disabled" "Keys prevent password guessing."

grep -q "^Protocol.*1" /etc/ssh/sshd_config &&
    check FAIL "SSH Protocol 1 active" "Protocol 1 is insecure and deprecated." ||
    check PASS "SSH Protocol 2 used" "Modern, secure protocol."

grep -q ":*:" /etc/shadow &&
    check FAIL "Empty passwords detected" "Accounts without passwords are critical risks." ||
    check PASS "No empty passwords" "All accounts require authentication."

# === USER ACCOUNT SECURITY ===
echo -e "\n${BLUE}=== USER ACCOUNT SECURITY ===${NC}"

np_shells=$(awk -F: '($2=="" && $7!="/usr/sbin/nologin" && $7!="/bin/false"){print $1}' /etc/shadow)
[[ -n "$np_shells" ]] &&
    check FAIL "Shell-Accounts ohne Passwort: $np_shells" "Leere Passwörter erlauben Login ohne Authentifizierung." ||
    check PASS "Keine Shell-Accounts ohne Passwort" "Alle Accounts sind geschützt."

unused=$(awk -F: '($3>=1000 && $3<65534 && $7=="/bin/bash"){print $1}' /etc/passwd | head -5)
[[ -n "$unused" ]] &&
    check INFO "Bash-Accounts gefunden: $unused" "Prüfen, ob diese Accounts wirklich benötigt werden."

um=$(umask)
[[ "$um" != "022" ]] &&
    check FAIL "Umask falsch: $um" "Umask 022 verhindert welt-schreibbare Dateien." ||
    check PASS "Umask korrekt (022)" "Neue Dateien haben sichere Standardrechte."

# === FILE PERMISSIONS ===
echo -e "\n${BLUE}=== FILE PERMISSIONS ===${NC}"

p_perm=$(stat -c "%a" /etc/passwd)
[[ "$p_perm" != "644" ]] &&
    check FAIL "/etc/passwd Rechte: $p_perm" "Nur root darf schreiben, alle dürfen lesen." ||
    check PASS "/etc/passwd korrekt (644)" "Schreibschutz für root gewährleistet."

s_perm=$(stat -c "%a" /etc/shadow)
[[ "$s_perm" != "640" ]] &&
    check FAIL "/etc/shadow Rechte: $s_perm" "Passworthashes dürfen nicht lesbar sein." ||
    check PASS "/etc/shadow korrekt (640)" "Nur root und shadow-Gruppe dürfen lesen."

sudo_perm=$(stat -c "%a" /etc/sudoers)
[[ "$sudo_perm" != "440" ]] &&
    check FAIL "/etc/sudoers Rechte: $sudo_perm" "Schreibrechte würden Root-Zugriff erlauben." ||
    check PASS "/etc/sudoers korrekt (440)" "Nur root kann sudo-Regeln ändern."

# === FIREWALL ===
echo -e "\n${BLUE}=== FIREWALL CONFIGURATION ===${NC}"

if command -v ufw >/dev/null; then
    ufw_status=$(ufw status | head -1)
    echo "$ufw_status" | grep -q inactive &&
        check FAIL "UFW inaktiv" "Ohne Firewall sind Ports offen." ||
        check PASS "UFW aktiv" "Firewall reduziert Angriffsfläche."
else
    check WARN "UFW nicht installiert" "iptables/nftables müssen konfiguriert sein."
fi

open=$(ss -tuln | grep LISTEN | wc -l)
[[ "$open" -gt 20 ]] &&
    check WARN "Viele offene Ports ($open)" "Jeder offene Port ist ein Angriffsvektor."

# === AUTOMATIC SECURITY UPDATES ===
echo -e "\n${BLUE}=== AUTOMATIC SECURITY UPDATES ===${NC}"

if dpkg -l | grep -q unattended-upgrades; then
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        upd=$(grep -q "Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades)
        upg=$(grep -q "Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades)
        [[ $upd && $upg ]] &&
            check PASS "Auto security updates aktiv" "Sicherheits-Patches werden automatisch eingespielt." ||
            check WARN "unattended-upgrades installiert, aber nicht konfiguriert" "Update/Upgrade Flags fehlen."
    else
        check WARN "Config fehlt" "Ohne 20auto-upgrades laufen keine Auto-Updates."
    fi
else
    check FAIL "unattended-upgrades nicht installiert" "System erhält keine automatischen Sicherheits-Patches."
fi

# === LOG MONITORING ===
echo -e "\n${BLUE}=== LOG MONITORING ===${NC}"

systemctl is-active --quiet auditd &&
    check PASS "auditd aktiv" "Audit-Logs erfassen sicherheitsrelevante Ereignisse." ||
    check FAIL "auditd inaktiv" "Wichtige Sicherheitsereignisse werden nicht protokolliert."

systemctl is-active --quiet rsyslog &&
    check PASS "rsyslog aktiv" "Systemlogs werden gespeichert." ||
    check WARN "rsyslog inaktiv" "Ohne Logs sind Vorfälle schwer nachvollziehbar."

grep -q "MaxFileSize" /etc/rsyslog.conf &&
    check PASS "Log-Retention konfiguriert" "Logs werden lange genug gespeichert." ||
    check INFO "Log-Retention prüfen" "Empfohlen: Logs ≥90 Tage aufbewahren."

# === NETWORK SECURITY ===
echo -e "\n${BLUE}=== NETWORK SECURITY ===${NC}"

[[ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]] &&
    check WARN "IP-Forwarding aktiv" "Kann für Pivoting/MITM missbraucht werden." ||
    check PASS "IP-Forwarding deaktiviert" "System fungiert nicht als Router."

[[ "$(cat /proc/sys/net/ipv4/conf/all/send_redirects)" = "1" ]] &&
    check WARN "ICMP Redirects aktiv" "Kann für MITM genutzt werden." ||
    check PASS "ICMP Redirects deaktiviert" "Schützt vor Traffic-Umleitung."

# === KERNEL SECURITY ===
echo -e "\n${BLUE}=== KERNEL SECURITY PARAMETERS ===${NC}"

kaslr=$(cat /proc/sys/kernel/randomize_va_space)
[[ "$kaslr" = "0" ]] && check FAIL "ASLR deaktiviert" "Speicheradressen vorhersagbar."
[[ "$kaslr" = "1" ]] && check WARN "ASLR teilweise aktiv" "Volle Randomisierung erhöht Sicherheit."
[[ "$kaslr" = "2" ]] && check PASS "ASLR voll aktiv" "Erschwert Exploits."

[[ "$(cat /proc/sys/net/ipv4/tcp_syncookies)" = "1" ]] &&
    check PASS "SYN Cookies aktiv" "Schützt vor SYN-Flood." ||
    check WARN "SYN Cookies deaktiviert" "System kann überlastet werden."

# === SUMMARY ===
echo -e "\n${BLUE}=== SECURITY SUMMARY ===${NC}"
echo "Empfehlungen:"
echo "1. Root-SSH deaktivieren, SSH-Keys nutzen"
echo "2. Auto-Sicherheitsupdates aktivieren"
echo "3. Firewall konfigurieren (UFW)"
echo "4. auditd aktivieren"
echo "5. Dateirechte prüfen"
echo "6. ASLR & SYN Cookies aktiv halten"

echo -e "\nSecurity Check Complete – Report: $OUT"