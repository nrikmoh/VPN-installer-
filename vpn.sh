#!/bin/bash

#===============================================================================
#
#   ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██╗      █████╗ ███████╗████████╗
#   ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██║     ██╔══██╗██╔════╝╚══██╔══╝
#   ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██║     ███████║███████╗   ██║
#   ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔══██╗██║     ██╔══██║╚════██║   ██║
#    ╚████╔╝ ██║     ██║ ╚████║    ██████╔╝███████╗██║  ██║███████║   ██║
#     ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝
#
#   VPN BLAST - The Ultimate VPN Deployment Arsenal
#   Version: 4.0 OMEGA NEON (Enhanced & Debugged)
#   Author: VPN Blast Team
#   License: MIT
#   "Your Privacy Is Not Optional — It's A Right."
#
#===============================================================================

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR DEFINITIONS & STYLING
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
NC='\033[0m'

BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_MAGENTA='\033[1;35m'
BRIGHT_CYAN='\033[1;36m'

BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'
BG_BLACK='\033[40m'
BG_MAGENTA='\033[45m'

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_VERSION="4.0-OMEGA-NEON"
LOG_FILE="/var/log/vpn-blast.log"
CONFIG_DIR="/etc/vpn-blast"
BACKUP_DIR="/etc/vpn-blast/backups"
INSTALL_DIR="/opt/vpn-blast"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

print_line() {
    local char="${1:-═}"
    local color="${2:-$CYAN}"
    printf "${color}"
    printf '%*s' "$TERM_WIDTH" '' | tr ' ' "$char"
    printf "${NC}\n"
}

print_centered() {
    local text="$1"
    local color="${2:-$WHITE}"
    local clean_text
    clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_length=${#clean_text}
    local padding=$(( (TERM_WIDTH - text_length) / 2 ))
    [[ $padding -lt 0 ]] && padding=0
    printf "%${padding}s" ""
    echo -e "${color}${text}${NC}"
}

typewriter() {
    local text="$1"
    local color="${2:-$GREEN}"
    local speed="${3:-0.02}"
    printf "${color}"
    for (( i=0; i<${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "$speed"
    done
    printf "${NC}\n"
}

# Enhanced typewriter with random glitch effect
glitch_typewriter() {
    local text="$1"
    local color="${2:-$GREEN}"
    local speed="${3:-0.02}"
    local glitch_chars="@#$%&*!?<>{}[]"
    printf "${color}"
    for (( i=0; i<${#text}; i++ )); do
        if (( RANDOM % 8 == 0 )); then
            local gc="${glitch_chars:$(( RANDOM % ${#glitch_chars} )):1}"
            printf "${BRIGHT_RED}%s${color}" "$gc"
            sleep 0.05
            printf "\b%s" "${text:$i:1}"
        else
            printf '%s' "${text:$i:1}"
        fi
        sleep "$speed"
    done
    printf "${NC}\n"
}

# REPAIRED SPINNER: Now catches exit codes correctly
spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local char="${spin_chars:$i:1}"
        printf "\r${CYAN}  [${BRIGHT_GREEN}%s${CYAN}] ${WHITE}%s...${NC}" "$char" "$message"
        i=$(( (i + 1) % ${#spin_chars} ))
        sleep 0.1
    done
    
    wait "$pid"
    local exit_status=$?
    if [ $exit_status -eq 0 ]; then
        printf "\r${CYAN}  [${BRIGHT_GREEN}✓${CYAN}] ${WHITE}%s... ${BRIGHT_GREEN}Done!${NC}\n" "$message"
    else
        printf "\r${CYAN}  [${BRIGHT_RED}✕${CYAN}] ${WHITE}%s... ${BRIGHT_RED}Failed! (Code: $exit_status)${NC}\n" "$message"
        log "ERROR" "Action '$message' failed with code $exit_status"
    fi
    return $exit_status
}

# NEW: Port Availability check
check_port() {
    local port=$1
    local proto=${2:-tcp}
    if lsof -Pi :"$port" -s"${proto^^}":LISTEN -t >/dev/null 2>&1; then
        warning_msg "Port $port is already in use by another service!"
        if ! confirm_prompt "Continue anyway? (May cause installation failure)"; then
            return 1
        fi
    fi
    return 0
}

progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Progress}"
    local width=40
    local percentage=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    printf "\r  ${CYAN}${message}: ${BRIGHT_GREEN}["
    printf '%*s' "$filled" '' | tr ' ' '█'
    printf '%*s' "$empty" '' | tr ' ' '░'
    printf "] ${WHITE}%3d%%${NC}" "$percentage"

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

success_msg() {
    echo -e "\n${BRIGHT_GREEN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_GREEN}  ║  ${WHITE}✅  $1${BRIGHT_GREEN}$(printf '%*s' $((38 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_GREEN}  ╚══════════════════════════════════════════╝${NC}\n"
}

error_msg() {
    echo -e "\n${BRIGHT_RED}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}  ║  ${WHITE}❌  $1${BRIGHT_RED}$(printf '%*s' $((38 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_RED}  ╚══════════════════════════════════════════╝${NC}\n"
}

warning_msg() {
    echo -e "\n${BRIGHT_YELLOW}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_YELLOW}  ║  ${WHITE}⚠️   $1${BRIGHT_YELLOW}$(printf '%*s' $((37 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_YELLOW}  ╚══════════════════════════════════════════╝${NC}\n"
}

info_box() {
    local title="$1"
    shift
    local lines=("$@")
    echo -e "\n${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}📋 ${BOLD}${WHITE}${title}${NC}$(printf '%*s' $((53 - ${#title})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    for line in "${lines[@]}"; do
        local clean_line
        clean_line=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local pad_len=$(( 56 - ${#clean_line} ))
        [[ $pad_len -lt 0 ]] && pad_len=0
        echo -e "${CYAN}  │  ${NC}${line}$(printf '%*s' "$pad_len" '')${CYAN}│${NC}"
    done
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}\n"
}

styled_prompt() {
    local prompt_text="$1"
    local default_val="${2:-}"
    if [[ -n "$default_val" ]]; then
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text} ${DIM}[${default_val}]${NC}${WHITE}: ${NC}"
    else
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text}: ${NC}"
    fi
}

confirm_prompt() {
    local prompt_text="$1"
    local default="${2:-y}"
    local response

    if [[ "$default" == "y" ]]; then
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text} ${DIM}[Y/n]${NC}${WHITE}: ${NC}"
    else
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text} ${DIM}[y/N]${NC}${WHITE}: ${NC}"
    fi
    read -r response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_msg "This script must be run as root!"
        echo -e "  ${YELLOW}Run with: ${WHITE}sudo $0${NC}\n"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    elif [[ -f /etc/centos-release ]]; then
        OS="centos"
        OS_VERSION=$(grep -oE '[0-9]+' /etc/centos-release | head -1)
        OS_NAME=$(cat /etc/centos-release)
    else
        OS="unknown"
        OS_VERSION="unknown"
        OS_NAME="Unknown OS"
    fi
}

# NEW: Pre-flight dependency check
pre_flight() {
    local deps=(curl wget lsof jq ca-certificates openssl tar)
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "  ${YELLOW}[*] Installing missing base dependencies: ${missing[*]}${NC}"
        case $OS in
            ubuntu|debian) apt-get update -qq && apt-get install -y "${missing[@]}" -qq > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y "${missing[@]}" -q > /dev/null 2>&1 ;;
        esac
    fi
}

get_public_ip() {
    local ip
    ip=$(curl -s4 --connect-timeout 5 https://ifconfig.me 2>/dev/null || \
         curl -s4 --connect-timeout 5 https://api.ipify.org 2>/dev/null || \
         curl -s4 --connect-timeout 5 https://icanhazip.com 2>/dev/null || \
         echo "Unable to detect")
    echo "$ip"
}

get_server_info() {
    SERVER_IP=$(get_public_ip)
    SERVER_RAM=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "N/A")
    SERVER_CPU=$(nproc 2>/dev/null || echo "N/A")
    SERVER_DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
    SERVER_HOSTNAME=$(hostname 2>/dev/null || echo "N/A")
    SERVER_KERNEL=$(uname -r 2>/dev/null || echo "N/A")
    SERVER_ARCH=$(uname -m 2>/dev/null || echo "N/A")
    SERVER_UPTIME=$(uptime -p 2>/dev/null || echo "N/A")
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENHANCED MATRIX RAIN EFFECT (4+ seconds)
# ═══════════════════════════════════════════════════════════════════════════════

matrix_rain() {
    local duration=${1:-5}
    local cols=$TERM_WIDTH
    local rows=$TERM_HEIGHT

    # Hide cursor
    tput civis 2>/dev/null

    clear

    # Initialize column positions
    declare -a col_pos
    declare -a col_speed
    declare -a col_char
    for (( c=0; c<cols; c++ )); do
        col_pos[$c]=$(( RANDOM % rows ))
        col_speed[$c]=$(( RANDOM % 3 + 1 ))
    done

    local end_time=$(( $(date +%s%N) / 1000000 + duration * 1000 ))
    local frame=0
    local katakana="アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    local chars="0123456789ABCDEFabcdef@#\$%&*!?<>{}[]|/\\~^"
    local all_chars="${katakana}${chars}"

    while [[ $(( $(date +%s%N) / 1000000 )) -lt $end_time ]]; do
        for (( c=0; c<cols; c+=2 )); do
            if (( frame % col_speed[$c] == 0 )); then
                local row=${col_pos[$c]}
                local rand_char="${all_chars:$(( RANDOM % ${#all_chars} )):1}"

                # Head of the stream (bright white/green)
                printf "\033[%d;%dH${BRIGHT_GREEN}${BOLD}%s${NC}" "$row" "$c" "$rand_char"

                # Trail (dimmer green)
                if (( row > 1 )); then
                    local trail_char="${all_chars:$(( RANDOM % ${#all_chars} )):1}"
                    printf "\033[%d;%dH${GREEN}%s${NC}" "$(( row - 1 ))" "$c" "$trail_char"
                fi

                # Dim old trail
                if (( row > 3 )); then
                    local dim_char="${all_chars:$(( RANDOM % ${#all_chars} )):1}"
                    printf "\033[%d;%dH${DIM}${GREEN}%s${NC}" "$(( row - 3 ))" "$c" "$dim_char"
                fi

                # Erase far trail
                if (( row > 8 )); then
                    printf "\033[%d;%dH " "$(( row - 8 ))" "$c"
                fi

                # Move column down
                col_pos[$c]=$(( (row + 1) % (rows + 10) ))

                # Random reset
                if (( RANDOM % 50 == 0 )); then
                    col_pos[$c]=0
                    col_speed[$c]=$(( RANDOM % 3 + 1 ))
                fi
            fi
        done

        # Random bright flashes
        if (( RANDOM % 5 == 0 )); then
            local flash_col=$(( RANDOM % cols ))
            local flash_row=$(( RANDOM % rows + 1 ))
            local flash_char="${all_chars:$(( RANDOM % ${#all_chars} )):1}"
            printf "\033[%d;%dH${BRIGHT_WHITE}${BOLD}%s${NC}" "$flash_row" "$flash_col" "$flash_char"
        fi

        frame=$(( frame + 1 ))
        sleep 0.03
    done

    # Fade out effect
    for (( fade=0; fade<10; fade++ )); do
        for (( i=0; i<20; i++ )); do
            local rc=$(( RANDOM % cols ))
            local rr=$(( RANDOM % rows + 1 ))
            printf "\033[%d;%dH " "$rr" "$rc"
        done
        sleep 0.05
    done

    # Show cursor
    tput cnorm 2>/dev/null

    clear
}

# Cool boot sequence
boot_sequence() {
    clear
    local boot_msgs=(
        "[BOOT] Initializing VPN Blast kernel modules..."
        "[BOOT] Loading cryptographic libraries..."
        "[BOOT] Establishing secure memory allocation..."
        "[BOOT] Mounting encrypted filesystem..."
        "[BOOT] Initializing network stack..."
        "[BOOT] Loading protocol handlers..."
        "[BOOT] Verifying system integrity..."
        "[BOOT] Checking for surveillance countermeasures..."
        "[BOOT] Deploying anti-fingerprinting modules..."
        "[BOOT] System ready. Welcome, operator."
    )

    echo ""
    for msg in "${boot_msgs[@]}"; do
        local color=$GREEN
        if [[ "$msg" == *"ready"* ]]; then
            color=$BRIGHT_GREEN
        elif [[ "$msg" == *"surveillance"* ]]; then
            color=$BRIGHT_YELLOW
        fi
        typewriter "  $msg" "$color" 0.01
        sleep 0.15
    done
    sleep 0.5
}

# ═══════════════════════════════════════════════════════════════════════════════
# DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    clear
    echo ""
    echo -e "${BRIGHT_GREEN}"
    cat << 'BANNER'

    ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██╗      █████╗ ███████╗████████╗
    ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██║     ██╔══██╗██╔════╝╚══██╔══╝
    ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██║     ███████║███████╗   ██║
    ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔══██╗██║     ██╔══██║╚════██║   ██║
     ╚████╔╝ ██║     ██║ ╚████║    ██████╔╝███████╗██║  ██║███████║   ██║
      ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝

BANNER
    echo -e "${NC}"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    print_centered "🔒 The Ultimate VPN Deployment Arsenal v${SCRIPT_VERSION} 🔒" "$BRIGHT_YELLOW"
    print_centered "\"Your Privacy Is Not Optional — It's A Right.\"" "$DIM$WHITE"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    echo ""
}

show_system_info() {
    get_server_info
    detect_os

    local threat_level="LOW"
    local threat_color="${BRIGHT_GREEN}"
    # Simulate threat assessment
    if [[ "$SERVER_IP" != "Unable to detect" ]]; then
        threat_level="NOMINAL"
        threat_color="${BRIGHT_GREEN}"
    fi

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🖥️  ${BOLD}${WHITE}SYSTEM RECONNAISSANCE${NC}                 ${GRAY}Threat Level: ${threat_color}${threat_level}${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "OS" "$OS_NAME"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "Kernel" "$SERVER_KERNEL"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "Arch" "$SERVER_ARCH"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "Hostname" "$SERVER_HOSTNAME"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_YELLOW}%-50s${NC}${CYAN}│${NC}\n" "Public IP" "$SERVER_IP"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "CPU/RAM/Disk" "${SERVER_CPU} cores / ${SERVER_RAM} / ${SERVER_DISK}"
    printf "${CYAN}  │  ${GREEN}▶ ${WHITE}%-12s ${GRAY}: ${BRIGHT_GREEN}%-50s${NC}${CYAN}│${NC}\n" "Uptime" "$SERVER_UPTIME"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU (EXPANDED)
# ═══════════════════════════════════════════════════════════════════════════════

show_main_menu() {
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🎯  ${BOLD}${WHITE}SELECT YOUR VPN WEAPON${NC}                                                ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_MAGENTA}━━━ TIER 1: RECOMMENDED & BATTLE-TESTED ━━━━━━━━━━━━━━━━━━━━━━━━${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC}  ${WHITE}🛡️  WireGuard         ${GRAY}─ Modern, Fast, Lightweight${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_GREEN}★ MOST SECURE${NC} ${GRAY}│ Kernel-level, ChaCha20, Curve25519${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC}  ${WHITE}🔐 OpenVPN            ${GRAY}─ Battle-tested, Versatile${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_YELLOW}★ MOST COMPATIBLE${NC} ${GRAY}│ SSL/TLS, works everywhere${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC}  ${WHITE}⚡ IKEv2/IPsec        ${GRAY}─ Native Mobile Support${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_CYAN}★ BEST FOR MOBILE${NC} ${GRAY}│ Built-in on iOS/Android/Win${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_MAGENTA}━━━ TIER 2: ANTI-CENSORSHIP & STEALTH ━━━━━━━━━━━━━━━━━━━━━━━━${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC}  ${WHITE}🚀 V2Ray/Xray         ${GRAY}─ Advanced Tunneling${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_RED}★ MOST CENSORSHIP-RESISTANT${NC} ${GRAY}│ VLESS/VMess/Trojan${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC}  ${WHITE}🕶️  Shadowsocks        ${GRAY}─ Stealth SOCKS5 Proxy${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_RED}★ ANTI-DPI${NC} ${GRAY}│ Encrypted proxy, bypasses firewalls${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC}  ${WHITE}🔥 Outline VPN        ${GRAY}─ Jigsaw/Google Anti-Censorship${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_RED}★ EASIEST ANTI-CENSORSHIP${NC} ${GRAY}│ Share access keys easily${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC}  ${WHITE}🌊 Hysteria 2         ${GRAY}─ QUIC-based, Brutal Speed${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_RED}★ FASTEST ANTI-CENSORSHIP${NC} ${GRAY}│ UDP-based, anti-QoS${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[8]${NC}  ${WHITE}🌀 REALITY/XTLS       ${GRAY}─ Next-Gen Stealth Protocol${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_RED}★ UNDETECTABLE${NC} ${GRAY}│ Mimics real TLS websites${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[9]${NC}  ${WHITE}🪱 WireGuard + obfs    ${GRAY}─ WireGuard + Obfuscation${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │       ${BRIGHT_GREEN}★ SECURE${NC} ${BRIGHT_RED}+ STEALTH${NC} ${GRAY}│ wg + wstunnel/udp2raw${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_MAGENTA}━━━ TIER 3: MULTI-PROTOCOL & SPECIALTY ━━━━━━━━━━━━━━━━━━━━━━━${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[10]${NC} ${WHITE}🌐 SoftEther VPN      ${GRAY}─ Multi-Protocol Suite${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[11]${NC} ${WHITE}🧅 Tor Bridge          ${GRAY}─ Maximum Anonymity${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[12]${NC} ${WHITE}🐚 OpenConnect (ocserv)${GRAY}─ Cisco AnyConnect Compatible${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[13]${NC} ${WHITE}🔷 TUIC               ${GRAY}─ QUIC-based Proxy${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[14]${NC} ${WHITE}🛸 NaiveProxy          ${GRAY}─ Chrome Network Stack Proxy${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[15]${NC} ${WHITE}🌉 Brook               ${GRAY}─ Simple Cross-Platform Proxy${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[96]${NC} ${WHITE}🏆 VPN Recommendation Wizard${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[97]${NC} ${WHITE}📊 Protocol Comparison Matrix${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[98]${NC} ${WHITE}📊 VPN Status Dashboard${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[99]${NC} ${WHITE}🔧 Management & Tools${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC}  ${WHITE}🚪 Exit${NC}                                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN RECOMMENDATION WIZARD
# ═══════════════════════════════════════════════════════════════════════════════

vpn_recommendation_wizard() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}🏆  ${BOLD}${WHITE}VPN RECOMMENDATION WIZARD${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GRAY}Answer a few questions and I'll recommend the best VPN for you${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Question 1: Primary use case
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}Q1: ${WHITE}What is your PRIMARY use case?${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Privacy & Security ${GRAY}(general browsing, data protection)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Bypass Censorship  ${GRAY}(China, Iran, Russia, etc.)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Maximum Speed      ${GRAY}(gaming, streaming, downloads)${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Mobile Use         ${GRAY}(phone/tablet, switching networks)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Maximum Anonymity  ${GRAY}(whistleblower, journalist)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Share VPN Access   ${GRAY}(give access to friends/family)${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Your answer" "1"
    read -r q1
    q1=${q1:-1}

    # Question 2: Censorship level
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}Q2: ${WHITE}How aggressive is the censorship/firewall?${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}None / Mild    ${GRAY}(Western countries, ISP blocks only)${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Moderate       ${GRAY}(Some VPN ports blocked, basic DPI)${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Heavy          ${GRAY}(China GFW, Iran, Turkmenistan)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Extreme        ${GRAY}(Active probing, protocol detection)${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Your answer" "1"
    read -r q2
    q2=${q2:-1}

    # Question 3: Technical level
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}Q3: ${WHITE}Your technical comfort level?${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Beginner   ${GRAY}(I just want it to work)${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Moderate   ${GRAY}(I can follow instructions)${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Advanced   ${GRAY}(I know networking, can configure manually)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Your answer" "2"
    read -r q3
    q3=${q3:-2}

    # Question 4: Devices
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}Q4: ${WHITE}Primary devices?${NC}                                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Desktop/Laptop only${NC}                                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Mobile only (iOS/Android)${NC}                                         ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Both desktop and mobile${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Router / Network-wide${NC}                                             ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Your answer" "3"
    read -r q4
    q4=${q4:-3}

    # Generate recommendation
    echo ""
    echo ""
    typewriter "  [*] Analyzing threat model..." "$BRIGHT_CYAN" 0.03
    sleep 0.3
    typewriter "  [*] Evaluating protocol capabilities..." "$BRIGHT_CYAN" 0.03
    sleep 0.3
    typewriter "  [*] Computing optimal configuration..." "$BRIGHT_CYAN" 0.03
    sleep 0.5
    echo ""

    # Decision logic
    local primary_rec=""
    local secondary_rec=""
    local primary_reason=""
    local secondary_reason=""
    local combo_rec=""

    # Heavy/Extreme censorship
    if [[ "$q2" =~ ^[34]$ ]]; then
        if [[ "$q3" == "3" ]]; then
            primary_rec="REALITY/XTLS (Xray)"
            primary_reason="Undetectable by DPI, mimics real HTTPS sites"
            secondary_rec="Hysteria 2"
            secondary_reason="QUIC-based, extremely fast, anti-QoS"
            combo_rec="For maximum stealth: REALITY + WireGuard (obfuscated)"
        elif [[ "$q3" == "2" ]]; then
            primary_rec="V2Ray/Xray (VMess + WebSocket)"
            primary_reason="Good balance of stealth and ease of setup"
            secondary_rec="Outline VPN"
            secondary_reason="Easiest censorship-resistant option"
            combo_rec="Add Cloudflare CDN to V2Ray for extra protection"
        else
            primary_rec="Outline VPN"
            primary_reason="One-click setup, designed for non-technical users"
            secondary_rec="Shadowsocks"
            secondary_reason="Simple proxy, good anti-censorship"
            combo_rec="Share Outline access keys with others easily"
        fi
    # Moderate censorship
    elif [[ "$q2" == "2" ]]; then
        if [[ "$q1" == "3" ]]; then
            primary_rec="Hysteria 2"
            primary_reason="QUIC-based, fastest speeds through censorship"
            secondary_rec="WireGuard + Obfuscation"
            secondary_reason="Fast WireGuard with tunnel obfuscation"
        else
            primary_rec="V2Ray/Xray (VLESS + WebSocket)"
            primary_reason="Reliable, can hide behind CDN like Cloudflare"
            secondary_rec="Shadowsocks"
            secondary_reason="Lightweight, fast, proven anti-censorship"
        fi
        combo_rec="Consider running behind Cloudflare CDN for extra stealth"
    # No censorship - focus on security/speed
    else
        case $q1 in
            1) # Privacy
                primary_rec="WireGuard"
                primary_reason="Strongest cryptography, minimal code, audited"
                secondary_rec="OpenVPN"
                secondary_reason="Battle-tested, highly configurable"
                combo_rec="WireGuard for speed, OpenVPN as backup"
                ;;
            3) # Speed
                primary_rec="WireGuard"
                primary_reason="Fastest VPN protocol, kernel-level performance"
                secondary_rec="Hysteria 2"
                secondary_reason="QUIC-based, designed for speed"
                combo_rec="WireGuard is the undisputed speed champion"
                ;;
            4) # Mobile
                primary_rec="IKEv2/IPsec"
                primary_reason="Native support, handles network switching perfectly"
                secondary_rec="WireGuard"
                secondary_reason="Fast reconnection, low battery usage"
                combo_rec="IKEv2 needs no app on iOS, WireGuard needs app but is faster"
                ;;
            5) # Anonymity
                primary_rec="Tor Bridge"
                primary_reason="Maximum anonymity through onion routing"
                secondary_rec="WireGuard + Tor"
                secondary_reason="VPN layer + Tor for defense in depth"
                combo_rec="WARNING: Tor is slow but offers the strongest anonymity"
                ;;
            6) # Sharing
                primary_rec="Outline VPN"
                primary_reason="Designed for sharing, easy access key management"
                secondary_rec="WireGuard"
                secondary_reason="Simple QR code sharing for mobile"
                combo_rec="Outline for non-technical users, WireGuard for tech-savvy"
                ;;
            *)
                primary_rec="WireGuard"
                primary_reason="Best all-around VPN protocol"
                secondary_rec="OpenVPN"
                secondary_reason="Most compatible backup option"
                combo_rec="Start with WireGuard, add more if needed"
                ;;
        esac
    fi

    # Display recommendation
    echo -e "${BRIGHT_GREEN}  ╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    echo -e "${BRIGHT_GREEN}  ║  ${BRIGHT_YELLOW}🏆 YOUR PERSONALIZED VPN RECOMMENDATION${NC}                              ${BRIGHT_GREEN}║${NC}"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    echo -e "${BRIGHT_GREEN}  ╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    printf "${BRIGHT_GREEN}  ║  ${BRIGHT_CYAN}🥇 PRIMARY:   ${BRIGHT_WHITE}%-54s${BRIGHT_GREEN}║${NC}\n" "$primary_rec"
    printf "${BRIGHT_GREEN}  ║     ${GRAY}%-64s${BRIGHT_GREEN}║${NC}\n" "$primary_reason"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    printf "${BRIGHT_GREEN}  ║  ${BRIGHT_CYAN}🥈 SECONDARY: ${BRIGHT_WHITE}%-54s${BRIGHT_GREEN}║${NC}\n" "$secondary_rec"
    printf "${BRIGHT_GREEN}  ║     ${GRAY}%-64s${BRIGHT_GREEN}║${NC}\n" "$secondary_reason"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    printf "${BRIGHT_GREEN}  ║  ${BRIGHT_YELLOW}💡 PRO TIP:   ${WHITE}%-54s${BRIGHT_GREEN}║${NC}\n" "$combo_rec"
    echo -e "${BRIGHT_GREEN}  ║                                                                      ║${NC}"
    echo -e "${BRIGHT_GREEN}  ╚══════════════════════════════════════════════════════════════════════╝${NC}"

    # Security ratings
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🔒 SECURITY RATING OF YOUR RECOMMENDATIONS${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"

    # Show ratings for common protocols
    declare -A sec_ratings
    sec_ratings[WireGuard]="████████████████████  10/10  ChaCha20-Poly1305"
    sec_ratings[OpenVPN]="██████████████████░░   9/10  AES-256-GCM + TLS"
    sec_ratings["IKEv2/IPsec"]="██████████████████░░   9/10  AES-256 + IKEv2"
    sec_ratings["REALITY/XTLS"]="████████████████████  10/10  TLS 1.3 + XTLS"
    sec_ratings["V2Ray/Xray"]="██████████████████░░   9/10  Multi-cipher"
    sec_ratings["Hysteria 2"]="██████████████████░░   9/10  QUIC + AES"
    sec_ratings["Shadowsocks"]="████████████████░░░░   8/10  AEAD ciphers"
    sec_ratings["Outline VPN"]="████████████████░░░░   8/10  Shadowsocks-based"
    sec_ratings["Tor Bridge"]="████████████████████  10/10  Onion routing"
    sec_ratings[NaiveProxy]="██████████████████░░   9/10  Chrome TLS stack"

    for proto in "WireGuard" "REALITY/XTLS" "Tor Bridge" "OpenVPN" "IKEv2/IPsec" "V2Ray/Xray" "Hysteria 2" "NaiveProxy" "Shadowsocks" "Outline VPN"; do
        printf "${CYAN}  │  ${WHITE}%-15s ${BRIGHT_GREEN}%s${NC}${CYAN}│${NC}\n" "$proto" "${sec_ratings[$proto]}"
    done

    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"

    # Censorship resistance ratings
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}🔥 CENSORSHIP RESISTANCE RATING${NC}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}████████████████████  10/10  ${GRAY}Undetectable${NC}     ${CYAN}│${NC}\n" "REALITY/XTLS"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}██████████████████░░   9/10  ${GRAY}QUIC anti-QoS${NC}    ${CYAN}│${NC}\n" "Hysteria 2"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}██████████████████░░   9/10  ${GRAY}Multi-protocol${NC}   ${CYAN}│${NC}\n" "V2Ray/Xray"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}██████████████████░░   9/10  ${GRAY}Chrome mimicry${NC}   ${CYAN}│${NC}\n" "NaiveProxy"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}████████████████░░░░   8/10  ${GRAY}Onion routing${NC}    ${CYAN}│${NC}\n" "Tor Bridge"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_RED}████████████████░░░░   8/10  ${GRAY}Easy sharing${NC}     ${CYAN}│${NC}\n" "Outline VPN"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_YELLOW}██████████████░░░░░░   7/10  ${GRAY}AEAD encrypted${NC}   ${CYAN}│${NC}\n" "Shadowsocks"
    printf "${CYAN}  │  ${WHITE}%-18s ${BRIGHT_YELLOW}████████████░░░░░░░░   6/10  ${GRAY}QUIC proxy${NC}       ${CYAN}│${NC}\n" "TUIC"
    printf "${CYAN}  │  ${WHITE}%-18s ${YELLOW}██████████░░░░░░░░░░   5/10  ${GRAY}Port 443 trick${NC}   ${CYAN}│${NC}\n" "OpenVPN TCP"
    printf "${CYAN}  │  ${WHITE}%-18s ${YELLOW}████████░░░░░░░░░░░░   4/10  ${GRAY}Standard VPN${NC}     ${CYAN}│${NC}\n" "WireGuard"
    printf "${CYAN}  │  ${WHITE}%-18s ${YELLOW}████████░░░░░░░░░░░░   4/10  ${GRAY}Known ports${NC}      ${CYAN}│${NC}\n" "IKEv2/IPsec"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"

    echo ""
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENHANCED VPN COMPARISON
# ═══════════════════════════════════════════════════════════════════════════════

show_vpn_comparison() {
    clear
    show_banner

    echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}📊  ${BOLD}${WHITE}COMPLETE VPN PROTOCOL COMPARISON MATRIX${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────┬────────┬────────┬────────┬──────────┬───────────────────────┤${NC}"
    echo -e "${CYAN}  │ ${BOLD}${WHITE}Protocol${NC}         ${CYAN}│ ${BOLD}${WHITE}Speed${NC}  ${CYAN}│ ${BOLD}${WHITE}Secure${NC} ${CYAN}│ ${BOLD}${WHITE}Stealth${NC}${CYAN}│ ${BOLD}${WHITE}Setup${NC}    ${CYAN}│ ${BOLD}${WHITE}Best For${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────┼────────┼────────┼────────┼──────────┼───────────────────────┤${NC}"
    echo -e "${CYAN}  │ ${GREEN}WireGuard${NC}        ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${YELLOW}★★☆☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}Easy${NC}     ${CYAN}│ ${WHITE}Speed & Security${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}OpenVPN${NC}          ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${YELLOW}Medium${NC}   ${CYAN}│ ${WHITE}Compatibility${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}IKEv2/IPsec${NC}      ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${YELLOW}★★☆☆☆${NC}${CYAN}│ ${YELLOW}Medium${NC}   ${CYAN}│ ${WHITE}Mobile Devices${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}V2Ray/Xray${NC}       ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}Anti-Censorship${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}REALITY/XTLS${NC}     ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}Stealth + Speed${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Hysteria 2${NC}       ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${YELLOW}Medium${NC}   ${CYAN}│ ${WHITE}Fast Anti-Censor${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Shadowsocks${NC}      ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}Easy${NC}     ${CYAN}│ ${WHITE}Bypass Firewalls${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Outline VPN${NC}      ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${YELLOW}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}Easy${NC}     ${CYAN}│ ${WHITE}Easy Anti-Censor${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}SoftEther${NC}        ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${YELLOW}★★★★☆${NC}${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}Multi-Protocol${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Tor Bridge${NC}       ${CYAN}│ ${RED}★★☆☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${YELLOW}Medium${NC}   ${CYAN}│ ${WHITE}Max Anonymity${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}OpenConnect${NC}      ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${YELLOW}Medium${NC}   ${CYAN}│ ${WHITE}Cisco Compatible${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}TUIC${NC}             ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}QUIC Proxy${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}NaiveProxy${NC}       ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}Chrome Mimicry${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Brook${NC}            ${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${YELLOW}★★★☆☆${NC}${CYAN}│ ${BRIGHT_GREEN}Easy${NC}     ${CYAN}│ ${WHITE}Simple Proxy${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}WG + obfs${NC}        ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}${CYAN}│ ${RED}Hard${NC}     ${CYAN}│ ${WHITE}Secure + Stealth${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────┴────────┴────────┴────────┴──────────┴───────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}🏅 QUICK PICKS${NC}                                                                   ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                                                  │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🔒 Most Secure:${NC}           ${WHITE}WireGuard > REALITY/XTLS > OpenVPN${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}🔥 Most Censorship-Resistant:${NC} ${WHITE}REALITY > Hysteria 2 > V2Ray/Xray${NC}              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}⚡ Fastest:${NC}                ${WHITE}WireGuard > Hysteria 2 > REALITY/XTLS${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}📱 Best Mobile:${NC}           ${WHITE}IKEv2/IPsec > WireGuard > OpenVPN${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_MAGENTA}🧅 Most Anonymous:${NC}        ${WHITE}Tor > WireGuard+Tor > NaiveProxy${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}👶 Easiest Setup:${NC}         ${WHITE}Outline > WireGuard > Shadowsocks${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🏢 Enterprise:${NC}            ${WHITE}OpenConnect > OpenVPN > IKEv2/IPsec${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                                  │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo ""
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# WIREGUARD INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_wireguard() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🛡️  ${BOLD}${WHITE}WIREGUARD VPN DEPLOYMENT${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}★ MOST SECURE PROTOCOL${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT WIREGUARD" \
        "${GREEN}▶${NC} ${WHITE}Modern, high-performance VPN protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses state-of-the-art cryptography${NC}" \
        "${GREEN}▶${NC} ${WHITE}Minimal attack surface (~4000 lines of code)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Built into Linux kernel 5.6+${NC}" \
        "${GREEN}▶${NC} ${WHITE}Extremely fast connection establishment${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports roaming (seamless IP changes)${NC}" \
        "" \
        "${BRIGHT_YELLOW}⚠️  Note: Easily detected by DPI.${NC}" \
        "${BRIGHT_YELLOW}   For censored regions, use option [9] WG+obfs${NC}"

    if ! confirm_prompt "Deploy WireGuard VPN?"; then
        return
    fi

    echo ""
    glitch_typewriter "  [*] Initializing WireGuard deployment sequence..." "$GREEN"
    echo ""

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}⚙️  ${BOLD}${WHITE}CONFIGURATION${NC}                                         ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    styled_prompt "WireGuard listen port" "51820"
    read -r WG_PORT
    WG_PORT=${WG_PORT:-51820}
    check_port "$WG_PORT" udp || return 1

    styled_prompt "VPN subnet (internal)" "10.66.66.0/24"
    read -r WG_SUBNET
    WG_SUBNET=${WG_SUBNET:-"10.66.66.0/24"}

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select DNS Provider:${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Cloudflare    ${GRAY}(1.1.1.1, 1.0.0.1)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Google        ${GRAY}(8.8.8.8, 8.8.4.4)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Quad9         ${GRAY}(9.9.9.9, 149.112.112.112)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}OpenDNS       ${GRAY}(208.67.222.222, 208.67.220.220)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}AdGuard DNS   ${GRAY}(94.140.14.14, 94.140.15.15)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Mullvad DNS   ${GRAY}(194.242.2.2) - No logging${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Custom DNS${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    styled_prompt "Choose DNS" "1"
    read -r dns_choice
    dns_choice=${dns_choice:-1}

    case $dns_choice in
        1) WG_DNS="1.1.1.1, 1.0.0.1" ;;
        2) WG_DNS="8.8.8.8, 8.8.4.4" ;;
        3) WG_DNS="9.9.9.9, 149.112.112.112" ;;
        4) WG_DNS="208.67.222.222, 208.67.220.220" ;;
        5) WG_DNS="94.140.14.14, 94.140.15.15" ;;
        6) WG_DNS="194.242.2.2" ;;
        7)
            styled_prompt "Enter primary DNS"
            read -r custom_dns1
            styled_prompt "Enter secondary DNS (optional)"
            read -r custom_dns2
            WG_DNS="$custom_dns1"
            [[ -n "$custom_dns2" ]] && WG_DNS="$custom_dns1, $custom_dns2"
            ;;
        *) WG_DNS="1.1.1.1, 1.0.0.1" ;;
    esac

    echo ""
    styled_prompt "Number of client configs to generate" "1"
    read -r WG_CLIENTS
    WG_CLIENTS=${WG_CLIENTS:-1}

    styled_prompt "First client name" "client1"
    read -r WG_CLIENT_NAME
    WG_CLIENT_NAME=${WG_CLIENT_NAME:-"client1"}

    styled_prompt "MTU size" "1420"
    read -r WG_MTU
    WG_MTU=${WG_MTU:-1420}

    echo ""
    info_box "DEPLOYMENT SUMMARY" \
        "${GREEN}▶${NC} ${WHITE}Port:    ${BRIGHT_GREEN}${WG_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Subnet:  ${BRIGHT_GREEN}${WG_SUBNET}${NC}" \
        "${GREEN}▶${NC} ${WHITE}DNS:     ${BRIGHT_GREEN}${WG_DNS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Clients: ${BRIGHT_GREEN}${WG_CLIENTS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}MTU:     ${BRIGHT_GREEN}${WG_MTU}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:  ${BRIGHT_YELLOW}${SERVER_IP}${NC}"

    if ! confirm_prompt "Proceed with installation?"; then
        warning_msg "Deployment aborted!"
        return
    fi

    echo ""
    glitch_typewriter "  [*] Starting WireGuard deployment..." "$GREEN"
    echo ""

    # Step 1
    echo -e "  ${BRIGHT_CYAN}[Step 1/7]${NC} ${WHITE}Updating system packages...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1 && apt-get upgrade -y -qq > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf update -y -q > /dev/null 2>&1 || yum update -y -q > /dev/null 2>&1 ;;
            arch|manjaro) pacman -Syu --noconfirm > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Updating system packages"

    # Step 2
    echo -e "  ${BRIGHT_CYAN}[Step 2/7]${NC} ${WHITE}Installing WireGuard...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get install -y -qq wireguard wireguard-tools qrencode > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux) dnf install -y -q epel-release > /dev/null 2>&1; dnf install -y -q wireguard-tools qrencode > /dev/null 2>&1 ;;
            fedora) dnf install -y -q wireguard-tools qrencode > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm wireguard-tools qrencode > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing WireGuard packages"

    # Step 3
    echo -e "  ${BRIGHT_CYAN}[Step 3/7]${NC} ${WHITE}Generating cryptographic keys...${NC}"
    (
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard
        wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
        chmod 600 /etc/wireguard/server_private.key
        sleep 1
    ) &
    spinner $! "Generating server keys"

    SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
    SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

    WG_SERVER_IP=$(echo "$WG_SUBNET" | sed 's/\.[0-9]*\//.1\//')
    WG_SERVER_ADDR=$(echo "$WG_SERVER_IP" | cut -d'/' -f1)

    # Step 4
    echo -e "  ${BRIGHT_CYAN}[Step 4/7]${NC} ${WHITE}Detecting network configuration...${NC}"
    SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    echo -e "  ${CYAN}  [${BRIGHT_GREEN}✓${CYAN}]${NC} ${WHITE}Network interface: ${BRIGHT_GREEN}${SERVER_NIC}${NC}"

    # Step 5
    echo -e "  ${BRIGHT_CYAN}[Step 5/7]${NC} ${WHITE}Creating server configuration...${NC}"
    (
        cat > /etc/wireguard/wg0.conf << WGEOF
# ═══════════════════════════════════════════════════════════
# WireGuard Server Configuration
# Generated by VPN Blast v${SCRIPT_VERSION}
# Date: $(date)
# ═══════════════════════════════════════════════════════════

[Interface]
Address = ${WG_SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
MTU = ${WG_MTU}

PostUp = iptables -I INPUT -p udp --dport ${WG_PORT} -j ACCEPT
PostUp = iptables -I FORWARD -i wg0 -j ACCEPT
PostUp = iptables -I FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_NIC} -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport ${WG_PORT} -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_NIC} -j MASQUERADE

WGEOF
        chmod 600 /etc/wireguard/wg0.conf
        sleep 1
    ) &
    spinner $! "Writing server configuration"

    # Step 6
    echo -e "  ${BRIGHT_CYAN}[Step 6/7]${NC} ${WHITE}Generating client configurations...${NC}"
    mkdir -p /etc/wireguard/clients

    for i in $(seq 1 "$WG_CLIENTS"); do
        local client_name
        if [[ $i -eq 1 ]]; then
            client_name="$WG_CLIENT_NAME"
        else
            styled_prompt "  Name for client #${i}"
            read -r client_name
            client_name=${client_name:-"client${i}"}
        fi

        (
            client_private=$(wg genkey)
            client_public=$(echo "$client_private" | wg pubkey)
            client_psk=$(wg genpsk)
            local client_ip_num=$(( i + 1 ))
            local base_ip
            base_ip=$(echo "$WG_SUBNET" | cut -d'.' -f1-3)
            local client_ip="${base_ip}.${client_ip_num}"

            cat >> /etc/wireguard/wg0.conf << PEER_EOF

[Peer]
# Client: ${client_name}
PublicKey = ${client_public}
PresharedKey = ${client_psk}
AllowedIPs = ${client_ip}/32
PEER_EOF

            cat > "/etc/wireguard/clients/${client_name}.conf" << CLIENT_EOF
[Interface]
PrivateKey = ${client_private}
Address = ${client_ip}/32
DNS = ${WG_DNS}
MTU = ${WG_MTU}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${client_psk}
Endpoint = ${SERVER_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CLIENT_EOF

            chmod 600 "/etc/wireguard/clients/${client_name}.conf"
            qrencode -t ansiutf8 < "/etc/wireguard/clients/${client_name}.conf" \
                > "/etc/wireguard/clients/${client_name}_qr.txt" 2>/dev/null
            sleep 0.5
        ) &
        spinner $! "Generating config for ${client_name}"
    done

    # Step 7
    echo -e "  ${BRIGHT_CYAN}[Step 7/7]${NC} ${WHITE}Activating WireGuard...${NC}"
    (
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1
        grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
        systemctl enable wg-quick@wg0 > /dev/null 2>&1
        systemctl start wg-quick@wg0 > /dev/null 2>&1
        if command -v ufw &> /dev/null; then ufw allow "$WG_PORT"/udp > /dev/null 2>&1; fi
        if command -v firewall-cmd &> /dev/null; then firewall-cmd --permanent --add-port="$WG_PORT"/udp > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        sleep 1
    ) &
    spinner $! "Activating WireGuard & configuring firewall"

    echo ""
    success_msg "WireGuard Deployed Successfully!"

    info_box "CLIENT CONFIGURATION FILES" \
        "${GREEN}▶${NC} ${WHITE}Config directory: ${BRIGHT_GREEN}/etc/wireguard/clients/${NC}" \
        "${GREEN}▶${NC} ${WHITE}Download configs via SCP:${NC}" \
        "  ${GRAY}scp root@${SERVER_IP}:/etc/wireguard/clients/*.conf ./${NC}"

    if [[ -f "/etc/wireguard/clients/${WG_CLIENT_NAME}_qr.txt" ]]; then
        echo -e "\n${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_CYAN}📱 QR Code for ${WG_CLIENT_NAME}${NC} ${GRAY}(scan with WireGuard app)${NC}     ${CYAN}│${NC}"
        echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
        echo ""
        cat "/etc/wireguard/clients/${WG_CLIENT_NAME}_qr.txt"
    fi

    info_box "CLIENT SETUP INSTRUCTIONS" \
        "${BRIGHT_YELLOW}📱 Mobile (iOS/Android):${NC}" \
        "  ${WHITE}1. Install WireGuard from App Store/Play Store${NC}" \
        "  ${WHITE}2. Scan the QR code above or import .conf file${NC}" \
        "  ${WHITE}3. Toggle the connection ON${NC}" \
        "" \
        "${BRIGHT_YELLOW}💻 Desktop (Windows/Mac/Linux):${NC}" \
        "  ${WHITE}1. Install WireGuard from wireguard.com${NC}" \
        "  ${WHITE}2. Import the .conf file${NC}" \
        "  ${WHITE}3. Click 'Activate' to connect${NC}" \
        "" \
        "${BRIGHT_YELLOW}🐧 Linux CLI:${NC}" \
        "  ${GRAY}sudo apt install wireguard${NC}" \
        "  ${GRAY}sudo cp client.conf /etc/wireguard/wg0.conf${NC}" \
        "  ${GRAY}sudo wg-quick up wg0${NC}"

    log "INFO" "WireGuard installed successfully"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPENVPN INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_openvpn() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🔐  ${BOLD}${WHITE}OPENVPN DEPLOYMENT${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}★ MOST COMPATIBLE VPN${NC}                                   ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT OPENVPN" \
        "${GREEN}▶${NC} ${WHITE}Industry-standard VPN solution${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports UDP and TCP protocols${NC}" \
        "${GREEN}▶${NC} ${WHITE}Works on virtually all platforms${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can traverse most firewalls (TCP/443)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Highly configurable${NC}" \
        "${GREEN}▶${NC} ${WHITE}SSL/TLS-based security${NC}" \
        "" \
        "${BRIGHT_YELLOW}TIP: Use TCP port 443 for moderate censorship${NC}"

    if ! confirm_prompt "Deploy OpenVPN?"; then
        return
    fi

    echo ""
    echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}For a full automated OpenVPN install, we recommend:${NC}"
    echo -e "  ${GRAY}    curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh${NC}"
    echo -e "  ${GRAY}    chmod +x openvpn-install.sh && sudo ./openvpn-install.sh${NC}"
    echo ""

    if ! confirm_prompt "Use VPN Blast's built-in OpenVPN installer instead?"; then
        echo -e "  ${GREEN}Run the command above to use Angristan's excellent installer.${NC}"
        echo -e "  ${GRAY}Press any key to return...${NC}"
        read -n 1 -s
        return
    fi

    glitch_typewriter "  [*] Initializing OpenVPN deployment sequence..." "$GREEN"
    echo ""

    # Protocol Selection
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Protocol:${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}UDP ${GRAY}─ Faster, recommended for most users${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}TCP ${GRAY}─ More reliable, works through firewalls${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose protocol" "1"
    read -r proto_choice
    case $proto_choice in
        2) OVPN_PROTO="tcp" ;;
        *) OVPN_PROTO="udp" ;;
    esac

    local default_port
    [[ "$OVPN_PROTO" == "udp" ]] && default_port="1194" || default_port="443"
    styled_prompt "Port number" "$default_port"
    read -r OVPN_PORT
    OVPN_PORT=${OVPN_PORT:-$default_port}
    check_port "$OVPN_PORT" "$OVPN_PROTO" || return 1

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Encryption Level:${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}AES-128-GCM  ${GRAY}─ Fast, very secure${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}AES-256-GCM  ${GRAY}─ Maximum security (recommended)${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}AES-256-CBC  ${GRAY}─ Compatible, slower${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose encryption" "2"
    read -r enc_choice
    case $enc_choice in
        1) OVPN_CIPHER="AES-128-GCM" ;;
        3) OVPN_CIPHER="AES-256-CBC" ;;
        *) OVPN_CIPHER="AES-256-GCM" ;;
    esac

    styled_prompt "First client name" "client1"
    read -r OVPN_CLIENT_NAME
    OVPN_CLIENT_NAME=${OVPN_CLIENT_NAME:-"client1"}

    echo ""
    info_box "DEPLOYMENT SUMMARY" \
        "${GREEN}▶${NC} ${WHITE}Protocol: ${BRIGHT_GREEN}${OVPN_PROTO^^}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${OVPN_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Cipher:   ${BRIGHT_GREEN}${OVPN_CIPHER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Client:   ${BRIGHT_GREEN}${OVPN_CLIENT_NAME}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}"

    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/4]${NC} ${WHITE}Installing dependencies...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq openvpn easy-rsa openssl ca-certificates iptables > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux) dnf install -y -q epel-release > /dev/null 2>&1; dnf install -y -q openvpn easy-rsa openssl > /dev/null 2>&1 ;;
            fedora) dnf install -y -q openvpn easy-rsa openssl > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm openvpn easy-rsa openssl > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing OpenVPN & Easy-RSA"

    echo -e "  ${BRIGHT_CYAN}[Step 2/4]${NC} ${WHITE}Setting up PKI & generating certificates...${NC}"
    (
        EASYRSA_DIR="/etc/openvpn/easy-rsa"
        mkdir -p "$EASYRSA_DIR"
        [[ -d /usr/share/easy-rsa ]] && cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
        [[ -d /usr/share/easy-rsa/3 ]] && cp -r /usr/share/easy-rsa/3/* "$EASYRSA_DIR/"
        cd "$EASYRSA_DIR" || exit
        ./easyrsa --batch init-pki > /dev/null 2>&1
        EASYRSA_BATCH=1 ./easyrsa --batch build-ca nopass > /dev/null 2>&1
        EASYRSA_BATCH=1 ./easyrsa --batch build-server-full server nopass > /dev/null 2>&1
        EASYRSA_BATCH=1 ./easyrsa --batch gen-dh > /dev/null 2>&1
        openvpn --genkey secret /etc/openvpn/tls-crypt.key > /dev/null 2>&1
        EASYRSA_BATCH=1 ./easyrsa --batch build-client-full "$OVPN_CLIENT_NAME" nopass > /dev/null 2>&1
        cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/ 2>/dev/null
        sleep 1
    ) &
    spinner $! "Building PKI & certificates (takes a moment)"

    echo -e "  ${BRIGHT_CYAN}[Step 3/4]${NC} ${WHITE}Creating server configuration...${NC}"
    (
        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
        # Fix group for CentOS
        OVPN_GROUP="nogroup"
        if ! grep -q "^nogroup:" /etc/group; then OVPN_GROUP="nobody"; fi
        
        cat > /etc/openvpn/server.conf << OVPNEOF
port ${OVPN_PORT}
proto ${OVPN_PROTO}
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt tls-crypt.key
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
keepalive 10 120
cipher ${OVPN_CIPHER}
auth SHA256
user nobody
group ${OVPN_GROUP}
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
explicit-exit-notify 1
OVPNEOF
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$SERVER_NIC" -j MASQUERADE 2>/dev/null
        iptables -I INPUT -p "$OVPN_PROTO" --dport "$OVPN_PORT" -j ACCEPT 2>/dev/null
        iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT 2>/dev/null
        iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
        sleep 1
    ) &
    spinner $! "Creating server configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 4/4]${NC} ${WHITE}Generating client profile & starting service...${NC}"
    (
        mkdir -p /etc/openvpn/clients
        cat > "/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn" << CLIENTEOF
client
dev tun
proto ${OVPN_PROTO}
remote ${SERVER_IP} ${OVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher ${OVPN_CIPHER}
auth SHA256
key-direction 1
verb 3
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/${OVPN_CLIENT_NAME}.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/${OVPN_CLIENT_NAME}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/tls-crypt.key)
</tls-crypt>
CLIENTEOF
        chmod 600 "/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn"
        systemctl enable openvpn@server > /dev/null 2>&1
        systemctl start openvpn@server > /dev/null 2>&1
        if command -v ufw &>/dev/null; then ufw allow "$OVPN_PORT"/"$OVPN_PROTO" > /dev/null 2>&1; fi
        if command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$OVPN_PORT"/"$OVPN_PROTO" > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        sleep 1
    ) &
    spinner $! "Generating client profile & activating service"

    echo ""
    success_msg "OpenVPN Deployed Successfully!"

    info_box "CLIENT CONFIGURATION" \
        "${GREEN}▶${NC} ${WHITE}Config: ${BRIGHT_GREEN}/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn${NC}" \
        "${GREEN}▶${NC} ${WHITE}SCP: ${GRAY}scp root@${SERVER_IP}:/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn ./${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Mobile:${NC} ${WHITE}OpenVPN Connect app${NC}" \
        "${BRIGHT_YELLOW}💻 Windows:${NC} ${WHITE}OpenVPN GUI from openvpn.net${NC}" \
        "${BRIGHT_YELLOW}🐧 Linux:${NC} ${GRAY}sudo openvpn --config ${OVPN_CLIENT_NAME}.ovpn${NC}"

    log "INFO" "OpenVPN installed successfully"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# IKEv2/IPSEC INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_ikev2() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}⚡  ${BOLD}${WHITE}IKEv2/IPsec VPN DEPLOYMENT${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}★ BEST FOR MOBILE DEVICES${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT IKEv2/IPsec" \
        "${GREEN}▶${NC} ${WHITE}Native support on iOS, macOS, Windows, Android${NC}" \
        "${GREEN}▶${NC} ${WHITE}No third-party app needed on most devices${NC}" \
        "${GREEN}▶${NC} ${WHITE}Strong security with IKEv2 key exchange${NC}" \
        "${GREEN}▶${NC} ${WHITE}Handles network switches seamlessly (WiFi↔LTE)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses strongSwan as the implementation${NC}"

    if ! confirm_prompt "Deploy IKEv2/IPsec VPN?"; then return; fi

    echo ""
    glitch_typewriter "  [*] Initializing IKEv2/IPsec deployment..." "$GREEN"
    echo ""

    styled_prompt "VPN username" "vpnuser"
    read -r IKEV2_USER
    IKEV2_USER=${IKEV2_USER:-"vpnuser"}

    styled_prompt "VPN password (leave empty to auto-generate)"
    read -rs IKEV2_PASS
    echo ""
    if [[ -z "$IKEV2_PASS" ]]; then
        IKEV2_PASS=$(openssl rand -base64 16 2>/dev/null)
        echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated password: ${BRIGHT_YELLOW}${IKEV2_PASS}${NC}"
    fi

    styled_prompt "VPN subnet" "10.10.10.0/24"
    read -r IKEV2_SUBNET
    IKEV2_SUBNET=${IKEV2_SUBNET:-"10.10.10.0/24"}

    IKEV2_DNS="1.1.1.1,1.0.0.1"

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/5]${NC} ${WHITE}Installing strongSwan...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y -q epel-release > /dev/null 2>&1; dnf install -y -q strongswan > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm strongswan > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing strongSwan"

    echo -e "  ${BRIGHT_CYAN}[Step 2/5]${NC} ${WHITE}Generating certificates...${NC}"
    (
        mkdir -p /etc/ipsec.d/{cacerts,certs,private}
        ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/ca-key.pem 2>/dev/null
        ipsec pki --self --ca --lifetime 3650 --in /etc/ipsec.d/private/ca-key.pem --type rsa --dn "CN=VPN Blast CA" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem 2>/dev/null
        ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/server-key.pem 2>/dev/null
        ipsec pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa | ipsec pki --issue --lifetime 1825 --cacert /etc/ipsec.d/cacerts/ca-cert.pem --cakey /etc/ipsec.d/private/ca-key.pem --dn "CN=${SERVER_IP}" --san "${SERVER_IP}" --flag serverAuth --flag ikeIntermediate --outform pem > /etc/ipsec.d/certs/server-cert.pem 2>/dev/null
        chmod 600 /etc/ipsec.d/private/*
        sleep 1
    ) &
    spinner $! "Generating PKI certificates"

    echo -e "  ${BRIGHT_CYAN}[Step 3/5]${NC} ${WHITE}Configuring strongSwan...${NC}"
    (
        cat > /etc/ipsec.conf << IPSECEOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=${SERVER_IP}
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=${IKEV2_SUBNET}
    rightdns=${IKEV2_DNS}
    rightsendcert=never
    eap_identity=%identity
    ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
IPSECEOF
        cat > /etc/ipsec.secrets << SECRETSEOF
: RSA "server-key.pem"
${IKEV2_USER} : EAP "${IKEV2_PASS}"
SECRETSEOF
        chmod 600 /etc/ipsec.secrets
        sleep 1
    ) &
    spinner $! "Writing configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 4/5]${NC} ${WHITE}Configuring networking...${NC}"
    (
        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null 2>&1
        sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null 2>&1
        sysctl -w net.ipv4.ip_no_pmtu_disc=1 > /dev/null 2>&1
        iptables -t nat -A POSTROUTING -s "$IKEV2_SUBNET" -o "$SERVER_NIC" -j MASQUERADE 2>/dev/null
        iptables -A INPUT -p udp --dport 500 -j ACCEPT 2>/dev/null
        iptables -A INPUT -p udp --dport 4500 -j ACCEPT 2>/dev/null
        if command -v ufw &>/dev/null; then ufw allow 500/udp > /dev/null 2>&1; ufw allow 4500/udp > /dev/null 2>&1; fi
        sleep 1
    ) &
    spinner $! "Configuring firewall & networking"

    echo -e "  ${BRIGHT_CYAN}[Step 5/5]${NC} ${WHITE}Starting strongSwan service...${NC}"
    (
        systemctl enable strongswan-starter > /dev/null 2>&1 || systemctl enable strongswan > /dev/null 2>&1
        systemctl restart strongswan-starter > /dev/null 2>&1 || systemctl restart strongswan > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting IKEv2/IPsec service"

    echo ""
    success_msg "IKEv2/IPsec Deployed!"

    info_box "CONNECTION CREDENTIALS" \
        "${GREEN}▶${NC} ${WHITE}Server:        ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}IPsec ID:      ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Type:          ${BRIGHT_GREEN}IKEv2${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username:      ${BRIGHT_GREEN}${IKEV2_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password:      ${BRIGHT_YELLOW}${IKEV2_PASS}${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}CA Cert: ${GRAY}/etc/ipsec.d/cacerts/ca-cert.pem${NC}" \
        "  ${GRAY}scp root@${SERVER_IP}:/etc/ipsec.d/cacerts/ca-cert.pem ./${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}Settings→VPN→IKEv2/IPSec MSCHAPv2${NC}" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Settings→General→VPN→IKEv2${NC}" \
        "${BRIGHT_YELLOW}💻 Windows:${NC} ${WHITE}Settings→Network→VPN→IKEv2${NC}"

    log "INFO" "IKEv2/IPsec installed successfully"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# V2RAY/XRAY INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_v2ray() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🚀  ${BOLD}${WHITE}V2RAY/XRAY DEPLOYMENT${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ TOP CENSORSHIP-RESISTANT PROTOCOL${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT V2RAY/XRAY" \
        "${GREEN}▶${NC} ${WHITE}Advanced proxy/tunneling platform${NC}" \
        "${GREEN}▶${NC} ${WHITE}Multiple protocols: VMess, VLESS, Trojan${NC}" \
        "${GREEN}▶${NC} ${WHITE}Traffic obfuscation (WebSocket, gRPC, HTTP/2)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can disguise as normal HTTPS traffic${NC}" \
        "${GREEN}▶${NC} ${WHITE}Xray is an enhanced fork with XTLS${NC}" \
        "${GREEN}▶${NC} ${WHITE}Excellent for bypassing DPI${NC}" \
        "" \
        "${BRIGHT_RED}🔥 RECOMMENDED for China, Iran, Russia, etc.${NC}"

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Implementation:${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Xray-core   ${GRAY}(recommended, XTLS+REALITY)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}V2Ray-core  ${GRAY}(original, stable)${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose" "1"
    read -r v2_impl
    [[ "$v2_impl" == "2" ]] && V2_ENGINE="v2ray" || V2_ENGINE="xray"

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Protocol:${NC}                                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}VLESS + WebSocket + TLS  ${GRAY}(recommended, CDN-friendly)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}VLESS + TCP + XTLS       ${GRAY}(fastest, Xray only)${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}VMess + WebSocket        ${GRAY}(most compatible)${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}VMess + TCP              ${GRAY}(simple setup)${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Trojan + WebSocket       ${GRAY}(mimics HTTPS)${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}VLESS + gRPC             ${GRAY}(CDN-friendly, multiplexed)${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                                      │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose protocol" "3"
    read -r v2_proto
    v2_proto=${v2_proto:-3}

    styled_prompt "Port" "443"
    read -r V2_PORT
    V2_PORT=${V2_PORT:-443}
    check_port "$V2_PORT" tcp || return 1

    V2_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated UUID: ${BRIGHT_YELLOW}${V2_UUID}${NC}"

    if [[ "$v2_proto" =~ ^[1356]$ ]]; then
        styled_prompt "WebSocket/gRPC path" "/ws"
        read -r V2_WS_PATH
        V2_WS_PATH=${V2_WS_PATH:-"/ws"}
    fi

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing ${V2_ENGINE}...${NC}"
    (
        if [[ "$V2_ENGINE" == "xray" ]]; then
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
        else
            bash -c "$(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)" > /dev/null 2>&1
        fi
        sleep 1
    ) &
    spinner $! "Installing ${V2_ENGINE}-core"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Creating configuration...${NC}"
    (
        local config_dir
        [[ "$V2_ENGINE" == "xray" ]] && config_dir="/usr/local/etc/xray" || config_dir="/usr/local/etc/v2ray"
        mkdir -p "$config_dir"

        case $v2_proto in
            1|3|6)
                local protocol="vless"
                local settings='"clients": [{"id": "'${V2_UUID}'", "level": 0}], "decryption": "none"'
                local network="ws"
                local net_settings='"wsSettings": {"path": "'${V2_WS_PATH}'"}'

                [[ "$v2_proto" == "3" ]] && protocol="vmess" && settings='"clients": [{"id": "'${V2_UUID}'", "alterId": 0}]'
                [[ "$v2_proto" == "6" ]] && network="grpc" && net_settings='"grpcSettings": {"serviceName": "'${V2_WS_PATH#/}'"}'

                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "${protocol}",
        "settings": {${settings}},
        "streamSettings": {"network": "${network}", ${net_settings}}
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
            2)
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=${SERVER_IP}" -keyout "${config_dir}/key.pem" -out "${config_dir}/cert.pem" > /dev/null 2>&1
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT}, "protocol": "vless",
        "settings": {"clients": [{"id": "${V2_UUID}", "flow": "xtls-rprx-vision", "level": 0}], "decryption": "none"},
        "streamSettings": {"network": "tcp", "security": "tls", "tlsSettings": {"certificates": [{"certificateFile": "${config_dir}/cert.pem", "keyFile": "${config_dir}/key.pem"}]}}
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
            4)
                cat > "${config_dir}/config.json" << V2EOF
{"log":{"loglevel":"warning"},"inbounds":[{"port":${V2_PORT},"protocol":"vmess","settings":{"clients":[{"id":"${V2_UUID}","alterId":0}]},"streamSettings":{"network":"tcp"}}],"outbounds":[{"protocol":"freedom"},{"protocol":"blackhole","tag":"blocked"}]}
V2EOF
                ;;
            5)
                V2_TROJAN_PASS=$(openssl rand -hex 16)
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=${SERVER_IP}" -keyout "${config_dir}/key.pem" -out "${config_dir}/cert.pem" > /dev/null 2>&1
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT}, "protocol": "trojan",
        "settings": {"clients": [{"password": "${V2_TROJAN_PASS}"}]},
        "streamSettings": {"network": "ws", "wsSettings": {"path": "${V2_WS_PATH}"}, "security": "tls", "tlsSettings": {"certificates": [{"certificateFile": "${config_dir}/cert.pem", "keyFile": "${config_dir}/key.pem"}]}}
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
        esac
        sleep 1
    ) &
    spinner $! "Creating ${V2_ENGINE} configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting ${V2_ENGINE} service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$V2_PORT" > /dev/null 2>&1; fi
        if command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$V2_PORT"/tcp > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        systemctl enable "$V2_ENGINE" > /dev/null 2>&1
        systemctl restart "$V2_ENGINE" > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting ${V2_ENGINE} service"

    local proto_name
    case $v2_proto in
        1) proto_name="VLESS+WS" ;; 2) proto_name="VLESS+XTLS" ;;
        3) proto_name="VMess+WS" ;; 4) proto_name="VMess+TCP" ;;
        5) proto_name="Trojan+WS" ;; 6) proto_name="VLESS+gRPC" ;;
    esac

    echo ""
    success_msg "${V2_ENGINE} Deployed!"

    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Engine:   ${BRIGHT_GREEN}${V2_ENGINE}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Protocol: ${BRIGHT_GREEN}${proto_name}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${V2_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}UUID:     ${BRIGHT_YELLOW}${V2_UUID}${NC}"

    info_box "CLIENT APPS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Shadowrocket, V2Box, Streisand${NC}" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}V2RayNG, Matsuri, NekoBox${NC}" \
        "${BRIGHT_YELLOW}💻 Windows:${NC} ${WHITE}V2RayN, Nekoray, Hiddify${NC}" \
        "${BRIGHT_YELLOW}🍎 macOS:${NC} ${WHITE}V2RayU, Nekoray, Hiddify${NC}" \
        "${BRIGHT_YELLOW}🐧 Linux:${NC} ${WHITE}Nekoray, v2ray CLI${NC}"

    log "INFO" "${V2_ENGINE} installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHADOWSOCKS
# ═══════════════════════════════════════════════════════════════════════════════

install_shadowsocks() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🕶️   ${BOLD}${WHITE}SHADOWSOCKS DEPLOYMENT${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ ANTI-DPI STEALTH PROXY${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT SHADOWSOCKS" \
        "${GREEN}▶${NC} ${WHITE}SOCKS5 based encrypted proxy${NC}" \
        "${GREEN}▶${NC} ${WHITE}Designed to bypass the Great Firewall${NC}" \
        "${GREEN}▶${NC} ${WHITE}Lightweight and fast${NC}" \
        "${GREEN}▶${NC} ${WHITE}Using shadowsocks-rust (latest implementation)${NC}"

    if ! confirm_prompt "Deploy Shadowsocks?"; then return; fi
    echo ""

    styled_prompt "Port" "8388"
    read -r SS_PORT
    SS_PORT=${SS_PORT:-8388}
    check_port "$SS_PORT" tcp || return 1

    styled_prompt "Password (leave empty to auto-generate)"
    read -rs SS_PASS
    echo ""
    [[ -z "$SS_PASS" ]] && SS_PASS=$(openssl rand -base64 24) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${SS_PASS}${NC}"

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Encryption:${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}aes-256-gcm              ${GRAY}(recommended)${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}chacha20-ietf-poly1305   ${GRAY}(great for mobile)${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}2022-blake3-aes-256-gcm  ${GRAY}(newest, most secure)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    styled_prompt "Choose" "1"
    read -r enc_choice
    case $overwrite in
        2) SS_METHOD="chacha20-ietf-poly1305" ;;
        3) SS_METHOD="2022-blake3-aes-256-gcm"; SS_PASS=$(openssl rand -base64 32); echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}2022 key: ${BRIGHT_YELLOW}${SS_PASS}${NC}" ;;
        *) SS_METHOD="aes-256-gcm" ;;
    esac

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing shadowsocks...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq shadowsocks-libev > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y -q epel-release > /dev/null 2>&1; dnf install -y -q shadowsocks-libev > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm shadowsocks-rust > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing Shadowsocks"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Creating configuration...${NC}"
    (
        mkdir -p /etc/shadowsocks
        cat > /etc/shadowsocks/config.json << SSEOF
{"server":"0.0.0.0","server_port":${SS_PORT},"password":"${SS_PASS}","method":"${SS_METHOD}","timeout":300,"mode":"tcp_and_udp","fast_open":true,"no_delay":true}
SSEOF
        local ss_bin
        ss_bin=$(which ssserver 2>/dev/null || which ss-server 2>/dev/null || echo "/usr/bin/ss-server")
        cat > /etc/systemd/system/shadowsocks.service << SSSERVEOF
[Unit]
Description=Shadowsocks Server
After=network.target
[Service]
Type=simple
ExecStart=${ss_bin} -c /etc/shadowsocks/config.json
Restart=on-failure
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
SSSERVEOF
        sleep 1
    ) &
    spinner $! "Creating configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$SS_PORT" > /dev/null 2>&1; fi
        if command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$SS_PORT"/tcp > /dev/null 2>&1; firewall-cmd --permanent --add-port="$SS_PORT"/udp > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        systemctl daemon-reload; systemctl enable shadowsocks > /dev/null 2>&1; systemctl start shadowsocks > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting Shadowsocks"

    SS_URI="ss://$(echo -n "${SS_METHOD}:${SS_PASS}" | base64 -w0)@${SERVER_IP}:${SS_PORT}"

    echo ""
    success_msg "Shadowsocks Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:  ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:    ${BRIGHT_GREEN}${SS_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Pass:    ${BRIGHT_YELLOW}${SS_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Method:  ${BRIGHT_GREEN}${SS_METHOD}${NC}" \
        "${GREEN}▶${NC} ${WHITE}URI: ${GRAY}${SS_URI}${NC}"

    log "INFO" "Shadowsocks installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTLINE VPN
# ═══════════════════════════════════════════════════════════════════════════════

install_outline() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🔥  ${BOLD}${WHITE}OUTLINE VPN DEPLOYMENT${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ EASIEST ANTI-CENSORSHIP TOOL${NC}                         ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT OUTLINE VPN" \
        "${GREEN}▶${NC} ${WHITE}Created by Jigsaw (Google/Alphabet)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Designed to resist censorship${NC}" \
        "${GREEN}▶${NC} ${WHITE}Based on Shadowsocks protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Easy to share access with others${NC}" \
        "${GREEN}▶${NC} ${WHITE}Runs in Docker containers${NC}" \
        "" \
        "${BRIGHT_YELLOW}NOTE: Only works with official Outline apps${NC}"

    if ! confirm_prompt "Deploy Outline VPN?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/2]${NC} ${WHITE}Installing Docker...${NC}"
    (
        if ! command -v docker &>/dev/null; then
            curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
            systemctl enable docker > /dev/null 2>&1
            systemctl start docker > /dev/null 2>&1
        fi
        sleep 1
    ) &
    spinner $! "Installing Docker"

    echo -e "  ${BRIGHT_CYAN}[Step 2/2]${NC} ${WHITE}Deploying Outline Server...${NC}"
    echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}Running Outline installer:${NC}"
    echo -e "  ${GRAY}─────────────────────────────────────${NC}"
    bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" 2>&1 | tee /tmp/outline_install.log
    echo -e "  ${GRAY}─────────────────────────────────────${NC}"

    echo ""
    success_msg "Outline VPN Deployed!"
    info_box "NEXT STEPS" \
        "${WHITE}1. Download Outline Manager from getoutline.org${NC}" \
        "${WHITE}2. Copy the API URL from the output above${NC}" \
        "${WHITE}3. Create access keys in Outline Manager${NC}" \
        "${WHITE}4. Share keys with users (Outline Client app)${NC}"

    log "INFO" "Outline installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# HYSTERIA 2
# ═══════════════════════════════════════════════════════════════════════════════

install_hysteria2() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🌊  ${BOLD}${WHITE}HYSTERIA 2 DEPLOYMENT${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ FASTEST ANTI-CENSORSHIP PROTOCOL${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT HYSTERIA 2" \
        "${GREEN}▶${NC} ${WHITE}QUIC-based proxy protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Brutal congestion control (anti-QoS)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Extremely fast, even on lossy networks${NC}" \
        "${GREEN}▶${NC} ${WHITE}Resistant to DPI and traffic analysis${NC}" \
        "${GREEN}▶${NC} ${WHITE}UDP-based: great for gaming & streaming${NC}" \
        "${GREEN}▶${NC} ${WHITE}Built-in traffic obfuscation${NC}" \
        "" \
        "${BRIGHT_RED}🔥 IDEAL for regions with heavy bandwidth throttling${NC}"

    if ! confirm_prompt "Deploy Hysteria 2?"; then return; fi
    echo ""

    styled_prompt "Port" "443"
    read -r HY2_PORT
    HY2_PORT=${HY2_PORT:-443}
    check_port "$HY2_PORT" udp || return 1

    styled_prompt "Password (leave empty to auto-generate)"
    read -rs HY2_PASS
    echo ""
    [[ -z "$HY2_PASS" ]] && HY2_PASS=$(openssl rand -base64 24) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${HY2_PASS}${NC}"

    styled_prompt "Download speed (Mbps) for bandwidth hint" "100"
    read -r HY2_DOWN
    HY2_DOWN=${HY2_DOWN:-100}

    styled_prompt "Upload speed (Mbps) for bandwidth hint" "50"
    read -r HY2_UP
    HY2_UP=${HY2_UP:-50}

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Obfuscation type:${NC}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}None         ${GRAY}(faster, less stealth)${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Salamander   ${GRAY}(obfuscated, more stealth)${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    styled_prompt "Choose" "2"
    read -r obfs_choice

    local obfs_config=""
    if [[ "$obfs_choice" == "2" ]]; then
        HY2_OBFS_PASS=$(openssl rand -hex 16)
        obfs_config='"obfs": {"type": "salamander", "salamander": {"password": "'${HY2_OBFS_PASS}'"}},'
    fi

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing Hysteria 2...${NC}"
    (
        bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Installing Hysteria 2"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Creating configuration...${NC}"
    (
        mkdir -p /etc/hysteria

        # Generate self-signed cert
        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -nodes -x509 \
            -subj "/CN=bing.com" \
            -keyout /etc/hysteria/server.key \
            -out /etc/hysteria/server.crt > /dev/null 2>&1

        cat > /etc/hysteria/config.yaml << HY2EOF
listen: :${HY2_PORT}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

${obfs_config:+obfs:
  type: salamander
  salamander:
    password: ${HY2_OBFS_PASS:-""}}

auth:
  type: password
  password: ${HY2_PASS}

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
HY2EOF

        chmod 600 /etc/hysteria/config.yaml
        sleep 1
    ) &
    spinner $! "Creating configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$HY2_PORT"/udp > /dev/null 2>&1; fi
        if command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$HY2_PORT"/udp > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        systemctl enable hysteria-server > /dev/null 2>&1
        systemctl restart hysteria-server > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting Hysteria 2"

    echo ""
    success_msg "Hysteria 2 Deployed!"

    local conn_lines=(
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}"
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${HY2_PORT}${NC}"
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${HY2_PASS}${NC}"
    )
    [[ -n "${HY2_OBFS_PASS:-}" ]] && conn_lines+=("${GREEN}▶${NC} ${WHITE}Obfs PW:  ${BRIGHT_YELLOW}${HY2_OBFS_PASS}${NC}")
    conn_lines+=(
        ""
        "${GREEN}▶${NC} ${WHITE}Client bandwidth hint:${NC}"
        "  ${GRAY}Download: ${HY2_DOWN} Mbps / Upload: ${HY2_UP} Mbps${NC}"
    )
    info_box "CONNECTION DETAILS" "${conn_lines[@]}"

    info_box "CLIENT CONFIGURATION (config.yaml)" \
        "${GRAY}server: ${SERVER_IP}:${HY2_PORT}${NC}" \
        "${GRAY}auth: ${HY2_PASS}${NC}" \
        "${GRAY}bandwidth:${NC}" \
        "${GRAY}  down: ${HY2_DOWN} mbps${NC}" \
        "${GRAY}  up: ${HY2_UP} mbps${NC}" \
        "${GRAY}tls:${NC}" \
        "${GRAY}  insecure: true  # self-signed cert${NC}" \
        "${GRAY}socks5:${NC}" \
        "${GRAY}  listen: 127.0.0.1:1080${NC}" \
        "${GRAY}http:${NC}" \
        "${GRAY}  listen: 127.0.0.1:8080${NC}"

    info_box "CLIENT APPS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Shadowrocket, Stash${NC}" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}NekoBox, Matsuri, Hiddify${NC}" \
        "${BRIGHT_YELLOW}💻 Desktop:${NC} ${WHITE}Nekoray, Hiddify, hysteria2 CLI${NC}" \
        "${BRIGHT_YELLOW}🐧 CLI:${NC} ${GRAY}hysteria client -c config.yaml${NC}"

    log "INFO" "Hysteria 2 installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# REALITY/XTLS
# ═══════════════════════════════════════════════════════════════════════════════

install_reality() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🌀  ${BOLD}${WHITE}XRAY REALITY DEPLOYMENT${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ UNDETECTABLE - NEXT-GEN STEALTH${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT REALITY" \
        "${GREEN}▶${NC} ${WHITE}Mimics TLS handshake of REAL websites${NC}" \
        "${GREEN}▶${NC} ${WHITE}No need for a domain or certificate!${NC}" \
        "${GREEN}▶${NC} ${WHITE}Undetectable by current DPI systems${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses Xray-core with VLESS protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Near zero-overhead encryption (XTLS)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Passes active probing tests${NC}" \
        "" \
        "${BRIGHT_RED}🔥 THE MOST ADVANCED anti-censorship protocol available${NC}" \
        "${BRIGHT_RED}   Proven effective against China GFW & Iran DPI${NC}"

    if ! confirm_prompt "Deploy REALITY?"; then return; fi
    echo ""

    styled_prompt "Port" "443"
    read -r REALITY_PORT
    REALITY_PORT=${REALITY_PORT:-443}
    check_port "$REALITY_PORT" tcp || return 1

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select a website to mimic (SNI/dest):${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}www.microsoft.com ${GRAY}(recommended)${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}www.apple.com${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}www.google.com${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}www.cloudflare.com${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}dl.google.com${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}www.yahoo.com${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Custom domain${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${GRAY}Choose a site that is NOT blocked in your region${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    styled_prompt "Choose" "1"
    read -r sni_choice
    case $sni_choice in
        2) REALITY_SNI="www.apple.com" ;;
        3) REALITY_SNI="www.google.com" ;;
        4) REALITY_SNI="www.cloudflare.com" ;;
        5) REALITY_SNI="dl.google.com" ;;
        6) REALITY_SNI="www.yahoo.com" ;;
        7) styled_prompt "Enter domain (e.g., www.example.com)"; read -r REALITY_SNI ;;
        *) REALITY_SNI="www.microsoft.com" ;;
    esac

    echo ""
    REALITY_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}UUID: ${BRIGHT_YELLOW}${REALITY_UUID}${NC}"

    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing Xray-core...${NC}"
    (
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Installing Xray-core"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Generating REALITY keys & configuration...${NC}"
    (
        # Generate REALITY key pair
        REALITY_KEYS=$(/usr/local/bin/xray x25519 2>/dev/null)
        REALITY_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep "Private" | awk '{print $3}')
        REALITY_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep "Public" | awk '{print $3}')
        REALITY_SHORT_ID=$(openssl rand -hex 8)

        # Save keys for display later
        echo "$REALITY_PRIVATE_KEY" > /etc/xray-reality-private.key
        echo "$REALITY_PUBLIC_KEY" > /etc/xray-reality-public.key
        echo "$REALITY_SHORT_ID" > /etc/xray-reality-shortid

        mkdir -p /usr/local/etc/xray
        cat > /usr/local/etc/xray/config.json << REALITYEOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "listen": "0.0.0.0",
        "port": ${REALITY_PORT},
        "protocol": "vless",
        "settings": {
            "clients": [{
                "id": "${REALITY_UUID}",
                "flow": "xtls-rprx-vision"
            }],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
                "show": false,
                "dest": "${REALITY_SNI}:443",
                "xver": 0,
                "serverNames": ["${REALITY_SNI}"],
                "privateKey": "${REALITY_PRIVATE_KEY}",
                "shortIds": ["${REALITY_SHORT_ID}"]
            }
        },
        "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"]
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "tag": "direct"
    }, {
        "protocol": "blackhole",
        "tag": "block"
    }]
}
REALITYEOF
        sleep 1
    ) &
    spinner $! "Generating REALITY configuration"

    # Read back the keys
    REALITY_PRIVATE_KEY=$(cat /etc/xray-reality-private.key 2>/dev/null)
    REALITY_PUBLIC_KEY=$(cat /etc/xray-reality-public.key 2>/dev/null)
    REALITY_SHORT_ID=$(cat /etc/xray-reality-shortid 2>/dev/null)

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting Xray REALITY...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$REALITY_PORT"/tcp > /dev/null 2>&1; fi
        if command -v firewall-cmd &>/dev/null; then firewall-cmd --permanent --add-port="$REALITY_PORT"/tcp > /dev/null 2>&1; firewall-cmd --reload > /dev/null 2>&1; fi
        systemctl enable xray > /dev/null 2>&1
        systemctl restart xray > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting Xray REALITY"

    echo ""
    success_msg "REALITY Deployed!"

    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Protocol:   ${BRIGHT_GREEN}VLESS + REALITY${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:     ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:       ${BRIGHT_GREEN}${REALITY_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}UUID:       ${BRIGHT_YELLOW}${REALITY_UUID}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Flow:       ${BRIGHT_GREEN}xtls-rprx-vision${NC}" \
        "${GREEN}▶${NC} ${WHITE}Security:   ${BRIGHT_GREEN}reality${NC}" \
        "${GREEN}▶${NC} ${WHITE}SNI:        ${BRIGHT_GREEN}${REALITY_SNI}${NC}" \
        "${GREEN}▶${NC} ${WHITE}PublicKey:  ${BRIGHT_YELLOW}${REALITY_PUBLIC_KEY}${NC}" \
        "${GREEN}▶${NC} ${WHITE}ShortId:    ${BRIGHT_YELLOW}${REALITY_SHORT_ID}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Fingerprint:${BRIGHT_GREEN}chrome${NC}"

    info_box "VLESS SHARE LINK" \
        "${GRAY}vless://${REALITY_UUID}@${SERVER_IP}:${REALITY_PORT}?${NC}" \
        "${GRAY}  encryption=none&flow=xtls-rprx-vision&${NC}" \
        "${GRAY}  security=reality&sni=${REALITY_SNI}&${NC}" \
        "${GRAY}  fp=chrome&pbk=${REALITY_PUBLIC_KEY}&${NC}" \
        "${GRAY}  sid=${REALITY_SHORT_ID}&type=tcp${NC}" \
        "${GRAY}  #VPNBlast-REALITY${NC}"

    info_box "CLIENT APPS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Shadowrocket, V2Box, Streisand, FoXray${NC}" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}V2RayNG, NekoBox, Hiddify${NC}" \
        "${BRIGHT_YELLOW}💻 Desktop:${NC} ${WHITE}Nekoray, Hiddify, V2RayN${NC}" \
        "" \
        "${BRIGHT_RED}⚠️  Use 'chrome' fingerprint in client settings${NC}"

    log "INFO" "REALITY installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# WIREGUARD + OBFUSCATION
# ═══════════════════════════════════════════════════════════════════════════════

install_wireguard_obfs() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🪱  ${BOLD}${WHITE}WIREGUARD + OBFUSCATION${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}★ SECURE${NC} ${BRIGHT_RED}+ STEALTH${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT WG + OBFUSCATION" \
        "${GREEN}▶${NC} ${WHITE}WireGuard's speed + tunnel obfuscation${NC}" \
        "${GREEN}▶${NC} ${WHITE}Wraps WG traffic in WebSocket/TCP${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses wstunnel to disguise as HTTPS${NC}" \
        "${GREEN}▶${NC} ${WHITE}Bypasses DPI that blocks WireGuard${NC}" \
        "${GREEN}▶${NC} ${WHITE}Maintains WireGuard's performance${NC}" \
        "" \
        "${BRIGHT_YELLOW}CONCEPT: WireGuard → wstunnel → Port 443 (looks like HTTPS)${NC}"

    echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}This will install WireGuard first, then add wstunnel.${NC}"
    echo ""

    if ! confirm_prompt "Deploy WireGuard + Obfuscation?"; then return; fi
    echo ""

    # First install WireGuard
    echo -e "  ${BRIGHT_CYAN}[Phase 1]${NC} ${WHITE}Installing WireGuard (standard)...${NC}"
    echo ""

    # Quick WG install
    styled_prompt "WireGuard port (internal, hidden behind tunnel)" "51820"
    read -r WG_PORT
    WG_PORT=${WG_PORT:-51820}

    styled_prompt "WebSocket tunnel port (public-facing)" "443"
    read -r WS_PORT
    WS_PORT=${WS_PORT:-443}
    check_port "$WS_PORT" tcp || return 1

    styled_prompt "Client name" "client1"
    read -r WG_CLIENT_NAME
    WG_CLIENT_NAME=${WG_CLIENT_NAME:-"client1"}

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    # Install WireGuard
    echo -e "  ${BRIGHT_CYAN}[Step 1/5]${NC} ${WHITE}Installing WireGuard...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq wireguard wireguard-tools qrencode > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y -q epel-release wireguard-tools qrencode > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm wireguard-tools qrencode > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing WireGuard"

    echo -e "  ${BRIGHT_CYAN}[Step 2/5]${NC} ${WHITE}Setting up WireGuard config...${NC}"
    (
        mkdir -p /etc/wireguard /etc/wireguard/clients
        chmod 700 /etc/wireguard

        wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
        chmod 600 /etc/wireguard/server_private.key

        SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
        SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

        client_private=$(wg genkey)
        client_public=$(echo "$client_private" | wg pubkey)
        client_psk=$(wg genpsk)

        # Server config - listens on localhost only (wstunnel forwards to it)
        cat > /etc/wireguard/wg0.conf << WGEOF
[Interface]
Address = 10.66.66.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
MTU = 1280
PostUp = iptables -I FORWARD -i wg0 -j ACCEPT; iptables -I FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_NIC} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_NIC} -j MASQUERADE

[Peer]
PublicKey = ${client_public}
PresharedKey = ${client_psk}
AllowedIPs = 10.66.66.2/32
WGEOF

        # Client config
        cat > "/etc/wireguard/clients/${WG_CLIENT_NAME}.conf" << CLIENTEOF
[Interface]
PrivateKey = ${client_private}
Address = 10.66.66.2/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${client_psk}
Endpoint = 127.0.0.1:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
CLIENTEOF

        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

        systemctl enable wg-quick@wg0 > /dev/null 2>&1
        systemctl start wg-quick@wg0 > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Configuring WireGuard"

    echo -e "  ${BRIGHT_CYAN}[Step 3/5]${NC} ${WHITE}Installing wstunnel...${NC}"
    (
        # Download latest wstunnel
        local arch
        arch=$(uname -m)
        [[ "$arch" == "x86_64" ]] && arch="amd64"
        [[ "$arch" == "aarch64" ]] && arch="arm64"

        local ws_url
        ws_url=$(curl -s https://api.github.com/repos/erebe/wstunnel/releases/latest | \
            grep "browser_download_url.*linux.*${arch}" | head -1 | cut -d'"' -f4)

        if [[ -n "$ws_url" ]]; then
            wget -q "$ws_url" -O /tmp/wstunnel.tar.gz 2>/dev/null || curl -sL "$ws_url" -o /tmp/wstunnel.tar.gz
            tar xzf /tmp/wstunnel.tar.gz -C /usr/local/bin/ 2>/dev/null
            chmod +x /usr/local/bin/wstunnel
        fi
        sleep 1
    ) &
    spinner $! "Installing wstunnel"

    echo -e "  ${BRIGHT_CYAN}[Step 4/5]${NC} ${WHITE}Creating wstunnel service...${NC}"
    (
        cat > /etc/systemd/system/wstunnel.service << WSTEOF
[Unit]
Description=wstunnel WebSocket Tunnel for WireGuard
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/wstunnel server --restrict-to 127.0.0.1:${WG_PORT} ws://0.0.0.0:${WS_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
WSTEOF

        systemctl daemon-reload
        systemctl enable wstunnel > /dev/null 2>&1
        systemctl start wstunnel > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Creating wstunnel service"

    echo -e "  ${BRIGHT_CYAN}[Step 5/5]${NC} ${WHITE}Configuring firewall...${NC}"
    (
        if command -v ufw &>/dev/null; then
            ufw allow "$WS_PORT"/tcp > /dev/null 2>&1
        fi
        if command -v firewall-cmd &>/dev/null; then
            firewall-cmd --permanent --add-port="$WS_PORT"/tcp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi
        sleep 1
    ) &
    spinner $! "Configuring firewall"

    echo ""
    success_msg "WireGuard + Obfuscation Deployed!"

    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:        ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}WS Tunnel Port:${BRIGHT_GREEN}${WS_PORT} (TCP)${NC}" \
        "${GREEN}▶${NC} ${WHITE}WG Port:       ${BRIGHT_GREEN}${WG_PORT} (internal)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Client config: ${BRIGHT_GREEN}/etc/wireguard/clients/${WG_CLIENT_NAME}.conf${NC}"

    info_box "CLIENT SETUP (2 steps)" \
        "${BRIGHT_YELLOW}Step 1: Run wstunnel client on your device:${NC}" \
        "  ${GRAY}wstunnel client -L udp://127.0.0.1:${WG_PORT}:127.0.0.1:${WG_PORT} ws://${SERVER_IP}:${WS_PORT}${NC}" \
        "" \
        "${BRIGHT_YELLOW}Step 2: Connect WireGuard to localhost:${NC}" \
        "  ${GRAY}Use the client config with Endpoint = 127.0.0.1:${WG_PORT}${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Android/iOS:${NC}" \
        "  ${WHITE}Use apps like WSTunnel + WireGuard together${NC}" \
        "  ${WHITE}Or use NekoBox/Hiddify with WG+WS transport${NC}"

    log "INFO" "WireGuard+obfuscation installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# SOFTETHER VPN
# ═══════════════════════════════════════════════════════════════════════════════

install_softether() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🌐  ${BOLD}${WHITE}SOFTETHER VPN DEPLOYMENT${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT SOFTETHER" \
        "${GREEN}▶${NC} ${WHITE}Multi-protocol VPN (SSL, L2TP, OpenVPN, SSTP)${NC}" \
        "${GREEN}▶${NC} ${WHITE}NAT traversal built-in${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can disguise as HTTPS on port 443${NC}" \
        "${GREEN}▶${NC} ${WHITE}GUI management tool available${NC}"

    if ! confirm_prompt "Deploy SoftEther VPN?"; then return; fi
    echo ""

    styled_prompt "Admin password" ""
    read -rs SE_ADMIN_PASS
    echo ""
    [[ -z "$SE_ADMIN_PASS" ]] && SE_ADMIN_PASS=$(openssl rand -base64 16) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${SE_ADMIN_PASS}${NC}"

    styled_prompt "Hub name" "VPN"
    read -r SE_HUB
    SE_HUB=${SE_HUB:-"VPN"}

    styled_prompt "VPN username" "vpnuser"
    read -r SE_USER
    SE_USER=${SE_USER:-"vpnuser"}

    styled_prompt "VPN user password" ""
    read -rs SE_USER_PASS
    echo ""
    [[ -z "$SE_USER_PASS" ]] && SE_USER_PASS=$(openssl rand -base64 12) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${SE_USER_PASS}${NC}"

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/4]${NC} ${WHITE}Installing build dependencies...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq build-essential wget curl gcc make libreadline-dev libssl-dev libncurses5-dev zlib1g-dev > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf groupinstall -y -q "Development Tools" > /dev/null 2>&1; dnf install -y -q readline-devel openssl-devel ncurses-devel wget curl > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm base-devel readline openssl ncurses wget curl > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing build dependencies"

    echo -e "  ${BRIGHT_CYAN}[Step 2/4]${NC} ${WHITE}Downloading & compiling SoftEther...${NC}"
    (
        cd /tmp || exit
        SE_URL="https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz"
        wget -q "$SE_URL" -O softether-vpnserver.tar.gz 2>/dev/null || curl -sL "$SE_URL" -o softether-vpnserver.tar.gz
        if [ ! -f softether-vpnserver.tar.gz ]; then exit 1; fi
        tar xzf softether-vpnserver.tar.gz > /dev/null 2>&1
        cd vpnserver || exit 1
        echo -e "1\n1\n1" | make > /dev/null 2>&1
        cd ..
        rm -rf /usr/local/vpnserver
        mv /tmp/vpnserver /usr/local/vpnserver
        chmod 600 /usr/local/vpnserver/*
        chmod 700 /usr/local/vpnserver/vpnserver /usr/local/vpnserver/vpncmd
        sleep 1
    ) &
    spinner $! "Compiling SoftEther (may take a while)" || return 1

    echo -e "  ${BRIGHT_CYAN}[Step 3/4]${NC} ${WHITE}Creating service...${NC}"
    (
        cat > /etc/systemd/system/softether-vpnserver.service << SEEOF
[Unit]
Description=SoftEther VPN Server
After=network.target
[Service]
Type=forking
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
Restart=on-failure
[Install]
WantedBy=multi-user.target
SEEOF
        systemctl daemon-reload; systemctl enable softether-vpnserver > /dev/null 2>&1; systemctl start softether-vpnserver > /dev/null 2>&1
        sleep 2
    ) &
    spinner $! "Creating & starting service"

    echo -e "  ${BRIGHT_CYAN}[Step 4/4]${NC} ${WHITE}Configuring hub & users...${NC}"
    (
        VPNCMD="/usr/local/vpnserver/vpncmd"
        $VPNCMD localhost /SERVER /CMD ServerPasswordSet "$SE_ADMIN_PASS" > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /CMD HubCreate "$SE_HUB" /PASSWORD:"$SE_ADMIN_PASS" > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD UserCreate "$SE_USER" /GROUP:none /REALNAME:none /NOTE:none > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD UserPasswordSet "$SE_USER" /PASSWORD:"$SE_USER_PASS" > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD SecureNatEnable > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:vpnblast /DEFAULTHUB:"$SE_HUB" > /dev/null 2>&1
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Configuring hub, users & protocols"

    echo ""
    success_msg "SoftEther VPN Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:    ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Admin PW:  ${BRIGHT_YELLOW}${SE_ADMIN_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Hub:       ${BRIGHT_GREEN}${SE_HUB}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username:  ${BRIGHT_GREEN}${SE_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password:  ${BRIGHT_YELLOW}${SE_USER_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}L2TP PSK:  ${BRIGHT_YELLOW}vpnblast${NC}" \
        "${GREEN}▶${NC} ${WHITE}Mgmt:      ${GRAY}${SERVER_IP}:5555 (SoftEther Manager)${NC}"

    log "INFO" "SoftEther installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOR BRIDGE
# ═══════════════════════════════════════════════════════════════════════════════

install_tor_bridge() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🧅  ${BOLD}${WHITE}TOR BRIDGE DEPLOYMENT${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_MAGENTA}★ MAXIMUM ANONYMITY${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT TOR BRIDGES" \
        "${GREEN}▶${NC} ${WHITE}Onion routing for maximum anonymity${NC}" \
        "${GREEN}▶${NC} ${WHITE}Bridges help users in censored regions${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses obfs4 pluggable transport${NC}" \
        "${GREEN}▶${NC} ${WHITE}Traffic looks like random data${NC}" \
        "" \
        "${BRIGHT_RED}⚠️  WARNING: Tor is SLOW but offers the strongest anonymity${NC}" \
        "${BRIGHT_YELLOW}   This sets up a Tor BRIDGE relay, not an exit node${NC}"

    if ! confirm_prompt "Deploy Tor Bridge?"; then return; fi
    echo ""

    styled_prompt "OR Port" "9001"
    read -r TOR_OR_PORT
    TOR_OR_PORT=${TOR_OR_PORT:-9001}
    check_port "$TOR_OR_PORT" tcp || return 1

    styled_prompt "obfs4 Port" "9002"
    read -r TOR_OBFS_PORT
    TOR_OBFS_PORT=${TOR_OBFS_PORT:-9002}
    check_port "$TOR_OBFS_PORT" tcp || return 1

    styled_prompt "Contact email (for Tor directory)" "nobody@example.com"
    read -r TOR_EMAIL
    TOR_EMAIL=${TOR_EMAIL:-"nobody@example.com"}

    styled_prompt "Bridge nickname" "VPNBlastBridge"
    read -r TOR_NICK
    TOR_NICK=${TOR_NICK:-"VPNBlastBridge"}

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing Tor & obfs4proxy...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1
                apt-get install -y -qq tor obfs4proxy > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf install -y -q epel-release > /dev/null 2>&1
                dnf install -y -q tor golang-github-nickcalyx-obfs4proxy > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -S --noconfirm tor obfs4proxy > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Installing Tor & obfs4proxy"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Configuring Tor bridge...${NC}"
    (
        cat > /etc/tor/torrc << TOREOF
BridgeRelay 1
ORPort ${TOR_OR_PORT}
ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy
ServerTransportListenAddr obfs4 0.0.0.0:${TOR_OBFS_PORT}
ExtORPort auto
ContactInfo ${TOR_EMAIL}
Nickname ${TOR_NICK}
Log notice file /var/log/tor/notices.log
TOREOF
        sleep 1
    ) &
    spinner $! "Writing Tor configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting Tor bridge...${NC}"
    (
        if command -v ufw &>/dev/null; then
            ufw allow "$TOR_OR_PORT"/tcp > /dev/null 2>&1
            ufw allow "$TOR_OBFS_PORT"/tcp > /dev/null 2>&1
        fi
        systemctl enable tor > /dev/null 2>&1
        systemctl restart tor > /dev/null 2>&1
        sleep 3
    ) &
    spinner $! "Starting Tor bridge"

    echo ""
    success_msg "Tor Bridge Deployed!"

    # Get bridge line
    local bridge_line=""
    if [[ -f /var/lib/tor/pt_state/obfs4_bridgeline.txt ]]; then
        bridge_line=$(grep "Bridge" /var/lib/tor/pt_state/obfs4_bridgeline.txt | head -1)
    fi

    info_box "BRIDGE DETAILS" \
        "${GREEN}▶${NC} ${WHITE}OR Port:    ${BRIGHT_GREEN}${TOR_OR_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}obfs4 Port: ${BRIGHT_GREEN}${TOR_OBFS_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Nickname:   ${BRIGHT_GREEN}${TOR_NICK}${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}Bridge line (share this):${NC}" \
        "  ${GRAY}${bridge_line:-Check /var/lib/tor/pt_state/obfs4_bridgeline.txt}${NC}"

    info_box "HOW TO USE" \
        "${WHITE}1. Open Tor Browser${NC}" \
        "${WHITE}2. Settings → Connection → Bridges${NC}" \
        "${WHITE}3. Select 'Provide a bridge'${NC}" \
        "${WHITE}4. Paste the bridge line above${NC}"

    log "INFO" "Tor bridge installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPENCONNECT (ocserv)
# ═══════════════════════════════════════════════════════════════════════════════

install_openconnect() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🐚  ${BOLD}${WHITE}OPENCONNECT (ocserv) DEPLOYMENT${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT OPENCONNECT" \
        "${GREEN}▶${NC} ${WHITE}Compatible with Cisco AnyConnect${NC}" \
        "${GREEN}▶${NC} ${WHITE}SSL-based VPN (port 443)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Works through corporate firewalls${NC}" \
        "${GREEN}▶${NC} ${WHITE}Native client on most platforms${NC}" \
        "${GREEN}▶${NC} ${WHITE}Often unblocked (looks like Cisco traffic)${NC}"

    if ! confirm_prompt "Deploy OpenConnect?"; then return; fi
    echo ""

    styled_prompt "Username" "vpnuser"
    read -r OC_USER
    OC_USER=${OC_USER:-"vpnuser"}

    styled_prompt "Password (leave empty to auto-generate)"
    read -rs OC_PASS
    echo ""
    [[ -z "$OC_PASS" ]] && OC_PASS=$(openssl rand -base64 16) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${OC_PASS}${NC}"

    styled_prompt "Port" "443"
    read -r OC_PORT
    OC_PORT=${OC_PORT:-443}
    check_port "$OC_PORT" tcp || return 1

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/4]${NC} ${WHITE}Installing ocserv...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq ocserv gnutls-bin > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y -q epel-release > /dev/null 2>&1; dnf install -y -q ocserv gnutls-utils > /dev/null 2>&1 ;;
            arch|manjaro) pacman -S --noconfirm ocserv gnutls > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Installing ocserv"

    echo -e "  ${BRIGHT_CYAN}[Step 2/4]${NC} ${WHITE}Generating certificates...${NC}"
    (
        mkdir -p /etc/ocserv/ssl
        # CA
        certtool --generate-privkey --outfile /etc/ocserv/ssl/ca-key.pem > /dev/null 2>&1
        cat > /tmp/ca.tmpl << CAEOF
cn = "VPN Blast CA"
organization = "VPN Blast"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key
CAEOF
        certtool --generate-self-signed --load-privkey /etc/ocserv/ssl/ca-key.pem --template /tmp/ca.tmpl --outfile /etc/ocserv/ssl/ca-cert.pem > /dev/null 2>&1

        # Server cert
        certtool --generate-privkey --outfile /etc/ocserv/ssl/server-key.pem > /dev/null 2>&1
        cat > /tmp/server.tmpl << SRVEOF
cn = "${SERVER_IP}"
organization = "VPN Blast"
serial = 2
expiration_days = 3650
signing_key
encryption_key
tls_www_server
dns_name = "${SERVER_IP}"
ip_address = "${SERVER_IP}"
SRVEOF
        certtool --generate-certificate --load-privkey /etc/ocserv/ssl/server-key.pem --load-ca-certificate /etc/ocserv/ssl/ca-cert.pem --load-ca-privkey /etc/ocserv/ssl/ca-key.pem --template /tmp/server.tmpl --outfile /etc/ocserv/ssl/server-cert.pem > /dev/null 2>&1
        rm -f /tmp/ca.tmpl /tmp/server.tmpl
        sleep 1
    ) &
    spinner $! "Generating SSL certificates"

    echo -e "  ${BRIGHT_CYAN}[Step 3/4]${NC} ${WHITE}Configuring ocserv...${NC}"
    (
        # Create user
        echo "$OC_PASS" | ocpasswd -c /etc/ocserv/ocpasswd "$OC_USER" > /dev/null 2>&1

        cat > /etc/ocserv/ocserv.conf << OCEOF
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
tcp-port = ${OC_PORT}
udp-port = ${OC_PORT}
server-cert = /etc/ocserv/ssl/server-cert.pem
server-key = /etc/ocserv/ssl/server-key.pem
ca-cert = /etc/ocserv/ssl/ca-cert.pem
max-clients = 128
max-same-clients = 2
try-mtu-discovery = true
default-domain = vpnblast.local
ipv4-network = 10.20.30.0
ipv4-netmask = 255.255.255.0
dns = 1.1.1.1
dns = 1.0.0.1
route = default
cisco-client-compat = true
dtls-legacy = true
OCEOF

        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        iptables -t nat -A POSTROUTING -s 10.20.30.0/24 -o "$SERVER_NIC" -j MASQUERADE 2>/dev/null
        sleep 1
    ) &
    spinner $! "Configuring ocserv"

    echo -e "  ${BRIGHT_CYAN}[Step 4/4]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$OC_PORT" > /dev/null 2>&1; fi
        systemctl enable ocserv > /dev/null 2>&1
        systemctl restart ocserv > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting OpenConnect"

    echo ""
    success_msg "OpenConnect Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${OC_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username: ${BRIGHT_GREEN}${OC_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${OC_PASS}${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Apps:${NC} ${WHITE}Cisco AnyConnect, OpenConnect${NC}" \
        "${BRIGHT_YELLOW}🐧 CLI:${NC} ${GRAY}sudo openconnect ${SERVER_IP}:${OC_PORT}${NC}"

    log "INFO" "OpenConnect installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# TUIC
# ═══════════════════════════════════════════════════════════════════════════════

install_tuic() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🔷  ${BOLD}${WHITE}TUIC v5 DEPLOYMENT${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT TUIC" \
        "${GREEN}▶${NC} ${WHITE}QUIC-based proxy protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Low latency, high throughput${NC}" \
        "${GREEN}▶${NC} ${WHITE}0-RTT handshake support${NC}" \
        "${GREEN}▶${NC} ${WHITE}Built-in multiplexing${NC}" \
        "${GREEN}▶${NC} ${WHITE}Good for censored networks${NC}"

    if ! confirm_prompt "Deploy TUIC?"; then return; fi
    echo ""

    styled_prompt "Port" "443"
    read -r TUIC_PORT
    TUIC_PORT=${TUIC_PORT:-443}
    check_port "$TUIC_PORT" udp || return 1

    TUIC_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    TUIC_PASS=$(openssl rand -base64 16)
    echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}UUID: ${BRIGHT_YELLOW}${TUIC_UUID}${NC}"
    echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${TUIC_PASS}${NC}"

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing TUIC...${NC}"
    (
        local arch=$(uname -m)
        [[ "$arch" == "x86_64" ]] && arch="x86_64-unknown-linux-gnu"
        [[ "$arch" == "aarch64" ]] && arch="aarch64-unknown-linux-gnu"

        local tuic_url
        tuic_url=$(curl -s https://api.github.com/repos/EAimTY/tuic/releases/latest | grep "browser_download_url.*${arch}" | head -1 | cut -d'"' -f4)

        if [[ -n "$tuic_url" ]]; then
            wget -q "$tuic_url" -O /usr/local/bin/tuic-server 2>/dev/null || curl -sL "$tuic_url" -o /usr/local/bin/tuic-server
            chmod +x /usr/local/bin/tuic-server
        fi
        sleep 1
    ) &
    spinner $! "Installing TUIC"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Creating configuration...${NC}"
    (
        mkdir -p /etc/tuic

        openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -nodes -x509 \
            -subj "/CN=bing.com" -keyout /etc/tuic/server.key -out /etc/tuic/server.crt > /dev/null 2>&1

        cat > /etc/tuic/config.json << TUICEOF
{
    "server": "[::]:${TUIC_PORT}",
    "users": {"${TUIC_UUID}": "${TUIC_PASS}"},
    "certificate": "/etc/tuic/server.crt",
    "private_key": "/etc/tuic/server.key",
    "congestion_control": "bbr",
    "alpn": ["h3", "spdy/3.1"],
    "log_level": "warn"
}
TUICEOF

        cat > /etc/systemd/system/tuic.service << TUICSVC
[Unit]
Description=TUIC Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/tuic-server -c /etc/tuic/config.json
Restart=on-failure
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
TUICSVC
        sleep 1
    ) &
    spinner $! "Creating configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$TUIC_PORT"/udp > /dev/null 2>&1; fi
        systemctl daemon-reload; systemctl enable tuic > /dev/null 2>&1; systemctl start tuic > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting TUIC"

    echo ""
    success_msg "TUIC Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${TUIC_PORT} (UDP)${NC}" \
        "${GREEN}▶${NC} ${WHITE}UUID:     ${BRIGHT_YELLOW}${TUIC_UUID}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${TUIC_PASS}${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Apps:${NC} ${WHITE}NekoBox, Hiddify, Shadowrocket${NC}"

    log "INFO" "TUIC installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# NAIVEPROXY
# ═══════════════════════════════════════════════════════════════════════════════

install_naiveproxy() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🛸  ${BOLD}${WHITE}NAIVEPROXY DEPLOYMENT${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}★ CHROME NETWORK STACK MIMICRY${NC}                          ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT NAIVEPROXY" \
        "${GREEN}▶${NC} ${WHITE}Uses Chromium's network stack${NC}" \
        "${GREEN}▶${NC} ${WHITE}Traffic indistinguishable from Chrome${NC}" \
        "${GREEN}▶${NC} ${WHITE}Resists traffic analysis & active probing${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses Caddy as frontend server${NC}" \
        "${GREEN}▶${NC} ${WHITE}Extremely difficult to detect${NC}" \
        "" \
        "${BRIGHT_RED}🔥 One of the most stealth proxies available${NC}"

    if ! confirm_prompt "Deploy NaiveProxy?"; then return; fi
    echo ""

    styled_prompt "Port" "443"
    read -r NP_PORT
    NP_PORT=${NP_PORT:-443}
    check_port "$NP_PORT" tcp || return 1

    styled_prompt "Username" "naiveuser"
    read -r NP_USER
    NP_USER=${NP_USER:-"naiveuser"}

    styled_prompt "Password (leave empty to auto-generate)"
    read -rs NP_PASS
    echo ""
    [[ -z "$NP_PASS" ]] && NP_PASS=$(openssl rand -base64 16) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${NP_PASS}${NC}"

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing Caddy with forwardproxy...${NC}"
    (
        local arch=$(uname -m)
        [[ "$arch" == "x86_64" ]] && arch="amd64"
        [[ "$arch" == "aarch64" ]] && arch="arm64"

        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1; apt-get install -y -qq golang > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf install -y -q golang > /dev/null 2>&1 ;;
        esac

        export GOPATH=$HOME/go
        go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest > /dev/null 2>&1
        $HOME/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive > /dev/null 2>&1
        [[ -f caddy ]] && mv caddy /usr/local/bin/caddy-naive
        chmod +x /usr/local/bin/caddy-naive 2>/dev/null

        if [[ ! -f /usr/local/bin/caddy-naive ]]; then
            curl -sL "https://caddyserver.com/api/download?os=linux&arch=${arch}" -o /usr/local/bin/caddy-naive 2>/dev/null
            chmod +x /usr/local/bin/caddy-naive
        fi
        sleep 1
    ) &
    spinner $! "Installing Caddy with NaiveProxy"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Configuring NaiveProxy...${NC}"
    (
        mkdir -p /etc/naiveproxy

        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/CN=${SERVER_IP}" \
            -keyout /etc/naiveproxy/key.pem \
            -out /etc/naiveproxy/cert.pem > /dev/null 2>&1

        cat > /etc/naiveproxy/Caddyfile << NPEOF
{
    order forward_proxy before file_server
    log {
        level ERROR
    }
}
:${NP_PORT}, ${SERVER_IP}:${NP_PORT} {
    tls /etc/naiveproxy/cert.pem /etc/naiveproxy/key.pem
    forward_proxy {
        basic_auth ${NP_USER} ${NP_PASS}
        hide_ip
        hide_via
        probe_resistance
    }
    file_server {
        root /var/www/html
    }
}
NPEOF

        mkdir -p /var/www/html
        echo "<h1>Welcome</h1>" > /var/www/html/index.html

        cat > /etc/systemd/system/naiveproxy.service << NPSVC
[Unit]
Description=NaiveProxy (Caddy)
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/caddy-naive run --config /etc/naiveproxy/Caddyfile
Restart=on-failure
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
NPSVC
        sleep 1
    ) &
    spinner $! "Configuring NaiveProxy"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$NP_PORT"/tcp > /dev/null 2>&1; fi
        systemctl daemon-reload; systemctl enable naiveproxy > /dev/null 2>&1; systemctl start naiveproxy > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting NaiveProxy"

    echo ""
    success_msg "NaiveProxy Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}https://${SERVER_IP}:${NP_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username: ${BRIGHT_GREEN}${NP_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${NP_PASS}${NC}" \
        "" \
        "${BRIGHT_YELLOW}Client config:${NC}" \
        "  ${GRAY}naive+https://${NP_USER}:${NP_PASS}@${SERVER_IP}:${NP_PORT}${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Apps:${NC} ${WHITE}NekoBox, Hiddify, Shadowrocket${NC}"

    log "INFO" "NaiveProxy installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# BROOK
# ═══════════════════════════════════════════════════════════════════════════════

install_brook() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🌉  ${BOLD}${WHITE}BROOK DEPLOYMENT${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT BROOK" \
        "${GREEN}▶${NC} ${WHITE}Simple cross-platform proxy/VPN${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports brook, wsbrook, wssbrook${NC}" \
        "${GREEN}▶${NC} ${WHITE}Easy to set up and use${NC}" \
        "${GREEN}▶${NC} ${WHITE}Built-in DNS over HTTPS${NC}" \
        "${GREEN}▶${NC} ${WHITE}WebSocket mode for firewall bypass${NC}"

    if ! confirm_prompt "Deploy Brook?"; then return; fi
    echo ""

    styled_prompt "Password" ""
    read -rs BROOK_PASS
    echo ""
    [[ -z "$BROOK_PASS" ]] && BROOK_PASS=$(openssl rand -base64 16) && echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${BROOK_PASS}${NC}"

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select mode:${NC}                                              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}brook server   ${GRAY}(standard, fast)${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}wsbrook server ${GRAY}(WebSocket, stealth)${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    styled_prompt "Choose" "1"
    read -r brook_mode
    [[ "$brook_mode" == "2" ]] && BROOK_MODE="wsserver" || BROOK_MODE="server"

    local default_port="9999"
    [[ "$BROOK_MODE" == "wsserver" ]] && default_port="443"
    styled_prompt "Port" "$default_port"
    read -r BROOK_PORT
    BROOK_PORT=${BROOK_PORT:-$default_port}
    check_port "$BROOK_PORT" tcp || return 1

    echo ""
    if ! confirm_prompt "Proceed?"; then return; fi
    echo ""

    echo -e "  ${BRIGHT_CYAN}[Step 1/2]${NC} ${WHITE}Installing Brook...${NC}"
    (
        curl -L https://github.com/txthinking/brook/releases/latest/download/brook_linux_amd64 -o /usr/local/bin/brook > /dev/null 2>&1
        chmod +x /usr/local/bin/brook

        local exec_cmd
        if [[ "$BROOK_MODE" == "wsserver" ]]; then
            exec_cmd="/usr/local/bin/brook wsserver --listen :${BROOK_PORT} --password ${BROOK_PASS}"
        else
            exec_cmd="/usr/local/bin/brook server --listen :${BROOK_PORT} --password ${BROOK_PASS}"
        fi

        cat > /etc/systemd/system/brook.service << BROOKSVC
[Unit]
Description=Brook Server
After=network.target
[Service]
Type=simple
ExecStart=${exec_cmd}
Restart=on-failure
LimitNOFILE=32768
[Install]
WantedBy=multi-user.target
BROOKSVC
        sleep 1
    ) &
    spinner $! "Installing Brook"

    echo -e "  ${BRIGHT_CYAN}[Step 2/2]${NC} ${WHITE}Starting service...${NC}"
    (
        if command -v ufw &>/dev/null; then ufw allow "$BROOK_PORT" > /dev/null 2>&1; fi
        systemctl daemon-reload; systemctl enable brook > /dev/null 2>&1; systemctl start brook > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting Brook"

    local brook_uri
    [[ "$BROOK_MODE" == "wsserver" ]] && brook_uri="brook://wsserver?wsserver=ws://${SERVER_IP}:${BROOK_PORT}&password=${BROOK_PASS}" || brook_uri="brook://server?server=${SERVER_IP}:${BROOK_PORT}&password=${BROOK_PASS}"

    echo ""
    success_msg "Brook Deployed!"
    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Mode:     ${BRIGHT_GREEN}${BROOK_MODE}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${BROOK_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${BROOK_PASS}${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}Brook URL:${NC}" \
        "  ${GRAY}${brook_uri}${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Apps:${NC} ${WHITE}Brook (iOS/Android/Desktop)${NC}" \
        "  ${GRAY}https://github.com/txthinking/brook${NC}"

    log "INFO" "Brook installed"
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════


show_status_dashboard() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}📊  ${BOLD}${WHITE}VPN STATUS DASHBOARD${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    local all_services=(
        "wg-quick@wg0:🛡️  WireGuard"
        "openvpn@server:🔐 OpenVPN"
        "strongswan-starter:⚡ IKEv2/IPsec"
        "strongswan:⚡ IKEv2/IPsec(alt)"
        "softether-vpnserver:🌐 SoftEther"
        "shadowsocks:🕶️  Shadowsocks"
        "xray:🚀 Xray"
        "v2ray:🚀 V2Ray"
        "hysteria-server:🌊 Hysteria 2"
        "tor:🧅 Tor Bridge"
        "ocserv:🐚 OpenConnect"
        "tuic:🔷 TUIC"
        "naiveproxy:🛸 NaiveProxy"
        "brook:🌉 Brook"
        "wstunnel-server:🪱 WG+wstunnel"
        "udp2raw-server:🪱 WG+udp2raw"
    )

    echo -e "${CYAN}  ┌──────────────────────┬────────────┬──────────────────────────────┐${NC}"
    echo -e "${CYAN}  │ ${BOLD}${WHITE}VPN Service${NC}          ${CYAN}│ ${BOLD}${WHITE}Status${NC}     ${CYAN}│ ${BOLD}${WHITE}Details${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────┼────────────┼──────────────────────────────┤${NC}"

    for svc_pair in "${all_services[@]}"; do
        local svc_name="${svc_pair%%:*}"
        local svc_label="${svc_pair##*:}"

        if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
            local details="Running"
            case $svc_name in
                "wg-quick@wg0")
                    local peers
                    peers=$(wg show wg0 peers 2>/dev/null | wc -l)
                    details="${peers} peer(s)"
                    ;;
                "openvpn@server")
                    local clients
                    clients=$(grep -c "CLIENT_LIST" /var/log/openvpn-status.log 2>/dev/null || echo "0")
                    details="${clients} client(s)"
                    ;;
            esac
            printf "${CYAN}  │ ${WHITE}%-20s${CYAN}│ ${BRIGHT_GREEN}● ACTIVE${NC}   ${CYAN}│ ${GREEN}%-28s${CYAN}│${NC}\n" "$svc_label" "$details"
        elif systemctl list-unit-files 2>/dev/null | grep -q "^${svc_name}"; then
            if systemctl is-enabled --quiet "$svc_name" 2>/dev/null; then
                printf "${CYAN}  │ ${DIM}${WHITE}%-20s${NC}${CYAN}│ ${YELLOW}○ STOPPED${NC}  ${CYAN}│ ${GRAY}%-28s${CYAN}│${NC}\n" "$svc_label" "Installed, not running"
            fi
        fi
    done

    echo -e "${CYAN}  └──────────────────────┴────────────┴──────────────────────────────┘${NC}"
    echo ""

    # Open Ports
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🌐  ${BOLD}${WHITE}OPEN VPN PORTS${NC}                                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"

    local vpn_ports
    vpn_ports=$(ss -tulnp 2>/dev/null | grep -E ":(51820|1194|443|500|4500|8388|5555|9001|9999|4096|8443)" | head -15)
    if [[ -n "$vpn_ports" ]]; then
        while IFS= read -r line; do
            local proto port process
            proto=$(echo "$line" | awk '{print $1}')
            port=$(echo "$line" | awk '{print $5}' | rev | cut -d: -f1 | rev)
            process=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' || echo "system")
            printf "${CYAN}  │  ${GREEN}▶${NC} ${WHITE}%-5s :%-7s ${GRAY}→ %-30s${NC}${CYAN}│${NC}\n" "$proto" "$port" "$process"
        done <<< "$vpn_ports"
    else
        echo -e "${CYAN}  │  ${GRAY}No VPN ports detected${NC}                                              ${CYAN}│${NC}"
    fi
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # WireGuard peers detail
    if command -v wg &>/dev/null && ip link show wg0 &>/dev/null 2>&1; then
        echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_CYAN}👥  ${BOLD}${WHITE}WIREGUARD ACTIVE PEERS${NC}                                         ${CYAN}│${NC}"
        echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
        local wg_peers
        wg_peers=$(wg show wg0 peers 2>/dev/null)
        if [[ -n "$wg_peers" ]]; then
            while IFS= read -r peer; do
                local endpoint handshake
                endpoint=$(wg show wg0 endpoints 2>/dev/null | grep "$peer" | awk '{print $2}')
                handshake=$(wg show wg0 latest-handshakes 2>/dev/null | grep "$peer" | awk '{print $2}')
                local ago="never"
                if [[ -n "$handshake" && "$handshake" != "0" ]]; then
                    local diff=$(( $(date +%s) - handshake ))
                    ago="${diff}s ago"
                fi
                printf "${CYAN}  │  ${GREEN}▶${NC} ${GRAY}%.20s${NC} ${WHITE}%-22s ${GRAY}handshake: %s${NC}${CYAN}│${NC}\n" \
                    "$peer" "${endpoint:-not connected}" "$ago"
            done <<< "$wg_peers"
        else
            echo -e "${CYAN}  │  ${GRAY}No peers connected${NC}                                                  ${CYAN}│${NC}"
        fi
        echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi

    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# MANAGEMENT MENU (Enhanced)
# ═══════════════════════════════════════════════════════════════════════════════

show_management_menu() {
    while true; do
        clear
        show_banner

        echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_CYAN}🔧  ${BOLD}${WHITE}MANAGEMENT & TOOLS${NC}                                            ${CYAN}│${NC}"
        echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}  │                                                                      │${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC}  ${WHITE}Add VPN Client/User${NC}                                          ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC}  ${WHITE}Remove VPN Client/User${NC}                                       ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC}  ${WHITE}List All Clients${NC}                                             ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC}  ${WHITE}Show Client QR Code (WireGuard)${NC}                              ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC}  ${WHITE}Restart VPN Service${NC}                                          ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC}  ${WHITE}Stop VPN Service${NC}                                             ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC}  ${WHITE}View VPN Logs${NC}                                                ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[8]${NC}  ${WHITE}Uninstall VPN${NC}                                                ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[9]${NC}  ${WHITE}Backup Configurations${NC}                                        ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[10]${NC} ${WHITE}Speed Test${NC}                                                   ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[11]${NC} ${WHITE}Security Hardening${NC}                                           ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[12]${NC} ${WHITE}Check for VPN Leaks${NC}                                          ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[13]${NC} ${WHITE}Update All VPN Services${NC}                                      ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC}  ${WHITE}Back to Main Menu${NC}                                           ${CYAN}│${NC}"
        echo -e "${CYAN}  │                                                                      │${NC}"
        echo -e "${CYAN}  └──────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        styled_prompt "Select option"
        read -r mgmt_choice

        case $mgmt_choice in
            1)  add_client ;;
            2)  remove_client ;;
            3)  list_clients ;;
            4)  show_qr_code ;;
            5)  restart_vpn ;;
            6)  stop_vpn ;;
            7)  view_logs ;;
            8)  uninstall_vpn ;;
            9)  backup_configs ;;
            10) run_speedtest ;;
            11) security_hardening ;;
            12) check_leaks ;;
            13) update_services ;;
            0)  return ;;
            *)  error_msg "Invalid option!" ; sleep 1 ;;
        esac
    done
}

# ─── Management functions ─────────────────────────────────────────────────────

check_leaks() {
    clear
    show_banner
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}🔍  ${BOLD}${WHITE}VPN LEAK DETECTION${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    typewriter "  [*] Running leak detection tests..." "$GREEN" 0.02
    echo ""

    # DNS Leak check
    echo -e "  ${BRIGHT_CYAN}[Test 1/4]${NC} ${WHITE}Checking current public IP...${NC}"
    local real_ip
    real_ip=$(get_public_ip)
    echo -e "  ${GREEN}  ▶${NC} ${WHITE}Public IP: ${BRIGHT_YELLOW}${real_ip}${NC}"

    echo ""
    echo -e "  ${BRIGHT_CYAN}[Test 2/4]${NC} ${WHITE}Checking IPv6 exposure...${NC}"
    local ipv6
    ipv6=$(curl -s6 --connect-timeout 2 https://ifconfig.me 2>/dev/null || echo "Not exposed")
    if [[ "$ipv6" == "Not exposed" ]]; then
        echo -e "  ${GREEN}  ▶ ✓${NC} ${WHITE}IPv6: ${BRIGHT_GREEN}Not exposed${NC}"
    else
        echo -e "  ${BRIGHT_RED}  ▶ ⚠${NC}  ${WHITE}IPv6 exposed: ${BRIGHT_RED}${ipv6}${NC}"
        echo -e "  ${BRIGHT_YELLOW}    Fix: Add 'block-outside-dns' to WireGuard or disable IPv6${NC}"
    fi

    echo ""
    echo -e "  ${BRIGHT_CYAN}[Test 3/4]${NC} ${WHITE}Checking DNS resolver...${NC}"
    local dns_check
    dns_check=$(dig +short whoami.akamai.net 2>/dev/null | head -1 || echo "Unable to check")
    echo -e "  ${GREEN}  ▶${NC} ${WHITE}DNS resolver IP: ${BRIGHT_YELLOW}${dns_check}${NC}"

    echo ""
    echo -e "  ${BRIGHT_CYAN}[Test 4/4]${NC} ${WHITE}Checking IP forwarding state...${NC}"
    local fwd
    fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [[ "$fwd" == "1" ]]; then
        echo -e "  ${GREEN}  ▶ ✓${NC} ${WHITE}IP forwarding: ${BRIGHT_GREEN}Enabled (required for VPN)${NC}"
    else
        echo -e "  ${BRIGHT_RED}  ▶ ⚠${NC}  ${WHITE}IP forwarding: ${BRIGHT_RED}Disabled! VPN may not route traffic${NC}"
        echo -e "  ${BRIGHT_YELLOW}    Fix: sysctl -w net.ipv4.ip_forward=1${NC}"
    fi

    echo ""
    info_box "LEAK TEST RESULTS" \
        "${GREEN}▶${NC} ${WHITE}Visit these sites on client devices for full tests:${NC}" \
        "" \
        "${BRIGHT_YELLOW}DNS Leaks:${NC}" \
        "  ${GRAY}https://dnsleaktest.com${NC}" \
        "  ${GRAY}https://browserleaks.com/dns${NC}" \
        "" \
        "${BRIGHT_YELLOW}IP Leaks:${NC}" \
        "  ${GRAY}https://ipleak.net${NC}" \
        "  ${GRAY}https://whatismyipaddress.com${NC}" \
        "" \
        "${BRIGHT_YELLOW}WebRTC Leaks:${NC}" \
        "  ${GRAY}https://browserleaks.com/webrtc${NC}"

    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

update_services() {
    clear
    show_banner
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🔄  ${BOLD}${WHITE}UPDATE VPN SERVICES${NC}                                   ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    typewriter "  [*] Checking for updates..." "$GREEN" 0.02
    echo ""

    # Update Xray
    if command -v xray &>/dev/null; then
        echo -e "  ${BRIGHT_CYAN}[*]${NC} ${WHITE}Updating Xray...${NC}"
        (bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1) &
        spinner $! "Updating Xray-core"
    fi

    # Update Hysteria 2
    if command -v hysteria &>/dev/null; then
        echo -e "  ${BRIGHT_CYAN}[*]${NC} ${WHITE}Updating Hysteria 2...${NC}"
        (bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1) &
        spinner $! "Updating Hysteria 2"
    fi

    # Update system packages
    echo -e "  ${BRIGHT_CYAN}[*]${NC} ${WHITE}Updating system packages...${NC}"
    (
        case $OS in
            ubuntu|debian) apt-get update -qq > /dev/null 2>&1 && apt-get upgrade -y -qq > /dev/null 2>&1 ;;
            centos|rhel|rocky|almalinux|fedora) dnf update -y -q > /dev/null 2>&1 ;;
        esac
    ) &
    spinner $! "Updating system packages"

    success_msg "Update complete!"
    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

add_client() {
    clear
    show_banner
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}➕  ${BOLD}${WHITE}ADD NEW CLIENT${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN${NC}                                              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2 (strongSwan)${NC}                                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}OpenConnect (ocserv)${NC}                                 ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose VPN type"
    read -r client_type

    styled_prompt "Client/username"
    read -r new_client_name
    [[ -z "$new_client_name" ]] && error_msg "Name cannot be empty!" && sleep 2 && return

    case $client_type in
        1) # WireGuard
            if [[ ! -f /etc/wireguard/wg0.conf ]]; then
                error_msg "WireGuard not installed!"
                sleep 2; return
            fi
            (
                local last_ip
                last_ip=$(grep "AllowedIPs" /etc/wireguard/wg0.conf | tail -1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
                local base_ip; base_ip=$(echo "$last_ip" | cut -d. -f1-3)
                local last_octet; last_octet=$(echo "$last_ip" | cut -d. -f4)
                local new_ip="${base_ip}.$((last_octet + 1))"
                local server_pub; server_pub=$(cat /etc/wireguard/server_public.key)
                local server_port; server_port=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')
                local priv pub psk
                priv=$(wg genkey); pub=$(echo "$priv" | wg pubkey); psk=$(wg genpsk)

                cat >> /etc/wireguard/wg0.conf << NEWPEER

[Peer]
# Client: ${new_client_name}
PublicKey = ${pub}
PresharedKey = ${psk}
AllowedIPs = ${new_ip}/32
NEWPEER

                cat > "/etc/wireguard/clients/${new_client_name}.conf" << NEWCLIENT
[Interface]
PrivateKey = ${priv}
Address = ${new_ip}/32
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = ${server_pub}
PresharedKey = ${psk}
Endpoint = ${SERVER_IP}:${server_port}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
NEWCLIENT
                chmod 600 "/etc/wireguard/clients/${new_client_name}.conf"
                qrencode -t ansiutf8 < "/etc/wireguard/clients/${new_client_name}.conf" \
                    > "/etc/wireguard/clients/${new_client_name}_qr.txt" 2>/dev/null
                wg syncconf wg0 <(wg-quick strip wg0) > /dev/null 2>&1
            ) &
            spinner $! "Adding WireGuard client"
            success_msg "Client ${new_client_name} added!"
            [[ -f "/etc/wireguard/clients/${new_client_name}_qr.txt" ]] && \
                cat "/etc/wireguard/clients/${new_client_name}_qr.txt"
            ;;
        2) # OpenVPN
            if [[ ! -d /etc/openvpn/easy-rsa ]]; then
                error_msg "OpenVPN not installed!"; sleep 2; return
            fi
            (
                cd /etc/openvpn/easy-rsa || exit
                EASYRSA_BATCH=1 ./easyrsa --batch build-client-full "$new_client_name" nopass > /dev/null 2>&1
                local proto port cipher
                proto=$(grep "^proto" /etc/openvpn/server.conf | awk '{print $2}')
                port=$(grep "^port" /etc/openvpn/server.conf | awk '{print $2}')
                cipher=$(grep "^cipher" /etc/openvpn/server.conf | awk '{print $2}')
                cat > "/etc/openvpn/clients/${new_client_name}.ovpn" << NEWOVPN
client
dev tun
proto ${proto}
remote ${SERVER_IP} ${port}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher ${cipher}
auth SHA256
key-direction 1
verb 3
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/${new_client_name}.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/${new_client_name}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/tls-crypt.key)
</tls-crypt>
NEWOVPN
                chmod 600 "/etc/openvpn/clients/${new_client_name}.ovpn"
            ) &
            spinner $! "Generating OpenVPN client"
            success_msg "Client added: /etc/openvpn/clients/${new_client_name}.ovpn"
            ;;
        3) # IKEv2
            styled_prompt "Password (leave empty to auto-generate)"
            read -rs new_pass; echo ""
            [[ -z "$new_pass" ]] && new_pass=$(openssl rand -base64 12)
            (
                echo "${new_client_name} : EAP \"${new_pass}\"" >> /etc/ipsec.secrets
                systemctl restart strongswan-starter > /dev/null 2>&1 || systemctl restart strongswan > /dev/null 2>&1
            ) &
            spinner $! "Adding IKEv2 user"
            success_msg "User ${new_client_name} added!"
            echo -e "  ${WHITE}Password: ${BRIGHT_YELLOW}${new_pass}${NC}"
            ;;
        4) # OpenConnect
            if [[ ! -f /etc/ocserv/ocpasswd ]]; then
                error_msg "OpenConnect not installed!"; sleep 2; return
            fi
            styled_prompt "Password (leave empty to auto-generate)"
            read -rs new_pass; echo ""
            [[ -z "$new_pass" ]] && new_pass=$(openssl rand -base64 12)
            echo "$new_pass" | ocpasswd -c /etc/ocserv/ocpasswd "$new_client_name" > /dev/null 2>&1
            success_msg "User ${new_client_name} added to ocserv!"
            echo -e "  ${WHITE}Password: ${BRIGHT_YELLOW}${new_pass}${NC}"
            ;;
    esac

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

remove_client() {
    echo ""
    info_box "REMOVE CLIENT REFERENCE" \
        "${BRIGHT_YELLOW}WireGuard:${NC}" \
        "  ${GRAY}nano /etc/wireguard/wg0.conf${NC}" \
        "  ${GRAY}Remove [Peer] block, then:${NC}" \
        "  ${GRAY}wg syncconf wg0 <(wg-quick strip wg0)${NC}" \
        "" \
        "${BRIGHT_YELLOW}OpenVPN:${NC}" \
        "  ${GRAY}cd /etc/openvpn/easy-rsa${NC}" \
        "  ${GRAY}./easyrsa revoke <client>${NC}" \
        "  ${GRAY}./easyrsa gen-crl${NC}" \
        "" \
        "${BRIGHT_YELLOW}IKEv2:${NC}" \
        "  ${GRAY}nano /etc/ipsec.secrets${NC}" \
        "  ${GRAY}Remove user line, restart strongswan${NC}" \
        "" \
        "${BRIGHT_YELLOW}OpenConnect:${NC}" \
        "  ${GRAY}ocpasswd -d -c /etc/ocserv/ocpasswd <user>${NC}"
    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

list_clients() {
    clear; show_banner
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}👥  ${BOLD}${WHITE}ALL VPN CLIENTS${NC}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    for label_dir in \
        "🛡️  WireGuard:/etc/wireguard/clients:.conf" \
        "🔐 OpenVPN:/etc/openvpn/clients:.ovpn"
    do
        local label="${label_dir%%:*}"
        local rest="${label_dir#*:}"
        local dir="${rest%%:*}"
        local ext="${rest##*:}"

        if [[ -d "$dir" ]]; then
            echo -e "  ${BRIGHT_GREEN}${label} Clients:${NC}"
            local found=0
            for conf in "${dir}"/*"${ext}"; do
                [[ -f "$conf" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}$(basename "$conf" "$ext")${NC}" && found=1
            done
            [[ $found -eq 0 ]] && echo -e "    ${GRAY}No clients found${NC}"
            echo ""
        fi
    done

    [[ -f /etc/ipsec.secrets ]] && {
        echo -e "  ${BRIGHT_GREEN}⚡ IKEv2 Users:${NC}"
        grep "EAP" /etc/ipsec.secrets 2>/dev/null | awk -F: '{print $1}' | xargs -I{} echo -e "    ${GREEN}▶${NC} ${WHITE}{}${NC}"
        echo ""
    }

    [[ -f /etc/ocserv/ocpasswd ]] && {
        echo -e "  ${BRIGHT_GREEN}🐚 OpenConnect Users:${NC}"
        awk -F: '{print $1}' /etc/ocserv/ocpasswd 2>/dev/null | while read -r u; do
            echo -e "    ${GREEN}▶${NC} ${WHITE}${u}${NC}"
        done
        echo ""
    }

    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

show_qr_code() {
    [[ ! -d /etc/wireguard/clients ]] && error_msg "No WireGuard clients!" && sleep 2 && return
    echo ""
    echo -e "  ${WHITE}Available WireGuard clients:${NC}"
    for conf in /etc/wireguard/clients/*.conf; do
        [[ -f "$conf" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}$(basename "$conf" .conf)${NC}"
    done
    echo ""
    styled_prompt "Enter client name"
    read -r qr_client
    if [[ -f "/etc/wireguard/clients/${qr_client}.conf" ]]; then
        echo ""
        qrencode -t ansiutf8 < "/etc/wireguard/clients/${qr_client}.conf" 2>/dev/null || \
            error_msg "qrencode not installed: apt install qrencode"
    else
        error_msg "Client '${qr_client}' not found!"
    fi
    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

restart_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select service to restart:${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard       ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN      ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther       ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Hysteria 2      ${BRIGHT_GREEN}[8]${NC} ${WHITE}Tor          ${BRIGHT_GREEN}[9]${NC} ${WHITE}OpenConnect${NC}${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[10]${NC} ${WHITE}TUIC           ${BRIGHT_GREEN}[11]${NC} ${WHITE}NaiveProxy   ${BRIGHT_GREEN}[12]${NC} ${WHITE}Brook${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[0]${NC} ${WHITE}ALL services${NC}                                        ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r rc

    local svc_map=(
        [1]="wg-quick@wg0"
        [2]="openvpn@server"
        [3]="strongswan-starter"
        [4]="softether-vpnserver"
        [5]="shadowsocks"
        [6]="xray"
        [7]="hysteria-server"
        [8]="tor"
        [9]="ocserv"
        [10]="tuic"
        [11]="naiveproxy"
        [12]="brook"
    )

    if [[ "$rc" == "0" ]]; then
        for svc in "${svc_map[@]}"; do
            systemctl restart "$svc" > /dev/null 2>&1
        done
        success_msg "All services restart attempted!"
    elif [[ -n "${svc_map[$rc]}" ]]; then
        systemctl restart "${svc_map[$rc]}" 2>/dev/null && \
            success_msg "${svc_map[$rc]} restarted!" || error_msg "Failed to restart!"
    fi
    sleep 2
}

stop_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select service to stop:${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Hysteria 2  ${BRIGHT_GREEN}[8]${NC} ${WHITE}Tor  ${BRIGHT_GREEN}[9]${NC} ${WHITE}OpenConnect${NC}         ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r sc
    local svc_map=([1]="wg-quick@wg0" [2]="openvpn@server" [3]="strongswan-starter"
                   [4]="softether-vpnserver" [5]="shadowsocks" [6]="xray"
                   [7]="hysteria-server" [8]="tor" [9]="ocserv")
    [[ -n "${svc_map[$sc]}" ]] && systemctl stop "${svc_map[$sc]}" 2>/dev/null && \
        success_msg "${svc_map[$sc]} stopped!" || error_msg "Failed!"
    sleep 2
}

view_logs() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select logs to view:${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard   ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Xray        ${BRIGHT_GREEN}[5]${NC} ${WHITE}Hysteria 2  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Tor${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}OpenConnect ${BRIGHT_GREEN}[8]${NC} ${WHITE}VPN Blast log${NC}                  ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r lc
    echo ""
    case $lc in
        1) journalctl -u wg-quick@wg0 --no-pager -n 50 ;;
        2) tail -50 /var/log/openvpn.log 2>/dev/null || journalctl -u openvpn@server --no-pager -n 50 ;;
        3) journalctl -u strongswan-starter --no-pager -n 50 2>/dev/null || journalctl -u strongswan --no-pager -n 50 ;;
        4) journalctl -u xray --no-pager -n 50 2>/dev/null || journalctl -u v2ray --no-pager -n 50 ;;
        5) journalctl -u hysteria-server --no-pager -n 50 ;;
        6) journalctl -u tor --no-pager -n 50 ;;
        7) journalctl -u ocserv --no-pager -n 50 ;;
        8) tail -100 "$LOG_FILE" 2>/dev/null || echo "No log file found at $LOG_FILE" ;;
    esac
    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

uninstall_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}⚠️   ${BOLD}${WHITE}UNINSTALL VPN SERVICE${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard      ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN      ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther      ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Hysteria 2     ${BRIGHT_GREEN}[8]${NC} ${WHITE}Tor          ${BRIGHT_GREEN}[9]${NC} ${WHITE}OpenConnect${NC}${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[10]${NC} ${WHITE}TUIC          ${BRIGHT_GREEN}[11]${NC} ${WHITE}NaiveProxy   ${BRIGHT_GREEN}[12]${NC} ${WHITE}Brook${NC}     ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r uc

    if ! confirm_prompt "SURE you want to uninstall? IRREVERSIBLE!" "n"; then return; fi

    local uninstall_cmds=(
        [1]="systemctl stop wg-quick@wg0; systemctl disable wg-quick@wg0; apt-get remove -y wireguard wireguard-tools 2>/dev/null || dnf remove -y wireguard-tools 2>/dev/null; rm -rf /etc/wireguard"
        [2]="systemctl stop openvpn@server; systemctl disable openvpn@server; apt-get remove -y openvpn easy-rsa 2>/dev/null || dnf remove -y openvpn easy-rsa 2>/dev/null; rm -rf /etc/openvpn"
        [3]="systemctl stop strongswan-starter 2>/dev/null; systemctl disable strongswan-starter 2>/dev/null; apt-get remove -y strongswan* 2>/dev/null || dnf remove -y strongswan 2>/dev/null; rm -f /etc/ipsec.conf /etc/ipsec.secrets; rm -rf /etc/ipsec.d"
        [4]="systemctl stop softether-vpnserver; systemctl disable softether-vpnserver; rm -rf /usr/local/vpnserver; rm -f /etc/systemd/system/softether-vpnserver.service; systemctl daemon-reload"
        [5]="systemctl stop shadowsocks; systemctl disable shadowsocks; rm -rf /etc/shadowsocks; rm -f /etc/systemd/system/shadowsocks.service; systemctl daemon-reload"
        [6]="bash -c '\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)' @ remove 2>/dev/null; rm -rf /usr/local/etc/xray"
        [7]="systemctl stop hysteria-server; systemctl disable hysteria-server; rm -f /usr/local/bin/hysteria; rm -rf /etc/hysteria"
        [8]="systemctl stop tor; systemctl disable tor; apt-get remove -y tor 2>/dev/null || dnf remove -y tor 2>/dev/null"
        [9]="systemctl stop ocserv; systemctl disable ocserv; apt-get remove -y ocserv 2>/dev/null || dnf remove -y ocserv 2>/dev/null; rm -rf /etc/ocserv"
        [10]="systemctl stop tuic; systemctl disable tuic; rm -f /usr/local/bin/tuic-server; rm -rf /etc/tuic; rm -f /etc/systemd/system/tuic.service; systemctl daemon-reload"
        [11]="systemctl stop naiveproxy; systemctl disable naiveproxy; rm -f /usr/local/bin/caddy-naive; rm -rf /etc/caddy-naive; rm -f /etc/systemd/system/naiveproxy.service; systemctl daemon-reload"
        [12]="systemctl stop brook; systemctl disable brook; rm -f /usr/local/bin/brook; rm -rf /etc/brook; rm -f /etc/systemd/system/brook.service; systemctl daemon-reload"
    )

    if [[ -n "${uninstall_cmds[$uc]}" ]]; then
        (eval "${uninstall_cmds[$uc]}" > /dev/null 2>&1; sleep 1) &
        spinner $! "Uninstalling VPN service"
        success_msg "Uninstalled successfully!"
    else
        error_msg "Invalid option!"
    fi
    sleep 2
}

backup_configs() {
    local backup_time
    backup_time=$(date +%Y%m%d_%H%M%S)
    local backup_path="/root/vpn-backup-${backup_time}"
    echo ""
    (
        mkdir -p "$backup_path"
        for d in /etc/wireguard /etc/openvpn /etc/shadowsocks /usr/local/etc/xray \
                  /usr/local/etc/v2ray /etc/hysteria /etc/ipsec.d /etc/ocserv \
                  /etc/tuic /etc/caddy-naive /etc/brook; do
            [[ -d "$d" ]] && cp -r "$d" "$backup_path/"
        done
        for f in /etc/ipsec.conf /etc/ipsec.secrets /etc/tor/torrc; do
            [[ -f "$f" ]] && cp "$f" "$backup_path/"
        done
        tar czf "${backup_path}.tar.gz" -C /root "vpn-backup-${backup_time}" 2>/dev/null
        rm -rf "$backup_path"
        sleep 1
    ) &
    spinner $! "Creating backup archive"
    success_msg "Backup: ${backup_path}.tar.gz"
    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

run_speedtest() {
    echo ""
    typewriter "  [*] Running network speed test..." "$GREEN" 0.02
    echo ""
    if ! command -v speedtest-cli &>/dev/null; then
        (apt-get install -y speedtest-cli > /dev/null 2>&1 || dnf install -y speedtest-cli > /dev/null 2>&1) &
        spinner $! "Installing speedtest-cli"
    fi
    if command -v speedtest-cli &>/dev/null; then
        speedtest-cli --simple 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${GREEN}▶${NC} ${WHITE}${line}${NC}"
        done
    else
        echo -e "  ${GRAY}Try: curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3${NC}"
    fi
    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

security_hardening() {
    clear; show_banner
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}🔒  ${BOLD}${WHITE}SECURITY HARDENING${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Enable UFW Firewall${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Install Fail2Ban${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Disable root SSH login${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Change SSH port${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Enable automatic security updates${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Harden sysctl parameters${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Install & configure BBR congestion${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[8]${NC} ${WHITE}Apply ALL hardening measures${NC}                         ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC} ${WHITE}Back${NC}                                                 ${CYAN}│${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r hc

    case $hc in
        1)
            (
                apt-get install -y -qq ufw > /dev/null 2>&1 || dnf install -y -q ufw > /dev/null 2>&1
                ufw default deny incoming > /dev/null 2>&1
                ufw default allow outgoing > /dev/null 2>&1
                ufw allow ssh > /dev/null 2>&1
                for port in 51820/udp 1194/udp 1194/tcp 443/tcp 443/udp 500/udp 4500/udp 8388 9001 9999; do
                    ufw allow "$port" > /dev/null 2>&1
                done
                echo "y" | ufw enable > /dev/null 2>&1
            ) &
            spinner $! "Configuring UFW"
            success_msg "UFW firewall enabled!"
            ;;
        2)
            (apt-get install -y -qq fail2ban > /dev/null 2>&1 || dnf install -y -q fail2ban > /dev/null 2>&1
             systemctl enable fail2ban > /dev/null 2>&1
             systemctl start fail2ban > /dev/null 2>&1) &
            spinner $! "Installing Fail2Ban"
            success_msg "Fail2Ban installed!"
            ;;
        3)
            sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
            systemctl restart sshd > /dev/null 2>&1
            warning_msg "Root SSH disabled! Ensure you have another user!"
            ;;
        4)
            styled_prompt "New SSH port" "2222"
            read -r new_ssh_port
            new_ssh_port=${new_ssh_port:-2222}
            sed -i "s/^#*Port.*/Port ${new_ssh_port}/" /etc/ssh/sshd_config
            command -v ufw &>/dev/null && ufw allow "$new_ssh_port"/tcp > /dev/null 2>&1
            systemctl restart sshd > /dev/null 2>&1
            success_msg "SSH port changed to ${new_ssh_port}!"
            ;;
        5)
            (
                if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
                    apt-get install -y -qq unattended-upgrades > /dev/null 2>&1
                    echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
                    dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
                else
                    dnf install -y -q dnf-automatic > /dev/null 2>&1
                    systemctl enable --now dnf-automatic.timer > /dev/null 2>&1
                fi
            ) &
            spinner $! "Enabling auto-updates"
            success_msg "Auto-updates enabled!"
            ;;
        6)
            (
                cat >> /etc/sysctl.conf << 'SYSCTL'
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
kernel.randomize_va_space=2
SYSCTL
                sysctl -p > /dev/null 2>&1
            ) &
            spinner $! "Hardening sysctl"
            success_msg "Sysctl hardened!"
            ;;
        7)
            (
                cat >> /etc/sysctl.conf << 'BBREOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
BBREOF
                sysctl -p > /dev/null 2>&1
            ) &
            spinner $! "Enabling BBR congestion control"
            success_msg "BBR enabled!"
            ;;
        8)
            for sub_choice in 1 2 5 6 7; do
                security_hardening_silent "$sub_choice"
            done
            success_msg "All hardening measures applied!"
            ;;
        0) return ;;
    esac
    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

# Helper for batch hardening
security_hardening_silent() {
    case $1 in
        1) apt-get install -y -qq ufw >/dev/null 2>&1; ufw allow ssh >/dev/null 2>&1; echo "y" | ufw enable >/dev/null 2>&1 ;;
        2) apt-get install -y -qq fail2ban >/dev/null 2>&1; systemctl enable --now fail2ban >/dev/null 2>&1 ;;
        5) apt-get install -y -qq unattended-upgrades >/dev/null 2>&1 ;;
        6) echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf; sysctl -p >/dev/null 2>&1 ;;
        7) echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf; sysctl -p >/dev/null 2>&1 ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXIT ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

show_exit() {
    clear
    echo ""
    echo -e "${BRIGHT_GREEN}"
    cat << 'EXIT_ART'

     ████████╗██╗  ██╗ █████╗ ███╗   ██╗██╗  ██╗███████╗██╗
     ╚══██╔══╝██║  ██║██╔══██╗████╗  ██║██║ ██╔╝██╔════╝██║
        ██║   ███████║███████║██╔██╗ ██║█████╔╝ ███████╗██║
        ██║   ██╔══██║██╔══██║██║╚██╗██║██╔═██╗ ╚════██║╚═╝
        ██║   ██║  ██║██║  ██║██║ ╚████║██║  ██╗███████║██╗
        ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝

EXIT_ART
    echo -e "${NC}"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    print_centered "🔒 Stay Secure. Stay Anonymous. Stay Free. 🔒" "$BRIGHT_YELLOW"
    print_centered "VPN Blast v${SCRIPT_VERSION} • \"Your Privacy Is Not Optional — It's A Right.\"" "$WHITE"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    echo ""

    glitch_typewriter "  [*] Wiping session artifacts..." "$GREEN" 0.02
    glitch_typewriter "  [*] Clearing memory buffers..." "$GREEN" 0.02
    glitch_typewriter "  [*] Terminating secure channel..." "$GREEN" 0.02
    glitch_typewriter "  [*] Session terminated. Goodbye, operator." "$BRIGHT_GREEN" 0.02
    echo ""
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    check_root
    detect_os
    pre_flight
    get_server_info

    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$INSTALL_DIR" 2>/dev/null
    touch "$LOG_FILE" 2>/dev/null

    log "INFO" "VPN Blast v${SCRIPT_VERSION} started"

    # Matrix rain intro (4+ seconds)
    matrix_rain 4

    # Boot sequence
    boot_sequence

    # Main loop
    while true; do
        show_banner
        show_system_info
        show_main_menu

        styled_prompt "Enter your choice, operator"
        read -r main_choice

        case $main_choice in
            1)  install_wireguard ;;
            2)  install_openvpn ;;
            3)  install_ikev2 ;;
            4)  install_v2ray ;;
            5)  install_shadowsocks ;;
            6)  install_outline ;;
            7)  install_hysteria2 ;;
            8)  install_reality ;;
            9)  install_wireguard_obfs ;;
            10) install_softether ;;
            11) install_tor_bridge ;;
            12) install_openconnect ;;
            13) install_tuic ;;
            14) install_naiveproxy ;;
            15) install_brook ;;
            96) vpn_recommendation_wizard ;;
            97) show_vpn_comparison ;;
            98) show_status_dashboard ;;
            99) show_management_menu ;;
            0)  show_exit ;;
            *)
                error_msg "Invalid option, operator!"
                sleep 1
                ;;
        esac
    done
}

# ─── Entry point ──────────────────────────────────────────────────────────────
main "$@"
