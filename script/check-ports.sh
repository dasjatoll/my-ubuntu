#!/bin/bash
# port-check.sh – Zeigt lauschende Ports mit Erklärungen (für nora)

set -euo pipefail

# ─── Farben & Stile ────────────────────────────────────────────────
reset="\033[0m"
bold="\033[1m"
dim="\033[2m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
cyan="\033[36m"
grey="\033[38;5;244m"
red="\033[31m"

# ─── Prüfen, ob wir Root-Rechte haben ─────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${yellow}⚠️  Nicht als root ausgeführt – einige Prozesse werden nicht angezeigt.${reset}"
    echo -e "${yellow}   Für vollständige Infos: ${bold}sudo ./port-check.sh${reset}"
    echo
    SUDO=""
else
    SUDO="sudo"
fi

# ─── Kopf ──────────────────────────────────────────────────────────
echo -e "${bold}${cyan}╔════════════════════════════════════════════════════════════╗${reset}"
echo -e "${bold}${cyan}║        Port-Check für nora – Lauschende Dienste          ║${reset}"
echo -e "${bold}${cyan}╚════════════════════════════════════════════════════════════╝${reset}"
echo

# ─── 1. Alle lauschenden Ports ────────────────────────────────────
echo -e "${bold}${blue}1. Alle lauschenden Ports (TCP/UDP) – ss -tulnp${reset}"
echo -e "${grey}   Zeigt alle Sockets im Listening-Status mit Portnummern und Prozessnamen.${reset}"
echo -e "${grey}   → Spalten: Netid (tcp/udp), State (LISTEN/UNCONN), Local Address:Port, Prozess.${reset}"
echo -e "${grey}   → Ports an 127.0.0.1 sind nur lokal erreichbar, an 0.0.0.0 von überall.${reset}"
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
$SUDO ss -tulnp
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
echo

# ─── 2. Ports auf allen Schnittstellen (von außen erreichbar) ────
echo -e "${bold}${blue}2. Ports, die auf allen Schnittstellen (0.0.0.0 oder ::) lauschen${reset}"
echo -e "${grey}   Diese Ports sind potenziell von außen erreichbar – besonders wichtig für Sicherheit.${reset}"
echo -e "${grey}   → Zeigt nur Einträge mit '0.0.0.0:' oder ':::' in der Local Address.${reset}"
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
OUT=$($SUDO ss -tulnp | grep -E '0.0.0.0:|:::' | grep LISTEN || true)
if [ -z "$OUT" ]; then
    echo -e "${dim}   Keine Einträge gefunden.${reset}"
else
    echo "$OUT"
fi
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
echo

# ─── 3. Spezifische dynamische Ports aus der Nora-Doku ──────────
echo -e "${bold}${blue}3. Dynamische / ephemere Ports (35902, 39814, 41343, 43693, 45886)${reset}"
echo -e "${grey}   Diese Ports werden oft von Anwendungen für ausgehende Verbindungen oder${reset}"
echo -e "${grey}   interne Dienste genutzt. Sie sind meist nur an 127.0.0.1 gebunden.${reset}"
echo -e "${grey}   → Prüft gezielt die in der Nora-Systemdoku aufgeführten Ports.${reset}"
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
OUT=$($SUDO ss -tulnp | grep -E ':(35902|39814|41343|43693|45886)' || true)
if [ -z "$OUT" ]; then
    echo -e "${dim}   Keine dieser Ports aktiv.${reset}"
else
    echo "$OUT"
fi
echo -e "${dim}   ────────────────────────────────────────────────────────────────────────${reset}"
echo

# ─── Zusammenfassung & Tipps ──────────────────────────────────────
echo -e "${bold}${green}✓ Fertig.${reset}"
echo -e "${grey}   Hinweise zur Interpretation:${reset}"
echo -e "${grey}   • Ports mit '127.0.0.1' sind nur lokal sichtbar.${reset}"
echo -e "${grey}   • Ports mit '0.0.0.0' oder '::' sind von außen erreichbar – ggf. Firewall prüfen.${reset}"
echo -e "${grey}   • 'UNCONN' bei udp bedeutet, dass der Socket bereit ist, aber keine Verbindung aufgebaut wurde.${reset}"
echo -e "${grey}   • Mit 'sudo' werden auch die Prozessnamen von Root-Diensten angezeigt.${reset}"
echo -e "${grey}   • Die dynamischen Ports können sich bei jedem Neustart ändern – das ist normal.${reset}"