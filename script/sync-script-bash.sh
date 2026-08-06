#!/bin/bash

# Zielhosts (SSH‑Targets)
TARGETS=("10.10.10.24" "10.10.10.36" "10.10.10.48")

# Quellen – Verzeichnisse und einzelne Dateien
SOURCE_DIRS=(
    "/home/alex/.local/share/nautilus/scripts"
    "/home/alex/.local/share/remmina"
    "/home/alex/script"
    "/home/alex/.bashrc"
    "/home/alex/.bash_a.sh"
    "/home/alex/.bash_f.sh"   # falls vorhanden
)

LOCAL_HOST=$(hostname)

if [[ "$LOCAL_HOST" != "nora" ]]; then
    echo "Dieses Skript ist nur für den Host 'nora' vorgesehen. Breche ab."
    exit 0
fi

SSH_OPTS="-e ssh"

for h in "${TARGETS[@]}"; do
    if [[ "$h" == "$LOCAL_HOST" ]]; then
        echo "Überspringe lokalen Host '$h'."
        continue
    fi

    echo "Synchronisiere zu $h ..."

    for src in "${SOURCE_DIRS[@]}"; do
        # Zielverzeichnis = Elternverzeichnis der Quelle
        dest_dir="$(dirname "$src")"

        if [[ -d "$src" ]]; then
            # Verzeichnis: gesamten Ordner inkl. Inhalt synchronisieren,
            # nicht nur den Inhalt in das Elternverzeichnis packen.
            # Kein trailing Slash, damit der Ordner selbst kopiert wird.
            rsync -avz --delete $SSH_OPTS "$src" "alex@$h:$dest_dir/"
        else
            # Einzelne Datei: überschreiben, aber nichts anderes löschen
            rsync -avz $SSH_OPTS "$src" "alex@$h:$dest_dir/"
        fi
    done
done

echo "Fertig."