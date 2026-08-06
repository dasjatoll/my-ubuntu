# pumpgun action --------------------------------

alias c='clear' # Terminal leeren
alias q='exit' # Beendet das Terminal mit einem Buchstaben
alias h='history' # Zeigt die Befehlshistorie an
alias x='chmod +x' # Macht eine Skriptdatei schnell ausführbar
alias reboot='shutdown -r now' # System sofort neu starten

# meins---------------------------------------------------
  alias alex='cd /home/alex/' # Wechselt in das Verzeichnis von Benutzer Alex
  alias home='cd /home/alex/' # Wechselt in das Home-Verzeichnis von Alex
  alias vera='cd /media/veracrypt1/' # Wechselt in den VeraCrypt-Mountpoint
  alias var='cd /var/' # Wechselt in das Verzeichnis für variable Daten (Logs etc.)
  alias log='cd /var/log/' # Wechselt in das Verzeichnis für variable Daten (Logs etc.)
  alias logs='cd /var/log/' # Wechselt in das Verzeichnis für variable Daten (Logs etc.)
  alias etc='cd /etc/' # Wechselt in das Systemkonfigurations-Verzeichnis
  
  # bevor back() func
  alias dvd='cd .. && ls -la' # Eine Ebene höher navigieren mit automatischer Auflistung
  alias cd2='cd .. && ls -la' # Fängt fehlendes Leerzeichen ab und listet Inhalt auf
 
  alias install-fancy='sudo apt install glances cockpit brasero zenity-common'
  alias install-new='sudo apt install 7zip btop build-essential cmatrix curl gedit git gufw gzip make mc meld micro ssh ufw yad zenity'
  
  # paket-manager
  alias install='sudo apt install ' # Bestätigender Shortcut für Paketinstallation
  alias uninstall='sudo apt remove' # Deinstalliert ein Paket
  alias update='sudo apt update && sudo apt full-upgrade -y && sudo snap refresh ' # All-in-One Update
  alias upgrade="sudo apt update && sudo apt upgrade -y" # System-Update ausführen
  alias upgrade-full='sudo apt update && sudo apt full-upgrade -y' # Vollständiges Ubuntu-Systemupgrade
# ---------------------------------------------------------
# help
alias help="echo 'man(pages) offline, https://tldr.inbrowser.app/, http://cheat.sh/'"

# system -> scripts gewandert
alias systemstatus='top -b -n 1 | head -n 20' # Schneller Überblick über die Top-Prozesse  # ubuntu-proofed
alias uptime_p='uptime -p' # Zeigt an, wie lange das System bereits läuft  # ubuntu-proofed

# ram
alias ram='free -h --si' # Übersicht über belegten/freien RAM-Speicher (SI-Einheiten)

# hdd platz
alias platz='df -hPT | column -t' # Formatiert Festplattenplatz als saubere Tabelle
alias platte='df -h' # Festplattenplatz in GB/MB anzeigen
alias diskinfo='lsblk' # Listet Blockgeräte und Partitionen als Baum auf

# taskmanager
alias killforce='kill -9' # Beendet einen Prozess sofort und unnachgiebig (SIGKILL)
alias exorzist='kill -9' # Sendet das Standard-Beendigungssignal an eine PID (SIGTERM) -> Hinweis: Nutzt SIGKILL (-9)
alias psaux='ps -aux' # Zeigt alle laufenden Prozesse im System an
alias psax='ps -aux' # Zeigt alle laufenden Prozesse im System an

# btop, btop, btop everything is btop!!!!!!
alias top='btop'
alias btop='btop'
alias htop='btop'

# Misc -------------------------------------------------------------------
alias warum='echo "Weil du der Admin bist. Atme tief durch."' # Trost bei Frust
alias why='echo "Weil du der Admin bist. Atme tief durch und prüfe die Logs."' # Bereitstellung von Administrator-Trost
alias matrix='cmatrix -b' # Aktiviert den Matrix-Bildschirmschoner im Terminal # ubuntu-proofed
alias rabbithole='cmatrix -b' # Matrix-Effekt im Terminal (erfordert cmatrix) # ubuntu-proofed

# Root Fehler Korrektur
alias bitte="sudo \$(history -p !!)"
alias pls="sudo \$(fc -ln -1)"
alias hg="history | grep"
alias history-grep="hg"
alias date_now="date '+%Y-%m-%d %H:%M:%S'"
alias schleife='echo "while true; do clear; ls -la; sleep 1; done"' # macht es so lange bis unendlich

# bisschen color
alias grep='grep --color=auto' # Hebt grep-Suchtreffer farblich hervor
alias egrep='egrep --color=auto' # Hebt egrep-Suchtreffer farblich hervor
alias fgrep='fgrep --color=auto' # Hebt fgrep-Suchtreffer farblich hervor
alias dir='dir --color=auto' # Aktiviert Farben für dir
alias vdir='vdir --color=auto' # Aktiviert Farben für vdir
alias l='ls -la --color=auto' # Standard-Spalten-Auflistung für schnelle Orientierung
alias sl='ls -la --color=auto' # Korrigiert Dreher bei 'ls'
alias ls='ls -la --color=auto' # Aktiviert Farben für ls
alias sl="ls -la --color=auto"               # Vertippt von ls zu sl

# Info-Modus-an
alias cp='cp -i' # Interaktives Kopieren (Schutz vor Überschreiben)
alias copy='cp -i' # Fragt vor dem Überschreiben beim Kopieren nach
alias mv='mv -i' # Interaktives Verschieben (Schutz vor Überschreiben)
alias move='mv -i' # Fragt vor dem Überschreiben beim Verschieben nach
alias rm='rm -i' # Fragt vor jedem Löschen um Bestätigung
alias remove='rm -i' # Fragt vor dem Löschen nach
