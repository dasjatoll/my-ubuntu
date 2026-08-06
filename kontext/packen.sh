#!/usr/bin/env bash
#
# packmenu.sh – Packen & Entpacken im Nautilus-Kontextmenü
# Rechtsklick auf Datei(en)/Ordner → Skripte → packmenu.sh
#

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ---------- Prüfen, ob etwas ausgewählt wurde ----------
if [ $# -eq 0 ]; then
    yad --error --title="Packen" --text="Nichts ausgewählt." --button="OK":0 2>/dev/null
    exit 1
fi

# ---------- Auswahl-Dialog ----------
choice=$(yad --list \
    --title="🐝 Packen / Entpacken" \
    --width=420 --height=280 \
    --column="Aktion" \
    --button="Abbrechen":1 \
    --button="Ausführen":0 \
    "📦  Als .7z packen (normal)" \
    "🗜️  Als .7z packen (stark -mx=9)" \
    "📁  Als .tar.gz packen" \
    "📤  Entpacken (.7z / .tar.gz)" \
    2>/dev/null)

# Abbrechen?
[ $? -ne 0 ] && exit 0
[ -z "$choice" ] && exit 0

# ---------- Aktion ausführen ----------
for item in "$@"; do
    [ -e "$item" ] || continue

    dir="$(dirname "$item")"
    name="$(basename "$item")"
    base="${name%.*}"          # Name ohne Endung

    case "$choice" in

        *"normal"*)
            # .7z normal
            target="$dir/${name}.7z"
            # Falls Ordner → Name.7z, falls Datei → Name.7z
            if [ -e "$target" ]; then
                yad --error --title="Packen" --text="Existiert schon:\n$target" --button="OK":0 2>/dev/null
                continue
            fi
            7z a -t7z "$target" "$item" >/dev/null 2>&1
            ;;

        *"stark"*)
            # .7z maximale Kompression
            target="$dir/${name}.7z"
            if [ -e "$target" ]; then
                yad --error --title="Packen" --text="Existiert schon:\n$target" --button="OK":0 2>/dev/null
                continue
            fi
            7z a -t7z -mx=9 "$target" "$item" >/dev/null 2>&1
            ;;

        *".tar.gz"*)
            # .tar.gz
            target="$dir/${name}.tar.gz"
            if [ -e "$target" ]; then
                yad --error --title="Packen" --text="Existiert schon:\n$target" --button="OK":0 2>/dev/null
                continue
            fi
            tar -czf "$target" -C "$dir" "$name" >/dev/null 2>&1
            ;;

        *"Entpacken"*)
            # Entpacken
            case "$item" in
                *.7z|*.7Z)
                    7z x -y -o"$dir" "$item" >/dev/null 2>&1
                    ;;
                *.tar.gz|*.tgz)
                    tar -xzf "$item" -C "$dir" >/dev/null 2>&1
                    ;;
                *.tar)
                    tar -xf "$item" -C "$dir" >/dev/null 2>&1
                    ;;
                *)
                    yad --error --title="Entpacken" \
                        --text="Unbekanntes Format:\n$name\n\nUnterstützt: .7z  .tar.gz  .tgz  .tar" \
                        --button="OK":0 2>/dev/null
                    continue
                    ;;
            esac
            ;;
    esac
done

# Fertig-Meldung
yad --info --title="🐝 Fertig" \
    --text="Aktion abgeschlossen." \
    --button="OK":0 \
    --timeout=2 2>/dev/null