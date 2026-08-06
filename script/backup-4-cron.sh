#================================================================
# backup cron job examples (alle 24 stunden oder benutzerdefiniert)
# syntax-hilfe: minute stunde tagmonat monat wochentag befehl
#================================================================
# m h  dom mon dow   command
# 42 * * * * bash /home/alex/backup/backup-n-cron.sh /home/alex/.bash_function
# 42 * * * * bash /home/alex/backup/backup-n-cron.sh /home/alex/.bash_history
# 42 * * * * bash /home/alex/backup/backup-n-cron.sh /home/alex/.bashrc
# lesen: crontab -e 
# check: crontab -l
# nicht unbedingt sudo - das kann zu zugriffsproblemen führen, wenn der cronjob als root läuft und auf benutzerdateien zugreifen möchte.  
#
#!/usr/bin/env bash
set -euo pipefail

 BACKUP_DIR="/home/${USER}/backup" # ein wenig universeller
# BACKUP_DIR="/home/alex/backup"
mkdir -p "$BACKUP_DIR" "$BACKUP_DIR/dir" "$BACKUP_DIR/file"

if [[ $# -ne 1 ]]; then
  echo "Fehler: Bitte gib eine Datei oder ein Verzeichnis an!" >&2
  echo "Nutzung: $0 /pfad/zur/datei_oder_ordner" >&2
  exit 1
fi

TARGET="$1"
if [[ ! -e "$TARGET" ]]; then
  echo "Fehler: '$TARGET' existiert nicht oder ist ungültig!" >&2
  exit 2
fi

TARGET_NAME="$(basename -- "$TARGET")"
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
DATE_DAY="$(date +"%Y-%m-%d")"

LOG_FILE="${BACKUP_DIR}/${DATE_DAY}.log"
BACKUP_NAME="${TIMESTAMP}_${TARGET_NAME}"

{
  echo "=== Backup-Start: $(date) ==="
  echo "Zielobjekt: $TARGET"
  echo "Backup-Name: $BACKUP_NAME"

  if [[ -d "$TARGET" ]]; then
    echo "Typ: Verzeichnis"
    tar -czf "${BACKUP_DIR}/dir/${BACKUP_NAME}.tar.gz" \
      -C "$(dirname -- "$TARGET")" "$TARGET_NAME"
    echo "Erfolgreich als ${BACKUP_NAME}.tar.gz gesichert."
  else
    echo "Typ: Datei"
    cp -- "$TARGET" "${BACKUP_DIR}/file/${BACKUP_NAME}"
    echo "Erfolgreich als ${BACKUP_NAME} gesichert."
  fi

  echo "=== Backup-Ende: $(date) ==="
  echo
} >> "$LOG_FILE" 2>&1