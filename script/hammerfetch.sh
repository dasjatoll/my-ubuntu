#!/usr/bin/env bash
# ============================================================
#  hammerfetch - getting fukkn wasted with dat tools

#  sudo apt update && sudo apt install -y \
#    lsb-release lshw dmidecode lm-sensors smartmontools acpi \
#    curl wget net-tools \
#    snapd flatpak docker.io podman \
#    python3-pip npm ruby-full \
#    build-essential cmake ninja-build golang-go rustc clang default-jdk \
#    apparmor-utils ufw openssh-server
    
# Alle Infos für Admin, Dev, Power-User – ohne Kompromisse
# ============================================================

# ---------- Farben & Formatierung (Hammerfetch – Rot) ----------
reset='\e[0m'
bold='\e[1m'
title_col="${bold}\e[38;5;196m"      # knalliges Rot (danger)
sub_col="${bold}\e[38;5;160m"        # dunkleres Rot (fire)
info_col="\e[38;5;255m"              # Weiß für Lesbarkeit
colon_col="\e[38;5;244m"             # Dunkelgrau
dim_col="\e[38;5;240m"               # Grau für Trennlinien
separator="${dim_col}────────────────────────────────────────────────${reset}"

# ---------- Hilfsfunktionen ----------
has_cmd() { command -v "$1" &>/dev/null; }
trim() { echo -n "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
err() { echo -e "${bold}${info_col}⚠️  $*${reset}" >&2; }
get_seconds_uptime() {
    if [[ -f /proc/uptime ]]; then cut -d. -f1 /proc/uptime; else echo 0; fi
}

# ---------- 1. System ----------
get_system() {
    hostname="$(hostname)"
    fqdn="$(hostname -f 2>/dev/null || echo "$hostname")"
    distro="$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    arch="$(uname -m)"
    [[ -n "$distro" ]] && distro="$distro $arch"
    kernel="$(uname -r)"
    kernel_build="$(uname -v | cut -d' ' -f1-2)"
    kernel_date="$(uname -v | grep -oP '^#\d+ SMP \K[^ ]+ [^ ]+ [^ ]+' || echo 'n/a')"
    
    uptime_sec="$(get_seconds_uptime)"
    d=$((uptime_sec/86400)); h=$(((uptime_sec%86400)/3600)); m=$(((uptime_sec%3600)/60))
    uptime=""
    ((d>0)) && uptime+="${d}d "
    ((h>0)) && uptime+="${h}h "
    ((m>0)) && uptime+="${m}m"
    [[ -z "$uptime" ]] && uptime="${uptime_sec}s"
    boot_time="$(date -d "@$(( $(date +%s) - uptime_sec ))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'n/a')"
    boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo 'n/a')"
    system_uuid="$(cat /sys/class/dmi/id/product_uuid 2>/dev/null || echo 'n/a')"
    
    # Virtualisierung
    if has_cmd systemd-detect-virt; then
        virt="$(systemd-detect-virt 2>/dev/null || echo 'none')"
    else
        virt="n/a"
    fi
    
    # Load Average
    read -r load1 load5 load15 _ < /proc/loadavg 2>/dev/null
    load_avg="$load1, $load5, $load15"
    
    # Prozesse & Threads
    processes="$(ps --no-headers -e 2>/dev/null | wc -l)"
    threads="$(ps --no-headers -eL 2>/dev/null | wc -l)"
    open_files="$(lsof 2>/dev/null | wc -l)"
    
    # Prozesse nach Zustand
    running_p="$(ps --no-headers -e -o state= | grep -c R)"
    sleeping_p="$(ps --no-headers -e -o state= | grep -c S)"
    stopped_p="$(ps --no-headers -e -o state= | grep -c T)"
    zombie_p="$(ps --no-headers -e -o state= | grep -c Z)"
    
    # Systemd-Dienste
    if has_cmd systemctl; then
        services_total="$(systemctl list-unit-files --type=service --no-pager 2>/dev/null | wc -l)"
        services_active="$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | wc -l)"
        services="$services_active / $services_total"
        systemd_start="$(systemctl show -p UserspaceTimestamp | cut -d= -f2 2>/dev/null || echo 'n/a')"
    else
        services="n/a"; systemd_start="n/a"
    fi
    
    # Mounts (Dateisysteme)
    mounts="$(df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | awk '{print $7 " ("$2") " $3 "/" $4 " ("$6")"}' | paste -sd ', ' -)"
    [[ -z "$mounts" ]] && mounts="n/a"
    
    # Zeitzone & Locale
    timezone="$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo 'n/a')"
    locale="$(localectl status 2>/dev/null | grep 'System Locale' | cut -d: -f2- | trim || echo 'n/a')"
}

# ---------- 2. Hardware ----------
get_hardware() {
    # CPU
    cpu_model="$(lscpu 2>/dev/null | awk -F': +' '/Model name/ {print $2; exit}')"
    [[ -z "$cpu_model" ]] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)"
    cores="$(nproc 2>/dev/null)"
    [[ -z "$cores" ]] && cores="$(grep -c '^processor' /proc/cpuinfo)"
    
    # CPU-Takt
    speed_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
    if [[ -f "$speed_file" ]]; then
        speed="$(($(< "$speed_file") / 1000))"
        (( speed > 1000 )) && speed="$(awk "BEGIN {printf \"%.1f\", $speed/1000}") GHz" || speed="${speed} MHz"
    else
        speed="n/a"
    fi
    
    # CPU-Temperatur
    cpu_temp=""
    if [[ -d /sys/class/thermal/thermal_zone0 ]]; then
        temp_raw="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)"
        [[ -n "$temp_raw" ]] && cpu_temp="[$(($temp_raw / 1000))°C]"
    fi
    # CPU-Auslastung (1-Minute-Durchschnitt)
    cpu_usage="$(top -bn1 | head -5 | awk '/%Cpu/ {print $2}' | cut -d. -f1)%"
    
    # CPU-Cache
    if has_cmd lscpu; then
        l1="$(lscpu | awk -F': +' '/L1d cache/ {print $2; exit}')"
        l2="$(lscpu | awk -F': +' '/L2 cache/ {print $2; exit}')"
        l3="$(lscpu | awk -F': +' '/L3 cache/ {print $2; exit}')"
        cpu_cache="L1 $l1, L2 $l2, L3 $l3"
    else
        cpu_cache="n/a"
    fi
    microcode="$(cat /proc/cpuinfo | grep microcode | head -1 | cut -d: -f2- | trim || echo 'n/a')"
    cpu_flags="$(grep -m1 flags /proc/cpuinfo | cut -d: -f2- | trim | cut -d' ' -f1-10 | tr '\n' ' ')"
    
    # GPU
    gpu="$(lspci -mm | awk -F'"' '/"Display|"3D|"VGA/ {print $4 " " $6; exit}')"
    gpu_driver="$(lspci -k | grep -A2 -E 'VGA|Display' | grep -i driver | head -1 | cut -d: -f2- | trim)"
    [[ -z "$gpu" ]] && gpu="n/a"
    [[ -z "$gpu_driver" ]] && gpu_driver="n/a"
    
    # Mainboard / BIOS (mit sudo falls möglich)
    if has_cmd lshw; then
        board="$(lshw -class system 2>/dev/null | grep -E 'product:|vendor:' | head -2 | tr -d '\t' | paste -sd ' ' -)"
        bios="$(lshw -class firmware 2>/dev/null | grep version | head -1 | cut -d: -f2- | trim)"
        serial="$(lshw -class system 2>/dev/null | grep serial | head -1 | cut -d: -f2- | trim)"
    elif has_cmd dmidecode && [[ "$EUID" -eq 0 ]]; then
        board="$(dmidecode -s system-manufacturer 2>/dev/null) $(dmidecode -s system-product-name 2>/dev/null)"
        bios="$(dmidecode -s bios-version 2>/dev/null)"
        serial="$(dmidecode -s system-serial-number 2>/dev/null)"
    else
        board="n/a"; bios="n/a"; serial="n/a"
    fi
    
    # RAM
    mem_total_kb="$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')"
    mem_avail_kb="$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
    mem_used_kb="$((mem_total_kb - mem_avail_kb))"
    mem_total="$((mem_total_kb / 1024)) MiB"
    mem_used="$((mem_used_kb / 1024)) MiB"
    mem_perc="$((mem_used_kb * 100 / mem_total_kb))%"
    
    # HugePages
    hugepages_total="$(grep HugePages_Total /proc/meminfo | awk '{print $2}')"
    hugepages_free="$(grep HugePages_Free /proc/meminfo | awk '{print $2}')"
    [[ -z "$hugepages_total" ]] && hugepages_total="0"
    
    # Slab
    slab="$(grep Slab /proc/meminfo | awk '{print $2 " " $3}')"
    # ZRAM
    zram="$(grep -E 'zram' /proc/swaps 2>/dev/null | wc -l)"
    
    # Swap
    swap_total_kb="$(grep '^SwapTotal:' /proc/meminfo | awk '{print $2}')"
    swap_free_kb="$(grep '^SwapFree:' /proc/meminfo | awk '{print $2}')"
    swap_used_kb="$((swap_total_kb - swap_free_kb))"
    swap_total="$((swap_total_kb / 1024)) MiB"
    swap_used="$((swap_used_kb / 1024)) MiB"
    
    # Blockgeräte (alle Festplatten/SSDs)
    block_devs=""
    if has_cmd lsblk; then
        block_devs="$(lsblk -d -o NAME,MODEL,SIZE 2>/dev/null | tail -n +2 | awk '{print $1 " ("$2") " $3}' | paste -sd ', ' -)"
    fi
    [[ -z "$block_devs" ]] && block_devs="n/a"
    
    # Partitionen (detailiert)
    disk_info="$(df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | head -5 | awk '{print $1 " ("$5")"}' | paste -sd ', ' -)"
    [[ -z "$disk_info" ]] && disk_info="n/a"
    
    # SMART (root)
    smart_status="n/a"
    if has_cmd smartctl && [[ "$EUID" -eq 0 ]]; then
        for dev in /dev/sd? /dev/nvme0n1; do
            [[ -b "$dev" ]] && smart_status="$(smartctl -H "$dev" 2>/dev/null | grep -i 'overall-health' | awk '{print $NF}')" && break
        done
    fi
    
    # Sensoren
    sensors_info="n/a"
    if has_cmd sensors; then
        sensors_info="$(sensors 2>/dev/null | grep -E 'Core|fan|temp' | head -3 | tr -d '+°' | paste -sd ', ' -)"
    fi
    
    # PCI-Geräte (kurz)
    pci_devices="$(lspci -mm | awk -F'"' '{print $2 " " $4}' | head -5 | paste -sd ', ' -)"
    [[ -z "$pci_devices" ]] && pci_devices="n/a"
    
    # USB-Geräte (lsusb -t)
    usb_devices="$(lsusb -t 2>/dev/null | head -3 | paste -sd ', ' -)"
    [[ -z "$usb_devices" ]] && usb_devices="n/a"
    
    # Display-Server & DPI
    if [[ -n "$DISPLAY" ]]; then
        display_server="X11"
        dpi="$(xdpyinfo 2>/dev/null | grep -i 'resolution' | awk '{print $2}' | head -1 || echo 'n/a')"
    elif [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        display_server="Wayland"
        dpi="n/a"
    else
        display_server="n/a"; dpi="n/a"
    fi
}

# ---------- 3. Netzwerk ----------
get_network() {
    interfaces_info=""
    if has_cmd ip; then
        while read -r iface; do
            [[ "$iface" == "lo" ]] && continue
            mac="$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')"
            ips="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | paste -sd ', ' -)"
            ips6="$(ip -6 addr show "$iface" 2>/dev/null | grep inet6 | awk '{print $2}' | cut -d/ -f1 | paste -sd ', ' -)"
            mtu="$(ip link show "$iface" 2>/dev/null | awk '/mtu/ {print $5}')"
            state="$(ip link show "$iface" 2>/dev/null | awk '/state/ {print $9}' | tr -d ',')"
            speed="$(cat /sys/class/net/"$iface"/speed 2>/dev/null) Mbps"
            [[ -z "$speed" || "$speed" == " Mbps" ]] && speed="n/a"
            # Statistiken (RX/TX)
            rx_bytes="$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null | numfmt --to=iec 2>/dev/null || echo '0')"
            tx_bytes="$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null | numfmt --to=iec 2>/dev/null || echo '0')"
            interfaces_info+="$iface: $state, MTU $mtu, MAC $mac, IPv4 $ips, IPv6 $ips6, Speed $speed, RX $rx_bytes, TX $tx_bytes; "
        done < <(ip -br link | grep -v LOOPBACK | awk '{print $1}')
    fi
    [[ -z "$interfaces_info" ]] && interfaces_info="n/a"
    
    # Gateway
    gateway="$(ip route | awk '/default/ {print $3; exit}')"
    [[ -z "$gateway" ]] && gateway="n/a"
    
    # Routing-Tabelle (kurz)
    route_table="$(ip route | grep -E 'default|dev' | head -3 | paste -sd ', ' -)"
    [[ -z "$route_table" ]] && route_table="n/a"
    
    # ARP-Tabelle
    arp_table="$(ip neigh | head -3 | paste -sd ', ' -)"
    [[ -z "$arp_table" ]] && arp_table="n/a"
    
    # Offene Ports (TCP/UDP mit Prozess)
    if has_cmd ss; then
        open_ports="$(ss -tulpn 2>/dev/null | awk 'NR>1 {print $5 " " $6}' | head -5 | paste -sd ', ' -)"
        [[ -z "$open_ports" ]] && open_ports="keine (oder keine Berechtigung)"
        # Verbindungszustände
        conn_stats="$(ss -s 2>/dev/null | grep -E 'TCP:|UDP:' | paste -sd ', ' -)"
    else
        open_ports="n/a"; conn_stats="n/a"
    fi
    
    # Öffentliche IP
    public_ip=""
    if has_cmd curl; then
        public_ip="$(curl -s --max-time 2 ifconfig.me 2>/dev/null)"
    elif has_cmd wget; then
        public_ip="$(wget -qO- --timeout=2 ifconfig.me 2>/dev/null)"
    fi
    [[ -z "$public_ip" ]] && public_ip="n/a"
    
    # DNS
    dns_servers="$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ', ' -)"
    search_domain="$(grep -E '^search' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ', ' -)"
    [[ -z "$dns_servers" ]] && dns_servers="n/a"
    [[ -z "$search_domain" ]] && search_domain="n/a"
    
    # HTTP-Proxy
    http_proxy="${http_proxy:-$HTTP_PROXY}"
    [[ -z "$http_proxy" ]] && http_proxy="n/a"
}

# ---------- 4. Software & Entwicklung ----------
get_software() {
    # Paketmanager
    if has_cmd dpkg; then
        packages_dpkg="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"
    else
        packages_dpkg="n/a"
    fi
    if has_cmd snap; then
        packages_snap="$(snap list 2>/dev/null | tail -n +2 | wc -l)"
        snap_list="$(snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | paste -sd ', ' - | cut -c1-50)..."  # gekürzt
    else
        packages_snap="n/a"; snap_list="n/a"
    fi
    if has_cmd flatpak; then
        packages_flatpak="$(flatpak list 2>/dev/null | wc -l)"
        flatpak_list="$(flatpak list 2>/dev/null | awk '{print $2}' | paste -sd ', ' - | cut -c1-50)..."
    else
        packages_flatpak="n/a"; flatpak_list="n/a"
    fi
    packages="${packages_dpkg} (dpkg), ${packages_snap} (snap), ${packages_flatpak} (flatpak)"
    
    # Updates
    if [[ -d /var/lib/apt/lists ]]; then
        updates="$(apt list --upgradable 2>/dev/null | grep -c upgradable)"
        [[ -z "$updates" ]] && updates="0"
    else
        updates="n/a"
    fi
    
    # Container
    containers=""
    if has_cmd docker; then
        containers+="Docker: $(docker ps -a -q 2>/dev/null | wc -l) (images: $(docker images -q 2>/dev/null | wc -l)) "
    fi
    if has_cmd podman; then
        containers+="Podman: $(podman ps -a -q 2>/dev/null | wc -l) "
    fi
    [[ -z "$containers" ]] && containers="n/a"
    
    # Kernel-Module
    if has_cmd lsmod; then
        modules_count="$(lsmod | tail -n +2 | wc -l)"
        modules_top="$(lsmod | tail -n +2 | head -3 | awk '{print $1}' | paste -sd ', ' -)"
    else
        modules_count="n/a"; modules_top="n/a"
    fi
    
    # Systemd-Analyse (Boot-Zeit)
    if has_cmd systemd-analyze; then
        boot_time_analyze="$(systemd-analyze time 2>/dev/null | grep -oP '.*\d+.\d+s' | head -1)"
    else
        boot_time_analyze="n/a"
    fi
    
    # Sprachen / Compiler
    lang_versions=""
    for cmd in gcc g++ python3 node java go rustc clang; do
        if has_cmd "$cmd"; then
            ver="$("$cmd" --version 2>/dev/null | head -1 | awk '{print $NF}')"
            lang_versions+="$cmd $ver, "
        fi
    done
    [[ -z "$lang_versions" ]] && lang_versions="n/a"
    
    # Build-Tools
    build_tools=""
    for cmd in make cmake ninja; do
        if has_cmd "$cmd"; then
            ver="$("$cmd" --version 2>/dev/null | head -1 | awk '{print $NF}')"
            build_tools+="$cmd $ver, "
        fi
    done
    [[ -z "$build_tools" ]] && build_tools="n/a"
    
    # Python-Pakete (global)
    python_pkgs="n/a"
    if has_cmd pip3; then
        python_pkgs="$(pip3 list --format=freeze 2>/dev/null | wc -l)"
    fi
    # Node.js globale Pakete
    node_pkgs="n/a"
    if has_cmd npm; then
        node_pkgs="$(npm list -g --depth=0 2>/dev/null | wc -l)"
    fi
    # Ruby Gems
    ruby_gems="n/a"
    if has_cmd gem; then
        ruby_gems="$(gem list 2>/dev/null | wc -l)"
    fi
    # ldconfig Cache
    ld_cache="$(ldconfig -p 2>/dev/null | wc -l)"
    [[ -z "$ld_cache" ]] && ld_cache="n/a"
    
    # Kernel-Cmdline
    kernel_cmdline="$(cat /proc/cmdline 2>/dev/null)"
    [[ -z "$kernel_cmdline" ]] && kernel_cmdline="n/a"
    
    # Environment
    env_path="$PATH"
    env_lang="$LANG"
}

# ---------- 5. Sicherheit & Zugriff ----------
get_security() {
    # Letzte Logins (aktueller User)
    last_login="$(last -1 "$USER" 2>/dev/null | head -1 | awk '{print $4, $5, $6, $7, $8, $9}')"
    [[ -z "$last_login" ]] && last_login="n/a"
    # Fehlgeschlagene Logins (letzte 5)
    failed_logins="$(lastb -a 2>/dev/null | head -5 | awk '{print $1 " " $3 " " $4 " " $5}' | paste -sd ', ' -)"
    [[ -z "$failed_logins" ]] && failed_logins="n/a"
    
    # Aktuelle Sessions (who)
    who_sessions="$(who -u 2>/dev/null | head -3 | awk '{print $1 " " $2 " " $3 " " $4}' | paste -sd ', ' -)"
    [[ -z "$who_sessions" ]] && who_sessions="n/a"
    
    # Sudo-User
    sudo_users="$(grep -E '^sudo:|^admin:' /etc/group 2>/dev/null | cut -d: -f4 | tr ',' ' ')"
    [[ -z "$sudo_users" ]] && sudo_users="n/a"
    
    # Sudo Defaults
    if has_cmd sudo; then
        sudo_defaults="$(sudo -l 2>/dev/null | grep -E 'Defaults|User|Commands' | head -3 | paste -sd ', ' -)"
        [[ -z "$sudo_defaults" ]] && sudo_defaults="n/a"
    else
        sudo_defaults="n/a"
    fi
    
    # Firewall
    if has_cmd ufw && ufw status | grep -q aktiv; then
        ufw_rules="$(ufw status numbered 2>/dev/null | grep -c '^\[')"
        firewall="UFW aktiv (Regeln: $ufw_rules)"
    elif has_cmd iptables; then
        ipt_rules="$(iptables -L -n 2>/dev/null | grep -c '^Chain')"
        firewall="iptables aktiv ($ipt_rules Ketten)"
    else
        firewall="n/a"
    fi
    
    # SSH-Server
    if has_cmd systemctl && systemctl is-active --quiet ssh 2>/dev/null; then
        ssh_port="$(grep -E '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)"
        [[ -z "$ssh_port" ]] && ssh_port="22"
        ssh_permitroot="$(grep -E '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)"
        ssh_pw_auth="$(grep -E '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)"
        ssh_status="aktiv (Port $ssh_port, RootLogin: ${ssh_permitroot:-default}, PassAuth: ${ssh_pw_auth:-default})"
    else
        ssh_status="inaktiv"
    fi
    
    # AppArmor / SELinux
    apparmor_status="n/a"
    if has_cmd apparmor_status; then
        apparmor_status="$(apparmor_status 2>/dev/null | grep -E 'profiles|processes' | paste -sd ', ' -)"
    fi
    selinux_status="n/a"
    if [[ -f /sys/fs/selinux/enforce ]]; then
        selinux_status="$(cat /sys/fs/selinux/enforce 2>/dev/null | awk '{print ($1==1?"enforcing":"permissive")}')"
    fi
    
    # Kernel-ASLR
    aslr="$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo 'n/a')"
    [[ "$aslr" == "2" ]] && aslr="active (2)" || aslr="inactive ($aslr)"
    
    # Cron/At-Jobs
    cron_jobs="$(crontab -l 2>/dev/null | grep -v '^#' | wc -l)"
    at_jobs="$(atq 2>/dev/null | wc -l)"
    [[ -z "$cron_jobs" ]] && cron_jobs="0"
    [[ -z "$at_jobs" ]] && at_jobs="0"
}

# ---------- Hauptausgabe ----------
main() {
    get_system
    get_hardware
    get_network
    get_software
    get_security
    
    # Kopf
    echo -e "${title_col}${bold}  $(hostname) – Systemübersicht (XXL)${reset}"
    echo -e "${sub_col}${bold}$distro${reset}"
    echo -e "${separator}"
    
    # 1. System
    echo -e "${sub_col}${bold}System${reset}"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Host" "$hostname ($fqdn)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "OS" "$distro"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Kernel" "$kernel ($kernel_build, $kernel_date)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Boot ID" "$boot_id"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "System UUID" "$system_uuid"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Virtualisierung" "$virt"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Uptime" "$uptime (seit $boot_time)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Load (1,5,15)" "$load_avg"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Prozesse" "$processes (Threads: $threads, R:$running_p S:$sleeping_p T:$stopped_p Z:$zombie_p)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Offene Files" "$open_files"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Systemd-Dienste" "$services (Start: $systemd_start)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Dateisysteme" "$mounts"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Zeitzone" "$timezone"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Locale" "$locale"
    echo -e "${separator}"
    
    # 2. Hardware
    echo -e "${sub_col}${bold}Hardware${reset}"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "CPU" "$cpu_model ($cores Kerne) @ $speed $cpu_temp, Auslastung $cpu_usage"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "CPU-Cache" "$cpu_cache"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Microcode" "$microcode"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "CPU-Flags" "$cpu_flags"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "GPU" "$gpu (Treiber: $gpu_driver)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Mainboard" "$board (SN: $serial)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "BIOS" "$bios"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Display-Server" "$display_server, DPI: $dpi"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "RAM" "$mem_used von $mem_total ($mem_perc belegt)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "HugePages" "$hugepages_total total, $hugepages_free frei"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Slab" "$slab"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "ZRAM" "$zram (Devices)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Swap" "$swap_used von $swap_total"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Blockgeräte" "$block_devs"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Partitionen" "$disk_info"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "SMART" "$smart_status"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Sensoren" "$sensors_info"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "PCI-Geräte" "$pci_devices"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "USB-Geräte" "$usb_devices"
    echo -e "${separator}"
    
    # 3. Netzwerk
    echo -e "${sub_col}${bold}Netzwerk${reset}"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Interfaces" "$interfaces_info"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Gateway" "$gateway"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Routing" "$route_table"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "ARP" "$arp_table"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Offene Ports" "$open_ports"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Verbindungsstatus" "$conn_stats"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Öffentliche IP" "$public_ip"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "DNS-Server" "$dns_servers"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Search Domain" "$search_domain"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "HTTP-Proxy" "$http_proxy"
    echo -e "${separator}"
    
    # 4. Software & Entwicklung
    echo -e "${sub_col}${bold}Software / Entwicklung${reset}"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Pakete" "$packages"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Snap-Liste" "$snap_list"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Flatpak-Liste" "$flatpak_list"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Updates" "$updates verfügbar"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Container" "$containers"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Kernel-Module" "$modules_count (z.B. $modules_top)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Systemd-Boot" "$boot_time_analyze"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Sprachen/Tools" "$lang_versions"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Build-Tools" "$build_tools"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Python-Pakete" "$python_pkgs (global)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Node.js-Pakete" "$node_pkgs (global)"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Ruby-Gems" "$ruby_gems"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "ldconfig-Cache" "$ld_cache Einträge"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Kernel-Cmdline" "$kernel_cmdline"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "PATH" "$env_path"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "LANG" "$env_lang"
    echo -e "${separator}"
    
    # 5. Sicherheit
    echo -e "${sub_col}${bold}Sicherheit / Zugriff${reset}"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Letzter Login" "$last_login"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Fehlgeschlagene" "$failed_logins"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Aktive Sessions" "$who_sessions"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Sudo-User" "$sudo_users"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Sudo-Defaults" "$sudo_defaults"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Firewall" "$firewall"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "SSH-Server" "$ssh_status"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "AppArmor" "$apparmor_status"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "SELinux" "$selinux_status"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "ASLR" "$aslr"
    printf "${sub_col}%-20s${colon_col}:${info_col} %s${reset}\n" "Cron/At" "$cron_jobs Cron, $at_jobs At"
    echo -e "${separator}"
    
    echo -e "${bold}${info_col}Generated: $(date '+%Y-%m-%d %H:%M:%S')${reset}"
}

# ---------- Start ----------
main "$@"
