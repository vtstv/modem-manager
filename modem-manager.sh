#!/bin/bash
#
# ███╗   ███╗ ██████╗ ██████╗ ███████╗███╗   ███╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗ 
# ████╗ ████║██╔═══██╗██╔══██╗██╔════╝████╗ ████║    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
# ██╔████╔██║██║   ██║██║  ██║█████╗  ██╔████╔██║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
# ██║╚██╔╝██║██║   ██║██║  ██║██╔══╝  ██║╚██╔╝██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
# ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████╗██║ ╚═╝ ██║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
# ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝     ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
#
# Mobile Modem Manager - Interactive GSM/LTE/eSIM Management Tool
# Author: Murr
# GitHub: https://github.com/vtstv
# License: MIT
#

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
    echo -e "${CYAN}║${NC}  Mobile Modem Manager v1.0 - GSM/LTE/eSIM Management    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Author: Murr | GitHub: github.com/vtstv | MIT License  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 1
}

# Check and install dependencies
check_dependencies() {
    local missing=()
    
    command -v mmcli >/dev/null 2>&1 || missing+=("modemmanager")
    command -v nmcli >/dev/null 2>&1 || missing+=("networkmanager")
    
    if [ ${#missing[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${YELLOW}[!] Missing packages: ${missing[*]}${NC}"
    read -p "Install missing packages? (y/n): " install
    
    [ "$install" != "y" ] && echo -e "${RED}[ERROR] Cannot continue without required packages${NC}" && exit 1
    
    if [ -f /etc/arch-release ]; then
        echo -e "${BLUE}[*] Installing on Arch Linux...${NC}"
        sudo pacman -S --noconfirm "${missing[@]}"
    elif [ -f /etc/debian_version ]; then
        echo -e "${BLUE}[*] Installing on Debian/Ubuntu...${NC}"
        sudo apt update
        sudo apt install -y "${missing[@]}"
    else
        echo -e "${RED}[ERROR] Unsupported distribution. Install manually: ${missing[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[OK] Dependencies installed${NC}"
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
    nmcli -t -f NAME,TYPE connection show | grep gsm | cut -d: -f1
}

select_connection() {
    local connections=($(list_gsm_connections))
    if [ ${#connections[@]} -eq 0 ]; then
        echo "No GSM connections found"
        return 1
    elif [ ${#connections[@]} -eq 1 ]; then
        echo "${connections[0]}"
        return 0
    fi
    
    echo "Select connection:"
    select conn in "${connections[@]}"; do
        [ -n "$conn" ] && echo "$conn" && return 0
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
    
    echo -e "${BLUE}[*] Enabling modem...${NC}"
    sudo mmcli -m "$MODEM" -e
    sleep 2
    
    CONNECTION=$(select_connection)
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    echo -e "${BLUE}[*] Connecting to $CONNECTION...${NC}"
    sudo nmcli connection up "$CONNECTION"
    echo -e "${GREEN}[OK] Done${NC}"
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
    [ -z "$CONNECTION" ] && read -p "Press Enter..." && return 1
    
    echo -e "${YELLOW}[!] PIN will be stored in NetworkManager${NC}"
    read -sp "Enter PIN: " PIN
    echo ""
    
    echo -e "${BLUE}[*] Storing PIN...${NC}"
    if sudo nmcli connection modify "$CONNECTION" gsm.pin "$PIN"; then
        echo -e "${GREEN}[OK] PIN stored in connection '$CONNECTION'${NC}"
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
    
    read -p "Connection name: " NAME
    read -p "APN (e.g., web.vodafone.de): " APN
    read -p "PIN (optional, press Enter to skip): " PIN
    
    echo -e "${BLUE}[*] Creating connection...${NC}"
    sudo nmcli connection add type gsm ifname '*' con-name "$NAME" apn "$APN" connection.autoconnect yes
    
    [ -n "$PIN" ] && sudo nmcli connection modify "$NAME" gsm.pin "$PIN"
    
    echo -e "${GREEN}[OK] Connection '$NAME' created${NC}"
    read -p "Press Enter..."
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

show_menu() {
    clear
    echo -e "${CYAN}Mobile Modem Manager v1.0${NC} | ${CYAN}Murr${NC} @ ${CYAN}github.com/vtstv${NC}"
    echo ""
    show_status
    echo "╔════════════════════════════════════╗"
    echo "║     MOBILE MODEM MANAGER           ║"
    echo "╚════════════════════════════════════╝"
    echo ""
    echo "  1) Connect (Up)"
    echo "  2) Disconnect (Down)"
    echo "  3) Restart Modem"
    echo "  4) Show Signal"
    echo "  5) Full Diagnostics"
    echo "  6) SIM Information"
    echo "  7) Unlock PIN"
    echo "  8) Unlock PUK"
    echo "  9) Change PIN"
    echo " 10) Disable PIN"
    echo " 11) Enable PIN"
    echo " 12) Store PIN in Connection"
    echo " 13) Create Connection"
    echo " 14) Switch SIM Slot"
    echo " 15) eSIM Management"
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
        7) unlock_pin ;;
        8) unlock_puk ;;
        9) change_pin ;;
        10) disable_pin ;;
        11) enable_pin ;;
        12) store_pin ;;
        13) create_connection ;;
        14) switch_sim_slot ;;
        15) esim_menu ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}[ERROR] Invalid option${NC}"; sleep 1 ;;
    esac
}

# Check dependencies on startup
check_dependencies

while true; do
    show_menu
done
