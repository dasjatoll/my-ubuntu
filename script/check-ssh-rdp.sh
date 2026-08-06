#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}      ADVANCED REMOTE SCAN (Ubuntu)     ${NC}"
echo -e "${CYAN}==========================================${NC}"

# --- SSH SEKTION (erweitert & tiefgehend) ---
echo -e "\n${GREEN}[1] SSH - Server, Schlüssel & Sitzungen${NC}"

# 1.1 SSH-Dienst prüfen
if pgrep -x "sshd" > /dev/null; then
    echo -e "${GREEN}✔ SSH-Dienst (sshd) läuft.${NC}"
else
    echo -e "${RED}✘ SSH-Dienst läuft NICHT.${NC}"
fi

# 1.2 Konfiguration aus /etc/ssh/sshd_config auslesen
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    echo -e "\n${YELLOW}--- Server-Konfiguration (aus $SSHD_CONFIG) ---${NC}"

    # Port(s)
    PORTS=$(grep -E "^\s*Port\s+" "$SSHD_CONFIG" | awk '{print $2}')
    if [ -n "$PORTS" ]; then
        echo -e "${CYAN}Port(s):${NC} $PORTS"
    else
        echo -e "${CYAN}Port(s):${NC} 22 (Standard, nicht explizit gesetzt)"
    fi

    # ListenAddress
    LISTEN=$(grep -E "^\s*ListenAddress\s+" "$SSHD_CONFIG" | awk '{print $2}')
    if [ -n "$LISTEN" ]; then
        echo -e "${CYAN}ListenAddress:${NC} $LISTEN"
    else
        echo -e "${CYAN}ListenAddress:${NC} 0.0.0.0 (Standard)"
    fi

    # Wichtige Parameter (nur anzeigen, wenn sie nicht auskommentiert sind)
    for param in "PermitRootLogin" "PasswordAuthentication" "PubkeyAuthentication" \
                 "ChallengeResponseAuthentication" "UsePAM" "X11Forwarding" \
                 "MaxAuthTries" "ClientAliveInterval" "ClientAliveCountMax"; do
        value=$(grep -E "^\s*$param\s+" "$SSHD_CONFIG" | awk '{print $2}')
        if [ -n "$value" ]; then
            echo -e "${CYAN}$param:${NC} $value"
        fi
    done

    # AllowUsers / AllowGroups
    for param in "AllowUsers" "AllowGroups" "DenyUsers" "DenyGroups"; do
        value=$(grep -E "^\s*$param\s+" "$SSHD_CONFIG" | sed 's/^[[:space:]]*//')
        if [ -n "$value" ]; then
            echo -e "${CYAN}$param:${NC} $value"
        fi
    done

    # Ciphers, MACs, KexAlgorithms (falls gesetzt)
    for param in "Ciphers" "MACs" "KexAlgorithms"; do
        value=$(grep -E "^\s*$param\s+" "$SSHD_CONFIG" | awk '{print $2}')
        if [ -n "$value" ]; then
            echo -e "${CYAN}$param:${NC} $value"
        fi
    done
else
    echo -e "${RED}sshd_config nicht gefunden!${NC}"
fi

# 1.3 Host-Schlüssel (Server-Schlüssel)
echo -e "\n${YELLOW}--- Host-Schlüssel (Server) ---${NC}"
HOST_KEYS=$(ls -l /etc/ssh/ssh_host_*_key 2>/dev/null)
if [ -n "$HOST_KEYS" ]; then
    echo "$HOST_KEYS" | while read line; do
        # extrahiere Dateiname und Berechtigungen
        file=$(echo "$line" | awk '{print $NF}')
        perm=$(echo "$line" | awk '{print $1}')
        echo -e "${CYAN}$(basename $file)${NC} (Berechtigung: $perm)"
    done
else
    echo "Keine Host-Schlüssel gefunden (möglicherweise in anderem Pfad)."
fi

# 1.4 Aktive SSH-Sitzungen
echo -e "\n${YELLOW}--- Aktive SSH-Sitzungen (aktuell eingeloggt) ---${NC}"
# Zeige Benutzer mit TTY (pts) – das sind meist SSH
who -u | grep -E "pts/[0-9]+" | while read line; do
    echo -e "  ${GREEN}$line${NC}"
done
# Falls keine, gib Meldung
if [ -z "$(who -u | grep pts)" ]; then
    echo "Keine aktiven SSH-Sitzungen."
fi

# Zusätzlich: letzte 3 Anmeldungen (via SSH)
echo -e "\n${YELLOW}--- Letzte SSH-Anmeldungen (last 3) ---${NC}"
last -n 3 -a | grep -E "pts/[0-9]+" | while read line; do
    echo -e "  ${GREEN}$line${NC}"
done

# 1.5 Benutzerschlüssel (für aktuellen Benutzer)
echo -e "\n${YELLOW}--- Benutzerschlüssel (~/.ssh/) ---${NC}"
if [ -d ~/.ssh ]; then
    # authorized_keys
    if [ -f ~/.ssh/authorized_keys ]; then
        count=$(grep -v '^[[:space:]]*#' ~/.ssh/authorized_keys | grep -v '^$' | wc -l)
        echo -e "${CYAN}authorized_keys:${NC} $count Schlüssel"
        # Zeige Kommentare (letztes Feld nach Leerzeichen) der ersten 5 Schlüssel
        grep -v '^[[:space:]]*#' ~/.ssh/authorized_keys | grep -v '^$' | head -5 | while read key; do
            comment=$(echo "$key" | awk '{print $NF}')
            if [ -n "$comment" ] && [ "$comment" != " " ]; then
                echo "  - $comment"
            fi
        done
        # Falls mehr als 5, Hinweis
        if [ $count -gt 5 ]; then
            echo "  ... und $((count-5)) weitere"
        fi
    else
        echo "Keine authorized_keys-Datei gefunden."
    fi

    # Private/öffentliche Schlüssel (id_*)
    id_files=$(ls ~/.ssh/id_* 2>/dev/null)
    if [ -n "$id_files" ]; then
        echo -e "${CYAN}Vorhandene Schlüsselpaare (id_*):${NC}"
        echo "$id_files" | while read f; do
            echo "  - $(basename $f)"
        done
    else
        echo "Keine id_*-Schlüssel gefunden."
    fi
else
    echo "~/.ssh-Verzeichnis existiert nicht."
fi

# 1.6 (Optional) Fehlgeschlagene Anmeldeversuche – nur die letzten 5 aus auth.log
if [ -f /var/log/auth.log ]; then
    echo -e "\n${YELLOW}--- Letzte fehlgeschlagene SSH-Logins (aus auth.log) ---${NC}"
    grep "Failed password" /var/log/auth.log | tail -5 | while read line; do
        echo -e "  ${RED}$line${NC}"
    done
else
    echo "auth.log nicht lesbar (kein root)."
fi

# --- RDP & REMMINA (unverändert) ---
echo -e "\n${GREEN}[2] RDP / Remmina Connection Data:${NC}"
REM_FILES=$(find ~/.local/share/remmina -name "*.remmina" 2>/dev/null)
if [ -n "$REM_FILES" ]; then
    echo -e "${YELLOW}Gefundene Remmina Profile (Extraktion von Servern):${NC}"
    for f in $REM_FILES; do
        SRV=$(grep "^server=" "$f" | cut -d= -f2)
        if [ -n "$SRV" ]; then
            echo -e "${CYAN}Datei: ${f: -30}${NC} -> ${GREEN}Ziel: $SRV${NC}"
        fi
    done
else
    echo "Keine Remmina Dateien gefunden."
fi

# --- GNOME REMOTE DESKTOP (unverändert) ---
echo -e "\n${GREEN}[3] Native Remote Desktop (GNOME):${NC}"
if [ -d ~/.local/share/gnome-remote-desktop ]; then
    echo -e "${YELLOW}System nutzt modernen Gnome-Remote-Desktop.${NC}"
    if [ -d ~/.local/share/gnome-remote-desktop/certificates ] && [ "$(ls -A ~/.local/share/gnome-remote-desktop/certificates 2>/dev/null)" ]; then
        echo "Zertifikateerkennung: OK"
    else
        echo "Keine Zertifikate gefunden (möglicherweise nicht aktiviert)."
    fi
else
    echo "Gnome-Remote-Desktop nicht eingerichtet."
fi

# --- NETWORK PORTS (nur 22 und 3389) ---
echo -e "\n${GREEN}[4] Aktive Ports (Listen):${NC}"
ss -tulpn 2>/dev/null | grep -E "(:3389|:22)" | awk '{print $5}' | sed 's/.*://' | sort -u | while read port; do
    echo -e "${CYAN}Port ${GREEN}$port${NC} aktiv"
done

echo -e "\n${CYAN}==========================================${NC}"
echo -e "${GREEN}                Scan abgeschlossen.        ${NC}"
echo -e "${CYAN}==========================================${NC}"