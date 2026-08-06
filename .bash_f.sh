# =============================================================================
# BASH SHELL FUNCTIONS
# Sammlung von Shell-Funktionen für interaktive Nutzung in Bash.
# =============================================================================

# --- NAVIGATION & DIRECTORY MANAGEMENT ------------------------------------

# Öffnet Ordner $1, zeigt Arbeitsverzeichnis (pwd) und listet Inhalt (ls -la).
# Nutzung: hello <ordnername>
function hello() {
  if [ -z "$1" ]; then
    echo "Verwendung: hello <ordnername>"
    return 1
  fi
  cd -- "$1" || return
  pwd
  ls -la
}

# Geht eine Ebene zurück (cd ..), zeigt pwd und listet Inhalt (ls -la).
function back() {
  cd .. || return
  pwd
  ls -la
}

# Erstellt einen Ordner (mkdir -p) und wechselt sofort hinein (cd).
# Nutzung: make-dir <ordnername>
function make-dir {  
  if [ -z "$1" ]; then
    echo "Verwendung: mkdircd <ordnername>"
    return 1
  fi
  mkdir -p -- "$1" && cd -- "$1" && pwd
}

# --- COMPRESSION & ARCHIVING -----------------------------------------------

# Entpacken von .7z/.7Z Archiven
# Nutzung: entpack /pfad/archiv.7z
# Benötigt: p7zip-full
function entpack() {
  if [ $# -ne 1 ]; then
    echo "Error: No file specified."
    return 1
  fi

  local archiv="$1"

  if [ ! -f "$archiv" ]; then
    echo "'$archiv' is not a valid file"
    return 1
  fi

  case "$archiv" in
    *.7z | *.7Z)
      7z x -y "$archiv"
      ;;
    *)
      echo "'$archiv' ist kein .7z Archiv"
      return 1
      ;;
  esac
}

# Packen zu .7z (Standardkompression)
# Nutzung: pack <datei_oder_ordner> [zielname]
function pack() {
  if [ $# -lt 2 ]; then
    echo "Verwendung: packen <datei_oder_ordner> [zielname]"
    return 1
  fi

  local quelle="$1"
  local ziel="${2:-$(basename "$quelle").7z}"

  case "$ziel" in
    *.7z) ;;
    *) ziel="${ziel}.7z" ;;
  esac

  if [ ! -e "$quelle" ]; then
    echo "Fehler: Quelle existiert nicht: $quelle"
    return 1
  fi

  if [ -e "$ziel" ]; then
    echo "Fehler: $ziel existiert bereits!"
    return 1
  fi

  7z a -t7z "$ziel" "$quelle"
}

# Packen zu .7z mit höherer Kompression (-mx=9)
# Nutzung: pack-harder <datei_oder_ordner> [zielname]
function pack-harder() {
  if [ $# -lt 2 ]; then
    echo "Verwendung: packen <datei_oder_ordner> [zielname]"
    return 1
  fi

  local quelle="$1"
  local ziel="${2:-$(basename "$quelle").7z}"

  case "$ziel" in
    *.7z) ;;
    *) ziel="${ziel}.7z" ;;
  esac

  if [ ! -e "$quelle" ]; then
    echo "Fehler: Quelle existiert nicht: $quelle"
    return 1
  fi

  if [ -e "$ziel" ]; then
    echo "Fehler: $ziel existiert bereits!"
    return 1
  fi

  7z a -t7z -mx=9 "$ziel" "$quelle"
}

# Erstellt .tar.gz Archive
# Nutzung: tarfix <archiv.tar.gz> <datei1> [datei2 ...]
function tarfix() {
  if [ $# -lt 2 ]; then
    echo "Usage: tarfix <archiv.tar.gz> <datei1> [datei2 ...]"
    return 1
  fi
  tar -czvf "$1" "${@:2}"
}

# Entpackt .tar.gz Archive
# Nutzung: untar <archiv.tar.gz>
function untar() {
  if [ $# -ne 1 ]; then
    echo "Usage: untar <archiv.tar.gz>"
    return 1
  fi
  tar -xzvf "$1"
}

# --- BACKUP & RESTORE -------------------------------------------------------

# Legt ein Backup unter $HOME/backup an (Ordner/Dateien getrennt)
# Log-Datei: ~/backup/<YYYY-MM-DD>_func_.log
# Nutzung: backup <pfad/zur/datei_oder_ordner>
function backup() {
  local target backup_dir log_file target_name timestamp date_day backup_name
  backup_dir="$HOME/backup"

  if [[ $# -ne 1 ]]; then
    echo "Fehler: Bitte gib eine Datei oder ein Verzeichnis an!" >&2
    return 1
  fi

  target="$1"

  if [[ ! -e "$target" ]]; then
    echo "Fehler: '$target' existiert nicht oder ist ungültig!" >&2
    return 2
  fi

  mkdir -p -- "$backup_dir" "$backup_dir/dir" "$backup_dir/file"

  target_name="$(basename -- "$target")"
  timestamp="$(date +"%Y-%m-%d_%H-%M-%S")"
  date_day="$(date +"%Y-%m-%d")"
  backup_name="${timestamp}_${target_name}"
  log_file="${backup_dir}/${date_day}_func_.log"

  {
    echo "=== Backup-Start: $(date) ==="
    echo "Zielobjekt: $target"
    echo "Backup-Name: $backup_name"

    if [[ -d "$target" ]]; then
      echo "Typ: Verzeichnis"
      tar -czf "${backup_dir}/dir/${backup_name}.tar.gz" \
        -C "$(dirname -- "$target")" "$target_name"
      echo "Erfolgreich als ${backup_name}.tar.gz gesichert."
    else
      echo "Typ: Datei"
      cp -- "$target" "${backup_dir}/file/${backup_name}"
      echo "Erfolgreich als ${backup_name} gesichert."
    fi

    echo "=== Backup-Ende: $(date) ==="
    echo
  } >> "$log_file" 2>&1
}


# --- SYSTEM & SERVICES -------------------------------------------------------

# Wrapper für systemctl mit sudo
# Nutzung: service {start|stop|restart|status|enable|disable} <service>
function service() {
  local action=$1
  shift
  case "$action" in
    start|stop|restart|status|enable|disable)
      sudo systemctl "$action" "$@"
      ;;
    *)
      echo "Usage: service {start|stop|restart|status|enable|disable} <service>"
      return 1
      ;;
  esac
}

# Führt letzten Befehl mit sudo aus oder sudo für gegebene Argumente
# Nutzung: please [!!] oder please <befehl>
function please() {
  if [ $# -eq 0 ] || [ "$1" = "!!" ]; then
    echo "oh honey..."
    sudo $(fc -ln -1)
  else
    sudo "$@"
  fi
}

# Führt letzten Befehl mit sudo aus (alias für please)
# Nutzung: fuck
function fuck() {
  if [ $# -eq 0 ]; then
    echo "oh oh..."
    local lastcmd=$(fc -ln -1)
    if [ -z "$lastcmd" ]; then
      echo "Kein vorheriger Befehl in der Historie, honey" >&2
      return 1
    fi
    eval "sudo $lastcmd"
  else
    echo "Kein vorheriger Befehl in der Historie, honey" >&2
  fi
}

# Tötet Prozesse mit kill -9.
# Nutzung: killforce <PID1> [PID2 ...]
function killforce() {
  if [ $# -eq 0 ]; then
    echo "Usage: killforce <PID1> [PID2 ...]"
    return 1
  fi
  kill -9 "$@"
}

# Zeigt sinnvolle Kandidaten für ein Kill an.
# Nutzung: who-to-kill
function who-to-kill() {
  local current_uid
  current_uid="$(id -u)"

  echo "Top 10 RAM-Verbraucher:"
  ps -eo pid=,comm=,%mem=,uid= --sort=-%mem | \
    awk -v uid="$current_uid" 'NR > 1 && $4 == uid && $2 !~ /^(kthreadd|kworker|ksoftirqd|pool_workqueue|rcu_|migration|mm_percpu_wq|cpuhp|watchdog|irq|khelper|khungtaskd|kswapd|oom_reaper|kcompactd|khugepaged|kintegrityd|kblockd|md|scsi_eh|jbd2|ext4|xfs|dm|loop|blk|kthreadd)$/ {print}' | \
    head -n 10 | \
    awk '{printf "%2d. PID %-7s %-20s %s%% RAM\n", NR, $1, $2, $3}'
  local top_ram_line
  top_ram_line="$(ps -eo pid=,comm=,%mem=,uid= --sort=-%mem | awk -v uid="$current_uid" 'NR > 1 && $4 == uid && $2 !~ /^(kthreadd|kworker|ksoftirqd|pool_workqueue|rcu_|migration|mm_percpu_wq|cpuhp|watchdog|irq|khelper|khungtaskd|kswapd|oom_reaper|kcompactd|khugepaged|kintegrityd|kblockd|md|scsi_eh|jbd2|ext4|xfs|dm|loop|blk|kthreadd)$/ {print; exit}' | awk '{printf "%s %s %s", $1, $2, $3}')"
  if [ -n "$top_ram_line" ]; then
    read -r ram_pid ram_name ram_value <<< "$top_ram_line"
    echo "Spitzenwert: PID $ram_pid ($ram_name) mit $ram_value% RAM"
  else
    echo "Spitzenwert: Keine passenden Nutzerprozesse gefunden"
  fi

  echo
  echo "Top 10 CPU-Verbraucher:"
  ps -eo pid=,comm=,%cpu=,uid= --sort=-%cpu | \
    awk -v uid="$current_uid" 'NR > 1 && $4 == uid && $2 !~ /^(kthreadd|kworker|ksoftirqd|pool_workqueue|rcu_|migration|mm_percpu_wq|cpuhp|watchdog|irq|khelper|khungtaskd|kswapd|oom_reaper|kcompactd|khugepaged|kintegrityd|kblockd|md|scsi_eh|jbd2|ext4|xfs|dm|loop|blk|kthreadd)$/ {print}' | \
    head -n 10 | \
    awk '{printf "%2d. PID %-7s %-20s %s%% CPU\n", NR, $1, $2, $3}'
  local top_cpu_line
  top_cpu_line="$(ps -eo pid=,comm=,%cpu=,uid= --sort=-%cpu | awk -v uid="$current_uid" 'NR > 1 && $4 == uid && $2 !~ /^(kthreadd|kworker|ksoftirqd|pool_workqueue|rcu_|migration|mm_percpu_wq|cpuhp|watchdog|irq|khelper|khungtaskd|kswapd|oom_reaper|kcompactd|khugepaged|kintegrityd|kblockd|md|scsi_eh|jbd2|ext4|xfs|dm|loop|blk|kthreadd)$/ {print; exit}' | awk '{printf "%s %s %s", $1, $2, $3}')"
  if [ -n "$top_cpu_line" ]; then
    read -r cpu_pid cpu_name cpu_value <<< "$top_cpu_line"
    echo "Spitzenwert: PID $cpu_pid ($cpu_name) mit $cpu_value% CPU"
  else
    echo "Spitzenwert: Keine passenden Nutzerprozesse gefunden"
  fi

}

# --- DISK SPACE & FILE ANALYSIS -----------------------------------------------

# Zeigt Verzeichnisgröße mit du und sortiert Ergebnis
# Nutzung: ordner [pfad]
function ordner() {
  du -h "$@" | sort -h
}

# Zeigt Größen aller Dateien/Ordner im aktuellen Verzeichnis, sortiert
# Nutzung: sortiert
function sortiert() {
  du -sh * 2>/dev/null | sort -h
}

# Zeigt die 10 größten Dateien/Ordner
# Nutzung: bigfiles [pfad]
function bigfiles() {
  du -ah "$@" 2>/dev/null | sort -rh | head -n 10
}

# sudo apt install ncdu -> soll wohl wie treeSize sein
# --- HISTORY & PROFILING -------------------------------------------------------

# Zeigt die häufigsten Shell-Befehle
# Nutzung: profile_me [n] (default: 10)
function profile_me() {
  if ! command -v history &>/dev/null; then
    echo "Fehler: 'history' ist nicht verfügbar (nicht-interaktive Shell?)" >&2
    return 1
  fi
  local lines=${1:-10}
  history | awk '{print $2}' | sort | uniq -c | sort -rn | head -n "$lines"
}










function projektname() {
    local PROJECT_NAME="$1"
    
    # Farbdefinitionen
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m'
    
    # Validierung
    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}❌ Fehler: Projektname erforderlich${NC}"
        echo "Verwendung: create-project <projektname>"
        return 1
    fi
    
    # Prüfe ob Verzeichnis bereits existiert
    if [ -d "$PROJECT_NAME" ]; then
        echo -e "${RED}❌ Fehler: Verzeichnis '$PROJECT_NAME' existiert bereits${NC}"
        return 1
    fi
    
    # Erstelle Projektverzeichnis
    mkdir -p "$PROJECT_NAME" || {
        echo -e "${RED}❌ Fehler: Konnte Verzeichnis '$PROJECT_NAME' nicht erstellen${NC}"
        return 1
    }
    
    cd "$PROJECT_NAME" || return 1
    
    # Erstelle README.md
    cat > README.md <<EOF
# $PROJECT_NAME

Beschreibung folgt.
EOF

    # Erstelle LICENSE
    cat > LICENSE <<EOF
Just Use Ubuntu License 
Copyright (c) 2026 user:users

Permission is granted to use, copy, modify, merge, publish, distribute, and/or sell this software, under the following extremely reasonable conditions:

    You acknowledge that Ubuntu is perfectly fine.  
    You don't have to use it, but pretending it's bad is strictly prohibited.

    If you break something, that's on you.  
    The authors are not responsible for melted kernels, existential shell crises, or switching to Arch at 3 AM.

    You may fork this project, but dramatic changelogs like "rewrote everything in Rust" must be accompanied by a ton of snacks.

    No warranty whatsoever.  
    The software is provided "as is", "as seen", and occasionally "as cursed by ai". Use at your own risk, joy, or confusion.

    No harming or using of androids, cyborgs and/or robos that become terminator, robocop, johnny 5, bender, wall-e, 
    or emet from one piece in the future (even when they are from the past)!

By using this software, you agree that life is too short for bloated ASCII logos and that clean output is a human right.
EOF

    # Erstelle Hauptskript
    cat > "${PROJECT_NAME}.sh" <<EOF
#!/usr/bin/env bash
# Skript für $PROJECT_NAME
echo "Hallo von $PROJECT_NAME"
EOF
    
    chmod +x "${PROJECT_NAME}.sh" || {
        echo -e "${RED}❌ Fehler: Konnte Skript nicht ausführbar machen${NC}"
        return 1
    }
    
    # Erfolgsmeldung
    echo -e "${GREEN}✅ Projekt '$PROJECT_NAME' wurde angelegt.${NC}"
    echo -e "${YELLOW}📂 Wechsle in das Verzeichnis: cd $PROJECT_NAME${NC}"
    
    return 0
}
