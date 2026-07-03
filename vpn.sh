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
#   VPN BLAST - The Ultimate VPN Deployment Tool
#   Version: 2.0
#   Author: VPN Blast Team
#   License: MIT
#
#===============================================================================

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR DEFINITIONS & STYLING
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
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
NC='\033[0m' # No Color

# Bright colors
BRIGHT_RED='\033[1;31m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_BLUE='\033[1;34m'
BRIGHT_MAGENTA='\033[1;35m'
BRIGHT_CYAN='\033[1;36m'

# Background colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'
BG_BLACK='\033[40m'

# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_VERSION="2.0"
LOG_FILE="/var/log/vpn-blast.log"
CONFIG_DIR="/etc/vpn-blast"
BACKUP_DIR="/etc/vpn-blast/backups"
INSTALL_DIR="/opt/vpn-blast"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
}

# Print a line across the terminal
print_line() {
    local char="${1:-═}"
    local color="${2:-$CYAN}"
    printf "${color}"
    printf '%*s' "$TERM_WIDTH" '' | tr ' ' "$char"
    printf "${NC}\n"
}

# Print centered text
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

# Typewriter effect
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

# Spinner animation
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
    printf "\r${CYAN}  [${BRIGHT_GREEN}✓${CYAN}] ${WHITE}%s... ${BRIGHT_GREEN}Done!${NC}\n" "$message"
}

# Progress bar
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

# Animated success message
success_msg() {
    echo -e "\n${BRIGHT_GREEN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_GREEN}  ║  ${WHITE}✅  $1${BRIGHT_GREEN}$(printf '%*s' $((38 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_GREEN}  ╚══════════════════════════════════════════╝${NC}\n"
}

# Animated error message
error_msg() {
    echo -e "\n${BRIGHT_RED}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}  ║  ${WHITE}❌  $1${BRIGHT_RED}$(printf '%*s' $((38 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_RED}  ╚══════════════════════════════════════════╝${NC}\n"
}

# Warning message
warning_msg() {
    echo -e "\n${BRIGHT_YELLOW}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_YELLOW}  ║  ${WHITE}⚠️   $1${BRIGHT_YELLOW}$(printf '%*s' $((37 - ${#1})) '')║${NC}"
    echo -e "${BRIGHT_YELLOW}  ╚══════════════════════════════════════════╝${NC}\n"
}

# Info box
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

# Prompt with style
styled_prompt() {
    local prompt_text="$1"
    local default_val="${2:-}"
    if [[ -n "$default_val" ]]; then
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text} ${DIM}[${default_val}]${NC}${WHITE}: ${NC}"
    else
        printf "${BRIGHT_CYAN}  ➤ ${WHITE}${prompt_text}: ${NC}"
    fi
}

# Yes/No prompt
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_msg "This script must be run as root!"
        echo -e "  ${YELLOW}Run with: ${WHITE}sudo $0${NC}\n"
        exit 1
    fi
}

# Detect OS
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

# Get public IP
get_public_ip() {
    local ip
    ip=$(curl -s4 https://ifconfig.me 2>/dev/null || \
         curl -s4 https://api.ipify.org 2>/dev/null || \
         curl -s4 https://icanhazip.com 2>/dev/null || \
         echo "Unable to detect")
    echo "$ip"
}

# Get server info
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
# DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Matrix rain effect (brief)
matrix_rain() {
    local duration=${1:-2}
    local cols=$TERM_WIDTH
    local end_time=$(( $(date +%s) + duration ))

    while [[ $(date +%s) -lt $end_time ]]; do
        local col=$(( RANDOM % cols ))
        local char_set="01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
        local rand_char="${char_set:$(( RANDOM % ${#char_set} )):1}"
        printf "\033[%d;%dH${GREEN}%s${NC}" $(( RANDOM % 20 + 1 )) "$col" "$rand_char"
        sleep 0.01
    done
    clear
}

# Show banner
show_banner() {
    clear
    echo ""
    echo -e "${BRIGHT_GREEN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║  ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██╗      █████╗ ███████╗████████╗║
    ║  ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██║     ██╔══██╗██╔════╝╚══██╔══╝║
    ║  ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██║     ███████║███████╗   ██║   ║
    ║  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔══██╗██║     ██╔══██║╚════██║   ██║   ║
    ║   ╚████╔╝ ██║     ██║ ╚████║    ██████╔╝███████╗██║  ██║███████║   ██║   ║
    ║    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    print_centered "🔒 The Ultimate VPN Deployment Arsenal v${SCRIPT_VERSION} 🔒" "$BRIGHT_YELLOW"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    echo ""
}

# Show system info
show_system_info() {
    get_server_info
    detect_os

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🖥️  ${BOLD}${WHITE}SYSTEM RECONNAISSANCE${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}OS          ${GRAY}: ${BRIGHT_GREEN}${OS_NAME}${NC}$(printf '%*s' $((35 - ${#OS_NAME})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Kernel      ${GRAY}: ${BRIGHT_GREEN}${SERVER_KERNEL}${NC}$(printf '%*s' $((35 - ${#SERVER_KERNEL})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Arch        ${GRAY}: ${BRIGHT_GREEN}${SERVER_ARCH}${NC}$(printf '%*s' $((35 - ${#SERVER_ARCH})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Hostname    ${GRAY}: ${BRIGHT_GREEN}${SERVER_HOSTNAME}${NC}$(printf '%*s' $((35 - ${#SERVER_HOSTNAME})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Public IP   ${GRAY}: ${BRIGHT_YELLOW}${SERVER_IP}${NC}$(printf '%*s' $((35 - ${#SERVER_IP})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}CPU Cores   ${GRAY}: ${BRIGHT_GREEN}${SERVER_CPU}${NC}$(printf '%*s' $((35 - ${#SERVER_CPU})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}RAM         ${GRAY}: ${BRIGHT_GREEN}${SERVER_RAM}${NC}$(printf '%*s' $((35 - ${#SERVER_RAM})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Disk        ${GRAY}: ${BRIGHT_GREEN}${SERVER_DISK}${NC}$(printf '%*s' $((35 - ${#SERVER_DISK})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${GREEN}▶ ${WHITE}Uptime      ${GRAY}: ${BRIGHT_GREEN}${SERVER_UPTIME}${NC}$(printf '%*s' $((35 - ${#SERVER_UPTIME})) '')${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_main_menu() {
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🎯  ${BOLD}${WHITE}SELECT YOUR VPN WEAPON${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}🛡️  WireGuard        ${GRAY}─ Modern, Fast, Lightweight${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}🔐 OpenVPN           ${GRAY}─ Battle-tested, Versatile${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}⚡ IKEv2/IPsec       ${GRAY}─ Native Mobile Support${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}🌐 SoftEther VPN     ${GRAY}─ Multi-Protocol Suite${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}🔥 Outline VPN       ${GRAY}─ Censorship Resistant${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}🕶️  Shadowsocks       ${GRAY}─ Stealth Proxy${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}🚀 V2Ray/Xray        ${GRAY}─ Advanced Tunneling${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[8]${NC} ${WHITE}📊 VPN Status Dashboard${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}[9]${NC} ${WHITE}🔧 Management & Tools${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC} ${WHITE}🚪 Exit${NC}                                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN COMPARISON / INFO
# ═══════════════════════════════════════════════════════════════════════════════

show_vpn_comparison() {
    clear
    show_banner

    echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}📊  ${BOLD}${WHITE}VPN PROTOCOL COMPARISON MATRIX${NC}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}  ├────────────────┬──────────┬──────────┬───────────┬──────────────────────┤${NC}"
    echo -e "${CYAN}  │ ${BOLD}${WHITE}Protocol${NC}       ${CYAN}│ ${BOLD}${WHITE}Speed${NC}    ${CYAN}│ ${BOLD}${WHITE}Security${NC} ${CYAN}│ ${BOLD}${WHITE}Setup${NC}     ${CYAN}│ ${BOLD}${WHITE}Best For${NC}             ${CYAN}│${NC}"
    echo -e "${CYAN}  ├────────────────┼──────────┼──────────┼───────────┼──────────────────────┤${NC}"
    echo -e "${CYAN}  │ ${GREEN}WireGuard${NC}      ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}  ${CYAN}│ ${BRIGHT_GREEN}Easy${NC}      ${CYAN}│ ${WHITE}Speed & Simplicity${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}OpenVPN${NC}        ${CYAN}│ ${YELLOW}★★★☆☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}  ${CYAN}│ ${YELLOW}Medium${NC}    ${CYAN}│ ${WHITE}Compatibility${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}IKEv2/IPsec${NC}    ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}  ${CYAN}│ ${YELLOW}Medium${NC}    ${CYAN}│ ${WHITE}Mobile Devices${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}SoftEther${NC}      ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}  ${CYAN}│ ${RED}Complex${NC}   ${CYAN}│ ${WHITE}Multi-protocol${NC}       ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Outline${NC}        ${CYAN}│ ${YELLOW}★★★☆☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}Easy${NC}      ${CYAN}│ ${WHITE}Anti-Censorship${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}Shadowsocks${NC}    ${CYAN}│ ${YELLOW}★★★☆☆${NC}  ${CYAN}│ ${YELLOW}★★★☆☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}Easy${NC}      ${CYAN}│ ${WHITE}Bypassing Firewalls${NC}  ${CYAN}│${NC}"
    echo -e "${CYAN}  │ ${GREEN}V2Ray/Xray${NC}     ${CYAN}│ ${BRIGHT_GREEN}★★★★☆${NC}  ${CYAN}│ ${BRIGHT_GREEN}★★★★★${NC}  ${CYAN}│ ${RED}Complex${NC}   ${CYAN}│ ${WHITE}Advanced Evasion${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  └────────────────┴──────────┴──────────┴───────────┴──────────────────────┘${NC}"
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
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT WIREGUARD" \
        "${GREEN}▶${NC} ${WHITE}Modern, high-performance VPN protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses state-of-the-art cryptography${NC}" \
        "${GREEN}▶${NC} ${WHITE}Minimal attack surface (~4000 lines of code)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Built into Linux kernel 5.6+${NC}" \
        "${GREEN}▶${NC} ${WHITE}Extremely fast connection establishment${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports roaming (seamless IP changes)${NC}"

    if ! confirm_prompt "Deploy WireGuard VPN?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing WireGuard deployment sequence..." "$GREEN"
    echo ""

    # ─── Configuration Options ────────────────────────────────────────────
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_YELLOW}⚙️  ${BOLD}${WHITE}CONFIGURATION${NC}                                         ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Server Port
    styled_prompt "WireGuard listen port" "51820"
    read -r WG_PORT
    WG_PORT=${WG_PORT:-51820}

    # Server Network
    styled_prompt "VPN subnet (internal)" "10.66.66.0/24"
    read -r WG_SUBNET
    WG_SUBNET=${WG_SUBNET:-"10.66.66.0/24"}

    # DNS
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select DNS Provider:${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Cloudflare    ${GRAY}(1.1.1.1, 1.0.0.1)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Google        ${GRAY}(8.8.8.8, 8.8.4.4)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Quad9         ${GRAY}(9.9.9.9, 149.112.112.112)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}OpenDNS       ${GRAY}(208.67.222.222, 208.67.220.220)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}AdGuard DNS   ${GRAY}(94.140.14.14, 94.140.15.15)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Custom DNS${NC}                                        ${CYAN}│${NC}"
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
        6)
            styled_prompt "Enter primary DNS"
            read -r custom_dns1
            styled_prompt "Enter secondary DNS (optional)"
            read -r custom_dns2
            WG_DNS="$custom_dns1"
            [[ -n "$custom_dns2" ]] && WG_DNS="$custom_dns1, $custom_dns2"
            ;;
        *) WG_DNS="1.1.1.1, 1.0.0.1" ;;
    esac

    # Number of clients
    echo ""
    styled_prompt "Number of client configs to generate" "1"
    read -r WG_CLIENTS
    WG_CLIENTS=${WG_CLIENTS:-1}

    # First client name
    styled_prompt "First client name" "client1"
    read -r WG_CLIENT_NAME
    WG_CLIENT_NAME=${WG_CLIENT_NAME:-"client1"}

    # MTU
    styled_prompt "MTU size" "1420"
    read -r WG_MTU
    WG_MTU=${WG_MTU:-1420}

    # Confirmation
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
    typewriter "  [*] Starting WireGuard deployment..." "$GREEN"
    echo ""

    # ─── Installation Process ─────────────────────────────────────────────

    # Step 1: Update system
    echo -e "  ${BRIGHT_CYAN}[Step 1/7]${NC} ${WHITE}Updating system packages...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1
                apt-get upgrade -y -qq > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf update -y -q > /dev/null 2>&1 || yum update -y -q > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -Syu --noconfirm > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Updating system packages"

    # Step 2: Install WireGuard
    echo -e "  ${BRIGHT_CYAN}[Step 2/7]${NC} ${WHITE}Installing WireGuard...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get install -y -qq wireguard wireguard-tools qrencode > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux)
                dnf install -y -q epel-release > /dev/null 2>&1
                dnf install -y -q wireguard-tools qrencode > /dev/null 2>&1
                ;;
            fedora)
                dnf install -y -q wireguard-tools qrencode > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -S --noconfirm wireguard-tools qrencode > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Installing WireGuard packages"

    # Step 3: Generate server keys
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

    # Determine the server address
    WG_SERVER_IP=$(echo "$WG_SUBNET" | sed 's/\.[0-9]*\//.1\//')
    WG_SERVER_ADDR=$(echo "$WG_SERVER_IP" | cut -d'/' -f1)

    # Step 4: Detect network interface
    echo -e "  ${BRIGHT_CYAN}[Step 4/7]${NC} ${WHITE}Detecting network configuration...${NC}"
    SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    echo -e "  ${CYAN}  [${BRIGHT_GREEN}✓${CYAN}]${NC} ${WHITE}Network interface: ${BRIGHT_GREEN}${SERVER_NIC}${NC}"

    # Step 5: Create server configuration
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

# NAT and Firewall Rules
PostUp = iptables -I INPUT -p udp --dport ${WG_PORT} -j ACCEPT
PostUp = iptables -I FORWARD -i wg0 -j ACCEPT
PostUp = iptables -I FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_NIC} -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport ${WG_PORT} -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_NIC} -j MASQUERADE

# SaveConfig = true

WGEOF
        chmod 600 /etc/wireguard/wg0.conf
        sleep 1
    ) &
    spinner $! "Writing server configuration"

    # Step 6: Generate client configurations
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
            # Generate client keys
            client_private=$(wg genkey)
            client_public=$(echo "$client_private" | wg pubkey)
            client_psk=$(wg genpsk)

            # Calculate client IP
            local client_ip_num=$(( i + 1 ))
            local base_ip
            base_ip=$(echo "$WG_SUBNET" | cut -d'.' -f1-3)
            local client_ip="${base_ip}.${client_ip_num}"

            # Add peer to server config
            cat >> /etc/wireguard/wg0.conf << PEER_EOF

# ─── Client: ${client_name} ─────────────────────────────
[Peer]
PublicKey = ${client_public}
PresharedKey = ${client_psk}
AllowedIPs = ${client_ip}/32
PEER_EOF

            # Create client config
            cat > "/etc/wireguard/clients/${client_name}.conf" << CLIENT_EOF
# ═══════════════════════════════════════════════════════════
# WireGuard Client Configuration: ${client_name}
# Generated by VPN Blast v${SCRIPT_VERSION}
# Server: ${SERVER_IP}
# Date: $(date)
# ═══════════════════════════════════════════════════════════

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

            # Generate QR code
            qrencode -t ansiutf8 < "/etc/wireguard/clients/${client_name}.conf" \
                > "/etc/wireguard/clients/${client_name}_qr.txt" 2>/dev/null

            sleep 0.5
        ) &
        spinner $! "Generating config for ${client_name}"
    done

    # Step 7: Enable IP forwarding and start WireGuard
    echo -e "  ${BRIGHT_CYAN}[Step 7/7]${NC} ${WHITE}Activating WireGuard...${NC}"
    (
        # Enable IP forwarding
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null 2>&1

        # Make permanent
        if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi
        if ! grep -q "net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf 2>/dev/null; then
            echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
        fi

        # Start WireGuard
        systemctl enable wg-quick@wg0 > /dev/null 2>&1
        systemctl start wg-quick@wg0 > /dev/null 2>&1

        # Open firewall port
        if command -v ufw &> /dev/null; then
            ufw allow "$WG_PORT"/udp > /dev/null 2>&1
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port="$WG_PORT"/udp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi

        sleep 1
    ) &
    spinner $! "Activating WireGuard & configuring firewall"

    # ─── Success Output ──────────────────────────────────────────────────
    echo ""
    success_msg "WireGuard Deployed Successfully!"

    info_box "CLIENT CONFIGURATION FILES" \
        "${GREEN}▶${NC} ${WHITE}Config directory: ${BRIGHT_GREEN}/etc/wireguard/clients/${NC}" \
        "${GREEN}▶${NC} ${WHITE}Download configs via SCP:${NC}" \
        "  ${GRAY}scp root@${SERVER_IP}:/etc/wireguard/clients/*.conf ./${NC}"

    # Show QR code for first client
    if [[ -f "/etc/wireguard/clients/${WG_CLIENT_NAME}_qr.txt" ]]; then
        echo -e "\n${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_CYAN}📱 ${BOLD}${WHITE}QR Code for ${WG_CLIENT_NAME}${NC} ${GRAY}(scan with WireGuard app)${NC}     ${CYAN}│${NC}"
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
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT OPENVPN" \
        "${GREEN}▶${NC} ${WHITE}Industry-standard VPN solution${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports UDP and TCP protocols${NC}" \
        "${GREEN}▶${NC} ${WHITE}Works on virtually all platforms${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can traverse most firewalls${NC}" \
        "${GREEN}▶${NC} ${WHITE}Highly configurable${NC}" \
        "${GREEN}▶${NC} ${WHITE}SSL/TLS-based security${NC}"

    if ! confirm_prompt "Deploy OpenVPN?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing OpenVPN deployment sequence..." "$GREEN"
    echo ""

    # ─── Protocol Selection ───────────────────────────────────────────────
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Protocol:${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}UDP ${GRAY}─ Faster, recommended for most users${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}TCP ${GRAY}─ More reliable, works through firewalls${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose protocol" "1"
    read -r proto_choice
    case $proto_choice in
        2) OVPN_PROTO="tcp" ;;
        *) OVPN_PROTO="udp" ;;
    esac

    # Port
    local default_port
    [[ "$OVPN_PROTO" == "udp" ]] && default_port="1194" || default_port="443"
    styled_prompt "Port number" "$default_port"
    read -r OVPN_PORT
    OVPN_PORT=${OVPN_PORT:-$default_port}

    # DNS
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select DNS Provider:${NC}                                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Cloudflare    ${GRAY}(1.1.1.1)${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Google        ${GRAY}(8.8.8.8)${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Quad9         ${GRAY}(9.9.9.9)${NC}                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}System DNS${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose DNS" "1"
    read -r dns_choice
    case $dns_choice in
        1) OVPN_DNS1="1.1.1.1"; OVPN_DNS2="1.0.0.1" ;;
        2) OVPN_DNS1="8.8.8.8"; OVPN_DNS2="8.8.4.4" ;;
        3) OVPN_DNS1="9.9.9.9"; OVPN_DNS2="149.112.112.112" ;;
        4) OVPN_DNS1=""; OVPN_DNS2="" ;;
        *) OVPN_DNS1="1.1.1.1"; OVPN_DNS2="1.0.0.1" ;;
    esac

    # Encryption
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Encryption Level:${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}AES-128-GCM  ${GRAY}─ Fast, very secure${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}AES-256-GCM  ${GRAY}─ Maximum security (recommended)${NC}      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}AES-256-CBC  ${GRAY}─ Compatible, slower${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose encryption" "2"
    read -r enc_choice
    case $enc_choice in
        1) OVPN_CIPHER="AES-128-GCM" ;;
        3) OVPN_CIPHER="AES-256-CBC" ;;
        *) OVPN_CIPHER="AES-256-GCM" ;;
    esac

    # Compression
    echo ""
    if confirm_prompt "Enable compression? (may reduce throughput)" "n"; then
        OVPN_COMPRESS="compress lz4-v2"
    else
        OVPN_COMPRESS=""
    fi

    # Client name
    styled_prompt "First client name" "client1"
    read -r OVPN_CLIENT_NAME
    OVPN_CLIENT_NAME=${OVPN_CLIENT_NAME:-"client1"}

    # Confirmation
    echo ""
    info_box "DEPLOYMENT SUMMARY" \
        "${GREEN}▶${NC} ${WHITE}Protocol:   ${BRIGHT_GREEN}${OVPN_PROTO^^}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:       ${BRIGHT_GREEN}${OVPN_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Cipher:     ${BRIGHT_GREEN}${OVPN_CIPHER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Client:     ${BRIGHT_GREEN}${OVPN_CLIENT_NAME}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server IP:  ${BRIGHT_YELLOW}${SERVER_IP}${NC}"

    if ! confirm_prompt "Proceed with installation?"; then
        warning_msg "Deployment aborted!"
        return
    fi

    echo ""
    typewriter "  [*] Starting OpenVPN deployment..." "$GREEN"
    echo ""

    # ─── Installation Process ─────────────────────────────────────────────

    # Step 1: Install dependencies
    echo -e "  ${BRIGHT_CYAN}[Step 1/8]${NC} ${WHITE}Installing dependencies...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1
                apt-get install -y -qq openvpn easy-rsa openssl ca-certificates iptables > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux)
                dnf install -y -q epel-release > /dev/null 2>&1
                dnf install -y -q openvpn easy-rsa openssl > /dev/null 2>&1
                ;;
            fedora)
                dnf install -y -q openvpn easy-rsa openssl > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -S --noconfirm openvpn easy-rsa openssl > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Installing OpenVPN & Easy-RSA"

    # Step 2: Setup Easy-RSA PKI
    echo -e "  ${BRIGHT_CYAN}[Step 2/8]${NC} ${WHITE}Setting up PKI infrastructure...${NC}"
    (
        EASYRSA_DIR="/etc/openvpn/easy-rsa"
        mkdir -p "$EASYRSA_DIR"

        # Find easy-rsa location
        if [[ -d /usr/share/easy-rsa ]]; then
            cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
        elif [[ -d /usr/share/easy-rsa/3 ]]; then
            cp -r /usr/share/easy-rsa/3/* "$EASYRSA_DIR/"
        fi

        cd "$EASYRSA_DIR" || exit

        # Initialize PKI
        ./easyrsa --batch init-pki > /dev/null 2>&1

        sleep 1
    ) &
    spinner $! "Initializing Public Key Infrastructure"

    # Step 3: Build CA
    echo -e "  ${BRIGHT_CYAN}[Step 3/8]${NC} ${WHITE}Building Certificate Authority...${NC}"
    (
        cd "/etc/openvpn/easy-rsa" || exit
        EASYRSA_BATCH=1 ./easyrsa --batch build-ca nopass > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Building CA (this may take a moment)"

    # Step 4: Generate server certificate
    echo -e "  ${BRIGHT_CYAN}[Step 4/8]${NC} ${WHITE}Generating server certificate...${NC}"
    (
        cd "/etc/openvpn/easy-rsa" || exit
        EASYRSA_BATCH=1 ./easyrsa --batch build-server-full server nopass > /dev/null 2>&1
        EASYRSA_BATCH=1 ./easyrsa --batch gen-dh > /dev/null 2>&1
        openvpn --genkey secret /etc/openvpn/tls-crypt.key > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Generating server certificates & DH parameters"

    # Step 5: Generate client certificate
    echo -e "  ${BRIGHT_CYAN}[Step 5/8]${NC} ${WHITE}Generating client certificate...${NC}"
    (
        cd "/etc/openvpn/easy-rsa" || exit
        EASYRSA_BATCH=1 ./easyrsa --batch build-client-full "$OVPN_CLIENT_NAME" nopass > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Generating client certificate for ${OVPN_CLIENT_NAME}"

    # Step 6: Copy certificates
    echo -e "  ${BRIGHT_CYAN}[Step 6/8]${NC} ${WHITE}Installing certificates...${NC}"
    (
        cd "/etc/openvpn/easy-rsa" || exit
        cp pki/ca.crt /etc/openvpn/ 2>/dev/null
        cp pki/issued/server.crt /etc/openvpn/ 2>/dev/null
        cp pki/private/server.key /etc/openvpn/ 2>/dev/null
        cp pki/dh.pem /etc/openvpn/ 2>/dev/null
        sleep 0.5
    ) &
    spinner $! "Installing certificates"

    # Step 7: Create server config
    echo -e "  ${BRIGHT_CYAN}[Step 7/8]${NC} ${WHITE}Creating server configuration...${NC}"
    (
        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

        cat > /etc/openvpn/server.conf << OVPNEOF
# ═══════════════════════════════════════════════════════════
# OpenVPN Server Configuration
# Generated by VPN Blast v${SCRIPT_VERSION}
# Date: $(date)
# ═══════════════════════════════════════════════════════════

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
OVPNEOF

        # Add DNS push directives
        if [[ -n "$OVPN_DNS1" ]]; then
            echo "push \"dhcp-option DNS ${OVPN_DNS1}\"" >> /etc/openvpn/server.conf
            [[ -n "$OVPN_DNS2" ]] && echo "push \"dhcp-option DNS ${OVPN_DNS2}\"" >> /etc/openvpn/server.conf
        fi

        cat >> /etc/openvpn/server.conf << OVPNEOF2

keepalive 10 120
cipher ${OVPN_CIPHER}
auth SHA256
${OVPN_COMPRESS}
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
explicit-exit-notify 1
OVPNEOF2

        # Enable IP forwarding
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi

        # Configure iptables
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$SERVER_NIC" -j MASQUERADE 2>/dev/null
        iptables -I INPUT -p "$OVPN_PROTO" --dport "$OVPN_PORT" -j ACCEPT 2>/dev/null
        iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT 2>/dev/null
        iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null

        sleep 1
    ) &
    spinner $! "Creating server configuration"

    # Step 8: Create client .ovpn file and start service
    echo -e "  ${BRIGHT_CYAN}[Step 8/8]${NC} ${WHITE}Generating client profile & starting service...${NC}"
    (
        mkdir -p /etc/openvpn/clients

        # Create .ovpn client file
        cat > "/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn" << CLIENTEOF
# ═══════════════════════════════════════════════════════════
# OpenVPN Client Configuration: ${OVPN_CLIENT_NAME}
# Generated by VPN Blast v${SCRIPT_VERSION}
# Server: ${SERVER_IP}
# ═══════════════════════════════════════════════════════════

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
${OVPN_COMPRESS}
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

        # Start OpenVPN
        systemctl enable openvpn@server > /dev/null 2>&1
        systemctl start openvpn@server > /dev/null 2>&1

        # Firewall
        if command -v ufw &> /dev/null; then
            ufw allow "$OVPN_PORT"/"$OVPN_PROTO" > /dev/null 2>&1
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port="$OVPN_PORT"/"$OVPN_PROTO" > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi

        sleep 1
    ) &
    spinner $! "Generating client profile & activating service"

    # ─── Success Output ──────────────────────────────────────────────────
    echo ""
    success_msg "OpenVPN Deployed Successfully!"

    info_box "CLIENT CONFIGURATION" \
        "${GREEN}▶${NC} ${WHITE}Config file: ${BRIGHT_GREEN}/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}Download via SCP:${NC}" \
        "  ${GRAY}scp root@${SERVER_IP}:/etc/openvpn/clients/${OVPN_CLIENT_NAME}.ovpn ./${NC}"

    info_box "CLIENT SETUP INSTRUCTIONS" \
        "${BRIGHT_YELLOW}📱 Mobile (iOS/Android):${NC}" \
        "  ${WHITE}1. Install OpenVPN Connect from App Store/Play Store${NC}" \
        "  ${WHITE}2. Transfer .ovpn file to your device${NC}" \
        "  ${WHITE}3. Import the profile and connect${NC}" \
        "" \
        "${BRIGHT_YELLOW}💻 Windows:${NC}" \
        "  ${WHITE}1. Install OpenVPN GUI from openvpn.net${NC}" \
        "  ${WHITE}2. Place .ovpn in C:\\Users\\<you>\\OpenVPN\\config${NC}" \
        "  ${WHITE}3. Right-click tray icon → Connect${NC}" \
        "" \
        "${BRIGHT_YELLOW}🐧 Linux:${NC}" \
        "  ${GRAY}sudo openvpn --config ${OVPN_CLIENT_NAME}.ovpn${NC}" \
        "  ${WHITE}Or import in NetworkManager${NC}"

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
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT IKEv2/IPsec" \
        "${GREEN}▶${NC} ${WHITE}Native support on iOS, macOS, Windows, Android${NC}" \
        "${GREEN}▶${NC} ${WHITE}No third-party app needed on most devices${NC}" \
        "${GREEN}▶${NC} ${WHITE}Strong security with IKEv2 key exchange${NC}" \
        "${GREEN}▶${NC} ${WHITE}Excellent for mobile (handles network switches)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Uses strongSwan as the implementation${NC}"

    if ! confirm_prompt "Deploy IKEv2/IPsec VPN?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing IKEv2/IPsec deployment..." "$GREEN"
    echo ""

    # ─── Configuration ────────────────────────────────────────────────────

    styled_prompt "VPN client username" "vpnuser"
    read -r IKEV2_USER
    IKEV2_USER=${IKEV2_USER:-"vpnuser"}

    styled_prompt "VPN client password (leave empty to auto-generate)"
    read -rs IKEV2_PASS
    echo ""
    if [[ -z "$IKEV2_PASS" ]]; then
        IKEV2_PASS=$(openssl rand -base64 16 2>/dev/null || head -c 16 /dev/urandom | base64)
        echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated password: ${BRIGHT_YELLOW}${IKEV2_PASS}${NC}"
    fi

    styled_prompt "VPN subnet" "10.10.10.0/24"
    read -r IKEV2_SUBNET
    IKEV2_SUBNET=${IKEV2_SUBNET:-"10.10.10.0/24"}

    # DNS
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select DNS:${NC}                                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Cloudflare  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Google  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Quad9${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    styled_prompt "Choose" "1"
    read -r dns_choice
    case $dns_choice in
        2) IKEV2_DNS="8.8.8.8,8.8.4.4" ;;
        3) IKEV2_DNS="9.9.9.9,149.112.112.112" ;;
        *) IKEV2_DNS="1.1.1.1,1.0.0.1" ;;
    esac

    # Confirmation
    echo ""
    info_box "DEPLOYMENT SUMMARY" \
        "${GREEN}▶${NC} ${WHITE}Username: ${BRIGHT_GREEN}${IKEV2_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Subnet:   ${BRIGHT_GREEN}${IKEV2_SUBNET}${NC}" \
        "${GREEN}▶${NC} ${WHITE}DNS:      ${BRIGHT_GREEN}${IKEV2_DNS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}"

    if ! confirm_prompt "Proceed?"; then
        return
    fi

    echo ""

    # ─── Installation ─────────────────────────────────────────────────────

    echo -e "  ${BRIGHT_CYAN}[Step 1/5]${NC} ${WHITE}Installing strongSwan...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1
                apt-get install -y -qq strongswan strongswan-pki libcharon-extra-plugins \
                    libcharon-extauth-plugins libstrongswan-extra-plugins libtss2-tcti-tabrmd0 > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf install -y -q epel-release > /dev/null 2>&1
                dnf install -y -q strongswan > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -S --noconfirm strongswan > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Installing strongSwan"

    echo -e "  ${BRIGHT_CYAN}[Step 2/5]${NC} ${WHITE}Generating certificates...${NC}"
    (
        mkdir -p /etc/ipsec.d/{cacerts,certs,private}

        # Generate CA key and certificate
        ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/ca-key.pem 2>/dev/null
        ipsec pki --self --ca --lifetime 3650 --in /etc/ipsec.d/private/ca-key.pem \
            --type rsa --dn "CN=VPN Blast CA" --outform pem > /etc/ipsec.d/cacerts/ca-cert.pem 2>/dev/null

        # Generate server key and certificate
        ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/ipsec.d/private/server-key.pem 2>/dev/null
        ipsec pki --pub --in /etc/ipsec.d/private/server-key.pem --type rsa | \
            ipsec pki --issue --lifetime 1825 \
            --cacert /etc/ipsec.d/cacerts/ca-cert.pem \
            --cakey /etc/ipsec.d/private/ca-key.pem \
            --dn "CN=${SERVER_IP}" --san "${SERVER_IP}" \
            --flag serverAuth --flag ikeIntermediate --outform pem \
            > /etc/ipsec.d/certs/server-cert.pem 2>/dev/null

        chmod 600 /etc/ipsec.d/private/*
        sleep 1
    ) &
    spinner $! "Generating PKI certificates"

    echo -e "  ${BRIGHT_CYAN}[Step 3/5]${NC} ${WHITE}Configuring strongSwan...${NC}"
    (
        # ipsec.conf
        cat > /etc/ipsec.conf << IPSECEOF
# ═══════════════════════════════════════════════════════════
# strongSwan IKEv2 Configuration
# Generated by VPN Blast v${SCRIPT_VERSION}
# ═══════════════════════════════════════════════════════════

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

        # ipsec.secrets
        cat > /etc/ipsec.secrets << SECRETSEOF
# ═══════════════════════════════════════════════════════════
# strongSwan Secrets
# Generated by VPN Blast v${SCRIPT_VERSION}
# ═══════════════════════════════════════════════════════════

: RSA "server-key.pem"
${IKEV2_USER} : EAP "${IKEV2_PASS}"
SECRETSEOF

        chmod 600 /etc/ipsec.secrets
        sleep 1
    ) &
    spinner $! "Writing strongSwan configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 4/5]${NC} ${WHITE}Configuring networking...${NC}"
    (
        SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

        # IP forwarding
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null 2>&1
        sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null 2>&1
        sysctl -w net.ipv4.ip_no_pmtu_disc=1 > /dev/null 2>&1

        cat >> /etc/sysctl.conf << SYSCTLEOF
# IKEv2 VPN settings
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.ip_no_pmtu_disc=1
SYSCTLEOF

        # Firewall rules
        iptables -t nat -A POSTROUTING -s "$IKEV2_SUBNET" -o "$SERVER_NIC" -j MASQUERADE 2>/dev/null
        iptables -A INPUT -p udp --dport 500 -j ACCEPT 2>/dev/null
        iptables -A INPUT -p udp --dport 4500 -j ACCEPT 2>/dev/null

        if command -v ufw &> /dev/null; then
            ufw allow 500/udp > /dev/null 2>&1
            ufw allow 4500/udp > /dev/null 2>&1
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-service=ipsec > /dev/null 2>&1
            firewall-cmd --permanent --add-port=500/udp > /dev/null 2>&1
            firewall-cmd --permanent --add-port=4500/udp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi

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

    # ─── Success ──────────────────────────────────────────────────────────
    echo ""
    success_msg "IKEv2/IPsec Deployed Successfully!"

    info_box "CONNECTION CREDENTIALS" \
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Type:     ${BRIGHT_GREEN}IKEv2${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username: ${BRIGHT_GREEN}${IKEV2_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password: ${BRIGHT_YELLOW}${IKEV2_PASS}${NC}" \
        "" \
        "${RED}▶${NC} ${WHITE}CA Certificate: ${GRAY}/etc/ipsec.d/cacerts/ca-cert.pem${NC}" \
        "  ${GRAY}scp root@${SERVER_IP}:/etc/ipsec.d/cacerts/ca-cert.pem ./${NC}"

    info_box "CLIENT SETUP INSTRUCTIONS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC}" \
        "  ${WHITE}Settings → General → VPN → Add VPN Config${NC}" \
        "  ${WHITE}Type: IKEv2 → Server: ${SERVER_IP}${NC}" \
        "  ${WHITE}Remote ID: ${SERVER_IP} → Auth: Username${NC}" \
        "  ${WHITE}Import CA cert via email/AirDrop first${NC}" \
        "" \
        "${BRIGHT_YELLOW}📱 Android:${NC}" \
        "  ${WHITE}Settings → Network → VPN → Add VPN${NC}" \
        "  ${WHITE}Type: IKEv2/IPSec MSCHAPv2${NC}" \
        "" \
        "${BRIGHT_YELLOW}💻 Windows 10/11:${NC}" \
        "  ${WHITE}Settings → Network → VPN → Add VPN${NC}" \
        "  ${WHITE}Provider: Windows built-in${NC}" \
        "  ${WHITE}Type: IKEv2 → Server: ${SERVER_IP}${NC}" \
        "" \
        "${BRIGHT_YELLOW}🍎 macOS:${NC}" \
        "  ${WHITE}System Preferences → Network → + → VPN${NC}" \
        "  ${WHITE}Type: IKEv2 → Server: ${SERVER_IP}${NC}"

    log "INFO" "IKEv2/IPsec installed successfully"

    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# SOFTETHER VPN INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_softether() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🌐  ${BOLD}${WHITE}SOFTETHER VPN DEPLOYMENT${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT SOFTETHER VPN" \
        "${GREEN}▶${NC} ${WHITE}Multi-protocol VPN server${NC}" \
        "${GREEN}▶${NC} ${WHITE}Supports SSL-VPN, L2TP, OpenVPN, SSTP${NC}" \
        "${GREEN}▶${NC} ${WHITE}NAT traversal built-in${NC}" \
        "${GREEN}▶${NC} ${WHITE}High-performance, academic project from Japan${NC}" \
        "${GREEN}▶${NC} ${WHITE}GUI management tool available${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can clone as HTTPS traffic on port 443${NC}"

    if ! confirm_prompt "Deploy SoftEther VPN?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing SoftEther deployment..." "$GREEN"
    echo ""

    # ─── Configuration ────────────────────────────────────────────────────

    styled_prompt "Admin password for SoftEther (leave empty to auto-generate)"
    read -rs SE_ADMIN_PASS
    echo ""
    if [[ -z "$SE_ADMIN_PASS" ]]; then
        SE_ADMIN_PASS=$(openssl rand -base64 16 2>/dev/null || head -c 16 /dev/urandom | base64)
        echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated password: ${BRIGHT_YELLOW}${SE_ADMIN_PASS}${NC}"
    fi

    styled_prompt "Hub name" "VPN"
    read -r SE_HUB
    SE_HUB=${SE_HUB:-"VPN"}

    styled_prompt "VPN username" "vpnuser"
    read -r SE_USER
    SE_USER=${SE_USER:-"vpnuser"}

    styled_prompt "VPN user password (leave empty to auto-generate)"
    read -rs SE_USER_PASS
    echo ""
    if [[ -z "$SE_USER_PASS" ]]; then
        SE_USER_PASS=$(openssl rand -base64 12 2>/dev/null || head -c 12 /dev/urandom | base64)
        echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated password: ${BRIGHT_YELLOW}${SE_USER_PASS}${NC}"
    fi

    echo ""
    if ! confirm_prompt "Proceed with installation?"; then
        return
    fi

    echo ""

    # ─── Installation ─────────────────────────────────────────────────────

    echo -e "  ${BRIGHT_CYAN}[Step 1/5]${NC} ${WHITE}Installing build dependencies...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1
                apt-get install -y -qq build-essential wget curl gcc make \
                    libreadline-dev libssl-dev libncurses5-dev zlib1g-dev > /dev/null 2>&1
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf groupinstall -y -q "Development Tools" > /dev/null 2>&1
                dnf install -y -q readline-devel openssl-devel ncurses-devel wget curl > /dev/null 2>&1
                ;;
            arch|manjaro)
                pacman -S --noconfirm base-devel readline openssl ncurses wget curl > /dev/null 2>&1
                ;;
        esac
    ) &
    spinner $! "Installing build dependencies"

    echo -e "  ${BRIGHT_CYAN}[Step 2/5]${NC} ${WHITE}Downloading SoftEther VPN Server...${NC}"
    (
        cd /tmp || exit
        # Get latest SoftEther (v4)
        SE_URL="https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz"
        wget -q "$SE_URL" -O softether-vpnserver.tar.gz 2>/dev/null || \
        curl -sL "$SE_URL" -o softether-vpnserver.tar.gz 2>/dev/null
        tar xzf softether-vpnserver.tar.gz > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Downloading SoftEther"

    echo -e "  ${BRIGHT_CYAN}[Step 3/5]${NC} ${WHITE}Compiling SoftEther (this may take a while)...${NC}"
    (
        cd /tmp/vpnserver || exit
        echo -e "1\n1\n1" | make > /dev/null 2>&1
        mv /tmp/vpnserver /usr/local/vpnserver
        chmod 600 /usr/local/vpnserver/*
        chmod 700 /usr/local/vpnserver/vpnserver
        chmod 700 /usr/local/vpnserver/vpncmd
        sleep 1
    ) &
    spinner $! "Compiling SoftEther VPN Server"

    echo -e "  ${BRIGHT_CYAN}[Step 4/5]${NC} ${WHITE}Creating systemd service...${NC}"
    (
        cat > /etc/systemd/system/softether-vpnserver.service << SEEOF
[Unit]
Description=SoftEther VPN Server
After=network.target auditd.service
ConditionPathExists=!/usr/local/vpnserver/do_not_run

[Service]
Type=forking
EnvironmentFile=-/usr/local/vpnserver
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255

[Install]
WantedBy=multi-user.target
SEEOF

        systemctl daemon-reload
        systemctl enable softether-vpnserver > /dev/null 2>&1
        systemctl start softether-vpnserver > /dev/null 2>&1
        sleep 2
    ) &
    spinner $! "Creating & starting service"

    echo -e "  ${BRIGHT_CYAN}[Step 5/5]${NC} ${WHITE}Configuring VPN Hub & Users...${NC}"
    (
        VPNCMD="/usr/local/vpnserver/vpncmd"

        # Set admin password
        $VPNCMD localhost /SERVER /CMD ServerPasswordSet "$SE_ADMIN_PASS" > /dev/null 2>&1

        # Create hub
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /CMD HubCreate "$SE_HUB" /PASSWORD:"$SE_ADMIN_PASS" > /dev/null 2>&1

        # Create user
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD UserCreate "$SE_USER" /GROUP:none /REALNAME:none /NOTE:none > /dev/null 2>&1
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD UserPasswordSet "$SE_USER" /PASSWORD:"$SE_USER_PASS" > /dev/null 2>&1

        # Enable SecureNAT
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /HUB:"$SE_HUB" /CMD SecureNatEnable > /dev/null 2>&1

        # Enable L2TP/IPsec
        $VPNCMD localhost /SERVER /PASSWORD:"$SE_ADMIN_PASS" /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:vpnblast /DEFAULTHUB:"$SE_HUB" > /dev/null 2>&1

        # Enable IP forwarding
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

        sleep 1
    ) &
    spinner $! "Configuring hub, users & protocols"

    # ─── Success ──────────────────────────────────────────────────────────
    echo ""
    success_msg "SoftEther VPN Deployed!"

    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:         ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Admin Password: ${BRIGHT_YELLOW}${SE_ADMIN_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Hub:            ${BRIGHT_GREEN}${SE_HUB}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Username:       ${BRIGHT_GREEN}${SE_USER}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password:       ${BRIGHT_YELLOW}${SE_USER_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}L2TP PSK:       ${BRIGHT_YELLOW}vpnblast${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}Ports: 443/tcp, 992/tcp, 1194/tcp+udp, 5555/tcp${NC}" \
        "${GREEN}▶${NC} ${WHITE}L2TP: 500/udp, 4500/udp${NC}"

    info_box "MANAGEMENT" \
        "${WHITE}Download SoftEther VPN Server Manager (GUI):${NC}" \
        "  ${GRAY}https://www.softether-download.com${NC}" \
        "" \
        "${WHITE}Connect manager to: ${BRIGHT_YELLOW}${SERVER_IP}:5555${NC}" \
        "" \
        "${WHITE}CLI Management:${NC}" \
        "  ${GRAY}/usr/local/vpnserver/vpncmd${NC}"

    log "INFO" "SoftEther VPN installed successfully"

    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTLINE VPN INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_outline() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🔥  ${BOLD}${WHITE}OUTLINE VPN DEPLOYMENT${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT OUTLINE VPN" \
        "${GREEN}▶${NC} ${WHITE}Created by Jigsaw (Google subsidiary)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Designed to resist censorship${NC}" \
        "${GREEN}▶${NC} ${WHITE}Based on Shadowsocks protocol${NC}" \
        "${GREEN}▶${NC} ${WHITE}Easy to share access with others${NC}" \
        "${GREEN}▶${NC} ${WHITE}Clients for all major platforms${NC}" \
        "${GREEN}▶${NC} ${WHITE}Runs in Docker containers${NC}"

    if ! confirm_prompt "Deploy Outline VPN?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing Outline VPN deployment..." "$GREEN"
    echo ""

    # Step 1: Install Docker
    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing Docker...${NC}"
    (
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
            systemctl enable docker > /dev/null 2>&1
            systemctl start docker > /dev/null 2>&1
        fi
        sleep 1
    ) &
    spinner $! "Installing Docker"

    # Step 2: Install Outline
    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Deploying Outline Server...${NC}"
    echo ""
    echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}Running Outline installer (output below):${NC}"
    echo -e "  ${GRAY}────────────────────────────────────────────────────────${NC}"

    # Run the Outline installer
    bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)" 2>&1 | tee /tmp/outline_install.log

    echo -e "  ${GRAY}────────────────────────────────────────────────────────${NC}"

    # Step 3: Extract API URL
    echo ""
    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Extracting configuration...${NC}"

    OUTLINE_API=$(grep -o 'https://[^"]*' /tmp/outline_install.log 2>/dev/null | head -1)

    echo ""
    success_msg "Outline VPN Deployed!"

    info_box "SETUP INSTRUCTIONS" \
        "${BRIGHT_YELLOW}Step 1: Install Outline Manager${NC}" \
        "  ${WHITE}Download from: ${GRAY}https://getoutline.org${NC}" \
        "" \
        "${BRIGHT_YELLOW}Step 2: Add your server${NC}" \
        "  ${WHITE}Copy the API URL from the output above${NC}" \
        "  ${WHITE}Paste it into Outline Manager${NC}" \
        "" \
        "${BRIGHT_YELLOW}Step 3: Create access keys${NC}" \
        "  ${WHITE}Use Outline Manager to create keys${NC}" \
        "  ${WHITE}Share keys with users${NC}" \
        "" \
        "${BRIGHT_YELLOW}Step 4: Connect${NC}" \
        "  ${WHITE}Install Outline Client on devices${NC}" \
        "  ${WHITE}Paste access key to connect${NC}"

    if [[ -n "$OUTLINE_API" ]]; then
        echo -e "  ${BRIGHT_GREEN}API URL:${NC} ${WHITE}${OUTLINE_API}${NC}"
    fi

    log "INFO" "Outline VPN installed successfully"

    echo -e "\n  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHADOWSOCKS INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════

install_shadowsocks() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}🕶️   ${BOLD}${WHITE}SHADOWSOCKS DEPLOYMENT${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT SHADOWSOCKS" \
        "${GREEN}▶${NC} ${WHITE}SOCKS5 based proxy${NC}" \
        "${GREEN}▶${NC} ${WHITE}Designed to bypass censorship${NC}" \
        "${GREEN}▶${NC} ${WHITE}Lightweight and fast${NC}" \
        "${GREEN}▶${NC} ${WHITE}Multiple encryption methods${NC}" \
        "${GREEN}▶${NC} ${WHITE}Using shadowsocks-rust (latest implementation)${NC}"

    if ! confirm_prompt "Deploy Shadowsocks?"; then
        return
    fi

    echo ""
    typewriter "  [*] Initializing Shadowsocks deployment..." "$GREEN"
    echo ""

    # ─── Configuration ────────────────────────────────────────────────────

    styled_prompt "Port" "8388"
    read -r SS_PORT
    SS_PORT=${SS_PORT:-8388}

    styled_prompt "Password (leave empty to auto-generate)"
    read -rs SS_PASS
    echo ""
    if [[ -z "$SS_PASS" ]]; then
        SS_PASS=$(openssl rand -base64 24 2>/dev/null || head -c 24 /dev/urandom | base64)
        echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated password: ${BRIGHT_YELLOW}${SS_PASS}${NC}"
    fi

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Encryption Method:${NC}                                ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}aes-256-gcm          ${GRAY}(recommended, fast)${NC}          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}chacha20-ietf-poly1305 ${GRAY}(great for mobile)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}2022-blake3-aes-256-gcm ${GRAY}(newest, most secure)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}2022-blake3-chacha20-poly1305${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose encryption" "1"
    read -r enc_choice
    case $enc_choice in
        2) SS_METHOD="chacha20-ietf-poly1305" ;;
        3) SS_METHOD="2022-blake3-aes-256-gcm"
           SS_PASS=$(openssl rand -base64 32)
           echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}2022 methods require base64 key: ${BRIGHT_YELLOW}${SS_PASS}${NC}"
           ;;
        4) SS_METHOD="2022-blake3-chacha20-poly1305"
           SS_PASS=$(openssl rand -base64 32)
           echo -e "  ${BRIGHT_YELLOW}[!]${NC} ${WHITE}2022 methods require base64 key: ${BRIGHT_YELLOW}${SS_PASS}${NC}"
           ;;
        *) SS_METHOD="aes-256-gcm" ;;
    esac

    echo ""
    if ! confirm_prompt "Proceed?"; then
        return
    fi

    echo ""

    # ─── Installation ─────────────────────────────────────────────────────

    echo -e "  ${BRIGHT_CYAN}[Step 1/3]${NC} ${WHITE}Installing shadowsocks-rust...${NC}"
    (
        case $OS in
            ubuntu|debian)
                apt-get update -qq > /dev/null 2>&1

                # Try snap first, then manual install
                if command -v snap &> /dev/null; then
                    snap install shadowsocks-rust > /dev/null 2>&1 && SS_BIN="shadowsocks-rust.ssserver"
                fi

                if [[ -z "$SS_BIN" ]]; then
                    # Download latest release
                    local arch
                    arch=$(uname -m)
                    [[ "$arch" == "x86_64" ]] && arch="x86_64-unknown-linux-gnu"
                    [[ "$arch" == "aarch64" ]] && arch="aarch64-unknown-linux-gnu"

                    local latest_url
                    latest_url=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | \
                        grep "browser_download_url.*${arch}.*tar" | head -1 | cut -d'"' -f4)

                    if [[ -n "$latest_url" ]]; then
                        wget -q "$latest_url" -O /tmp/ss-rust.tar.xz 2>/dev/null
                        mkdir -p /tmp/ss-rust
                        tar xf /tmp/ss-rust.tar.xz -C /tmp/ss-rust 2>/dev/null
                        cp /tmp/ss-rust/ssserver /usr/local/bin/ 2>/dev/null
                        chmod +x /usr/local/bin/ssserver
                        SS_BIN="ssserver"
                    fi
                fi

                # Fallback to shadowsocks-libev
                if [[ -z "$SS_BIN" ]]; then
                    apt-get install -y -qq shadowsocks-libev > /dev/null 2>&1
                    SS_BIN="ss-server"
                fi
                ;;
            centos|rhel|rocky|almalinux|fedora)
                dnf install -y -q epel-release > /dev/null 2>&1
                dnf install -y -q shadowsocks-libev > /dev/null 2>&1
                SS_BIN="ss-server"
                ;;
            arch|manjaro)
                pacman -S --noconfirm shadowsocks-rust > /dev/null 2>&1
                SS_BIN="ssserver"
                ;;
        esac
    ) &
    spinner $! "Installing Shadowsocks"

    echo -e "  ${BRIGHT_CYAN}[Step 2/3]${NC} ${WHITE}Creating configuration...${NC}"
    (
        mkdir -p /etc/shadowsocks

        cat > /etc/shadowsocks/config.json << SSEOF
{
    "server": "0.0.0.0",
    "server_port": ${SS_PORT},
    "password": "${SS_PASS}",
    "method": "${SS_METHOD}",
    "timeout": 300,
    "mode": "tcp_and_udp",
    "fast_open": true,
    "no_delay": true
}
SSEOF

        chmod 600 /etc/shadowsocks/config.json

        # Create systemd service
        local ss_bin_path
        ss_bin_path=$(which "${SS_BIN:-ssserver}" 2>/dev/null || echo "/usr/local/bin/ssserver")

        cat > /etc/systemd/system/shadowsocks.service << SSSERVEOF
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
Type=simple
ExecStart=${ss_bin_path} -c /etc/shadowsocks/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SSSERVEOF

        sleep 1
    ) &
    spinner $! "Creating configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting service...${NC}"
    (
        # Firewall
        if command -v ufw &> /dev/null; then
            ufw allow "$SS_PORT" > /dev/null 2>&1
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port="$SS_PORT"/tcp > /dev/null 2>&1
            firewall-cmd --permanent --add-port="$SS_PORT"/udp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi

        systemctl daemon-reload
        systemctl enable shadowsocks > /dev/null 2>&1
        systemctl start shadowsocks > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting Shadowsocks service"

    # Generate SS URI for easy import
    SS_URI="ss://$(echo -n "${SS_METHOD}:${SS_PASS}" | base64 -w0)@${SERVER_IP}:${SS_PORT}"

    # ─── Success ──────────────────────────────────────────────────────────
    echo ""
    success_msg "Shadowsocks Deployed!"

    info_box "CONNECTION DETAILS" \
        "${GREEN}▶${NC} ${WHITE}Server:     ${BRIGHT_YELLOW}${SERVER_IP}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Port:       ${BRIGHT_GREEN}${SS_PORT}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Password:   ${BRIGHT_YELLOW}${SS_PASS}${NC}" \
        "${GREEN}▶${NC} ${WHITE}Method:     ${BRIGHT_GREEN}${SS_METHOD}${NC}" \
        "" \
        "${GREEN}▶${NC} ${WHITE}SS URI:${NC}" \
        "  ${GRAY}${SS_URI}${NC}"

    info_box "CLIENT APPS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Shadowrocket, Potatso${NC}" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}Shadowsocks (Play Store)${NC}" \
        "${BRIGHT_YELLOW}💻 Windows:${NC} ${WHITE}Shadowsocks-windows${NC}" \
        "${BRIGHT_YELLOW}🍎 macOS:${NC} ${WHITE}ShadowsocksX-NG${NC}" \
        "${BRIGHT_YELLOW}🐧 Linux:${NC} ${WHITE}shadowsocks-rust / ss-local${NC}"

    log "INFO" "Shadowsocks installed successfully"

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
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    info_box "ABOUT V2RAY/XRAY" \
        "${GREEN}▶${NC} ${WHITE}Advanced proxy/tunneling platform${NC}" \
        "${GREEN}▶${NC} ${WHITE}Multiple protocols: VMess, VLESS, Trojan${NC}" \
        "${GREEN}▶${NC} ${WHITE}Traffic obfuscation (WebSocket, gRPC, HTTP/2)${NC}" \
        "${GREEN}▶${NC} ${WHITE}Can disguise as normal HTTPS traffic${NC}" \
        "${GREEN}▶${NC} ${WHITE}Xray is an enhanced fork with XTLS${NC}" \
        "${GREEN}▶${NC} ${WHITE}Excellent for bypassing DPI${NC}"

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Implementation:${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Xray-core   ${GRAY}(recommended, newer, XTLS support)${NC}    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}V2Ray-core  ${GRAY}(original, stable)${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose" "1"
    read -r v2_impl
    [[ "$v2_impl" == "2" ]] && V2_ENGINE="v2ray" || V2_ENGINE="xray"

    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select Protocol:${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}VLESS + WebSocket + TLS  ${GRAY}(recommended)${NC}            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}VLESS + TCP + XTLS       ${GRAY}(fastest)${NC}                ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}VMess + WebSocket        ${GRAY}(most compatible)${NC}        ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}VMess + TCP              ${GRAY}(simple)${NC}                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Trojan + WebSocket       ${GRAY}(stealth)${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose protocol" "3"
    read -r v2_proto
    v2_proto=${v2_proto:-3}

    styled_prompt "Port" "443"
    read -r V2_PORT
    V2_PORT=${V2_PORT:-443}

    # Generate UUID
    V2_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || \
        python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "$(head -c 16 /dev/urandom | xxd -p)")

    echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated UUID: ${BRIGHT_YELLOW}${V2_UUID}${NC}"

    if [[ "$v2_proto" =~ ^[135]$ ]]; then
        styled_prompt "WebSocket path" "/ws"
        read -r V2_WS_PATH
        V2_WS_PATH=${V2_WS_PATH:-"/ws"}
    fi

    echo ""
    if ! confirm_prompt "Proceed with installation?"; then
        return
    fi

    echo ""
    typewriter "  [*] Deploying ${V2_ENGINE}..." "$GREEN"
    echo ""

    # ─── Installation ─────────────────────────────────────────────────────

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
            1) # VLESS + WebSocket
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "${V2_UUID}", "level": 0}],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "${V2_WS_PATH}"}
        }
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
            2) # VLESS + TCP + XTLS
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "${V2_UUID}", "flow": "xtls-rprx-vision", "level": 0}],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp",
            "security": "tls",
            "tlsSettings": {"certificates": [{"certificateFile": "/usr/local/etc/xray/cert.pem", "keyFile": "/usr/local/etc/xray/key.pem"}]}
        }
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                # Generate self-signed cert
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
                    -subj "/CN=${SERVER_IP}" \
                    -keyout "${config_dir}/key.pem" \
                    -out "${config_dir}/cert.pem" > /dev/null 2>&1
                ;;
            3) # VMess + WebSocket
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "vmess",
        "settings": {
            "clients": [{"id": "${V2_UUID}", "alterId": 0}]
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "${V2_WS_PATH}"}
        }
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
            4) # VMess + TCP
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "vmess",
        "settings": {
            "clients": [{"id": "${V2_UUID}", "alterId": 0}]
        },
        "streamSettings": {"network": "tcp"}
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                ;;
            5) # Trojan + WebSocket
                V2_TROJAN_PASS=$(openssl rand -hex 16)
                cat > "${config_dir}/config.json" << V2EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [{
        "port": ${V2_PORT},
        "protocol": "trojan",
        "settings": {
            "clients": [{"password": "${V2_TROJAN_PASS}"}]
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "${V2_WS_PATH}"},
            "security": "tls",
            "tlsSettings": {"certificates": [{"certificateFile": "${config_dir}/cert.pem", "keyFile": "${config_dir}/key.pem"}]}
        }
    }],
    "outbounds": [{"protocol": "freedom"}, {"protocol": "blackhole", "tag": "blocked"}]
}
V2EOF
                openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
                    -subj "/CN=${SERVER_IP}" \
                    -keyout "${config_dir}/key.pem" \
                    -out "${config_dir}/cert.pem" > /dev/null 2>&1
                ;;
        esac

        sleep 1
    ) &
    spinner $! "Creating ${V2_ENGINE} configuration"

    echo -e "  ${BRIGHT_CYAN}[Step 3/3]${NC} ${WHITE}Starting ${V2_ENGINE} service...${NC}"
    (
        # Firewall
        if command -v ufw &> /dev/null; then
            ufw allow "$V2_PORT" > /dev/null 2>&1
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --add-port="$V2_PORT"/tcp > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
        fi

        systemctl enable "$V2_ENGINE" > /dev/null 2>&1
        systemctl restart "$V2_ENGINE" > /dev/null 2>&1
        sleep 1
    ) &
    spinner $! "Starting ${V2_ENGINE} service"

    # Build connection details based on protocol
    local proto_name
    case $v2_proto in
        1) proto_name="VLESS + WebSocket" ;;
        2) proto_name="VLESS + TCP + XTLS" ;;
        3) proto_name="VMess + WebSocket" ;;
        4) proto_name="VMess + TCP" ;;
        5) proto_name="Trojan + WebSocket" ;;
    esac

    echo ""
    success_msg "${V2_ENGINE} Deployed!"

    local connection_lines=(
        "${GREEN}▶${NC} ${WHITE}Engine:   ${BRIGHT_GREEN}${V2_ENGINE}${NC}"
        "${GREEN}▶${NC} ${WHITE}Protocol: ${BRIGHT_GREEN}${proto_name}${NC}"
        "${GREEN}▶${NC} ${WHITE}Server:   ${BRIGHT_YELLOW}${SERVER_IP}${NC}"
        "${GREEN}▶${NC} ${WHITE}Port:     ${BRIGHT_GREEN}${V2_PORT}${NC}"
        "${GREEN}▶${NC} ${WHITE}UUID:     ${BRIGHT_YELLOW}${V2_UUID}${NC}"
    )

    [[ "$v2_proto" =~ ^[135]$ ]] && connection_lines+=("${GREEN}▶${NC} ${WHITE}WS Path:  ${BRIGHT_GREEN}${V2_WS_PATH}${NC}")
    [[ "$v2_proto" == "5" ]] && connection_lines+=("${GREEN}▶${NC} ${WHITE}Trojan PW:${BRIGHT_YELLOW}${V2_TROJAN_PASS}${NC}")

    info_box "CONNECTION DETAILS" "${connection_lines[@]}"

    info_box "CLIENT APPS" \
        "${BRIGHT_YELLOW}📱 iOS:${NC} ${WHITE}Shadowrocket, Quantumult X, V2Box${NC}" \
        "${BRIGHT_YELLOW}📱 Android:${NC} ${WHITE}V2RayNG, Matsuri${NC}" \
        "${BRIGHT_YELLOW}💻 Windows:${NC} ${WHITE}V2RayN, Qv2ray, Nekoray${NC}" \
        "${BRIGHT_YELLOW}🍎 macOS:${NC} ${WHITE}V2RayU, Qv2ray, Nekoray${NC}" \
        "${BRIGHT_YELLOW}🐧 Linux:${NC} ${WHITE}Qv2ray, Nekoray, v2ray CLI${NC}"

    log "INFO" "${V2_ENGINE} installed successfully"

    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════

show_status_dashboard() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}📊  ${BOLD}${WHITE}VPN STATUS DASHBOARD${NC}                                   ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Check each VPN service
    local services=("wg-quick@wg0:WireGuard" "openvpn@server:OpenVPN" "strongswan-starter:IKEv2/IPsec" \
                    "strongswan:IKEv2/IPsec" "softether-vpnserver:SoftEther" "shadowsocks:Shadowsocks" \
                    "xray:Xray" "v2ray:V2Ray")

    echo -e "${CYAN}  ┌────────────────────┬──────────┬────────────────────────────┐${NC}"
    echo -e "${CYAN}  │ ${BOLD}${WHITE}VPN Service${NC}        ${CYAN}│ ${BOLD}${WHITE}Status${NC}   ${CYAN}│ ${BOLD}${WHITE}Details${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├────────────────────┼──────────┼────────────────────────────┤${NC}"

    for svc_pair in "${services[@]}"; do
        local svc_name="${svc_pair%%:*}"
        local svc_label="${svc_pair##*:}"

        if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
            local status="${BRIGHT_GREEN}●  ACTIVE${NC}"
            local details=""

            # Get extra details
            case $svc_label in
                "WireGuard")
                    local peers
                    peers=$(wg show wg0 peers 2>/dev/null | wc -l)
                    details="${peers} peer(s) configured"
                    ;;
                "OpenVPN")
                    local clients
                    clients=$(cat /var/log/openvpn-status.log 2>/dev/null | grep "CLIENT_LIST" | wc -l)
                    details="${clients} client(s) connected"
                    ;;
                *)
                    details="Running"
                    ;;
            esac

            printf "${CYAN}  │ ${WHITE}%-18s${CYAN}│ ${BRIGHT_GREEN}● ACTIVE${NC} ${CYAN}│ ${WHITE}%-26s${CYAN}│${NC}\n" "$svc_label" "$details"
        elif systemctl is-enabled --quiet "$svc_name" 2>/dev/null; then
            printf "${CYAN}  │ ${WHITE}%-18s${CYAN}│ ${YELLOW}○ STOPPED${NC}${CYAN}│ ${GRAY}%-26s${CYAN}│${NC}\n" "$svc_label" "Enabled but not running"
        else
            # Check if installed
            if systemctl list-unit-files | grep -q "$svc_name" 2>/dev/null; then
                printf "${CYAN}  │ ${DIM}${WHITE}%-18s${NC}${CYAN}│ ${RED}● DOWN${NC}  ${CYAN} │ ${GRAY}%-26s${CYAN}│${NC}\n" "$svc_label" "Installed, disabled"
            fi
        fi
    done

    echo -e "${CYAN}  └────────────────────┴──────────┴────────────────────────────┘${NC}"

    # Network stats
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}🌐  ${BOLD}${WHITE}NETWORK STATISTICS${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"

    # Show listening VPN ports
    local vpn_ports
    vpn_ports=$(ss -tulnp 2>/dev/null | grep -E "(51820|1194|443|500|4500|8388|5555)" | head -10)

    if [[ -n "$vpn_ports" ]]; then
        while IFS= read -r line; do
            local proto port
            proto=$(echo "$line" | awk '{print $1}')
            port=$(echo "$line" | awk '{print $5}' | rev | cut -d: -f1 | rev)
            local process
            process=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' || echo "unknown")
            printf "${CYAN}  │  ${GREEN}▶${NC} ${WHITE}%-5s port %-6s ${GRAY}(${process})${NC}$(printf '%*s' 20 '')${CYAN}│${NC}\n" "$proto" "$port"
        done <<< "$vpn_ports"
    else
        echo -e "${CYAN}  │  ${GRAY}No VPN services detected on standard ports${NC}           ${CYAN}│${NC}"
    fi

    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"

    # Active connections
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}👥  ${BOLD}${WHITE}ACTIVE CONNECTIONS${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"

    # WireGuard peers
    if command -v wg &>/dev/null && ip link show wg0 &>/dev/null 2>&1; then
        local wg_output
        wg_output=$(wg show wg0 2>/dev/null)
        if [[ -n "$wg_output" ]]; then
            echo -e "${CYAN}  │  ${BRIGHT_GREEN}WireGuard:${NC}                                             ${CYAN}│${NC}"
            while IFS= read -r peer; do
                local endpoint latest_handshake transfer
                endpoint=$(wg show wg0 endpoints 2>/dev/null | grep "$peer" | awk '{print $2}')
                latest_handshake=$(wg show wg0 latest-handshakes 2>/dev/null | grep "$peer" | awk '{print $2}')
                if [[ -n "$endpoint" && "$endpoint" != "(none)" ]]; then
                    printf "${CYAN}  │    ${WHITE}%-15s ${GRAY}last seen: %ss ago${NC}$(printf '%*s' 10 '')${CYAN}│${NC}\n" \
                        "${endpoint%:*}" "$(($(date +%s) - latest_handshake))"
                fi
            done < <(wg show wg0 peers 2>/dev/null)
        fi
    fi

    echo -e "${CYAN}  │  ${GRAY}(Detailed stats per VPN in management menu)${NC}           ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"

    echo ""
    echo -e "  ${GRAY}Press any key to return to menu...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# MANAGEMENT & TOOLS
# ═══════════════════════════════════════════════════════════════════════════════

show_management_menu() {
    while true; do
        clear
        show_banner

        echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_CYAN}🔧  ${BOLD}${WHITE}MANAGEMENT & TOOLS${NC}                                    ${CYAN}│${NC}"
        echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}  │                                                          │${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC}  ${WHITE}Add VPN Client/User${NC}                                  ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC}  ${WHITE}Remove VPN Client/User${NC}                               ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC}  ${WHITE}List All Clients${NC}                                     ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC}  ${WHITE}Show Client QR Code (WireGuard)${NC}                      ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC}  ${WHITE}Restart VPN Service${NC}                                  ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC}  ${WHITE}Stop VPN Service${NC}                                     ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC}  ${WHITE}View VPN Logs${NC}                                        ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[8]${NC}  ${WHITE}Uninstall VPN${NC}                                        ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[9]${NC}  ${WHITE}Backup Configurations${NC}                                ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[10]${NC} ${WHITE}Protocol Comparison Chart${NC}                            ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[11]${NC} ${WHITE}Speed Test${NC}                                           ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_GREEN}[12]${NC} ${WHITE}Security Hardening${NC}                                   ${CYAN}│${NC}"
        echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC}  ${WHITE}Back to Main Menu${NC}                                   ${CYAN}│${NC}"
        echo -e "${CYAN}  │                                                          │${NC}"
        echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
        echo ""

        styled_prompt "Select option"
        read -r mgmt_choice

        case $mgmt_choice in
            1) add_client ;;
            2) remove_client ;;
            3) list_clients ;;
            4) show_qr_code ;;
            5) restart_vpn ;;
            6) stop_vpn ;;
            7) view_logs ;;
            8) uninstall_vpn ;;
            9) backup_configs ;;
            10) show_vpn_comparison ;;
            11) run_speedtest ;;
            12) security_hardening ;;
            0) return ;;
            *) error_msg "Invalid option!" ; sleep 1 ;;
        esac
    done
}

# ─── Management Sub-functions ─────────────────────────────────────────────────

add_client() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}➕  ${BOLD}${WHITE}ADD NEW CLIENT${NC}                                         ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard Client${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN Client${NC}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2 User${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    styled_prompt "Choose VPN type"
    read -r client_type

    styled_prompt "Client name"
    read -r new_client_name

    if [[ -z "$new_client_name" ]]; then
        error_msg "Client name cannot be empty!"
        sleep 2
        return
    fi

    case $client_type in
        1) # WireGuard
            if [[ ! -f /etc/wireguard/wg0.conf ]]; then
                error_msg "WireGuard is not installed!"
                sleep 2
                return
            fi

            echo ""
            typewriter "  [*] Adding WireGuard client: ${new_client_name}" "$GREEN"
            echo ""

            (
                # Find next available IP
                local last_ip
                last_ip=$(grep "AllowedIPs" /etc/wireguard/wg0.conf | tail -1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)
                local base_ip
                base_ip=$(echo "$last_ip" | cut -d. -f1-3)
                local last_octet
                last_octet=$(echo "$last_ip" | cut -d. -f4)
                local new_octet=$(( last_octet + 1 ))
                local new_ip="${base_ip}.${new_octet}"

                local server_pub
                server_pub=$(cat /etc/wireguard/server_public.key)
                local server_port
                server_port=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')

                # Generate keys
                local priv pub psk
                priv=$(wg genkey)
                pub=$(echo "$priv" | wg pubkey)
                psk=$(wg genpsk)

                # Add to server config
                cat >> /etc/wireguard/wg0.conf << NEWPEER

# ─── Client: ${new_client_name} ─────────────────────────────
[Peer]
PublicKey = ${pub}
PresharedKey = ${psk}
AllowedIPs = ${new_ip}/32
NEWPEER

                # Create client config
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

                # Generate QR
                qrencode -t ansiutf8 < "/etc/wireguard/clients/${new_client_name}.conf" \
                    > "/etc/wireguard/clients/${new_client_name}_qr.txt" 2>/dev/null

                # Reload WireGuard
                wg syncconf wg0 <(wg-quick strip wg0) > /dev/null 2>&1

                sleep 1
            ) &
            spinner $! "Adding WireGuard client"

            success_msg "Client ${new_client_name} added!"
            echo -e "  ${WHITE}Config: ${BRIGHT_GREEN}/etc/wireguard/clients/${new_client_name}.conf${NC}"

            if [[ -f "/etc/wireguard/clients/${new_client_name}_qr.txt" ]]; then
                echo ""
                echo -e "  ${BRIGHT_CYAN}QR Code:${NC}"
                cat "/etc/wireguard/clients/${new_client_name}_qr.txt"
            fi
            ;;

        2) # OpenVPN
            if [[ ! -d /etc/openvpn/easy-rsa ]]; then
                error_msg "OpenVPN is not installed!"
                sleep 2
                return
            fi

            echo ""
            (
                cd /etc/openvpn/easy-rsa || exit
                EASYRSA_BATCH=1 ./easyrsa --batch build-client-full "$new_client_name" nopass > /dev/null 2>&1

                # Create .ovpn file
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
                sleep 1
            ) &
            spinner $! "Generating OpenVPN client"

            success_msg "Client ${new_client_name} added!"
            echo -e "  ${WHITE}Config: ${BRIGHT_GREEN}/etc/openvpn/clients/${new_client_name}.ovpn${NC}"
            ;;

        3) # IKEv2
            styled_prompt "Password for new user"
            read -rs new_pass
            echo ""

            if [[ -z "$new_pass" ]]; then
                new_pass=$(openssl rand -base64 12)
                echo -e "  ${BRIGHT_GREEN}  [*]${NC} ${WHITE}Generated: ${BRIGHT_YELLOW}${new_pass}${NC}"
            fi

            (
                echo "${new_client_name} : EAP \"${new_pass}\"" >> /etc/ipsec.secrets
                systemctl restart strongswan-starter > /dev/null 2>&1 || systemctl restart strongswan > /dev/null 2>&1
                sleep 1
            ) &
            spinner $! "Adding IKEv2 user"

            success_msg "User ${new_client_name} added!"
            echo -e "  ${WHITE}Username: ${BRIGHT_GREEN}${new_client_name}${NC}"
            echo -e "  ${WHITE}Password: ${BRIGHT_YELLOW}${new_pass}${NC}"
            ;;

        *)
            error_msg "Invalid option!"
            ;;
    esac

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

remove_client() {
    echo ""
    warning_msg "Remove client functionality"
    echo -e "  ${WHITE}To remove a WireGuard client:${NC}"
    echo -e "  ${GRAY}1. Edit /etc/wireguard/wg0.conf${NC}"
    echo -e "  ${GRAY}2. Remove the [Peer] block for that client${NC}"
    echo -e "  ${GRAY}3. Run: wg syncconf wg0 <(wg-quick strip wg0)${NC}"
    echo ""
    echo -e "  ${WHITE}To remove an OpenVPN client:${NC}"
    echo -e "  ${GRAY}1. cd /etc/openvpn/easy-rsa${NC}"
    echo -e "  ${GRAY}2. ./easyrsa revoke <client_name>${NC}"
    echo -e "  ${GRAY}3. ./easyrsa gen-crl${NC}"
    echo -e "  ${GRAY}4. Restart OpenVPN${NC}"
    echo ""
    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

list_clients() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_CYAN}👥  ${BOLD}${WHITE}CLIENT LIST${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # WireGuard clients
    if [[ -d /etc/wireguard/clients ]]; then
        echo -e "  ${BRIGHT_GREEN}🛡️  WireGuard Clients:${NC}"
        for conf in /etc/wireguard/clients/*.conf; do
            [[ -f "$conf" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}$(basename "$conf" .conf)${NC}"
        done
        echo ""
    fi

    # OpenVPN clients
    if [[ -d /etc/openvpn/clients ]]; then
        echo -e "  ${BRIGHT_GREEN}🔐 OpenVPN Clients:${NC}"
        for conf in /etc/openvpn/clients/*.ovpn; do
            [[ -f "$conf" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}$(basename "$conf" .ovpn)${NC}"
        done
        echo ""
    fi

    # IKEv2 users
    if [[ -f /etc/ipsec.secrets ]]; then
        echo -e "  ${BRIGHT_GREEN}⚡ IKEv2 Users:${NC}"
        grep "EAP" /etc/ipsec.secrets 2>/dev/null | while read -r line; do
            local user
            user=$(echo "$line" | awk -F: '{print $1}' | xargs)
            [[ -n "$user" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}${user}${NC}"
        done
        echo ""
    fi

    echo -e "  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

show_qr_code() {
    if [[ ! -d /etc/wireguard/clients ]]; then
        error_msg "No WireGuard clients found!"
        sleep 2
        return
    fi

    echo ""
    echo -e "  ${WHITE}Available clients:${NC}"
    for conf in /etc/wireguard/clients/*.conf; do
        [[ -f "$conf" ]] && echo -e "    ${GREEN}▶${NC} ${WHITE}$(basename "$conf" .conf)${NC}"
    done
    echo ""
    styled_prompt "Enter client name"
    read -r qr_client

    if [[ -f "/etc/wireguard/clients/${qr_client}_qr.txt" ]]; then
        echo ""
        cat "/etc/wireguard/clients/${qr_client}_qr.txt"
    elif [[ -f "/etc/wireguard/clients/${qr_client}.conf" ]]; then
        echo ""
        qrencode -t ansiutf8 < "/etc/wireguard/clients/${qr_client}.conf"
    else
        error_msg "Client not found!"
    fi

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

restart_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select service to restart:${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray/V2Ray${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}All services${NC}                                        ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r restart_choice

    case $restart_choice in
        1) systemctl restart wg-quick@wg0 2>/dev/null && success_msg "WireGuard restarted!" || error_msg "Failed!" ;;
        2) systemctl restart openvpn@server 2>/dev/null && success_msg "OpenVPN restarted!" || error_msg "Failed!" ;;
        3) (systemctl restart strongswan-starter 2>/dev/null || systemctl restart strongswan 2>/dev/null) && success_msg "IKEv2 restarted!" || error_msg "Failed!" ;;
        4) systemctl restart softether-vpnserver 2>/dev/null && success_msg "SoftEther restarted!" || error_msg "Failed!" ;;
        5) systemctl restart shadowsocks 2>/dev/null && success_msg "Shadowsocks restarted!" || error_msg "Failed!" ;;
        6) (systemctl restart xray 2>/dev/null || systemctl restart v2ray 2>/dev/null) && success_msg "Xray/V2Ray restarted!" || error_msg "Failed!" ;;
        7)
            systemctl restart wg-quick@wg0 2>/dev/null
            systemctl restart openvpn@server 2>/dev/null
            systemctl restart strongswan-starter 2>/dev/null
            systemctl restart softether-vpnserver 2>/dev/null
            systemctl restart shadowsocks 2>/dev/null
            systemctl restart xray 2>/dev/null
            success_msg "All services restart attempted!"
            ;;
    esac
    sleep 2
}

stop_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select service to stop:${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray/V2Ray${NC}     ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r stop_choice

    case $stop_choice in
        1) systemctl stop wg-quick@wg0 2>/dev/null && success_msg "WireGuard stopped!" ;;
        2) systemctl stop openvpn@server 2>/dev/null && success_msg "OpenVPN stopped!" ;;
        3) (systemctl stop strongswan-starter 2>/dev/null || systemctl stop strongswan 2>/dev/null) && success_msg "IKEv2 stopped!" ;;
        4) systemctl stop softether-vpnserver 2>/dev/null && success_msg "SoftEther stopped!" ;;
        5) systemctl stop shadowsocks 2>/dev/null && success_msg "Shadowsocks stopped!" ;;
        6) (systemctl stop xray 2>/dev/null || systemctl stop v2ray 2>/dev/null) && success_msg "Xray/V2Ray stopped!" ;;
    esac
    sleep 2
}

view_logs() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${WHITE}Select VPN logs to view:${NC}                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2${NC}               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Xray/V2Ray  ${BRIGHT_GREEN}[5]${NC} ${WHITE}System journal${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose"
    read -r log_choice

    echo ""
    echo -e "  ${BRIGHT_CYAN}─── LOG OUTPUT (press q to quit) ───${NC}"
    echo ""

    case $log_choice in
        1) journalctl -u wg-quick@wg0 --no-pager -n 50 2>/dev/null || echo "No logs found" ;;
        2) tail -50 /var/log/openvpn.log 2>/dev/null || journalctl -u openvpn@server --no-pager -n 50 2>/dev/null ;;
        3) journalctl -u strongswan-starter --no-pager -n 50 2>/dev/null || journalctl -u strongswan --no-pager -n 50 2>/dev/null ;;
        4) journalctl -u xray --no-pager -n 50 2>/dev/null || journalctl -u v2ray --no-pager -n 50 2>/dev/null ;;
        5) journalctl --no-pager -n 50 ;;
    esac

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

uninstall_vpn() {
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}⚠️  ${BOLD}${WHITE}UNINSTALL VPN${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}WireGuard${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}OpenVPN${NC}                                              ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}IKEv2/IPsec (strongSwan)${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}SoftEther${NC}                                            ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Shadowsocks${NC}                                          ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Xray/V2Ray${NC}                                           ${CYAN}│${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    styled_prompt "Choose VPN to uninstall"
    read -r uninstall_choice

    if ! confirm_prompt "Are you SURE you want to uninstall? This is irreversible!" "n"; then
        return
    fi

    case $uninstall_choice in
        1)
            (
                systemctl stop wg-quick@wg0 2>/dev/null
                systemctl disable wg-quick@wg0 2>/dev/null
                case $OS in
                    ubuntu|debian) apt-get remove -y wireguard wireguard-tools > /dev/null 2>&1 ;;
                    centos|rhel|rocky|almalinux|fedora) dnf remove -y wireguard-tools > /dev/null 2>&1 ;;
                esac
                rm -rf /etc/wireguard
            ) &
            spinner $! "Uninstalling WireGuard"
            success_msg "WireGuard uninstalled!"
            ;;
        2)
            (
                systemctl stop openvpn@server 2>/dev/null
                systemctl disable openvpn@server 2>/dev/null
                case $OS in
                    ubuntu|debian) apt-get remove -y openvpn easy-rsa > /dev/null 2>&1 ;;
                    centos|rhel|rocky|almalinux|fedora) dnf remove -y openvpn easy-rsa > /dev/null 2>&1 ;;
                esac
                rm -rf /etc/openvpn
            ) &
            spinner $! "Uninstalling OpenVPN"
            success_msg "OpenVPN uninstalled!"
            ;;
        3)
            (
                systemctl stop strongswan-starter 2>/dev/null || systemctl stop strongswan 2>/dev/null
                systemctl disable strongswan-starter 2>/dev/null || systemctl disable strongswan 2>/dev/null
                case $OS in
                    ubuntu|debian) apt-get remove -y strongswan* > /dev/null 2>&1 ;;
                    centos|rhel|rocky|almalinux|fedora) dnf remove -y strongswan > /dev/null 2>&1 ;;
                esac
                rm -f /etc/ipsec.conf /etc/ipsec.secrets
            ) &
            spinner $! "Uninstalling strongSwan"
            success_msg "IKEv2/IPsec uninstalled!"
            ;;
        4)
            (
                systemctl stop softether-vpnserver 2>/dev/null
                systemctl disable softether-vpnserver 2>/dev/null
                rm -rf /usr/local/vpnserver
                rm -f /etc/systemd/system/softether-vpnserver.service
                systemctl daemon-reload
            ) &
            spinner $! "Uninstalling SoftEther"
            success_msg "SoftEther uninstalled!"
            ;;
        5)
            (
                systemctl stop shadowsocks 2>/dev/null
                systemctl disable shadowsocks 2>/dev/null
                rm -rf /etc/shadowsocks
                rm -f /etc/systemd/system/shadowsocks.service
                systemctl daemon-reload
            ) &
            spinner $! "Uninstalling Shadowsocks"
            success_msg "Shadowsocks uninstalled!"
            ;;
        6)
            (
                systemctl stop xray 2>/dev/null || systemctl stop v2ray 2>/dev/null
                systemctl disable xray 2>/dev/null || systemctl disable v2ray 2>/dev/null
                bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove > /dev/null 2>&1
                bash -c "$(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)" -- --remove > /dev/null 2>&1
            ) &
            spinner $! "Uninstalling Xray/V2Ray"
            success_msg "Xray/V2Ray uninstalled!"
            ;;
    esac

    sleep 2
}

backup_configs() {
    local backup_time
    backup_time=$(date +%Y%m%d_%H%M%S)
    local backup_path="/root/vpn-backup-${backup_time}"

    echo ""
    (
        mkdir -p "$backup_path"

        [[ -d /etc/wireguard ]] && cp -r /etc/wireguard "$backup_path/"
        [[ -d /etc/openvpn ]] && cp -r /etc/openvpn "$backup_path/"
        [[ -f /etc/ipsec.conf ]] && cp /etc/ipsec.conf "$backup_path/"
        [[ -f /etc/ipsec.secrets ]] && cp /etc/ipsec.secrets "$backup_path/"
        [[ -d /etc/shadowsocks ]] && cp -r /etc/shadowsocks "$backup_path/"
        [[ -d /usr/local/etc/xray ]] && cp -r /usr/local/etc/xray "$backup_path/"
        [[ -d /usr/local/etc/v2ray ]] && cp -r /usr/local/etc/v2ray "$backup_path/"

        tar czf "${backup_path}.tar.gz" -C /root "vpn-backup-${backup_time}" 2>/dev/null
        rm -rf "$backup_path"

        sleep 1
    ) &
    spinner $! "Creating backup"

    success_msg "Backup created!"
    echo -e "  ${WHITE}Location: ${BRIGHT_GREEN}${backup_path}.tar.gz${NC}"

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

run_speedtest() {
    echo ""
    echo -e "  ${WHITE}Installing speedtest-cli...${NC}"

    if ! command -v speedtest-cli &> /dev/null; then
        pip3 install speedtest-cli > /dev/null 2>&1 || \
        pip install speedtest-cli > /dev/null 2>&1 || \
        apt-get install -y speedtest-cli > /dev/null 2>&1
    fi

    if command -v speedtest-cli &> /dev/null; then
        echo ""
        echo -e "  ${BRIGHT_CYAN}Running speed test...${NC}"
        echo ""
        speedtest-cli --simple 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${GREEN}▶${NC} ${WHITE}${line}${NC}"
        done
    else
        error_msg "Could not install speedtest-cli"
    fi

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

security_hardening() {
    clear
    show_banner

    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}🔒  ${BOLD}${WHITE}SECURITY HARDENING${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[1]${NC} ${WHITE}Enable UFW Firewall${NC}                                  ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[2]${NC} ${WHITE}Install Fail2Ban${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[3]${NC} ${WHITE}Disable root SSH login${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[4]${NC} ${WHITE}Change SSH port${NC}                                      ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[5]${NC} ${WHITE}Enable automatic security updates${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[6]${NC} ${WHITE}Harden sysctl parameters${NC}                             ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_GREEN}[7]${NC} ${WHITE}Apply ALL hardening measures${NC}                         ${CYAN}│${NC}"
    echo -e "${CYAN}  │  ${BRIGHT_RED}[0]${NC} ${WHITE}Back${NC}                                                 ${CYAN}│${NC}"
    echo -e "${CYAN}  │                                                          │${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    styled_prompt "Choose option"
    read -r hard_choice

    case $hard_choice in
        1)
            (
                apt-get install -y -qq ufw > /dev/null 2>&1 || dnf install -y -q ufw > /dev/null 2>&1
                ufw default deny incoming > /dev/null 2>&1
                ufw default allow outgoing > /dev/null 2>&1
                ufw allow ssh > /dev/null 2>&1
                # Allow VPN ports
                ufw allow 51820/udp > /dev/null 2>&1  # WireGuard
                ufw allow 1194/udp > /dev/null 2>&1   # OpenVPN
                ufw allow 443/tcp > /dev/null 2>&1    # HTTPS/various
                ufw allow 500/udp > /dev/null 2>&1    # IKEv2
                ufw allow 4500/udp > /dev/null 2>&1   # IKEv2
                echo "y" | ufw enable > /dev/null 2>&1
            ) &
            spinner $! "Configuring UFW firewall"
            success_msg "UFW firewall enabled!"
            ;;
        2)
            (
                apt-get install -y -qq fail2ban > /dev/null 2>&1 || dnf install -y -q fail2ban > /dev/null 2>&1
                systemctl enable fail2ban > /dev/null 2>&1
                systemctl start fail2ban > /dev/null 2>&1
            ) &
            spinner $! "Installing Fail2Ban"
            success_msg "Fail2Ban installed!"
            ;;
        3)
            (
                sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
                systemctl restart sshd > /dev/null 2>&1
            ) &
            spinner $! "Disabling root SSH"
            warning_msg "Root SSH disabled! Make sure you have another user!"
            ;;
        4)
            styled_prompt "New SSH port" "2222"
            read -r new_ssh_port
            new_ssh_port=${new_ssh_port:-2222}
            (
                sed -i "s/^#Port.*/Port ${new_ssh_port}/" /etc/ssh/sshd_config
                sed -i "s/^Port.*/Port ${new_ssh_port}/" /etc/ssh/sshd_config
                if command -v ufw &>/dev/null; then
                    ufw allow "$new_ssh_port"/tcp > /dev/null 2>&1
                fi
                systemctl restart sshd > /dev/null 2>&1
            ) &
            spinner $! "Changing SSH port"
            success_msg "SSH port changed to ${new_ssh_port}!"
            ;;
        5)
            (
                if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
                    apt-get install -y -qq unattended-upgrades > /dev/null 2>&1
                    dpkg-reconfigure -plow unattended-upgrades > /dev/null 2>&1
                elif [[ "$OS" =~ ^(centos|rhel|rocky|almalinux|fedora)$ ]]; then
                    dnf install -y -q dnf-automatic > /dev/null 2>&1
                    systemctl enable dnf-automatic.timer > /dev/null 2>&1
                    systemctl start dnf-automatic.timer > /dev/null 2>&1
                fi
            ) &
            spinner $! "Enabling automatic updates"
            success_msg "Auto-updates enabled!"
            ;;
        6)
            (
                cat >> /etc/sysctl.conf << 'HARDENEOF'
# Security hardening
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
HARDENEOF
                sysctl -p > /dev/null 2>&1
            ) &
            spinner $! "Hardening sysctl"
            success_msg "Sysctl hardened!"
            ;;
        0) return ;;
    esac

    echo -e "\n  ${GRAY}Press any key to continue...${NC}"
    read -n 1 -s
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXIT ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

show_exit() {
    clear
    echo ""
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
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    print_centered "🔒 Stay secure. Stay anonymous. Stay free. 🔒" "$BRIGHT_YELLOW"
    print_centered "VPN Blast v${SCRIPT_VERSION} - Your Privacy Matters" "$WHITE"
    print_centered "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
    echo ""
    echo ""

    typewriter "  [*] Shutting down VPN Blast console..." "$GREEN" 0.03
    typewriter "  [*] Cleaning up temporary files..." "$GREEN" 0.03
    typewriter "  [*] Session terminated. Goodbye, operator." "$BRIGHT_GREEN" 0.03
    echo ""

    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Check root
    check_root

    # Detect OS
    detect_os

    # Get server info
    get_server_info

    # Create directories
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$INSTALL_DIR" 2>/dev/null
    touch "$LOG_FILE" 2>/dev/null

    # Brief intro animation
    clear
    matrix_rain 1

    # Main loop
    while true; do
        show_banner
        show_system_info
        show_main_menu

        styled_prompt "Enter your choice, operator"
        read -r main_choice

        case $main_choice in
            1) install_wireguard ;;
            2) install_openvpn ;;
            3) install_ikev2 ;;
            4) install_softether ;;
            5) install_outline ;;
            6) install_shadowsocks ;;
            7) install_v2ray ;;
            8) show_status_dashboard ;;
            9) show_management_menu ;;
            0) show_exit ;;
            *)
                error_msg "Invalid option, operator!"
                sleep 1
                ;;
        esac
    done
}

# Run
main "$@"
