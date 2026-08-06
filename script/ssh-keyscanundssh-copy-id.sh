#!/bin/bash
# Liste der existierenden Hosts (ohne sich selbst)
TARGETS=("10.10.10.12" "10.10.10.24" "10.10.10.36" "10.10.10.48")
# Schlüssel generieren (falls nicht vorhanden)
[ ! -f ~/.ssh/id_ed25519 ] && ssh-keygen -t ed25519 -C "alex@$(hostname)" -f ~/.ssh/id_ed25519 -N ""
# SSH‑Keyscan für alle Targets, um known_hosts zu füllen
for t in "${TARGETS[@]}"; do
    ssh-keyscan $t >> ~/.ssh/known_hosts 2>/dev/null
done
# Schlüssel zu allen Targets kopieren (interaktiv nach Passwort)
for t in "${TARGETS[@]}"; do
    ssh-copy-id alex@$t
done