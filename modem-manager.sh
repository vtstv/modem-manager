#!/bin/bash
# Mobile Modem Manager - Interactive GSM/LTE/eSIM Management Tool
# Version: 1.2
# Author: Murr
# GitHub: https://github.com/vtstv
# License: MIT
#

VERSION="1.3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_copyright() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  Mobile Modem Manager v${VERSION} - GSM/LTE/eSIM Management    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Author: Murr | GitHub: github.com/vtstv | MIT License  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 1
}

# Detect the Linux distribution and set package manager info
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID,,}"
        DISTRO_ID_LIKE="${ID_LIKE,,}"
    else
        DISTRO_ID=""
        DISTRO_ID_LIKE=""
    fi

    # Arch-based (Arch, Manjaro, EndeavourOS, Garuda, etc.)
    if [ -f /etc/arch-release ] || echo "$DISTRO_ID $DISTRO_ID_LIKE" | grep -qw "arch"; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE=""
        # package name map: tool -> package
        declare -gA PKG_MAP=(
            [mmcli]="modemmanager"
            [nmcli]="networkmanager"
            [systemctl]="systemd"
            [systemd-creds]="systemd"
            [sudo]="sudo"
            [ping]="iputils"
        )
        DISTRO_LABEL="Arch Linux"

    # Debian/Ubuntu-based
    elif [ -f /etc/debian_version ] || echo "$DISTRO_ID $DISTRO_ID_LIKE" | grep -qwE "debian|ubuntu"; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt install -y"
        PKG_UPDATE="sudo apt update"
        declare -gA PKG_MAP=(
            [mmcli]="modemmanager"
            [nmcli]="network-manager"
            [systemctl]="systemd"
            [systemd-creds]="systemd"
            [sudo]="sudo"
            [ping]="iputils-ping"
        )
        DISTRO_LABEL="Debian/Ubuntu"

    # Fedora / RHEL / CentOS / Rocky / AlmaLinux
    elif echo "$DISTRO_ID $DISTRO_ID_LIKE" | grep -qwE "fedora|rhel|centos|rocky|alma|redhat"; then
        if command -v dnf >/dev/null 2>&1; then
            PKG_MANAGER="dnf"
            PKG_INSTALL="sudo dnf install -y"
            PKG_UPDATE=""
        else
            PKG_MANAGER="yum"
            PKG_INSTALL="sudo yum install -y"
            PKG_UPDATE=""
        fi
        declare -gA PKG_MAP=(
            [mmcli]="ModemManager"
            [nmcli]="NetworkManager"
            [systemctl]="systemd"
            [systemd-creds]="systemd"
            [sudo]="sudo"
            [ping]="iputils"
        )
        DISTRO_LABEL="Fedora/RHEL"

    # openSUSE / SUSE
    elif echo "$DISTRO_ID $DISTRO_ID_LIKE" | grep -qwE "suse|opensuse"; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="sudo zypper install -y"
        PKG_UPDATE=""
        declare -gA PKG_MAP=(
            [mmcli]="ModemManager"
            [nmcli]="NetworkManager"
            [systemctl]="systemd"
            [systemd-creds]="systemd"
            [sudo]="sudo"
            [ping]="iputils"
        )
        DISTRO_LABEL="openSUSE/SUSE"

    else
        PKG_MANAGER=""
        PKG_INSTALL=""
        PKG_UPDATE=""
        declare -gA PKG_MAP=()
        DISTRO_LABEL="Unknown"
    fi
}

# Check and install dependencies
check_dependencies() {
    detect_distro

    # Map: binary -> human-readable description
    declare -A DEP_DESC=(
        [mmcli]="ModemManager CLI (mmcli)"
        [nmcli]="NetworkManager CLI (nmcli)"
        [systemctl]="systemd (systemctl)"
        [systemd-creds]="systemd credentials (systemd-creds)"
        [sudo]="sudo"
        [ping]="ping (iputils)"
    )

    local missing_bins=()
    local missing_pkgs=()
    local seen_pkgs=()

    for bin in mmcli nmcli systemctl systemd-creds sudo ping; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing_bins+=("$bin")
            local pkg="${PKG_MAP[$bin]:-$bin}"
            # Avoid duplicate package names
            if [[ ! " ${seen_pkgs[*]} " =~ " ${pkg} " ]]; then
                missing_pkgs+=("$pkg")
                seen_pkgs+=("$pkg")
            fi
        fi
    done

    # ── All good ──────────────────────────────────────────────────────────────
    if [ ${#missing_bins[@]} -eq 0 ]; then
        # Check if services need to be started (ask user first)
        _ensure_services_running
        return 0
    fi

    # ── Report missing deps ───────────────────────────────────────────────────
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              MISSING DEPENDENCIES DETECTED                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}  The following required tools are not installed:${NC}"
    echo ""
    for bin in "${missing_bins[@]}"; do
        echo -e "    ${RED}✗${NC}  ${DEP_DESC[$bin]:-$bin}"
    done
    echo ""

    if [ -z "$PKG_MANAGER" ]; then
        echo -e "${RED}[ERROR] Unsupported distribution ($DISTRO_LABEL).${NC}"
        echo -e "${YELLOW}        Please install the following packages manually:${NC}"
        for pkg in "${missing_pkgs[@]}"; do
            echo -e "          - $pkg"
        done
        echo ""
        exit 1
    fi

    echo -e "${BLUE}  Detected distribution : ${NC}${DISTRO_LABEL}"
    echo -e "${BLUE}  Package manager       : ${NC}${PKG_MANAGER}"
    echo -e "${BLUE}  Packages to install   : ${NC}${missing_pkgs[*]}"
    echo ""
    read -p "  Install missing packages now? (y/n): " do_install
    echo ""

    if [ "$do_install" != "y" ] && [ "$do_install" != "Y" ]; then
        echo -e "${RED}[ERROR] Cannot continue without required packages. Exiting.${NC}"
        exit 1
    fi

    # ── Run package manager update if needed ─────────────────────────────────
    if [ -n "$PKG_UPDATE" ]; then
        echo -e "${BLUE}[*] Updating package lists...${NC}"
        if ! eval "$PKG_UPDATE"; then
            echo -e "${RED}[ERROR] Failed to update package lists.${NC}"
            exit 1
        fi
    fi

    # ── Install missing packages ──────────────────────────────────────────────
    echo -e "${BLUE}[*] Installing on ${DISTRO_LABEL}...${NC}"
    if ! eval "$PKG_INSTALL ${missing_pkgs[*]}"; then
        echo -e "${RED}[ERROR] Package installation failed. Please install manually:${NC}"
        for pkg in "${missing_pkgs[@]}"; do
            echo -e "          - $pkg"
        done
        exit 1
    fi

    echo ""
    echo -e "${GREEN}[OK] All dependencies installed successfully.${NC}"
    echo ""

    # ── Enable & start services after install (ask user) ─────────────────────
    _ensure_services_running

    sleep 2
}

# Check if ModemManager / NetworkManager are running; ask user before starting
_ensure_services_running() {
    local services=("ModemManager" "NetworkManager")
    local stopped_svcs=()

    for svc in "${services[@]}"; do
        if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
            stopped_svcs+=("$svc")
        fi
    done

    [ ${#stopped_svcs[@]} -eq 0 ] && return 0

    echo ""
    echo -e "${YELLOW}  The following required services are not running:${NC}"
    for svc in "${stopped_svcs[@]}"; do
        echo -e "    ${YELLOW}⚠${NC}  $svc"
    done
    echo ""
    read -p "  Enable and start these services now? (y/n): " do_start
    echo ""

    if [ "$do_start" != "y" ] && [ "$do_start" != "Y" ]; then
        echo -e "${YELLOW}[!] Services not started. Some features may not work.${NC}"
        sleep 2
        return 0
    fi

    for svc in "${stopped_svcs[@]}"; do
        echo -e "${BLUE}[*] Enabling and starting ${svc}...${NC}"
        if sudo systemctl enable --now "$svc" 2>/dev/null; then
            echo -e "${GREEN}[OK] ${svc} started.${NC}"
        else
            echo -e "${YELLOW}[!] Could not start ${svc}.${NC}"
        fi
    done

    sleep 2
}

get_modem_id() {
    mmcli -L 2>/dev/null | grep -oP '/Modem/\K[0-9]+' | head -1
}

get_sim_id() {
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && return 1
    mmcli -m "$MODEM" | grep -oP 'primary sim path: /org/freedesktop/ModemManager1/SIM/\K[0-9]+'
}

list_gsm_connections() {
    nmcli -t -f NAME,TYPE connection show | grep ":gsm" | cut -d: -f1
}

select_connection() {
    # NOTE: This function prints the chosen connection name to stdout.
    # All interactive prompts MUST go to stderr so callers using $() capture
    # only the connection name and not menu text.
    local connections=()
    while IFS= read -r line; do
        connections+=("$line")
    done < <(list_gsm_connections)

    if [ ${#connections[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No GSM connections found. Create one via Connection Management (option 10).${NC}" >&2
        return 1
    elif [ ${#connections[@]} -eq 1 ]; then
        echo "${connections[0]}"
        return 0
    fi

    # Multiple connections — show a numbered menu on stderr, read choice
    echo -e "${CYAN}  Available GSM connections:${NC}" >&2
    local i=1
    for conn in "${connections[@]}"; do
        echo "  $i) $conn" >&2
        (( i++ ))
    done
    echo "" >&2

    while true; do
        read -p "  Select connection [1-${#connections[@]}]: " sel >&2 2>&1
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#connections[@]}" ]; then
            echo "${connections[$((sel-1))]}"
            return 0
        fi
        echo -e "${RED}  [ERROR] Invalid selection.${NC}" >&2
    done
}

show_status() {
    echo "╔════════════════════════════════════╗"
    echo "║      CONNECTION STATUS             ║"
    echo "╚════════════════════════════════════╝"
    nmcli device status | grep -E "DEVICE|gsm|wwan"
    echo ""
    echo "╔════════════════════════════════════╗"
    echo "║        MODEM STATUS                ║"
    echo "╚════════════════════════════════════╝"
    MODEM=$(get_modem_id)
    if [ -n "$MODEM" ]; then
        mmcli -m "$MODEM" | grep -E "state|signal|access tech|operator|sim slot"
    else
        echo "No modem found"
    fi
    echo ""
}

modem_up() {
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1

    echo -e "${BLUE}[*] Enabling modem $MODEM...${NC}"
    if ! sudo mmcli -m "$MODEM" -e; then
        echo -e "${YELLOW}[!] Could not enable modem (may already be enabled, continuing...)${NC}"
    fi
    sleep 2

    CONNECTION=$(select_connection)
    if [ -z "$CONNECTION" ]; then
        read -p "Press Enter..."
        return 1
    fi

    echo -e "${BLUE}[*] Bringing up connection '$CONNECTION'...${NC}"
    if sudo nmcli connection up "$CONNECTION"; then
        echo -e "${GREEN}[OK] Connected successfully.${NC}"
    else
        echo -e "${RED}[ERROR] Failed to bring up connection '$CONNECTION'.${NC}"
        echo -e "${YELLOW}[!] Possible causes:${NC}"
        echo -e "      - SIM PIN not unlocked (use option 7 → Unlock PIN)"
        echo -e "      - Wrong APN (use option 10 → Modify Connection)"
        echo -e "      - Modem not registered to network (check signal: option 4)"
        echo -e "      - Run Full Diagnostics (option 5) for details"
    fi
    read -p "Press Enter..."
}

modem_down() {
    CONNECTION=$(select_connection)
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    echo -e "${BLUE}[*] Disconnecting $CONNECTION...${NC}"
    sudo nmcli connection down "$CONNECTION" 2>/dev/null
    
    MODEM=$(get_modem_id)
    if [ -n "$MODEM" ]; then
        echo -e "${BLUE}[*] Disabling modem...${NC}"
        sudo mmcli -m "$MODEM" -d
    fi
    echo -e "${GREEN}[OK] Done${NC}"
    read -p "Press Enter..."
}

modem_restart() {
    echo -e "${BLUE}[*] Restarting modem...${NC}"
    CONNECTION=$(select_connection)
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    sudo nmcli connection down "$CONNECTION" 2>/dev/null
    MODEM=$(get_modem_id)
    [ -n "$MODEM" ] && sudo mmcli -m "$MODEM" -d
    
    sudo systemctl restart ModemManager
    sleep 3
    
    MODEM=$(get_modem_id)
    [ -n "$MODEM" ] && sudo mmcli -m "$MODEM" -e
    sleep 2
    sudo nmcli connection up "$CONNECTION"
    echo -e "${GREEN}[OK] Done${NC}"
    read -p "Press Enter..."
}

show_diag() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      FULL DIAGNOSTICS              ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    echo "--- Modem List ---"
    mmcli -L
    echo ""
    
    MODEM=$(get_modem_id)
    if [ -n "$MODEM" ]; then
        echo "--- Modem Details ---"
        mmcli -m "$MODEM"
        echo ""
        
        echo "--- SIM Details ---"
        SIM=$(get_sim_id)
        [ -n "$SIM" ] && mmcli -i "$SIM"
        echo ""
    fi
    
    echo "--- Network Devices ---"
    nmcli device status
    echo ""
    
    echo "--- GSM Connections ---"
    nmcli connection show | grep gsm
    echo ""
    
    echo "--- Internet Test ---"
    ping -c 2 8.8.8.8 2>&1 | tail -2
    echo ""
    read -p "Press Enter..."
}

show_signal() {
    clear
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1
    
    echo "╔════════════════════════════════════╗"
    echo "║      SIGNAL INFORMATION            ║"
    echo "╚════════════════════════════════════╝"
    mmcli -m "$MODEM" | grep -E "signal quality|access tech|operator|state"
    echo ""
    read -p "Press Enter..."
}

unlock_pin() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║         UNLOCK SIM PIN             ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    read -sp "Enter PIN: " PIN
    echo ""
    
    echo -e "${BLUE}[*] Unlocking SIM...${NC}"
    if sudo mmcli -i "$SIM" --pin="$PIN"; then
        echo -e "${GREEN}[OK] SIM unlocked${NC}"
        MODEM=$(get_modem_id)
        [ -n "$MODEM" ] && sudo mmcli -m "$MODEM" -e
    else
        echo -e "${RED}[ERROR] Failed to unlock${NC}"
    fi
    read -p "Press Enter..."
}

unlock_puk() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      UNLOCK WITH PUK CODE          ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    read -sp "Enter PUK: " PUK
    echo ""
    read -sp "Enter new PIN: " PIN
    echo ""
    read -sp "Confirm new PIN: " PIN2
    echo ""
    
    [ "$PIN" != "$PIN2" ] && echo -e "${RED}[ERROR] PINs don't match${NC}" && read -p "Press Enter..." && return 1
    
    echo -e "${BLUE}[*] Unlocking with PUK...${NC}"
    if sudo mmcli -i "$SIM" --puk="$PUK" --pin="$PIN"; then
        echo -e "${GREEN}[OK] SIM unlocked, new PIN set${NC}"
        MODEM=$(get_modem_id)
        [ -n "$MODEM" ] && sudo mmcli -m "$MODEM" -e
    else
        echo -e "${RED}[ERROR] Failed to unlock${NC}"
    fi
    read -p "Press Enter..."
}

change_pin() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║         CHANGE PIN CODE            ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    read -sp "Enter current PIN: " OLD_PIN
    echo ""
    read -sp "Enter new PIN: " NEW_PIN
    echo ""
    read -sp "Confirm new PIN: " NEW_PIN2
    echo ""
    
    [ "$NEW_PIN" != "$NEW_PIN2" ] && echo -e "${RED}[ERROR] PINs don't match${NC}" && read -p "Press Enter..." && return 1
    
    echo -e "${BLUE}[*] Changing PIN...${NC}"
    if sudo mmcli -i "$SIM" --pin="$OLD_PIN" --change-pin="$NEW_PIN"; then
        echo -e "${GREEN}[OK] PIN changed successfully${NC}"
    else
        echo -e "${RED}[ERROR] Failed to change PIN${NC}"
    fi
    read -p "Press Enter..."
}

disable_pin() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║         DISABLE PIN CODE           ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    echo -e "${YELLOW}[!] This will disable PIN requirement on boot${NC}"
    read -sp "Enter current PIN: " PIN
    echo ""
    
    echo -e "${BLUE}[*] Disabling PIN...${NC}"
    if sudo mmcli -i "$SIM" --disable-pin="$PIN"; then
        echo -e "${GREEN}[OK] PIN disabled${NC}"
    else
        echo -e "${RED}[ERROR] Failed to disable PIN${NC}"
    fi
    read -p "Press Enter..."
}

enable_pin() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║         ENABLE PIN CODE            ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    read -sp "Enter PIN: " PIN
    echo ""
    
    echo -e "${BLUE}[*] Enabling PIN...${NC}"
    if sudo mmcli -i "$SIM" --enable-pin="$PIN"; then
        echo -e "${GREEN}[OK] PIN enabled${NC}"
    else
        echo -e "${RED}[ERROR] Failed to enable PIN${NC}"
    fi
    read -p "Press Enter..."
}

store_pin() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      STORE PIN IN CONNECTION       ║"
    echo "╚════════════════════════════════════╝"
    
    CONNECTION=$(select_connection)
    if [ -z "$CONNECTION" ]; then
        echo -e "${YELLOW}[!] No GSM connection found. Create one first (option 13)${NC}"
        read -p "Press Enter..."
        return 1
    fi
    
    echo -e "${YELLOW}[!] PIN will be stored securely in NetworkManager${NC}"
    echo -e "${YELLOW}[!] System will auto-unlock SIM on boot${NC}"
    read -sp "Enter PIN: " PIN
    echo ""
    
    echo -e "${BLUE}[*] Storing PIN in connection...${NC}"
    if sudo nmcli connection modify "$CONNECTION" gsm.pin "$PIN" && \
       sudo nmcli connection modify "$CONNECTION" connection.autoconnect yes; then
        echo -e "${GREEN}[OK] PIN stored securely${NC}"
        echo -e "${GREEN}[OK] SIM will auto-unlock on boot${NC}"
    else
        echo -e "${RED}[ERROR] Failed to store PIN${NC}"
    fi
    
    read -p "Press Enter..."
}

show_siminfo() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║       SIM INFORMATION              ║"
    echo "╚════════════════════════════════════╝"
    
    SIM=$(get_sim_id)
    [ -z "$SIM" ] && echo -e "${RED}[ERROR] No SIM found${NC}" && read -p "Press Enter..." && return 1
    
    mmcli -i "$SIM"
    echo ""
    read -p "Press Enter..."
}

create_connection() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      CREATE GSM CONNECTION         ║"
    echo "╚════════════════════════════════════╝"
    echo ""

    # Validate name
    while true; do
        read -p "  Connection name: " NAME
        [ -n "$NAME" ] && break
        echo -e "${RED}  [ERROR] Name cannot be empty.${NC}"
    done

    # Validate APN
    while true; do
        read -p "  APN (e.g., internet, web.vodafone.de): " APN
        [ -n "$APN" ] && break
        echo -e "${RED}  [ERROR] APN cannot be empty.${NC}"
    done

    read -p "  Username (optional, press Enter to skip): " USR
    read -sp "  Password (optional, press Enter to skip): " PASS
    echo ""
    read -sp "  SIM PIN (optional, press Enter to skip): " PIN
    echo ""
    echo ""

    echo -e "${BLUE}[*] Creating GSM connection '$NAME'...${NC}"

    # Build the nmcli command — ifname '*' lets NM pick the modem device
    local cmd="sudo nmcli connection add type gsm ifname '*' con-name \"$NAME\" gsm.apn \"$APN\" connection.autoconnect yes"
    [ -n "$USR" ]  && cmd+=" gsm.username \"$USR\""
    [ -n "$PASS" ] && cmd+=" gsm.password \"$PASS\""

    if ! eval "$cmd"; then
        echo -e "${RED}[ERROR] Failed to create connection.${NC}"
        echo -e "${YELLOW}[!] Make sure ModemManager and NetworkManager are running.${NC}"
        read -p "Press Enter..."
        return 1
    fi

    # Store PIN separately (avoids it appearing in process list)
    if [ -n "$PIN" ]; then
        if ! sudo nmcli connection modify "$NAME" gsm.pin "$PIN"; then
            echo -e "${YELLOW}[!] Connection created but failed to store PIN.${NC}"
        fi
    fi

    echo -e "${GREEN}[OK] Connection '$NAME' created successfully.${NC}"
    echo -e "${BLUE}[*] Use option 1 (Connect) to bring it up.${NC}"
    read -p "Press Enter..."
}

delete_connection() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      DELETE GSM CONNECTION         ║"
    echo "╚════════════════════════════════════╝"
    
    CONNECTION=$(select_connection)
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    read -p "Delete '$CONNECTION'? (yes/no): " CONFIRM
    [ "$CONFIRM" != "yes" ] && echo "Cancelled" && read -p "Press Enter..." && return 0
    
    echo -e "${BLUE}[*] Deleting connection...${NC}"
    if sudo nmcli connection delete "$CONNECTION"; then
        echo -e "${GREEN}[OK] Connection deleted${NC}"
    else
        echo -e "${RED}[ERROR] Failed to delete${NC}"
    fi
    read -p "Press Enter..."
}

modify_connection() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      MODIFY GSM CONNECTION         ║"
    echo "╚════════════════════════════════════╝"
    
    CONNECTION=$(select_connection)
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    read -p "New APN (press Enter to skip): " APN
    read -p "New PIN (press Enter to skip): " PIN
    
    echo -e "${BLUE}[*] Modifying connection...${NC}"
    [ -n "$APN" ] && sudo nmcli connection modify "$CONNECTION" gsm.apn "$APN"
    [ -n "$PIN" ] && sudo nmcli connection modify "$CONNECTION" gsm.pin "$PIN"
    
    echo -e "${GREEN}[OK] Connection modified${NC}"
    read -p "Press Enter..."
}

connection_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║     CONNECTION MANAGEMENT          ║"
        echo "╚════════════════════════════════════╝"
        echo ""
        echo "  1) Create Connection"
        echo "  2) Delete Connection"
        echo "  3) Modify Connection"
        echo "  0) Back to Main Menu"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) create_connection ;;
            2) delete_connection ;;
            3) modify_connection ;;
            0) return ;;
            *) echo -e "${RED}[ERROR] Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

switch_sim_slot() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║       SWITCH SIM SLOT              ║"
    echo "╚════════════════════════════════════╝"
    
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1
    
    echo "Current SIM slots:"
    mmcli -m "$MODEM" | grep -E "sim slot"
    echo ""
    echo "1) Slot 1 (Physical SIM)"
    echo "2) Slot 2 (eSIM)"
    read -p "Select slot: " SLOT
    
    case $SLOT in
        1|2)
            echo -e "${BLUE}[*] Switching to slot $SLOT...${NC}"
            if sudo mmcli -m "$MODEM" --set-primary-sim-slot="$SLOT"; then
                echo -e "${GREEN}[OK] Switched to slot $SLOT${NC}"
                echo -e "${BLUE}[*] Restarting ModemManager...${NC}"
                sudo systemctl restart ModemManager
                sleep 3
                echo -e "${GREEN}[OK] Done. Modem may need to be enabled.${NC}"
            else
                echo -e "${RED}[ERROR] Failed to switch slot${NC}"
            fi
            ;;
        *) echo -e "${RED}[ERROR] Invalid option${NC}" ;;
    esac
    read -p "Press Enter..."
}

list_esim_profiles() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║       eSIM PROFILES                ║"
    echo "╚════════════════════════════════════╝"
    
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1
    
    echo "Installed eSIM profiles:"
    sudo mmcli -m "$MODEM" --list-profiles 2>/dev/null || echo "No profiles or command not supported"
    echo ""
    read -p "Press Enter..."
}

install_esim_profile() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║     INSTALL eSIM PROFILE           ║"
    echo "╚════════════════════════════════════╝"
    
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1
    
    echo "Enter activation code from your carrier:"
    echo "Format: LPA:1\$SM-DP+\$ADDRESS\$ACTIVATION_CODE"
    echo ""
    read -p "Activation code: " ACTIVATION
    
    [ -z "$ACTIVATION" ] && echo -e "${RED}[ERROR] No activation code provided${NC}" && read -p "Press Enter..." && return 1
    
    echo -e "${BLUE}[*] Installing eSIM profile...${NC}"
    echo -e "${YELLOW}[!] This may take a few minutes...${NC}"
    
    if sudo mmcli -m "$MODEM" --install-profile="$ACTIVATION" 2>/dev/null; then
        echo -e "${GREEN}[OK] eSIM profile installed successfully${NC}"
    else
        echo -e "${RED}[ERROR] Failed to install profile${NC}"
        echo -e "${YELLOW}[!] Note: Your modem may not support eSIM management via mmcli${NC}"
        echo "Try using your carrier's app or web portal"
    fi
    read -p "Press Enter..."
}

delete_esim_profile() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║     DELETE eSIM PROFILE            ║"
    echo "╚════════════════════════════════════╝"
    
    MODEM=$(get_modem_id)
    [ -z "$MODEM" ] && echo -e "${RED}[ERROR] No modem found${NC}" && read -p "Press Enter..." && return 1
    
    echo "Installed profiles:"
    sudo mmcli -m "$MODEM" --list-profiles 2>/dev/null || echo "No profiles or command not supported"
    echo ""
    
    read -p "Enter profile ID to delete: " PROFILE_ID
    [ -z "$PROFILE_ID" ] && echo -e "${RED}[ERROR] No profile ID provided${NC}" && read -p "Press Enter..." && return 1
    
    read -p "Are you sure? (yes/no): " CONFIRM
    [ "$CONFIRM" != "yes" ] && echo "Cancelled" && read -p "Press Enter..." && return 0
    
    echo -e "${BLUE}[*] Deleting profile...${NC}"
    if sudo mmcli -m "$MODEM" --delete-profile="$PROFILE_ID" 2>/dev/null; then
        echo -e "${GREEN}[OK] Profile deleted${NC}"
    else
        echo -e "${RED}[ERROR] Failed to delete profile${NC}"
    fi
    read -p "Press Enter..."
}

esim_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║       eSIM MANAGEMENT              ║"
        echo "╚════════════════════════════════════╝"
        echo ""
        echo "  1) List eSIM Profiles"
        echo "  2) Install eSIM Profile"
        echo "  3) Delete eSIM Profile"
        echo "  0) Back to Main Menu"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) list_esim_profiles ;;
            2) install_esim_profile ;;
            3) delete_esim_profile ;;
            0) return ;;
            *) echo -e "${RED}[ERROR] Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Automatic SIM unlock service functions
log_info() { echo -e "${BLUE}[*]${NC} $*"; }
log_ok() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

unlock_service_status() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║   AUTO UNLOCK SERVICE STATUS       ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    local service_file="/etc/systemd/system/unlock-sim.service"
    local cred_file="/etc/systemd/credentials/sim-pin.cred"
    
    [ -f "$service_file" ] && log_ok "Service file exists" || log_error "Service file missing"
    [ -f "$cred_file" ] && log_ok "Encrypted credential exists" || log_warn "Credential in runtime (normal)"
    systemctl is-enabled unlock-sim.service &>/dev/null && log_ok "Service enabled" || log_warn "Service not enabled"
    
    if systemctl is-active unlock-sim.service &>/dev/null; then
        log_ok "Service active"
    elif systemctl is-failed unlock-sim.service &>/dev/null; then
        log_warn "Service failed (check logs below)"
    else
        log_warn "Service not active"
    fi
    
    echo ""
    echo "Recent logs:"
    sudo journalctl -u unlock-sim.service -n 5 --no-pager 2>/dev/null | tail -3
    
    echo ""
    read -p "Press Enter..."
}

install_unlock_service() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║   INSTALL AUTO UNLOCK SERVICE      ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    local missing=()
    command -v mmcli >/dev/null 2>&1 || missing+=("mmcli")
    command -v systemd-creds >/dev/null 2>&1 || missing+=("systemd (systemd-creds)")
    command -v systemctl >/dev/null 2>&1 || missing+=("systemctl")
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        read -p "Press Enter..."
        return 1
    fi
    
    log_info "Detecting modem..."
    local modem_id
    modem_id=$(mmcli -L 2>/dev/null | grep -oP '/Modem/\K[0-9]+' | head -1)
    
    if [ -z "$modem_id" ]; then
        log_error "No modem found"
        read -p "Press Enter..."
        return 1
    fi
    log_ok "Found modem: $modem_id"
    
    if [ -f "/etc/systemd/system/unlock-sim.service" ]; then
        log_warn "Service already exists"
        read -p "Overwrite? (y/N): " overwrite
        [ "$overwrite" != "y" ] && return 0
    fi
    
    echo ""
    local pin pin2
    read -sp "Enter SIM PIN: " pin
    echo ""
    read -sp "Confirm PIN: " pin2
    echo ""
    
    if [ "$pin" != "$pin2" ]; then
        log_error "PINs don't match"
        read -p "Press Enter..."
        return 1
    fi
    
    if [ -z "$pin" ]; then
        log_error "PIN cannot be empty"
        read -p "Press Enter..."
        return 1
    fi
    
    log_info "Creating credentials directory..."
    sudo mkdir -p /etc/systemd/credentials
    sudo chmod 700 /etc/systemd/credentials
    
    log_info "Encrypting PIN..."
    if ! echo -n "$pin" | sudo systemd-creds encrypt --name=sim_pin - /etc/systemd/credentials/sim-pin.cred 2>/dev/null; then
        log_error "Failed to encrypt PIN"
        pin=""
        read -p "Press Enter..."
        return 1
    fi
    pin=""
    
    sudo chmod 600 /etc/systemd/credentials/sim-pin.cred
    log_ok "PIN encrypted"
    
    log_info "Creating systemd service..."
    sudo tee /etc/systemd/system/unlock-sim.service >/dev/null <<'EOF'
[Unit]
Description=Automatic SIM PIN Unlock
After=ModemManager.service
Requires=ModemManager.service

[Service]
Type=oneshot
RemainAfterExit=yes
LoadCredentialEncrypted=sim_pin:/etc/systemd/credentials/sim-pin.cred
ExecStart=/bin/bash -c 'sleep 5; MODEM=$(mmcli -L 2>/dev/null | grep -oP "/Modem/\\K[0-9]+" | head -1); [ -n "$MODEM" ] && SIM=$(mmcli -m $MODEM 2>/dev/null | grep -oP "primary sim path: /org/freedesktop/ModemManager1/SIM/\\K[0-9]+"); [ -n "$SIM" ] && mmcli -i $SIM --pin="$(cat ${CREDENTIALS_DIRECTORY}/sim_pin)"; sleep 2; [ -n "$MODEM" ] && mmcli -m $MODEM -e || true'

[Install]
WantedBy=multi-user.target
EOF
    
    sudo chmod 644 /etc/systemd/system/unlock-sim.service
    
    log_info "Enabling service..."
    sudo systemctl daemon-reload
    
    if ! sudo systemctl enable unlock-sim.service; then
        log_error "Failed to enable service"
        read -p "Press Enter..."
        return 1
    fi
    
    log_ok "Service installed and enabled"
    echo ""
    log_info "Service will run automatically on boot"
    log_info "To test now: sudo systemctl start unlock-sim.service"
    echo ""
    read -p "Press Enter..."
}

uninstall_unlock_service() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║  UNINSTALL AUTO UNLOCK SERVICE     ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    if [ ! -f "/etc/systemd/system/unlock-sim.service" ]; then
        log_warn "Service not installed"
        read -p "Press Enter..."
        return 0
    fi
    
    read -p "Remove auto unlock service? (y/N): " confirm
    [ "$confirm" != "y" ] && return 0
    
    log_info "Stopping service..."
    sudo systemctl stop unlock-sim.service 2>/dev/null || true
    
    log_info "Disabling service..."
    sudo systemctl disable unlock-sim.service 2>/dev/null || true
    
    log_info "Removing files..."
    sudo rm -f /etc/systemd/system/unlock-sim.service
    sudo rm -f /etc/systemd/credentials/sim-pin.cred
    
    log_info "Reloading systemd..."
    sudo systemctl daemon-reload
    
    log_ok "Service uninstalled"
    echo ""
    read -p "Press Enter..."
}

unlock_service_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║   AUTOMATIC SIM UNLOCK (ENCRYPTED) ║"
        echo "╚════════════════════════════════════╝"
        echo ""
        echo "  1) Install"
        echo "  2) Uninstall"
        echo "  3) Status"
        echo "  0) Back"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) install_unlock_service ;;
            2) uninstall_unlock_service ;;
            3) unlock_service_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# FCC Unlock Management
check_fcc_lock_status() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      FCC UNLOCK STATUS             ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    local modem_id
    modem_id=$(get_modem_id)
    
    if [ -z "$modem_id" ]; then
        log_error "No modem found"
        read -p "Press Enter..."
        return 1
    fi
    
    log_info "Detecting modem hardware..."
    local modem_info
    modem_info=$(mmcli -m "$modem_id" 2>/dev/null)
    
    # Extract manufacturer and model
    local manufacturer model
    manufacturer=$(echo "$modem_info" | grep -oP "manufacturer: '\K[^']+")
    model=$(echo "$modem_info" | grep -oP "model: '\K[^']+")
    
    echo "  Manufacturer: ${manufacturer:-Unknown}"
    echo "  Model: ${model:-Unknown}"
    echo ""
    
    # Get PCI device ID (VID:PID)
    local vid_pid
    vid_pid=$(lspci -nn 2>/dev/null | grep -i "wireless\|wwan\|mobile" | grep -oP '\[([0-9a-f]{4}:[0-9a-f]{4})\]' | tr -d '[]' | head -1)
    
    if [ -n "$vid_pid" ]; then
        log_ok "Device ID: $vid_pid"
    else
        log_warn "Could not detect device ID"
        vid_pid=""
    fi
    echo ""
    
    # Check if FCC unlock is needed (Qualcomm-based modems)
    local needs_fcc=false
    if echo "$manufacturer $model" | grep -qiE "quectel|foxconn|fibocom"; then
        if echo "$model" | grep -qiE "em120|sdx55|l860"; then
            needs_fcc=true
        fi
    fi
    
    if [ "$needs_fcc" = true ]; then
        log_warn "This modem may require FCC unlock"
        echo "  Common models needing FCC unlock:"
        echo "    - Quectel EM120 (Qualcomm)"
        echo "    - Foxconn SDX55 (Qualcomm)"
        echo "    - Fibocom L860 (Intel)"
    else
        log_ok "This modem likely does not require FCC unlock"
    fi
    echo ""
    
    # Check if unlock scripts are available
    log_info "Checking for available FCC unlock scripts..."
    local available_dir="/usr/share/ModemManager/fcc-unlock.available.d"
    local enabled_dir="/etc/ModemManager/fcc-unlock.d"
    
    if [ ! -d "$available_dir" ]; then
        log_error "ModemManager FCC unlock scripts not found"
        echo "  Install ModemManager 1.16.6 or newer"
        read -p "Press Enter..."
        return 1
    fi
    
    local available_scripts
    available_scripts=$(ls "$available_dir" 2>/dev/null | wc -l)
    
    if [ "$available_scripts" -eq 0 ]; then
        log_warn "No FCC unlock scripts available"
    else
        log_ok "Found $available_scripts unlock script(s)"
        echo ""
        echo "  Available unlock scripts:"
        ls -1 "$available_dir" 2>/dev/null | sed 's/^/    /'
    fi
    echo ""
    
    # Check if unlock is enabled
    if [ -d "$enabled_dir" ]; then
        local enabled_scripts
        enabled_scripts=$(ls "$enabled_dir" 2>/dev/null | wc -l)
        
        if [ "$enabled_scripts" -gt 0 ]; then
            log_ok "FCC unlock enabled for $enabled_scripts device(s)"
            echo ""
            echo "  Enabled unlock scripts:"
            ls -1 "$enabled_dir" 2>/dev/null | sed 's/^/    /'
        else
            log_warn "FCC unlock not enabled (no symlinks in $enabled_dir)"
        fi
    else
        log_warn "FCC unlock directory not found: $enabled_dir"
    fi
    
    echo ""
    
    # Check modem state
    log_info "Checking modem state..."
    local state
    state=$(echo "$modem_info" | grep -oP "state: '\K[^']+")
    echo "  State: ${state:-Unknown}"
    
    if echo "$state" | grep -qiE "disabled|locked"; then
        log_warn "Modem is not in online mode"
        echo "  This could indicate FCC lock is active"
    elif echo "$state" | grep -qiE "registered|connected"; then
        log_ok "Modem is operational (FCC unlock not needed or already done)"
    fi
    
    echo ""
    read -p "Press Enter..."
}

enable_fcc_unlock() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      ENABLE FCC UNLOCK             ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    local available_dir="/usr/share/ModemManager/fcc-unlock.available.d"
    local enabled_dir="/etc/ModemManager/fcc-unlock.d"
    
    # Check if available scripts exist
    if [ ! -d "$available_dir" ]; then
        log_error "ModemManager FCC unlock scripts not found"
        echo "  Install ModemManager 1.16.6 or newer"
        read -p "Press Enter..."
        return 1
    fi
    
    local scripts=()
    while IFS= read -r script; do
        scripts+=("$script")
    done < <(ls "$available_dir" 2>/dev/null)
    
    if [ ${#scripts[@]} -eq 0 ]; then
        log_error "No FCC unlock scripts available"
        read -p "Press Enter..."
        return 1
    fi
    
    # Try to auto-detect device
    log_info "Detecting your modem..."
    local vid_pid
    vid_pid=$(lspci -nn 2>/dev/null | grep -i "wireless\|wwan\|mobile" | grep -oP '\[([0-9a-f]{4}:[0-9a-f]{4})\]' | tr -d '[]' | head -1)
    
    if [ -n "$vid_pid" ]; then
        log_ok "Detected device: $vid_pid"
        echo ""
        
        # Check if matching script exists
        local matching_script=""
        for script in "${scripts[@]}"; do
            if [[ "$script" == "$vid_pid"* ]]; then
                matching_script="$script"
                break
            fi
        done
        
        if [ -n "$matching_script" ]; then
            log_ok "Found matching unlock script: $matching_script"
            echo ""
            read -p "Enable FCC unlock for this device? (y/N): " confirm
            
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                log_info "Creating unlock directory..."
                sudo mkdir -p "$enabled_dir"
                
                log_info "Enabling FCC unlock..."
                if sudo ln -sf "$available_dir/$matching_script" "$enabled_dir/$matching_script"; then
                    log_ok "FCC unlock enabled"
                    echo ""
                    log_info "Restarting ModemManager..."
                    sudo systemctl restart ModemManager
                    sleep 3
                    log_ok "Done. Try connecting now (option 1)"
                else
                    log_error "Failed to create symlink"
                fi
            else
                echo "Cancelled"
            fi
            read -p "Press Enter..."
            return 0
        else
            log_warn "No matching unlock script found for $vid_pid"
            echo ""
        fi
    else
        log_warn "Could not auto-detect device ID"
        echo ""
    fi
    
    # Manual selection
    echo "Available unlock scripts:"
    echo ""
    local i=1
    for script in "${scripts[@]}"; do
        echo "  $i) $script"
        ((i++))
    done
    echo "  0) Cancel"
    echo ""
    
    read -p "Select script to enable [0-${#scripts[@]}]: " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#scripts[@]}" ]; then
        echo "Cancelled"
        read -p "Press Enter..."
        return 0
    fi
    
    local selected_script="${scripts[$((selection-1))]}"
    
    log_info "Creating unlock directory..."
    sudo mkdir -p "$enabled_dir"
    
    log_info "Enabling FCC unlock for $selected_script..."
    if sudo ln -sf "$available_dir/$selected_script" "$enabled_dir/$selected_script"; then
        log_ok "FCC unlock enabled"
        echo ""
        log_info "Restarting ModemManager..."
        sudo systemctl restart ModemManager
        sleep 3
        log_ok "Done. Try connecting now (option 1)"
    else
        log_error "Failed to create symlink"
    fi
    
    echo ""
    read -p "Press Enter..."
}

disable_fcc_unlock() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║      DISABLE FCC UNLOCK            ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    
    local enabled_dir="/etc/ModemManager/fcc-unlock.d"
    
    if [ ! -d "$enabled_dir" ]; then
        log_warn "FCC unlock directory not found"
        read -p "Press Enter..."
        return 0
    fi
    
    local enabled_scripts=()
    while IFS= read -r script; do
        enabled_scripts+=("$script")
    done < <(ls "$enabled_dir" 2>/dev/null)
    
    if [ ${#enabled_scripts[@]} -eq 0 ]; then
        log_warn "No FCC unlock scripts are enabled"
        read -p "Press Enter..."
        return 0
    fi
    
    echo "Enabled unlock scripts:"
    echo ""
    local i=1
    for script in "${enabled_scripts[@]}"; do
        echo "  $i) $script"
        ((i++))
    done
    echo "  0) Cancel"
    echo ""
    
    read -p "Select script to disable [0-${#enabled_scripts[@]}]: " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#enabled_scripts[@]}" ]; then
        echo "Cancelled"
        read -p "Press Enter..."
        return 0
    fi
    
    local selected_script="${enabled_scripts[$((selection-1))]}"
    
    log_info "Disabling FCC unlock for $selected_script..."
    if sudo rm -f "$enabled_dir/$selected_script"; then
        log_ok "FCC unlock disabled"
        echo ""
        log_info "Restarting ModemManager..."
        sudo systemctl restart ModemManager
        sleep 2
        log_ok "Done"
    else
        log_error "Failed to remove symlink"
    fi
    
    echo ""
    read -p "Press Enter..."
}

fcc_unlock_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║      FCC UNLOCK MANAGEMENT         ║"
        echo "╚════════════════════════════════════╝"
        echo ""
        echo "  Some Qualcomm/Intel modems require FCC unlock"
        echo "  to enable RF functionality (online mode)."
        echo ""
        echo "  Affected models:"
        echo "    • Quectel EM120"
        echo "    • Foxconn SDX55"
        echo "    • Fibocom L860"
        echo ""
        echo "  1) Check FCC Lock Status"
        echo "  2) Enable FCC Unlock"
        echo "  3) Disable FCC Unlock"
        echo "  0) Back"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) check_fcc_lock_status ;;
            2) enable_fcc_unlock ;;
            3) disable_fcc_unlock ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

show_menu() {
    clear
    echo -e "${CYAN}Mobile Modem Manager v${VERSION}${NC} | ${CYAN}Murr${NC} @ ${CYAN}github.com/vtstv${NC}"
    echo ""
    show_status
    echo "╔════════════════════════════════════╗"
    echo "║     MOBILE MODEM MANAGER           ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    echo "  CONNECTION"
    echo "  1) Connect (Up)"
    echo "  2) Disconnect (Down)"
    echo "  3) Restart Modem"
    echo "  4) Show Signal"
    echo "  5) Full Diagnostics"
    echo ""
    echo "  SIM MANAGEMENT"
    echo "  6) SIM Information"
    echo "  7) SIM PIN/PUK Management"
    echo "  8) Switch SIM Slot"
    echo "  9) Auto Unlock Service"
    echo ""
    echo "  ADVANCED"
    echo " 10) Connection Management"
    echo " 11) eSIM Management"
    echo " 12) FCC Unlock (Qualcomm/Intel)"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) modem_up ;;
        2) modem_down ;;
        3) modem_restart ;;
        4) show_signal ;;
        5) show_diag ;;
        6) show_siminfo ;;
        7) sim_pin_menu ;;
        8) switch_sim_slot ;;
        9) unlock_service_menu ;;
        10) connection_menu ;;
        11) esim_menu ;;
        12) fcc_unlock_menu ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}[ERROR] Invalid option${NC}"; sleep 1 ;;
    esac
}

sim_pin_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║      SIM PIN/PUK MANAGEMENT        ║"
        echo "╚════════════════════════════════════╝"
        echo ""
        echo "  1) Unlock PIN"
        echo "  2) Unlock PUK"
        echo "  3) Change PIN"
        echo "  4) Enable PIN"
        echo "  5) Disable PIN"
        echo "  6) Store PIN in Connection"
        echo "  0) Back"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) unlock_pin ;;
            2) unlock_puk ;;
            3) change_pin ;;
            4) enable_pin ;;
            5) disable_pin ;;
            6) store_pin ;;
            0) break ;;
            *) echo -e "${RED}[ERROR] Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Check dependencies on startup
check_dependencies

while true; do
    show_menu
done
