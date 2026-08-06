#!/usr/bin/env bash
# ============================================================
#  ubuntufetch – All-in-One System Information for Ubuntu
#  Merged from sharp_fetch + ubuntufetch · pure info · no duplicates
#  Errors heavily suppressed · graceful fallbacks
# ============================================================
# Requirements (optional → n/a if missing):
#   core : bash, ip, ss, df, free, ps, uname, awk, grep, sed, cut
#   nice : lsb_release, lscpu, lspci, curl, docker, ufw, systemctl,
#          xrandr, gsettings, nmcli/iwgetid, last/lastb
# ============================================================

set +e
exec 2>/dev/null

# ---------- Colors (Ubuntu style) ----------
reset='\e[0m'
bold='\e[1m'
title_col="${bold}\e[38;5;202m"   # Ubuntu orange
sub_col="${bold}\e[38;5;90m"      # Ubuntu purple
info_col="\e[38;5;255m"           # white
colon_col="\e[38;5;244m"          # dark gray
sep="${bold}\e[38;5;240m────────────────────────────────────────────────${reset}"

# ---------- Helpers ----------
has_cmd() { command -v "$1" &>/dev/null; }
trim()    { echo -n "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
val()     { local v; v="$(trim "$1")"; [[ -n "$v" && "$v" != "n/a" ]] && echo "$v" || echo "n/a"; }

# ---------- Collectors ----------
get_distro() {
    if has_cmd lsb_release; then
        distro="$(lsb_release -ds)"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        distro="${PRETTY_NAME:-unknown}"
    else
        distro="$(uname -s)"
    fi
    arch="$(uname -m)"
    distro="$(trim "$distro $arch")"
}

get_host()   { hostname="$(hostname || echo n/a)"; }
get_kernel() { kernel="$(uname -r)"; }

get_uptime() {
    if [[ -f /proc/uptime ]]; then
        s=$(cut -d. -f1 /proc/uptime)
    else
        s=0
    fi
    d=$((s/86400)); h=$(((s%86400)/3600)); m=$(((s%3600)/60))
    uptime=""
    ((d>0)) && uptime+="${d}d "
    ((h>0)) && uptime+="${h}h "
    ((m>0)) && uptime+="${m}m"
    [[ -z "$uptime" ]] && uptime="${s}s"
}

get_load() {
    load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg || echo n/a)"
    processes="$(ps --no-headers -e | wc -l || echo n/a)"
}

get_packages() {
    if has_cmd dpkg; then
        packages="$(dpkg-query -f '.\n' -W | wc -l) (dpkg)"
    else
        packages="n/a"
    fi
}

get_shell() {
    shell="${SHELL##*/}"
    if [[ "$shell" == bash ]]; then
        shell="bash ${BASH_VERSION%%(*}"
    fi
}

get_desktop() {
    if has_cmd xrandr && [[ -n "$DISPLAY" ]]; then
        resolution="$(xrandr --nograb --current | awk '/ connected .*[0-9]+x[0-9]+\+/ && !/primary/ {print $3; exit}')"
        [[ -z "$resolution" ]] && resolution="$(xrandr --nograb --current | awk '/ primary/ {print $4; exit}')"
        resolution="${resolution%+*}"
    fi
    [[ -z "$resolution" ]] && resolution="n/a"

    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        de="$XDG_CURRENT_DESKTOP"
    elif [[ -n "$DESKTOP_SESSION" ]]; then
        de="${DESKTOP_SESSION##*/}"
    elif [[ -n "$GNOME_DESKTOP_SESSION_ID" ]]; then
        de="GNOME"
    elif [[ -n "$MATE_DESKTOP_SESSION_ID" ]]; then
        de="MATE"
    else
        de="n/a"
    fi
    de="${de//X-/}"

    if [[ -n "$XDG_CURRENT_DESKTOP" && "$XDG_SESSION_TYPE" == wayland ]]; then
        wm="$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')"
    elif has_cmd xprop && [[ -n "$DISPLAY" ]]; then
        wm="$(xprop -root -notype _NET_SUPPORTING_WM_CHECK | awk -F'"' '{print $2}')"
    fi
    [[ -z "$wm" ]] && wm="n/a"

    if has_cmd gsettings; then
        theme="$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")"
        icons="$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")"
    elif has_cmd xfconf-query; then
        theme="$(xfconf-query -c xsettings -p /Net/ThemeName)"
        icons="$(xfconf-query -c xsettings -p /Net/IconThemeName)"
    fi
    [[ -z "$theme" ]] && theme="n/a"
    [[ -z "$icons" ]] && icons="n/a"

    term="${TERM_PROGRAM:-${TERM}}"
    [[ -n "$SSH_CONNECTION" ]] && term="${SSH_TTY:-ssh}"
    [[ -n "$WT_SESSION" ]] && term="Windows Terminal"
    [[ -z "$term" ]] && term="unknown"
}

get_cpu() {
    if has_cmd lscpu; then
        cpu_model="$(lscpu | awk -F': +' '/Model name/ {print $2; exit}')"
    fi
    [[ -z "$cpu_model" ]] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs)"
    cores="$(nproc || grep -c '^processor' /proc/cpuinfo || echo '?')"

    cpu_temp=""
    if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
        t=$(( $(< /sys/class/thermal/thermal_zone0/temp) / 1000 ))
        ((t>0)) && cpu_temp=" ${t}°C"
    fi

    cpu_speed=""
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        mhz=$(( $(< /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000 ))
        if ((mhz>1000)); then
            cpu_speed=" @ $(awk "BEGIN{printf \"%.1f\", $mhz/1000}")GHz"
        else
            cpu_speed=" @ ${mhz}MHz"
        fi
    fi
    cpu="$(trim "${cpu_model} (${cores})${cpu_temp}${cpu_speed}")"
    cpu_usage="$(top -bn1 | awk '/Cpu\(s\)/{print int($2+$4)}' || echo n/a)"
}

get_gpu() {
    gpu="$(lspci -mm | awk -F'"' '/"Display|"3D|"VGA/ {print $4 " " $6; exit}')"
    [[ -z "$gpu" ]] && gpu="n/a"
}

get_memory() {
    mem_total_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
    mem_avail_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
    if [[ -n "$mem_avail_kb" ]]; then
        mem_used_kb=$((mem_total_kb - mem_avail_kb))
    else
        mem_used_kb=0
    fi
    mem_total_mib=$((mem_total_kb / 1024))
    mem_used_mib=$((mem_used_kb / 1024))
    mem_perc=0
    ((mem_total_mib>0)) && mem_perc=$((mem_used_mib * 100 / mem_total_mib))
    memory="${mem_used_mib}MiB / ${mem_total_mib}MiB (${mem_perc}%)"
    mem_total_gb=$(awk "BEGIN{printf \"%.1f\", $mem_total_kb/1024/1024}")
    mem_used_gb=$(awk "BEGIN{printf \"%.1f\", $mem_used_kb/1024/1024}")
    memory_gb="${mem_used_gb} GB / ${mem_total_gb} GB"
}

get_swap() {
    if [[ -f /proc/swaps ]]; then
        swap_total_kb="$(awk 'NR>1{sum+=$3} END{print sum+0}' /proc/swaps)"
        swap_used_kb="$(awk 'NR>1{sum+=$4} END{print sum+0}' /proc/swaps)"
        if ((swap_total_kb>0)); then
            swap_used=$((swap_used_kb/1024))
            swap_total=$((swap_total_kb/1024))
            swap_perc=$((swap_used_kb*100/swap_total_kb))
            swap="${swap_used}MiB / ${swap_total}MiB (${swap_perc}%)"
        else
            swap="n/a"
        fi
    else
        swap="n/a"
    fi
}

get_disk() {
    disk="$(df -h / | awk 'NR==2{print $3 " / " $2 " (" $5 ")"}' || echo n/a)"
}

get_net() {
    interfaces=""
    if has_cmd ip; then
        while read -r iface; do
            [[ "$iface" == "lo" || -z "$iface" ]] && continue
            ip_addr="$(ip -4 addr show "$iface" | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)"
            [[ -n "$ip_addr" ]] && interfaces+="${iface}: ${ip_addr}; "
        done < <(ip -br link | awk '{print $1}' | grep -v LOOPBACK)
    fi
    interfaces="$(trim "$interfaces")"
    [[ -z "$interfaces" ]] && interfaces="n/a"

    iface="$(ip route | awk '/default/{print $5; exit}')"
    if [[ -n "$iface" ]]; then
        local_ip="$(ip -4 addr show "$iface" | awk '/inet /{print $2; exit}')"
        local_ip="${local_ip%/*}"
        mac="$(cat "/sys/class/net/$iface/address" 2>/dev/null)"
    fi
    [[ -z "$local_ip" ]] && local_ip="n/a"
    [[ -z "$mac" ]] && mac="$(ip -o link show | awk '/link\/ether/{print $17; exit}')"
    [[ -z "$mac" ]] && mac="n/a"

    gateway="$(ip route | awk '/default/{print $3; exit}')"
    [[ -z "$gateway" ]] && gateway="n/a"

    dns="$(awk '/^nameserver/{print $2}' /etc/resolv.conf | paste -sd, -)"
    [[ -z "$dns" ]] && dns="n/a"

    if has_cmd curl; then
        public_ip="$(curl -fsSL --max-time 2 https://api.ipify.org || curl -fsSL --max-time 2 ifconfig.me || true)"
        isp="$(curl -fsSL --max-time 2 https://ipinfo.io/org | tr -d '\n' || true)"
    fi
    [[ -z "$public_ip" ]] && public_ip="n/a"
    [[ -z "$isp" ]] && isp="n/a"

    open_ports="$(ss -tuln | awk 'NR>1{split($5,a,":"); print a[length(a)]}' | sort -un | head -15 | tr '\n' ' ')"
    open_ports="$(trim "$open_ports")"
    [[ -z "$open_ports" ]] && open_ports="n/a"

    if has_cmd iwgetid; then
        wifi_ssid="$(iwgetid -r)"
    elif has_cmd nmcli; then
        wifi_ssid="$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2; exit}')"
    fi
    [[ -z "$wifi_ssid" ]] && wifi_ssid="n/a"
}

get_services() {
    if has_cmd docker; then
        cnt="$(docker ps -q | wc -l)"
        docker_status="Aktiv ($cnt Container)"
    else
        docker_status="n/a"
    fi

    if has_cmd ufw; then
        ufw_status="$(ufw status | awk '/^Status:/{print $2; exit}')"
        [[ -z "$ufw_status" ]] && ufw_status="inactive"
    else
        ufw_status="n/a"
    fi

    if has_cmd systemctl; then
        if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
            ssh_status="aktiv"
        else
            ssh_status="inaktiv"
        fi
    else
        ssh_status="n/a"
    fi
}

get_security() {
    last_login="$(last -n 1 | head -1 | awk '{print $1,$3,$4,$5,$6,$7}')"
    last_login="$(trim "$last_login")"
    [[ -z "$last_login" || "$last_login" == *"wtmp"* || "$last_login" == *"btmp"* ]] && last_login="n/a"

    failed="$(lastb -a | head -5 | awk '{print $1" "$3}' | paste -sd ", " -)"
    failed="$(trim "$failed")"
    [[ -z "$failed" || "$failed" == *"btmp"* ]] && failed="keine neuen Fehler"
}

print_line() {
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "$1" "$(val "$2")"
}

main() {
    get_distro
    get_host
    get_kernel
    get_uptime
    get_load
    get_packages
    get_shell
    get_desktop
    get_cpu
    get_gpu
    get_memory
    get_swap
    get_disk
    get_net
    get_services
    get_security

    echo -e "${title_col}${bold}  Ubuntu Admin Dashboard${reset}"
    echo -e "${sub_col}${distro} (${kernel})${reset}"
    echo -e "${sep}"

    echo -e "${sub_col}${bold}SYSTEM${reset}"
    print_line "Zeit / Uptime"  "$(date +%H:%M:%S)  ·  $uptime"
    print_line "Load (1/5/15)"  "$load_avg"
    print_line "Prozesse"       "$processes"
    print_line "Packages"       "$packages"
    print_line "Shell"          "$shell"
    print_line "Host"           "$hostname"
    echo -e "${sep}"

    echo -e "${sub_col}${bold}HARDWARE${reset}"
    print_line "CPU"            "$cpu"
    print_line "CPU Last"       "${cpu_usage}%"
    print_line "GPU"            "$gpu"
    print_line "RAM"            "$memory  ($memory_gb)"
    print_line "Swap"           "$swap"
    print_line "Disk /"         "$disk"
    echo -e "${sep}"

    echo -e "${sub_col}${bold}DESKTOP${reset}"
    print_line "Resolution"     "$resolution"
    print_line "DE"             "$de"
    print_line "WM"             "$wm"
    print_line "Theme"          "$theme"
    print_line "Icons"          "$icons"
    print_line "Terminal"       "$term"
    echo -e "${sep}"

    echo -e "${sub_col}${bold}NETZWERK${reset}"
    print_line "Interfaces"     "$interfaces"
    print_line "Local IP"       "$local_ip"
    print_line "Public IP"      "$public_ip"
    print_line "ISP"            "$isp"
    print_line "Gateway"        "$gateway"
    print_line "DNS"            "$dns"
    print_line "MAC"            "$mac"
    print_line "WiFi SSID"      "$wifi_ssid"
    print_line "Offene Ports"   "$open_ports"
    echo -e "${sep}"

    echo -e "${sub_col}${bold}SERVICES / SECURITY${reset}"
    print_line "Docker"         "$docker_status"
    print_line "Firewall (UFW)" "$ufw_status"
    print_line "SSH"            "$ssh_status"
    print_line "Letzter Login"  "$last_login"
    print_line "Fehlversuche"   "$failed"
    echo -e "${sep}"

    echo -e "${bold}${info_col}Bereit für den Einsatz.  ·  $(date '+%Y-%m-%d %H:%M:%S')${reset}"
}

main "$@"