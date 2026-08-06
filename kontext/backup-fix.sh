#!/usr/bin/env bash
#
# backup.sh – Dateien/Ordner nach ~/backup/ sichern
# Rechtsklick → Skripte → backup.sh
#

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ---------- Prüfen ----------
if [ $# -eq 0 ]; then
    yad --error --title="Backup" --text="Nichts ausgewählt." --button="OK":0 2>/dev/null
    exit 1
fi

backup_dir="$HOME/backup"
mkdir -p -- "$backup_dir/dir" "$backup_dir/file"

timestamp="$(date +"%Y-%m-%d_%H-%M-%S")"
date_day="$(date +"%Y-%m-%d")"
log_file="${backup_dir}/${date_day}_func_.log"

success_count=0
error_count=0
result_text=""

# ---------- Backup durchführen ----------
{
    echo "=== Backup-Start: $(date) ==="

    for target in "$@"; do
        [ -e "$target" ] || {
            echo "Übersprungen (existiert nicht): $target"
            ((error_count++)) || true
            continue
        }

        target_name="$(basename -- "$target")"
        backup_name="${timestamp}_${target_name}"

        echo "Zielobjekt: $target"

        if [ -d "$target" ]; then
            # Ordner → tar.gz
            out="${backup_dir}/dir/${backup_name}.tar.gz"
            if tar -czf "$out" -C "$(dirname -- "$target")" "$target_name" 2>/dev/null; then
                echo "✓ Verzeichnis gesichert: $out"
                result_text+="📁  $target_name → dir/${backup_name}.tar.gz\n"
                ((success_count++)) || true
            else
                echo "✗ Fehler beim Sichern von: $target"
                result_text+="❌  $target_name (Fehler)\n"
                ((error_count++)) || true
            fi
        else
            # Datei → kopieren
            out="${backup_dir}/file/${backup_name}"
            if cp -- "$target" "$out" 2>/dev/null; then
                echo "✓ Datei gesichert: $out"
                result_text+="📄  $target_name → file/${backup_name}\n"
                ((success_count++)) || true
            else
                echo "✗ Fehler beim Kopieren von: $target"
                result_text+="❌  $target_name (Fehler)\n"
                ((error_count++)) || true
            fi
        fi
        echo
    done

    echo "=== Backup-Ende: $(date) ==="
    echo
} >> "$log_file" 2>&1

# ---------- Ergebnis anzeigen ----------
if [ $success_count -gt 0 ] && [ $error_count -eq 0 ]; then
    icon="emblem-default"
    title="🐝 Backup erfolgreich"
    msg="Gesichert nach: ~/backup/\n\n$result_text\nLog: $log_file"
elif [ $success_count -gt 0 ]; then
    icon="dialog-warning"
    title="🐝 Backup teilweise erfolgreich"
    msg="Erfolgreich: $success_count\nFehler: $error_count\n\n$result_text\nLog: $log_file"
else
    icon="dialog-error"
    title="🐝 Backup fehlgeschlagen"
    msg="Nichts konnte gesichert werden.\n\nLog: $log_file"
fi

yad --info \
    --title="$title" \
    --text="$msg" \
    --width=500 \
    --button="OK":0 \
    --window-icon="$icon" \
    2>/dev/null