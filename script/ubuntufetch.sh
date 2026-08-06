#!/usr/bin/env bash
# ============================================================
#  ubuntufetch – Vollständiges Systeminfo-Tool für Ubuntu
#  Basierend auf Neofetch, aber optimiert und Ubuntu-proofed
# ============================================================

# ---------- Farben & Formatierung (nur Ubuntu-Farben) ----------
reset='\e[0m'
bold='\e[1m'
title_col="${bold}\e[38;5;202m"      # Ubuntu-Orange
sub_col="${bold}\e[38;5;90m"        # Ubuntu-Lila
info_col="\e[38;5;255m"             # Weiß
colon_col="\e[38;5;244m"            # Dunkelgrau
bar_col_elapsed="\e[38;5;202m"      # Orange (falls verwendet)
bar_col_total="\e[38;5;240m"        # Dunkelgrau
c1="${bold}\e[38;5;202m"            # Orange für Logo
c2="${bold}\e[38;5;208m"            # Helleres Orange
c3="${bold}\e[38;5;90m"             # Lila
c4="${bold}\e[38;5;129m"            # Helleres Lila

# ---------- Hilfsfunktionen ----------
has_cmd() { command -v "$1" &>/dev/null; }
trim() { echo -n "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
err() { echo -e "${bold}${info_col}⚠️  $*${reset}" >&2; }

# ---------- Informationssammlung (wie Neofetch) ----------
get_distro() {
    if has_cmd lsb_release; then
        distro="$(lsb_release -ds 2>/dev/null)"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="$PRETTY_NAME"
    else
        distro="$(uname -s) $(uname -r)"
    fi
    arch="$(uname -m)"
    [[ "$arch" =~ (x86_64|i686|arm64) ]] && distro="$distro $arch"
}

get_host() { hostname="$(hostname)"; }

get_kernel() { kernel="$(uname -r)"; }

get_uptime() {
    if [[ -f /proc/uptime ]]; then
        s=$(cut -d. -f1 /proc/uptime)
    else
        boot="$(date -d"$(uptime -s)" +%s 2>/dev/null || echo 0)"
        now="$(date +%s)"
        s="$((now - boot))"
    fi
    d="$((s/86400))"
    h="$(((s%86400)/3600))"
    m="$(((s%3600)/60))"
    uptime=""
    ((d>0)) && uptime+="${d}d "
    ((h>0)) && uptime+="${h}h "
    ((m>0)) && uptime+="${m}m"
    [[ -z "$uptime" ]] && uptime="${s}s"
}

get_packages() {
    if has_cmd dpkg; then
        packages="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"
        packages="$packages (dpkg)"
    else
        packages="n/a"
    fi
}

get_shell() {
    shell="${SHELL##*/}"
    if [[ "$shell" = bash ]]; then
        shell="$shell $BASH_VERSION"
    elif has_cmd "$SHELL"; then
        ver="$("$SHELL" --version 2>/dev/null | head -1 | awk '{print $NF}')"
        [[ -n "$ver" ]] && shell="$shell $ver"
    fi
}

get_resolution() {
    if has_cmd xrandr && [[ -n "$DISPLAY" ]]; then
        resolution="$(xrandr --nograb --current | awk '/ connected .*[0-9]+x[0-9]+\+/ && !/primary/ {print $3; exit}')"
        [[ -z "$resolution" ]] && resolution="$(xrandr --nograb --current | awk '/ primary/ {print $4; exit}')"
        resolution="${resolution%+*}"
    else
        resolution="n/a"
    fi
}

get_de() {
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
    [[ "$de" =~ (X-|:ubuntu) ]] && de="${de//X-/}"
}

get_wm() {
    if [[ -n "$XDG_CURRENT_DESKTOP" ]] && [[ "$XDG_SESSION_TYPE" = wayland ]]; then
        wm="$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')"
    elif has_cmd xprop && [[ -n "$DISPLAY" ]]; then
        wm="$(xprop -root -notype _NET_SUPPORTING_WM_CHECK 2>/dev/null | awk -F'"' '{print $2}')"
    fi
    [[ -z "$wm" ]] && wm="n/a"
}

get_theme() {
    if has_cmd gsettings; then
        theme="$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")"
    elif has_cmd xfconf-query; then
        theme="$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null)"
    fi
    [[ -z "$theme" ]] && theme="n/a"
}

get_icons() {
    if has_cmd gsettings; then
        icons="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
    elif has_cmd xfconf-query; then
        icons="$(xfconf-query -c xsettings -p /Net/IconThemeName 2>/dev/null)"
    fi
    [[ -z "$icons" ]] && icons="n/a"
}

get_term() {
    term="${TERM_PROGRAM:-${TERM}}"
    [[ -n "$SSH_CONNECTION" ]] && term="$SSH_TTY"
    [[ -n "$WT_SESSION" ]] && term="Windows Terminal"
    [[ -z "$term" ]] && term="unknown"
}

get_cpu() {
    cpu_model="$(lscpu 2>/dev/null | awk -F': +' '/Model name/ {print $2; exit}')"
    [[ -z "$cpu_model" ]] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)"
    cores="$(nproc 2>/dev/null)"
    [[ -z "$cores" ]] && cores="$(grep -c '^processor' /proc/cpuinfo)"
    
    # CPU-Temperatur
    if [[ -d /sys/class/thermal/thermal_zone0 ]]; then
        temp_raw="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
        if [[ -n "$temp_raw" ]]; then
            temp_c="$((temp_raw / 1000))"
            [[ "$temp_c" -gt 0 ]] && cpu_temp=" [${temp_c}°C]"
        fi
    fi
    
    # CPU-Takt
    speed_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    if [[ -f "$speed_file" ]]; then
        speed="$(($(< "$speed_file") / 1000))"
        if (( speed > 1000 )); then
            speed="$(awk "BEGIN {printf \"%.1f\", $speed/1000}")GHz"
        else
            speed="${speed}MHz"
        fi
    else
        speed=""
    fi
    
    cpu="$cpu_model (${cores})${cpu_temp:+ $cpu_temp}${speed:+ @ $speed}"
}

get_gpu() {
    gpu="$(lspci -mm | awk -F'"' '/"Display|"3D|"VGA/ {print $4 " " $6; exit}')"
    [[ -z "$gpu" ]] && gpu="n/a"
}

get_memory() {
    mem_total_kb="$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')"
    mem_avail_kb="$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
    if [[ -n "$mem_avail_kb" ]]; then
        mem_used_kb="$((mem_total_kb - mem_avail_kb))"
    else
        mem_free_kb="$(grep '^MemFree:' /proc/meminfo | awk '{print $2}')"
        buffers="$(grep '^Buffers:' /proc/meminfo | awk '{print $2}')"
        cached="$(grep '^Cached:' /proc/meminfo | awk '{print $2}')"
        sreclaim="$(grep '^SReclaimable:' /proc/meminfo | awk '{print $2}')"
        mem_used_kb="$((mem_total_kb - mem_free_kb - buffers - cached - sreclaim))"
    fi
    mem_total="$((mem_total_kb / 1024))"
    mem_used="$((mem_used_kb / 1024))"
    mem_perc="$((mem_used * 100 / mem_total))"
    memory="${mem_used}MiB / ${mem_total}MiB (${mem_perc}%)"
}

get_disk() {
    disk_used="$(df -h / | awk 'NR==2 {print $3}')"
    disk_total="$(df -h / | awk 'NR==2 {print $2}')"
    disk_perc="$(df -h / | awk 'NR==2 {print $5}')"
    disk="${disk_used} / ${disk_total} (${disk_perc})"
}

get_swap() {
    if [[ -f /proc/swaps ]]; then
        swap_total_kb="$(awk 'NR>1 {sum+=$3} END {print sum+0}' /proc/swaps)"
        swap_used_kb="$(awk 'NR>1 {sum+=$4} END {print sum+0}' /proc/swaps)"
        if [[ -n "$swap_total_kb" && "$swap_total_kb" -gt 0 ]]; then
            swap_used_mb="$((swap_used_kb / 1024))"
            swap_total_mb="$((swap_total_kb / 1024))"
            swap_perc="$((swap_used_kb * 100 / swap_total_kb))"
            swap="${swap_used_mb}MiB / ${swap_total_mb}MiB (${swap_perc}%)"
        else
            swap="n/a"
        fi
    else
        swap="n/a"
    fi
}

get_local_ip() {
    iface="$(ip route | awk '/default/ {print $5; exit}')"
    if [[ -n "$iface" ]]; then
        ip_addr="$(ip -4 addr show "$iface" | awk '/inet / {print $2; exit}')"
        ip_addr="${ip_addr%/*}"
    fi
    [[ -z "$ip_addr" ]] && ip_addr="n/a"
}

get_external_ip() {
    if has_cmd curl; then
        ext_ip="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || true)"
        isp="$(curl -fsSL --max-time 5 https://ipinfo.io/org 2>/dev/null | tr -d '\n' || true)"
    fi
    [[ -z "$ext_ip" ]] && ext_ip="n/a"
    [[ -z "$isp" ]] && isp="n/a"
}

get_gateway() {
    gateway="$(ip route | awk '/default/ {print $3; exit}')"
    [[ -z "$gateway" ]] && gateway="n/a"
}

get_dns() {
    dns_servers=()
    while IFS= read -r ns; do
        [[ "$ns" =~ ^nameserver[[:space:]]+(.+) ]] && dns_servers+=("${BASH_REMATCH[1]}")
    done < /etc/resolv.conf 2>/dev/null

    if ((${#dns_servers[@]} > 0)); then
        dns="$(IFS=', '; echo "${dns_servers[*]}")"
    else
        dns="n/a"
    fi
}

get_mac() {
    iface="$(ip route | awk '/default/ {print $5; exit}')"
    if [[ -n "$iface" ]]; then
        mac_addr="$(cat "/sys/class/net/$iface/address" 2>/dev/null)"
    fi
    [[ -z "$mac_addr" ]] && mac_addr="$(ip -o link show 2>/dev/null | awk '/link\/ether/ {print $17; exit}')"
    [[ -z "$mac_addr" ]] && mac_addr="n/a"
}

get_wifi_ssid() {
    if has_cmd iwgetid; then
        wifi_ssid="$(iwgetid -r 2>/dev/null)"
    elif has_cmd nmcli; then
        wifi_ssid="$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')"
    fi
    [[ -z "$wifi_ssid" ]] && wifi_ssid="n/a"
}

get_ufw() {
    if has_cmd ufw; then
        ufw_status="$(ufw status 2>/dev/null | awk '/^Status:/ {print $2; exit}')"
        [[ -z "$ufw_status" ]] && ufw_status="inactive"
    else
        ufw_status="n/a"
    fi
}

# ---------- ASCII-Logo (Ubuntu) – hier kann später ein Logo in Ubuntu-Farben eingefügt werden ----------
# print_ascii() {
# }

# ---------- Hauptausgabe ----------
main() {
    # Alle Informationen sammeln
    get_distro
    get_host
    get_kernel
    get_uptime
    get_packages
    get_shell
    get_resolution
    get_de
    get_wm
    get_theme
    get_icons
    get_term
    get_cpu
    get_gpu
    get_memory
    get_disk
    get_swap
    get_local_ip
    get_external_ip
    get_gateway
    get_dns
    get_mac
    get_wifi_ssid
    get_ufw

    # Ausgabe
    echo -e "${title_col}${bold}$(hostname) System Information${reset}"
    echo -e "${sub_col}${bold}$distro${reset}\n"

    # ASCII-Logo (optional)
    # print_ascii

    # Info-Zeilen mit automatischem Alignment
    max_len=0
    declare -A info_lines
    info_lines=(
        ["OS"]="$distro"
        ["Host"]="$hostname"
        ["Kernel"]="$kernel"
        ["Uptime"]="$uptime"
        ["Packages"]="$packages"
        ["Shell"]="$shell"
        ["Resolution"]="$resolution"
        ["DE"]="$de"
        ["WM"]="$wm"
        ["Theme"]="$theme"
        ["Icons"]="$icons"
        ["Terminal"]="$term"
        ["CPU"]="$cpu"
        ["GPU"]="$gpu"
        ["Memory"]="$memory"
        ["Swap"]="$swap"
        ["Disk (/)"]="$disk"
        ["Local IP"]="$ip_addr"
        ["External IP"]="$ext_ip"
        ["ISP"]="$isp"
        ["Gateway"]="$gateway"
        ["DNS"]="$dns"
        ["MAC"]="$mac_addr"
        ["WiFi SSID"]="$wifi_ssid"
        ["UFW"]="$ufw_status"
    )

    for key in "${!info_lines[@]}"; do
        len="${#key}"
        (( len > max_len )) && max_len="$len"
    done
    col_width="$((max_len + 2))"

    for key in "OS" "Host" "Kernel" "Uptime" "Packages" "Shell" "Resolution" "DE" "WM" "Theme" "Icons" "Terminal" "CPU" "GPU" "Memory" "Swap" "Disk (/)" "Local IP" "External IP" "ISP" "Gateway" "DNS" "MAC" "WiFi SSID" "UFW"; do
        value="${info_lines[$key]}"
        value="$(trim "$value")"
        printf "${sub_col}%-${col_width}s${colon_col}:${info_col} %s${reset}\n" "$key" "$value"
    done

    echo -e "\n${bold}${info_col}Generated: $(date '+%Y-%m-%d %H:%M:%S')${reset}"
}

# ---------- Start ----------
main "$@"