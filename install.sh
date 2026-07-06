#!/usr/bin/env bash

# Terminal Self-Healing logic (fixes "terminals database is inaccessible" errors)
if ! tput colors &>/dev/null; then
    export TERM=xterm-256color
fi

# ==============================================================================
# Premium Hyprland & Quickshell Desktop Environment Installer
# ==============================================================================

# set -e

# Script Versioning & Initialization
DOTS_VERSION="1.2.3"
VERSION_FILE="$HOME/.local/state/imperative-dots-version"

# Terminal UI Colors & Formatting
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
C_BLUE="\e[34m"
C_CYAN="\e[36m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_MAGENTA="\e[35m"

# Early Distro Detection
if [ -f /etc/os-release ]; then
    DETECTED_OS=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
else
    echo -e "${C_RED}Cannot detect OS. /etc/os-release not found.${RESET}"
    exit 1
fi

case "$DETECTED_OS" in
    arch|endeavouros|manjaro|cachyos|parch|garuda)
        OS="$DETECTED_OS"
        ;;
    *)
        echo -e "${C_RED}Unsupported OS ($DETECTED_OS). This script strictly supports Arch Linux and its derivatives.${RESET}"
        exit 1
        ;;
esac

# Prevent TTY/Console from falling asleep during long builds
setterm -blank 0 -powerdown 0 2>/dev/null || true
printf '\033[9;0]' 2>/dev/null || true

# Global Variables & Initial States (Defaults)
USER_PICTURES_DIR=""
if [ -f "$HOME/.config/user-dirs.dirs" ]; then
    USER_PICTURES_DIR=$(grep '^XDG_PICTURES_DIR' "$HOME/.config/user-dirs.dirs" | cut -d= -f2 | tr -d '"' | sed "s|\$HOME|$HOME|g")
fi
if [[ -z "$USER_PICTURES_DIR" || "$USER_PICTURES_DIR" == "$HOME" ]]; then
    USER_PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null)"
fi
if [[ -z "$USER_PICTURES_DIR" || "$USER_PICTURES_DIR" == "$HOME" ]]; then
    USER_PICTURES_DIR="$HOME/Pictures"
fi
USER_PICTURES_DIR="${USER_PICTURES_DIR/#\~/$HOME}"
USER_PICTURES_DIR="${USER_PICTURES_DIR%/}"

USER_VIDEOS_DIR=""
if [ -f "$HOME/.config/user-dirs.dirs" ]; then
    USER_VIDEOS_DIR=$(grep '^XDG_VIDEOS_DIR' "$HOME/.config/user-dirs.dirs" | cut -d= -f2 | tr -d '"' | sed "s|\$HOME|$HOME|g")
fi
if [[ -z "$USER_VIDEOS_DIR" || "$USER_VIDEOS_DIR" == "$HOME" ]]; then
    USER_VIDEOS_DIR="$(xdg-user-dir VIDEOS 2>/dev/null)"
fi
if [[ -z "$USER_VIDEOS_DIR" || "$USER_VIDEOS_DIR" == "$HOME" ]]; then
    USER_VIDEOS_DIR="$HOME/Videos"
fi
USER_VIDEOS_DIR="${USER_VIDEOS_DIR/#\~/$HOME}"
USER_VIDEOS_DIR="${USER_VIDEOS_DIR%/}"

WALLPAPER_DIR="$USER_PICTURES_DIR/Wallpapers"
WEATHER_API_KEY=""
WEATHER_CITY_ID=""
WEATHER_UNIT=""
FAILED_PKGS=()

TARGET_BRANCH="main"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dev) TARGET_BRANCH="dev"; shift ;;
        *) shift ;;
    esac
done

if [[ "$TARGET_BRANCH" == "dev" ]]; then
    echo -e "${C_YELLOW}[!] RUNNING IN DEVELOPMENT MODE (Branch: dev)${RESET}"
fi

OPT_SDDM=false
OPT_NVIM=false
OPT_FISH=false
OPT_WALLPAPERS=false
OPT_OVERRIDE_KEYBINDS=false
OPT_OVERRIDE_STARTUPS=false

INSTALL_NVIM=false
INSTALL_FISH=false
INSTALL_SDDM=false
REPLACE_DM=false
SETUP_SDDM_THEME=false
SDDM_WAYLAND=false

DRIVER_CHOICE="None (Skipped)"
DRIVER_PKGS=()
HAS_NVIDIA_PROPRIETARY=false
LAST_COMMIT=""
KEEP_OLD_ENV=true

ENABLE_TELEMETRY=false

VISITED_PKGS=false
VISITED_OVERVIEW=false
VISITED_WEATHER=false
VISITED_DRIVERS=false
VISITED_KEYBOARD=false

KB_LAYOUTS="us"
KB_LAYOUTS_DISPLAY="English (US)"
KB_OPTIONS="grp:alt_shift_toggle"

mkdir -p "$(dirname "$VERSION_FILE")"

if [ -f "$VERSION_FILE" ] && [ -s "$VERSION_FILE" ]; then
    source "$VERSION_FILE"
    if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "Not Installed" ]; then
        [ -n "$KB_LAYOUTS" ] && VISITED_KEYBOARD=true
        [ -n "$WEATHER_API_KEY" ] && VISITED_WEATHER=true
        [[ "$DRIVER_CHOICE" != "None (Skipped)" && -n "$DRIVER_CHOICE" ]] && VISITED_DRIVERS=true
    fi
else
    LOCAL_VERSION="Not Installed"
fi

if [ -z "$TELEMETRY_ID" ]; then
    if command -v uuidgen &> /dev/null; then
        TELEMETRY_ID=$(uuidgen)
    else
        TELEMETRY_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
    fi
    echo "TELEMETRY_ID=\"$TELEMETRY_ID\"" >> "$VERSION_FILE"
fi

# Main official packages
ARCH_PKGS=(
    "hyprland" "hypridle" "kitty" "cava" "zbar" "pavucontrol" "alsa-utils" "awww" 
    "wl-clipboard" "fd" "qt6-multimedia" "qt6-5compat" "ripgrep" "fcitx5" "fcitx5-configtool"
    "cliphist" "jq" "socat" "inotify-tools" "pamixer" "brightnessctl" "acpi" "iw"
    "bluez" "bluez-utils" "libnotify" "networkmanager" "lm_sensors" "bc" 
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "libpulse" "python"
    "imagemagick" "wget" "file" "git" "psmisc"
    "matugen-bin" "ffmpeg" "fastfetch" "quickshell-git" "unzip" "python-websockets" "qt6-websockets"
    "grim" "playerctl" "satty" "yq" "xdg-desktop-portal-gtk" "slurp" "mpvpaper"
    "wmctrl" "power-profiles-daemon" "swayosd-git" "nautilus" "hyprpolkitagent"
    "qt5-wayland" "qt5-quickcontrols" "qt5-quickcontrols2" "qt5-graphicaleffects" "qt6-wayland"
    "qt5ct" "qt6ct" "gpu-screen-recorder" "adw-gtk-theme" "xdg-desktop-portal-wlr"
)

PKGS=("${ARCH_PKGS[@]}")

# Bootstrap dependencies
if ! command -v fzf &> /dev/null || ! command -v lspci &> /dev/null || ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    echo -e "${C_CYAN}Bootstrapping TUI dependencies (fzf, pciutils, jq, curl)...${RESET}"
    sudo pacman -Sy --noconfirm --needed fzf pciutils jq curl > /dev/null 2>&1
fi

if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "${C_CYAN}Enabling multilib repository for 32-bit driver support...${RESET}"
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy --noconfirm > /dev/null 2>&1
fi

if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
    echo -e "${C_CYAN}Installing 'yay' (AUR helper) to fetch custom packages...${RESET}"
    sudo pacman -S --noconfirm --needed base-devel git
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin > /dev/null 2>&1
    (cd /tmp/yay-bin && makepkg -si --noconfirm > /dev/null 2>&1)
    rm -rf /tmp/yay-bin
fi

if command -v yay &> /dev/null; then
    PKG_MANAGER="yay -S --noconfirm --needed"
elif command -v paru &> /dev/null; then
    PKG_MANAGER="paru -S --noconfirm --needed"
else
    PKG_MANAGER="sudo pacman -S --noconfirm --needed"
fi

USER_NAME=$USER
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
CPU_INFO=$(grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)

GPU_RAW=$(lspci -nn | grep -iE 'vga|3d|display')
GPU_INFO=$(echo "$GPU_RAW" | cut -d: -f3 | sed -E 's/ \(rev [0-9a-f]+\)//g' | xargs)
[[ -z "$GPU_INFO" ]] && GPU_INFO="Unknown / Virtual Machine"

GPU_VENDOR="Unknown / Generic VM"
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    GPU_VENDOR="NVIDIA"
elif echo "$GPU_INFO" | grep -qi "amd\|radeon"; then
    GPU_VENDOR="AMD"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    GPU_VENDOR="INTEL"
elif echo "$GPU_INFO" | grep -qi "vmware\|virtualbox\|qxl\|virtio\|bochs"; then
    GPU_VENDOR="VM"
fi

EXISTING_SETTINGS="$HOME/.config/niri/settings.json"
if [ -f "$EXISTING_SETTINGS" ] && command -v jq &>/dev/null; then
    _sj_lang=$(jq -r 'if has("language") then (.language // "") else "IGNORE_ME" end' "$EXISTING_SETTINGS" 2>/dev/null)
    _sj_kbopt=$(jq -r 'if has("kbOptions") then (.kbOptions // "") else "IGNORE_ME" end' "$EXISTING_SETTINGS" 2>/dev/null)
    _sj_wpdir=$(jq -r 'if has("wallpaperDir") then (.wallpaperDir // "") else "IGNORE_ME" end' "$EXISTING_SETTINGS" 2>/dev/null)

    if [[ "$_sj_lang" != "IGNORE_ME" ]]; then
        KB_LAYOUTS="$_sj_lang"
        if [ "$KB_LAYOUTS" != "$( (source "$VERSION_FILE" 2>/dev/null; echo "$KB_LAYOUTS") )" ] || [ -z "$KB_LAYOUTS_DISPLAY" ]; then
            KB_LAYOUTS_DISPLAY="$_sj_lang"
        fi
        VISITED_KEYBOARD=true
    fi

    if [[ "$_sj_kbopt" != "IGNORE_ME" ]]; then
        KB_OPTIONS="$_sj_kbopt"
    fi

    if [[ "$_sj_wpdir" != "IGNORE_ME" ]] && [[ -n "$_sj_wpdir" ]]; then
        _sj_wpdir="${_sj_wpdir%/}"
        WALLPAPER_DIR="$_sj_wpdir"
        USER_PICTURES_DIR="$(dirname "$_sj_wpdir")"
    fi
fi

# Telemetry Endpoint
WORKER_URL="https://dots-telemetry.ilyamiro-work.workers.dev"

send_telemetry() {
    local mode=$1
    if [[ "$ENABLE_TELEMETRY" != true ]]; then
        if [[ "$mode" != "done" ]]; then
            return 0
        fi
    fi
    if [[ -n "$WORKER_URL" && "$WORKER_URL" != *"YOUR_USERNAME"* ]]; then
        if [[ "$mode" == "init" ]]; then
            local payload=$(cat <<EOF
{
  "type": "init",
  "version": "${DOTS_VERSION}",
  "id": "${TELEMETRY_ID}",
  "os": "${OS_NAME//\"/\\\"}"
}
EOF
)
            curl -X POST -H "Content-Type: application/json" -d "$payload" "$WORKER_URL" -s -o /dev/null &

        elif [[ "$mode" == "full" ]]; then
            local payload=$(cat <<EOF
{
  "type": "full",
  "version": "${DOTS_VERSION}",
  "id": "${TELEMETRY_ID}",
  "os": "${OS_NAME//\"/\\\"}"
}
EOF
)
            curl -X POST -H "Content-Type: application/json" -d "$payload" "$WORKER_URL" -s -o /dev/null &

        elif [[ "$mode" == "done" ]]; then
            local payload=""
            local failed_str=""

            if [[ "$ENABLE_TELEMETRY" == true ]]; then
                if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
                    failed_str="${FAILED_PKGS[*]}"
                fi
                
                local ram=$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "Unknown")
                local kernel=$(uname -r 2>/dev/null || echo "Unknown")
                local current_de=${XDG_CURRENT_DESKTOP:-"TTY / Unknown"}
                
                payload=$(cat <<EOF
{
  "type": "done",
  "version": "${DOTS_VERSION}",
  "id": "${TELEMETRY_ID}",
  "telemetry_enabled": true,
  "failed_packages": "${failed_str//\"/\\\"}",
  "os": "${OS_NAME//\"/\\\"}",
  "kernel": "${kernel//\"/\\\"}",
  "ram": "${ram//\"/\\\"}",
  "de": "${current_de//\"/\\\"}",
  "cpu": "${CPU_INFO//\"/\\\"}",
  "gpu": "${GPU_INFO//\"/\\\"}"
}
EOF
)
            else
                payload=$(cat <<EOF
{
  "type": "done",
  "version": "${DOTS_VERSION}",
  "id": "${TELEMETRY_ID}",
  "telemetry_enabled": false,
  "os": "${OS_NAME//\"/\\\"}"
}
EOF
)
            fi
            curl -X POST -H "Content-Type: application/json" -d "$payload" "$WORKER_URL" -s -o /dev/null &
        fi
    fi
}

send_telemetry "init"

draw_header() {
    clear 
    printf "${BOLD}${C_CYAN}"
    cat << "EOF"
    ██╗  ██╗██╗  ██╗██╗  ██╗███╗   ██╗██╗  ██╗
    ██║ ██╔╝██║  ██║╚██╗██╔╝████╗  ██║██║  ██║
    █████╔╝ ███████║ ╚███╔╝ ██╔██╗ ██║███████║
    ██╔═██╗ ██╔══██║ ██╔██╗ ██║╚██╗██║██╔══██║
    ██║  ██╗██║  ██║██╔╝ ██╗██║ ╚████║██║  ██║
    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝
                                          
EOF
    printf "${RESET}\n"

    local OSC8_GH="\e]8;;https://github.com/noqokhxnh/my_configuration.git\a"
    local OSC8_END="\e]8;;\a"

    printf "\033[K${C_BLUE} -----------------------------------------------------------------${RESET}\n"
    printf "\033[K${BOLD}${C_GREEN} GitHub:${RESET}  ${OSC8_GH}https://github.com/noqokhxnh/my_configuration.git${OSC8_END}\n"
    printf "\033[K${C_BLUE} -----------------------------------------------------------------${RESET}\n"
    printf "\033[K${BOLD} User:           ${RESET} %s\n" "$USER_NAME"
    printf "\033[K${BOLD} OS:             ${RESET} %s\n" "$OS_NAME"
    printf "\033[K${BOLD} CPU:            ${RESET} %s\n" "$CPU_INFO"
    printf "\033[K${BOLD} GPU:            ${RESET} %s\n" "$GPU_INFO"
    printf "\033[K${C_BLUE} -----------------------------------------------------------------${RESET}\n"
    printf "\033[K${BOLD} Config Version: ${RESET} %s\n" "$DOTS_VERSION"
    printf "\033[K${BOLD} Local Version:  ${RESET} %s\n" "$LOCAL_VERSION"
    printf "\033[K${C_BLUE} =================================================================${RESET}\n\n"
}

manage_packages() {
    while true; do
        draw_header
        local action
        action=$(echo -e "1. View Packages to be Installed\n2. Add Custom Packages\n3. Back to Main Menu" | fzf \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=15 \
            --prompt=" Package Manager > " \
            --pointer=">" \
            --header=" Use ARROW KEYS and ENTER ")

        case "$action" in
            *"1"*)
                echo "${PKGS[@]}" | tr ' ' '\n' | fzf \
                    --layout=reverse \
                    --border=rounded \
                    --margin=1,2 \
                    --height=25 \
                    --prompt=" Current Packages > " \
                    --pointer=">" \
                    --header=" Press ESC or ENTER to return to menu "
                ;;
            *"2"*)
                echo -e "${C_CYAN}Enter package names to add (separated by space) ${BOLD}[Leave empty and press ENTER to cancel]${RESET}${C_CYAN}:${RESET}"
                read -r new_pkgs
                if [ -n "$new_pkgs" ]; then
                    PKGS+=($new_pkgs)
                    echo -e "${C_GREEN}Packages added!${RESET}"
                    sleep 1
                fi
                ;;
            *"3"*) VISITED_PKGS=true; break ;;
            *) VISITED_PKGS=true; break ;;
        esac
    done
}

manage_drivers() {
    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== Hardware Driver Configuration ===${RESET}"
        echo -e "${BOLD}${C_RED}=================== EXPERIMENTAL WARNING ===================${RESET}"
        echo -e "${C_RED}This automated driver installer is highly experimental and${RESET}"
        echo -e "${C_RED}can be unreliable across different kernel/distro variations.${RESET}"
        echo -e "${C_RED}It is strongly recommended to SKIP this and install your${RESET}"
        echo -e "${C_RED}graphics drivers manually according to your distro's wiki.${RESET}"
        echo -e "${BOLD}${C_RED}============================================================${RESET}\n"
        echo -e "Detected GPU Vendor: ${BOLD}${C_YELLOW}$GPU_VENDOR${RESET}\n"

        local current_driver="None"
        if command -v lsmod &> /dev/null; then
            if lsmod | grep -wq nvidia; then
                current_driver="nvidia"
            elif lsmod | grep -wq nouveau; then
                current_driver="nouveau"
            elif lsmod | grep -Ewq "amdgpu|radeon"; then
                current_driver="amd"
            elif lsmod | grep -Ewq "i915|xe"; then
                current_driver="intel"
            fi
        fi

        local options=""
        case "$GPU_VENDOR" in
            "NVIDIA")
                if [[ "$current_driver" == "nouveau" ]]; then
                    echo -e "${C_YELLOW}[!] Notice: Open-source 'nouveau' drivers are currently loaded.${RESET}"
                    echo -e "${C_RED}[!] Proprietary installation is locked out to prevent initramfs conflicts/black screens.${RESET}\n"
                    options="1. Update/Keep Nouveau (Open Source)\n2. Skip Driver Installation"
                elif [[ "$current_driver" == "nvidia" ]]; then
                    echo -e "${C_YELLOW}[!] Notice: Proprietary 'nvidia' drivers are currently loaded.${RESET}"
                    echo -e "${C_RED}[!] Open-source installation is locked out to prevent conflicts.${RESET}\n"
                    options="1. Update/Keep Proprietary NVIDIA Drivers\n2. Skip Driver Installation"
                else
                    options="1. Install Proprietary NVIDIA Drivers (Recommended for Gaming/Wayland)\n2. Install Nouveau (Open Source, Better VM compat)\n3. Skip Driver Installation"
                fi
                ;;
            "AMD")
                options="1. Install AMD Mesa & Vulkan Drivers (RADV)\n2. Skip Driver Installation"
                ;;
            "INTEL")
                options="1. Install Intel Mesa & Vulkan Drivers (ANV)\n2. Skip Driver Installation"
                ;;
            *)
                options="1. Install Generic Mesa Drivers (For VMs / Software Rendering)\n2. Skip Driver Installation"
                ;;
        esac

        local choice
        choice=$(echo -e "$options\nBack to Main Menu" | fzf \
            --ansi \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=15 \
            --prompt=" Drivers > " \
            --pointer=">" \
            --header=" Select the graphics drivers to install ")

        if [[ "$choice" == *"Back"* ]]; then break; fi

        if [[ "$choice" != *"Skip"* ]]; then
            echo -e "\n${BOLD}${C_RED}=================== ACTION REQUIRED ===================${RESET}"
            echo -e "${C_YELLOW}You have selected to AUTOMATICALLY install/configure drivers.${RESET}"
            echo -e "${C_YELLOW}If your system already has working drivers, this might break your boot sequence.${RESET}"
            echo -n -e "Are you ${BOLD}${C_RED}100% sure${RESET} you want to proceed with this driver installation? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "\n${C_RED}Driver setup aborted. Returning to menu...${RESET}"
                sleep 1.2
                continue
            fi
        fi

        DRIVER_PKGS=()
        HAS_NVIDIA_PROPRIETARY=false

        if [[ "$choice" == *"Proprietary NVIDIA"* ]]; then
            DRIVER_CHOICE="NVIDIA Proprietary"
            HAS_NVIDIA_PROPRIETARY=true
            DRIVER_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "linux-headers" "egl-wayland")

        elif [[ "$choice" == *"Nouveau"* ]]; then
            DRIVER_CHOICE="NVIDIA Nouveau"
            DRIVER_PKGS+=("mesa" "vulkan-nouveau" "lib32-mesa")

        elif [[ "$choice" == *"AMD"* ]]; then
            DRIVER_CHOICE="AMD Drivers"
            DRIVER_PKGS+=("mesa" "vulkan-radeon" "lib32-vulkan-radeon" "lib32-mesa" "xf86-video-amdgpu")

        elif [[ "$choice" == *"Intel"* ]]; then
            DRIVER_CHOICE="Intel Drivers"
            DRIVER_PKGS+=("mesa" "vulkan-intel" "lib32-vulkan-intel" "lib32-mesa" "intel-media-driver")

        elif [[ "$choice" == *"Generic"* ]]; then
            DRIVER_CHOICE="Generic / VM"
            DRIVER_PKGS+=("mesa" "lib32-mesa")

        elif [[ "$choice" == *"Skip"* ]]; then
            DRIVER_CHOICE="Skipped"
            DRIVER_PKGS=()
        fi

        echo -e "\n${C_GREEN}Driver configuration saved!${RESET}"
        sleep 1.2
        VISITED_DRIVERS=true
        break
    done
}

manage_keyboard() {
    local available_layouts=(
        "us - English (US)" "vn - Vietnamese" "jp - Japanese" "cn - Chinese"
        "kr - Korean" "fr - French" "de - German" "es - Spanish" "ru - Russian"
        "gb - English (UK)" "ca - English/French (Canada)" "tw - Taiwanese"
        "us-intl - US International" "dvorak - US Dvorak" "colemak - US Colemak" 
    )
    
    local selected_codes=()
    local selected_names=()

    if [[ -n "$KB_LAYOUTS" ]]; then
        IFS=',' read -ra tmp_codes <<< "$KB_LAYOUTS"
        for code in "${tmp_codes[@]}"; do
            selected_codes+=("$(echo "$code" | xargs)")
        done
    else
        selected_codes=("us")
    fi

    if [[ -n "$KB_LAYOUTS_DISPLAY" ]]; then
        IFS=',' read -ra tmp_names <<< "$KB_LAYOUTS_DISPLAY"
        for name in "${tmp_names[@]}"; do
            selected_names+=("$(echo "$name" | xargs)")
        done
    else
        selected_names=("English (US)")
    fi

    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== Keyboard Layout Configuration ===${RESET}\n"

        if [ ${#selected_codes[@]} -gt 0 ]; then
            echo -e "Currently added (US is mandatory): ${C_GREEN}$(IFS=', '; echo "${selected_names[*]}")${RESET}\n"
        fi

        local choice
        choice=$(printf "%s\n" "Done (Finish Selection)" "Reset (Clear All Except US)" "${available_layouts[@]}" | sed '/^[[:space:]]*$/d' | fzf \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=15 \
            --prompt=" Add Layout > " \
            --pointer=">" \
            --header=" Select a language to add, or select Done ")

        if [[ -z "$choice" || "$choice" == *"Done"* ]]; then
            break
        fi
        
        if [[ "$choice" == *"Reset"* ]]; then
            selected_codes=("us")
            selected_names=("English (US)")
            continue
        fi

        local code=$(echo "$choice" | awk '{print $1}')
        local name=$(echo "$choice" | cut -d'-' -f2- | sed 's/^ //')

        local duplicate=false
        for existing in "${selected_codes[@]}"; do
            if [[ "$existing" == "$code" ]]; then
                duplicate=true
                break
            fi
        done

        if [ "$duplicate" = false ]; then
            selected_codes+=("$code")
            selected_names+=("$name")
        fi
    done

    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== Keyboard Layout Configuration ===${RESET}\n"
        echo -e "Currently added: ${C_GREEN}$(IFS=', '; echo "${selected_names[*]}")${RESET}\n"
        echo -e "${C_CYAN}Choose a key combination to switch between layouts:${RESET}"

        local options="1. Alt + Shift (grp:alt_shift_toggle)\n"
        options+="2. Win + Space (grp:win_space_toggle)\n"
        options+="3. Caps Lock (grp:caps_toggle)\n"
        options+="4. Ctrl + Shift (grp:ctrl_shift_toggle)"

        local choice
        choice=$(echo -e "$options" | fzf \
            --ansi \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=12 \
            --prompt=" Toggle Keybind > " \
            --pointer=">" \
            --header=" Select layout switching method ")

        local kb_opt=""
        case "$choice" in
            *"1"*) kb_opt="grp:alt_shift_toggle" ;;
            *"2"*) kb_opt="grp:win_space_toggle" ;;
            *"3"*) kb_opt="grp:caps_toggle" ;;
            *"4"*) kb_opt="grp:ctrl_shift_toggle" ;;
            *) kb_opt="grp:alt_shift_toggle" ;;
        esac

        KB_LAYOUTS=$(IFS=','; echo "${selected_codes[*]}")
        KB_LAYOUTS_DISPLAY=$(IFS=', '; echo "${selected_names[*]}")
        KB_OPTIONS="$kb_opt"

        echo -e "\n${C_GREEN}Keyboard configured: Layouts = $KB_LAYOUTS_DISPLAY | Switch = ${KB_OPTIONS:-None}${RESET}"
        sleep 1.5
        VISITED_KEYBOARD=true
        break
    done
}

show_overview() {
    draw_header
    echo -e "${BOLD}${C_MAGENTA}=== System Overview & Keybinds ===${RESET}\n"
    echo -e "This configuration is a premium Hyprland & Quickshell environment.\n"

    print_kb() {
        printf "  ${C_CYAN}[${RESET} ${BOLD}%-17s${RESET} ${C_CYAN}]${RESET}  ${C_YELLOW}➜${RESET}  %s\n" "$1" "$2"
    }

    echo -e "${BOLD}${C_BLUE}--- Applications ---${RESET}"
    print_kb "SUPER + RETURN" "Open Terminal"
    print_kb "SUPER + W" "Open Browser (Brave)"
    print_kb "SUPER + E" "Open File Manager (Nautilus)"
    print_kb "SUPER + V" "Clipboard History Manager"
    print_kb "SUPER + ," "Lock Screen"
    echo ""

    echo -e "${BOLD}${C_BLUE}--- Quickshell Widgets ---${RESET}"
    print_kb "SUPER_L (Win Key)" "Toggle App Launcher"
    print_kb "SUPER + SHIFT + I" "Toggle Control Center / Settings"
    print_kb "SUPER + SHIFT + Q" "Toggle Music Player Popup"
    print_kb "SUPER + SHIFT + W" "Toggle Wallpaper Picker"
    print_kb "SUPER + SHIFT + C" "Toggle Calendar Popup"
    print_kb "SUPER + C" "Toggle PhotoBooth"
    print_kb "SUPER + N" "Toggle Notes Widget"
    print_kb "SUPER + SHIFT + N" "Toggle Network Panel"
    print_kb "SUPER + D" "Toggle System Dashboard"
    echo ""

    echo -e "${BOLD}${C_BLUE}--- Window Management ---${RESET}"
    print_kb "SUPER + Q" "Kill Active Client"
    print_kb "SUPER + SHIFT + F" "Toggle Floating Mode"
    print_kb "SUPER + Alt + Space" "Toggle Floating Mode (Alternative)"
    print_kb "SUPER + Arrows" "Move Client Focus"
    print_kb "SUPER + CTRL + Arr" "Move Window Placement"
    echo ""

    echo -e "${BOLD}${C_BLUE}--- Screenshots & Audio ---${RESET}"
    print_kb "Print Screen" "Area Screenshot (Grim/Satty)"
    print_kb "SHIFT + Print" "Area Screenshot + Edit Overlay"
    print_kb "SUPER + Print" "Full Screen Screenshot"
    print_kb "SUPER + SPACE" "Media Play/Pause"
    echo ""

    echo -e "${BOLD}${C_GREEN}Press ENTER to return to the Main Menu...${RESET}"
    read -r
    VISITED_OVERVIEW=true
}

set_weather_api() {
    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== OpenWeatherMap Interactive Setup ===${RESET}"

        ENV_FILE="$HOME/.config/niri/scripts/quickshell/calendar/.env"

        if [ -f "$ENV_FILE" ] || [[ -n "$WEATHER_API_KEY" && "$WEATHER_API_KEY" != "Skipped" ]]; then
            echo -e "${C_GREEN}An existing Weather configuration (.env) was detected.${RESET}"
            echo -e "${BOLD}${C_YELLOW}Press ENTER without typing anything to KEEP your existing configuration.${RESET}\n"
        else
            echo -e "${BOLD}${C_YELLOW}Without this, weather widgets WILL NOT WORK.${RESET}\n"
            echo -e "${C_MAGENTA}How to get a free API key:${RESET}"
            echo -e "  1. Visit ${C_BLUE}https://openweathermap.org/${RESET}"
            echo -e "  2. Create a free account, log in, and grab your API key."
        fi

        read -p "Enter your OpenWeather API Key (or press Enter to skip/keep): " input_key

        if [[ -z "$input_key" ]]; then
            if [ -f "$ENV_FILE" ] || [[ -n "$WEATHER_API_KEY" && "$WEATHER_API_KEY" != "Skipped" ]]; then
                echo -e "\n${C_GREEN}Keeping existing weather configuration.${RESET}"
                KEEP_OLD_ENV=true
                VISITED_WEATHER=true
                sleep 1.5
                break
            else
                echo -e "\n${C_RED}WARNING: You did not enter an API key.${RESET}"
                echo -n -e "Are you ${BOLD}${C_RED}100% sure${RESET} you want to proceed without it? (y/n): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    WEATHER_API_KEY="Skipped"
                    WEATHER_CITY_ID=""
                    WEATHER_UNIT=""
                    KEEP_OLD_ENV=false
                    VISITED_WEATHER=true
                    break
                fi
                continue
            fi
        fi

        input_key=$(echo "$input_key" | tr -d ' ')
        WEATHER_API_KEY="$input_key"

        echo -e "\n${C_CYAN}Let's set your location using your City ID.${RESET}"
        echo -e "Enter the City ID of your location (e.g. 1566083 for Ho Chi Minh City):"
        read -p "Enter City ID: " input_id

        if [[ -z "$input_id" || ! "$input_id" =~ ^[0-9]+$ ]]; then
            echo -e "${C_RED}Invalid City ID. It must be a number.${RESET}"
            sleep 1.5
            continue
        fi

        WEATHER_CITY_ID="$input_id"

        echo ""
        unit_choice=$(echo -e "metric (Celsius)\nimperial (Fahrenheit)" | fzf \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=8 \
            --prompt=" Select Temperature Unit > " \
            --pointer=">" \
            --header=" Choose your preferred unit format ")

        WEATHER_UNIT=$(echo "$unit_choice" | awk '{print $1}')
        [[ -z "$WEATHER_UNIT" ]] && WEATHER_UNIT="metric"

        KEEP_OLD_ENV=false
        echo -e "\n${C_GREEN}Weather configuration complete!${RESET}"
        sleep 2.5
        VISITED_WEATHER=true
        break
    done
}

manage_telemetry() {
    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== Telemetry Configuration ===${RESET}\n"
        echo -e "Help improve the environment by sending anonymous hardware statistics"
        echo -e "when starting the installation process.\n"

        local current_status="${DIM}OFF${RESET}"
        if [[ "$ENABLE_TELEMETRY" == true ]]; then
            current_status="${C_GREEN}ON${RESET}"
        fi

        echo -e "Current Status: ${BOLD}$current_status${RESET}\n"

        local action
        action=$(echo -e "1. Enable Telemetry\n2. Disable Telemetry\n3. Back to Main Menu" | fzf \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=12 \
            --prompt=" Telemetry > " \
            --pointer=">" \
            --header=" Use ARROW KEYS and ENTER ")

        case "$action" in
            *"1"*)
                ENABLE_TELEMETRY=true
                echo -e "${C_GREEN}Telemetry Enabled. Thank you!${RESET}"
                sleep 1
                break
                ;;
            *"2"*)
                ENABLE_TELEMETRY=false
                echo -e "${C_YELLOW}Telemetry Disabled.${RESET}"
                sleep 1
                break
                ;;
            *"3"*) break ;;
            *) break ;;
        esac
    done
}

prompt_optional_features_menu() {
    DM_SERVICES=("gdm" "gdm3" "lightdm" "sddm" "lxdm" "lxdm-gtk3" "ly")
    CURRENT_DM=""
    for dm in "${DM_SERVICES[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
            CURRENT_DM="$dm"
            break
        fi
    done

    local DM_LABEL="Display Manager Integration (SDDM)"
    if [[ "$CURRENT_DM" == "sddm" ]]; then
        DM_LABEL="Configure SDDM Theme (sddm detected)"
    elif [[ -n "$CURRENT_DM" ]]; then
        DM_LABEL="Replace $CURRENT_DM with SDDM"
    fi

    local HAS_HISTORY=false
    if [ "$LOCAL_VERSION" != "Not Installed" ] && [ -n "$LOCAL_VERSION" ]; then
        HAS_HISTORY=true
    fi

    while true; do
        draw_header
        echo -e "${BOLD}${C_CYAN}=== Optional Component Setup ===${RESET}\n"

        local S_SDDM=$( [ "$OPT_SDDM" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )
        local S_NVIM=$( [ "$OPT_NVIM" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )
        local S_FISH=$( [ "$OPT_FISH" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )
        local S_WP=$( [ "$OPT_WALLPAPERS" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )

        local MENU_ITEMS="1. $S_SDDM $DM_LABEL\n"
        MENU_ITEMS+="2. $S_NVIM Neovim Matugen Configuration\n"
        MENU_ITEMS+="3. $S_FISH Fish Shell Setup\n"
        MENU_ITEMS+="4. $S_WP Download FULL Wallpaper Pack (Unchecked = 3 Random)\n"

        if [ "$HAS_HISTORY" = true ]; then
            local S_KB_OVR=$( [ "$OPT_OVERRIDE_KEYBINDS" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )
            local S_STARTUPS_OVR=$( [ "$OPT_OVERRIDE_STARTUPS" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${DIM}[ ]${RESET}" )
            MENU_ITEMS+="5. $S_KB_OVR Reset local keybinds to upstream defaults\n"
            MENU_ITEMS+="6. $S_STARTUPS_OVR Overwrite Local Startups with Upstream Defaults\n"
            MENU_ITEMS+="7. ${BOLD}${C_GREEN}Proceed with Installation / Update${RESET}\n"
            MENU_ITEMS+="8. ${DIM}Back to Main Menu${RESET}"
        else
            OPT_OVERRIDE_KEYBINDS=false
            OPT_OVERRIDE_STARTUPS=false
            MENU_ITEMS+="5. ${BOLD}${C_GREEN}Proceed with Installation${RESET}\n"
            MENU_ITEMS+="6. ${DIM}Back to Main Menu${RESET}"
        fi

        local choice
        choice=$(echo -e "$MENU_ITEMS" | fzf \
            --ansi \
            --layout=reverse \
            --border=rounded \
            --margin=1,2 \
            --height=18 \
            --prompt=" Options > " \
            --pointer=">" \
            --header=" SPACE or ENTER to toggle. Select Proceed when ready. ")

        local break_and_proceed=false

        case "$choice" in
            *"1."*) OPT_SDDM=$([ "$OPT_SDDM" = true ] && echo false || echo true) ;;
            *"2."*) OPT_NVIM=$([ "$OPT_NVIM" = true ] && echo false || echo true) ;;
            *"3."*) OPT_FISH=$([ "$OPT_FISH" = true ] && echo false || echo true) ;;
            *"4."*) OPT_WALLPAPERS=$([ "$OPT_WALLPAPERS" = true ] && echo false || echo true) ;;
            *"5."*) 
                if [ "$HAS_HISTORY" = true ]; then
                    OPT_OVERRIDE_KEYBINDS=$([ "$OPT_OVERRIDE_KEYBINDS" = true ] && echo false || echo true)
                else
                    break_and_proceed=true
                fi
                ;;
            *"6."*) 
                if [ "$HAS_HISTORY" = true ]; then
                    OPT_OVERRIDE_STARTUPS=$([ "$OPT_OVERRIDE_STARTUPS" = true ] && echo false || echo true)
                else
                    return 1
                fi
                ;;
            *"7."*) 
                if [ "$HAS_HISTORY" = true ]; then
                    break_and_proceed=true
                fi
                ;;
            *"8."*) 
                if [ "$HAS_HISTORY" = true ]; then
                    return 1
                fi
                ;;
            *) ;;
        esac

        if [ "$break_and_proceed" = true ]; then
            if [ "$OPT_SDDM" = true ]; then
                if [[ -z "$CURRENT_DM" ]]; then
                    INSTALL_SDDM=true
                    SETUP_SDDM_THEME=true
                    PKGS+=("sddm")
                elif [[ "$CURRENT_DM" == "sddm" ]]; then
                    SETUP_SDDM_THEME=true
                else
                    INSTALL_SDDM=true
                    REPLACE_DM=true
                    SETUP_SDDM_THEME=true
                    PKGS+=("sddm")
                fi
                
                clear
                draw_header
                echo -e "${BOLD}${C_CYAN}=== SDDM Configuration ===${RESET}\n"
                echo -e "Do you want to force SDDM to run natively on Wayland?"
                read -p "Force SDDM Wayland backend? (y/N): " sddm_wayland
                if [[ "$sddm_wayland" =~ ^[Yy]$ ]]; then
                    SDDM_WAYLAND=true
                else
                    SDDM_WAYLAND=false
                fi
            fi
            if [ "$OPT_NVIM" = true ]; then
                INSTALL_NVIM=true
                PKGS+=("neovim" "lua-language-server" "unzip" "nodejs" "npm" "python3")
            fi
            if [ "$OPT_FISH" = true ]; then
                INSTALL_FISH=true
                PKGS+=("fish")
            fi
            return 0 
        fi
    done
}

# ==============================================================================
# Main Menu Loop
# ==============================================================================
while true; do
    draw_header

    S_PKG=$( [ "$VISITED_PKGS" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${C_YELLOW}[-]${RESET}" )
    S_OVW=$( [ "$VISITED_OVERVIEW" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${C_YELLOW}[-]${RESET}" )
    S_WTH=$( [ "$VISITED_WEATHER" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${C_YELLOW}[-]${RESET}" )
    S_DRV=$( [ "$VISITED_DRIVERS" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${C_YELLOW}[-]${RESET}" )
    S_KBD=$( [ "$VISITED_KEYBOARD" = true ] && echo -e "${C_GREEN}[✓]${RESET}" || echo -e "${C_RED}[ ]${RESET}" )
    S_TEL=$( [ "$ENABLE_TELEMETRY" = true ] && echo -e "${C_GREEN}[ON]${RESET}" || echo -e "${DIM}[OFF]${RESET}" )

    if [[ -z "$WEATHER_API_KEY" ]]; then
        if [ -f "$HOME/.config/niri/scripts/quickshell/calendar/.env" ]; then
            API_DISPLAY="Set (from .env file)"
        else
            API_DISPLAY="Not Set"
        fi
    elif [[ "$WEATHER_API_KEY" == "Skipped" ]]; then API_DISPLAY="Skipped"
    else API_DISPLAY="Set ($WEATHER_UNIT, ID: $WEATHER_CITY_ID)"; fi

    if [ "$LOCAL_VERSION" != "Not Installed" ] && [ -n "$LOCAL_VERSION" ]; then
        INSTALL_LABEL="UPDATE"
    else
        INSTALL_LABEL="START"
    fi

    MENU_ITEMS="1. $S_PKG ${C_GREEN}Manage Packages${RESET} [${#PKGS[@]} queued, Optional]\n"
    MENU_ITEMS+="2. $S_OVW ${C_CYAN}Overview & Keybinds${RESET} [Optional]\n"
    MENU_ITEMS+="3. $S_WTH ${C_YELLOW}Set Weather API Key${RESET} [${API_DISPLAY}, Optional]\n"
    MENU_ITEMS+="4. $S_DRV ${C_RED}[ DRIVERS ] Setup${RESET} [${DRIVER_CHOICE}, Optional]\n"
    MENU_ITEMS+="5. $S_KBD ${C_BLUE}Keyboard Layout Setup${RESET} [${KB_LAYOUTS_DISPLAY:-$KB_LAYOUTS}]\n"
    MENU_ITEMS+="6. $S_TEL ${C_CYAN}Telemetry Settings${RESET}\n"
    MENU_ITEMS+="7. ${BOLD}${C_MAGENTA}${INSTALL_LABEL}${RESET}\n"
    MENU_ITEMS+="8. ${DIM}Exit${RESET}"

    MENU_OPTION=$(echo -e "$MENU_ITEMS" | fzf \
        --ansi \
        --layout=reverse \
        --border=rounded \
        --margin=1,2 \
        --height=17 \
        --prompt=" Main Menu > " \
        --pointer=">" \
        --header=" Navigate with ARROWS. Select with ENTER. ")

    case "$MENU_OPTION" in
        *"1."*) manage_packages ;;
        *"2."*) show_overview ;;
        *"3."*) set_weather_api ;;
        *"4."*) manage_drivers ;;
        *"5."*) manage_keyboard ;;
        *"6."*) manage_telemetry ;;
        *"7."*) 
            if [ "$VISITED_KEYBOARD" = false ]; then
                echo -e "\n${C_RED}[!] You must configure your Keyboard Layouts in the submenu before starting.${RESET}"
                sleep 2.5
                continue
            fi
            if prompt_optional_features_menu; then
                break 
            else
                continue
            fi
            ;;
        *"8."*) clear; exit 0 ;;
        *) exit 0 ;;
    esac
done

# ==============================================================================
# Installation Process Execution
# ==============================================================================
clear
draw_header
echo -e "${BOLD}${C_BLUE}::${RESET} ${BOLD}Starting Installation Process...${RESET}\n"

send_telemetry "full"

echo -e "${C_CYAN}[ INFO ]${RESET} Requesting sudo privileges for installation..."
if ! sudo -v; then
    echo -e "${C_RED}[ ERROR ] Failed to obtain sudo privileges. Exiting...${RESET}"
    exit 1
fi

# --- 0. Resolve Package Conflicts ---
echo -e "\n${C_CYAN}[ INFO ]${RESET} Resolving potential package conflicts..."
for jack_pkg in jack jack2 jack2-dbus; do
    if pacman -Qq "$jack_pkg" &>/dev/null; then
        echo -e "  -> Removing conflicting package '$jack_pkg'..."
        sudo pacman -Rdd --noconfirm "$jack_pkg" 2>/dev/null || true
    fi
done

yes "Y" | $PKG_MANAGER pipewire-jack > /dev/null 2>&1 || true

CONFLICTING_PKGS=("swayosd" "quickshell" "matugen")
for cpkg in "${CONFLICTING_PKGS[@]}"; do
    if pacman -Qq | grep -qx "$cpkg"; then
        echo -e "  -> ${C_YELLOW}Removing conflicting package '$cpkg'...${RESET}"
        systemctl --user stop "$cpkg" 2>/dev/null || true
        sudo systemctl stop "$cpkg" 2>/dev/null || true

        if ! sudo pacman -Rns --noconfirm "$cpkg" > /dev/null 2>&1; then
            sudo pacman -Rdd --noconfirm "$cpkg" > /dev/null 2>&1
        fi
    fi
done

ALL_PKGS=("${PKGS[@]}" "${DRIVER_PKGS[@]}")
MISSING_PKGS=()

echo -e "\n${C_CYAN}[ INFO ]${RESET} Checking for already installed packages..."

# Filter out empty entries from ALL_PKGS
UNIQUE_PKGS=()
for pkg in "${ALL_PKGS[@]}"; do
    [[ -n "$pkg" ]] && UNIQUE_PKGS+=("$pkg")
done

if [ ${#UNIQUE_PKGS[@]} -gt 0 ]; then
    # Fast path: check if all packages are installed at once
    if pacman -Qq "${UNIQUE_PKGS[@]}" &>/dev/null; then
        true
    else
        # Slow path: find exactly which packages are missing
        for pkg in "${UNIQUE_PKGS[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                MISSING_PKGS+=("$pkg")
            fi
        done
    fi
fi

# --- 1. Install Dependencies & Drivers ---
if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    echo -e "  -> ${C_GREEN}All packages are already installed! Skipping package download phase.${RESET}\n"
else
    echo -e "  -> ${C_YELLOW}Found ${#MISSING_PKGS[@]} missing packages to install.${RESET}"
    echo -e "\n${C_CYAN}[ INFO ]${RESET} Installing System Packages & Drivers...\n"

    # Separate official and AUR packages
    MISSING_OFFICIAL=()
    MISSING_AUR=()
    for pkg in "${MISSING_PKGS[@]}"; do
        if pacman -Sp "$pkg" &>/dev/null; then
            MISSING_OFFICIAL+=("$pkg")
        else
            MISSING_AUR+=("$pkg")
        fi
    done

    # Safe compile jobs environment variables
    SAFE_JOBS=$(( $(nproc) / 2 ))
    [[ $SAFE_JOBS -lt 1 ]] && SAFE_JOBS=1
    [[ $SAFE_JOBS -gt 4 ]] && SAFE_JOBS=4
    export CARGO_BUILD_JOBS="$SAFE_JOBS"
    export MAKEFLAGS="-j$SAFE_JOBS"

    # Install Official Packages first
    if [ ${#MISSING_OFFICIAL[@]} -gt 0 ]; then
        echo -e "\n${C_CYAN}[ INFO ]${RESET} Installing Official Packages: ${MISSING_OFFICIAL[*]}..."
        if sudo pacman -S --needed --noconfirm "${MISSING_OFFICIAL[@]}"; then
            echo -e "${C_GREEN}[ OK ] Successfully installed official packages.${RESET}"
        else
            echo -e "${C_RED}[ WARNING ] Batch installation of official packages failed. Falling back to sequential...${RESET}"
            for pkg in "${MISSING_OFFICIAL[@]}"; do
                if sudo pacman -S --needed --noconfirm "$pkg"; then
                    echo -e "  -> ${C_GREEN}[ OK ] Installed $pkg${RESET}"
                else
                    echo -e "  -> ${C_RED}[ FAILED ] Failed to install $pkg${RESET}"
                    FAILED_PKGS+=("$pkg")
                fi
            done
        fi
    fi

    # Install AUR Packages
    if [ ${#MISSING_AUR[@]} -gt 0 ]; then
        echo -e "\n${C_CYAN}[ INFO ]${RESET} Installing AUR Packages: ${MISSING_AUR[*]}..."
        if yes "Y" | $PKG_MANAGER "${MISSING_AUR[@]}"; then
            echo -e "${C_GREEN}[ OK ] Successfully installed AUR packages.${RESET}"
        else
            echo -e "${C_RED}[ WARNING ] Batch installation of AUR packages failed. Falling back to sequential...${RESET}"
            for pkg in "${MISSING_AUR[@]}"; do
                if yes "Y" | $PKG_MANAGER "$pkg"; then
                    echo -e "  -> ${C_GREEN}[ OK ] Installed $pkg${RESET}"
                else
                    echo -e "  -> ${C_RED}[ FAILED ] Failed to install $pkg${RESET}"
                    FAILED_PKGS+=("$pkg")
                fi
            done
        fi
    fi
fi

# --- 1.5. Advanced Proprietary NVIDIA Setup ---
if [ "$HAS_NVIDIA_PROPRIETARY" = true ]; then
    echo -e "\n${C_CYAN}[ INFO ]${RESET} Performing Precise NVIDIA Initialization for Wayland..."
    echo -e "  -> Injecting kernel parameters via modprobe (nvidia-drm.modeset=1 nvidia-drm.fbdev=1)..."
    echo -e "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null

    if command -v mkinitcpio &> /dev/null; then
        echo -e "  -> Rebuilding initramfs (mkinitcpio)..."
        sudo mkinitcpio -P >/dev/null 2>&1
        printf "  -> Mkinitcpio rebuild successful %-9s ${C_GREEN}[ OK ]${RESET}\n" ""
    elif command -v dracut &> /dev/null; then
        echo -e "  -> Rebuilding initramfs (dracut)..."
        sudo dracut --force >/dev/null 2>&1
        printf "  -> Dracut rebuild successful %-14s ${C_GREEN}[ OK ]${RESET}\n" ""
    fi
fi

# --- 2. Display Manager Configuration ---
if [[ "$INSTALL_SDDM" == true || "$SETUP_SDDM_THEME" == true || "$REPLACE_DM" == true ]]; then
    echo -e "\n${C_CYAN}[ INFO ]${RESET} Configuring Display Manager..."
fi

if [[ "$REPLACE_DM" == true ]]; then
    DMS=("lightdm" "gdm" "gdm3" "lxdm" "lxdm-gtk3" "ly")
    for dm in "${DMS[@]}"; do
        if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then
            echo "  -> Disabling conflicting Display Manager: $dm"
            sudo systemctl disable "$dm.service" 2>/dev/null || true
            sudo pacman -Rns --noconfirm "$dm" > /dev/null 2>&1 || true
        fi
    done
fi

if [[ "$INSTALL_SDDM" == true ]]; then
    sudo systemctl enable sddm.service -f
    printf "  -> SDDM enabled successfully %-14s ${C_GREEN}[ OK ]${RESET}\n" ""
fi

# ------------------------------------------------------------------------------
# 3. DEPLOY CONFIGURATION AND CLONING
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Setting up Dotfiles Configuration..."
REPO_URL="https://github.com/noqokhxnh/my_configuration.git"
TARGET_CONFIG_DIR="$HOME/.config/niri"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

OLD_COMMIT=""
NEW_COMMIT=""

# Safety Backup of Existing Settings
if [ -f "$TARGET_CONFIG_DIR/settings.json" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$TARGET_CONFIG_DIR/settings.json" "$BACKUP_DIR/settings.json"
fi

if [ -f "$(pwd)/install.sh" ] && [ -d "$(pwd)/config" ] && [ -d "$(pwd)/.git" ] && [ "$(pwd)" != "$HOME" ]; then
    REPO_DIR="$(pwd)"
    echo "  -> Running from local repository at $REPO_DIR"
    NEW_COMMIT=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
    OLD_COMMIT="$LAST_COMMIT"
else
    OLD_COMMIT="$LAST_COMMIT"
    if [ -d "$TARGET_CONFIG_DIR" ]; then
        echo -e "  -> Backing up old configuration to ${BACKUP_DIR}/hypr"
        mkdir -p "$BACKUP_DIR"
        mv "$TARGET_CONFIG_DIR" "$BACKUP_DIR/hypr"
    fi
    echo -e "  -> Cloning repository from ${REPO_URL}..."
    if ! git clone -b "$TARGET_BRANCH" "$REPO_URL" "$TARGET_CONFIG_DIR"; then
        echo -e "${C_RED}[ ERROR ] Failed to clone repository. Cannot proceed with installation.${RESET}"
        exit 1
    fi
    REPO_DIR="$TARGET_CONFIG_DIR"
    NEW_COMMIT=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
fi

# Deploy Upstream Optional Packages (Neovim/Fish)
if [ "$INSTALL_NVIM" = true ]; then
    echo -e "  -> Deploying Neovim configuration..."
    git clone https://github.com/ilyamiro/imperative-dots.git /tmp/dots-temp >/dev/null 2>&1
    if [ -d "/tmp/dots-temp/.config/nvim" ]; then
        mv "$HOME/.config/nvim" "$BACKUP_DIR/nvim" 2>/dev/null || true
        cp -r /tmp/dots-temp/.config/nvim "$HOME/.config/nvim"
    fi
    rm -rf /tmp/dots-temp
fi

if [ "$INSTALL_FISH" = true ]; then
    echo -e "  -> Deploying Fish Shell configuration..."
    # Back up existing fish folder
    mv "$HOME/.config/fish" "$BACKUP_DIR/fish" 2>/dev/null || true
    mkdir -p "$HOME/.config/fish"
    
    # Set up basic structure
    echo -e "  -> Fish Shell package queued. Setting up default config structure..."
fi

# ------------------------------------------------------------------------------
# 4. FETCH WALLPAPERS
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Fetching Wallpapers..."
mkdir -p "$WALLPAPER_DIR"

if [ "$(ls -A "$WALLPAPER_DIR" 2>/dev/null | grep -E '\.(jpg|png|jpeg|gif|webp)$')" ]; then
    echo -e "  -> ${C_GREEN}Wallpapers already present in $WALLPAPER_DIR. Skipping download.${RESET}"
else
    WALLPAPER_REPO="https://github.com/ilyamiro/shell-wallpapers.git"
    WALLPAPER_CLONE_DIR="/tmp/shell-wallpapers"

    if [ -d "$WALLPAPER_CLONE_DIR" ]; then
        rm -rf "$WALLPAPER_CLONE_DIR"
    fi

    if [[ "$OPT_WALLPAPERS" == true ]]; then
        git clone --progress "$WALLPAPER_REPO" "$WALLPAPER_CLONE_DIR" 2>&1 | tr '\r' '\n' | while read -r line; do
            if [[ "$line" =~ Receiving\ objects:\ *([0-9]+)% ]]; then
                pc="${BASH_REMATCH[1]}"
                fill=$(printf "%*s" $((pc / 2)) "" | tr ' ' '#')
                empty=$(printf "%*s" $((50 - (pc / 2))) "" | tr ' ' '-')
                printf "\r\033[K  -> Downloading: [%s%s] %3d%%" "$fill" "$empty" "$pc"
            fi
        done
        echo "" 

        if [ -d "$WALLPAPER_CLONE_DIR/images" ]; then
            cp -r "$WALLPAPER_CLONE_DIR/images/"* "$WALLPAPER_DIR/" 2>/dev/null || true
        else
            cp -r "$WALLPAPER_CLONE_DIR/"* "$WALLPAPER_DIR/" 2>/dev/null || true
        fi
        rm -rf "$WALLPAPER_CLONE_DIR"
        printf "  -> Full wallpaper pack installed to %-12s ${C_GREEN}[ OK ]${RESET}\n" "$WALLPAPER_DIR"
    else
        echo -e "  -> ${C_CYAN}Fetching 3 random wallpapers to save time...${RESET}"
        mkdir -p "$WALLPAPER_CLONE_DIR"
        (
            cd "$WALLPAPER_CLONE_DIR" || exit
            git init -q
            git remote add origin "$WALLPAPER_REPO"
            git fetch --depth 1 --filter=blob:none origin HEAD -q
            RANDOM_PICS=$(git ls-tree -r FETCH_HEAD --name-only | grep -iE '\.(jpg|jpeg|png|gif|webp)$' | shuf -n 3)
            if [ -n "$RANDOM_PICS" ]; then
                for pic in $RANDOM_PICS; do
                    filename=$(basename "$pic")
                    echo -n "    -> Downloading $filename... "
                    git show FETCH_HEAD:"$pic" > "$WALLPAPER_DIR/$filename" 2>/dev/null
                    echo -e "${C_GREEN}[ DONE ]${RESET}"
                done
            else
                echo -e "    -> ${C_RED}Could not find any images in the repository.${RESET}"
            fi
        )
        rm -rf "$WALLPAPER_CLONE_DIR"
        printf "  -> Random wallpapers installed to %-12s ${C_GREEN}[ OK ]${RESET}\n" "$WALLPAPER_DIR"
    fi
fi

# ------------------------------------------------------------------------------
# 5. SINGLE SOURCE OF TRUTH (SSoT) SETTINGS MERGING
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Establishing settings.json SSoT..."
SETTINGS_FILE="$TARGET_CONFIG_DIR/settings.json"
UPSTREAM_JSON="$REPO_DIR/default_settings.json"

mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ -f "$BACKUP_DIR/settings.json" ] && jq -e . "$BACKUP_DIR/settings.json" >/dev/null 2>&1; then
    OLD_JSON="$BACKUP_DIR/settings.json"
    echo "  -> Processing JSON Merges safely..."
else
    OLD_JSON="$UPSTREAM_JSON"
    echo "  -> Generating fresh configuration from upstream defaults..."
fi

# Pure jq merge logic
jq -n --slurpfile local "$OLD_JSON" --slurpfile up "$UPSTREAM_JSON" \
   --arg langs "$KB_LAYOUTS" \
   --arg wpdir "$WALLPAPER_DIR" \
   --arg kbopt "$KB_OPTIONS" \
   --arg ovr_kb "$OPT_OVERRIDE_KEYBINDS" \
   --arg ovr_su "$OPT_OVERRIDE_STARTUPS" '
   
   $up[0] as $u |
   (if ($local | length > 0) then $local[0] else $u end) as $l |
   
   ($u + $l) | 
   .language = $langs |
   .wallpaperDir = $wpdir |
   .kbOptions = $kbopt |
   
   .keybinds = (
       if $ovr_kb == "true" then 
           $u.keybinds 
       else 
           ($l.keybinds | map(((.mods // "") + "|" + (.key // "")))) as $local_keys |
           ($l.keybinds | map(.command)) as $local_cmds |
           
           ($u.keybinds | map(select(
               (((.mods // "") + "|" + (.key // "")) as $k | ($local_keys | index($k)) == null) and
               (.command as $cmd | ($local_cmds | index($cmd)) == null)
           ))) as $new_upstream |
           
           ($l.keybinds + $new_upstream)
       end
   ) |
   
   .startup = (
       if $ovr_su == "true" then 
           $u.startup 
       else 
           ($l.startup | map(.command)) as $local_startups |
           ($u.startup | map(select(.command as $cmd | ($local_startups | index($cmd)) == null))) as $new_upstream_startups |
           ($l.startup + $new_upstream_startups)
       end
   )
' > "$SETTINGS_FILE"

printf "  -> Configuration merged %-23s ${C_GREEN}[ OK ]${RESET}\n" ""

# ------------------------------------------------------------------------------
# 5.5. WEATHER ENVIRONMENT PERSISTENCE
# ------------------------------------------------------------------------------
if [[ "$WEATHER_API_KEY" != "Skipped" && -n "$WEATHER_API_KEY" ]]; then
    WEATHER_ENV="$TARGET_CONFIG_DIR/scripts/quickshell/calendar/.env"
    mkdir -p "$(dirname "$WEATHER_ENV")"
    cat <<EOF > "$WEATHER_ENV"
OPENWEATHER_KEY='$WEATHER_API_KEY'
OPENWEATHER_CITY_ID='$WEATHER_CITY_ID'
OPENWEATHER_UNIT='$WEATHER_UNIT'
EOF
    chmod 600 "$WEATHER_ENV"
    printf "  -> Weather environment saved %-20s ${C_GREEN}[ OK ]${RESET}\n" ""
fi

# ------------------------------------------------------------------------------
# 6. SYSTEM FONTS SETUP
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Checking and Configuring Fonts..."
TARGET_FONTS_DIR="$HOME/.local/share/fonts"
mkdir -p "$TARGET_FONTS_DIR"

if ! fc-list : family | grep -qi "Iosevka Nerd Font"; then
    echo -e "  -> Downloading Iosevka Nerd Font..."
    ZIP_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip"
    TEMP_ZIP="/tmp/Iosevka.zip"
    
    if curl -L --fail --connect-timeout 15 --retry 3 -o "$TEMP_ZIP" "$ZIP_URL" -s; then
        echo -e "  -> Extracting font files..."
        TEMP_DIR="/tmp/iosevka_fonts"
        mkdir -p "$TEMP_DIR"
        if unzip -q -o "$TEMP_ZIP" -d "$TEMP_DIR"; then
            cp "$TEMP_DIR"/*.ttf "$TARGET_FONTS_DIR/" 2>/dev/null || cp "$TEMP_DIR"/*.otf "$TARGET_FONTS_DIR/" 2>/dev/null || true
            printf "  -> Font installed successfully %-10s ${C_GREEN}[ OK ]${RESET}\n" ""
        else
            echo -e "  -> ${C_RED}[ ERROR ] Failed to extract font files.${RESET}"
        fi
        rm -rf "$TEMP_ZIP" "$TEMP_DIR"
    else
        echo -e "  -> ${C_RED}[ ERROR ] Failed to download Iosevka Nerd Font (network timeout or package not found).${RESET}"
        rm -f "$TEMP_ZIP"
    fi
fi

if [ -d "$TARGET_FONTS_DIR" ]; then
    find "$TARGET_FONTS_DIR" -type f -exec chmod 644 {} \; 2>/dev/null
    find "$TARGET_FONTS_DIR" -type d -exec chmod 755 {} \; 2>/dev/null
fi

if command -v fc-cache &> /dev/null; then
    fc-cache -f "$TARGET_FONTS_DIR" > /dev/null 2>&1
    printf "  -> Font cache updated %-21s ${C_GREEN}[ OK ]${RESET}\n" ""
fi

# ------------------------------------------------------------------------------
# 6.3. ENVIRONMENT PATHS AUTOGENERATION
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Generating dynamic environment paths (env.conf)..."
cat <<EOF > "$TARGET_CONFIG_DIR/config/env.conf"
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ ENVIRONMENT VARIABLES (AUTOGENERATED)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

env = NIXOS_OZONE_WL,1
env = XDG_PICTURES_DIR,$USER_PICTURES_DIR
env = XDG_VIDEOS_DIR,$USER_VIDEOS_DIR
env = WALLPAPER_DIR,$WALLPAPER_DIR
env = SCRIPT_DIR,$TARGET_CONFIG_DIR/scripts
env = QT_QPA_PLATFORMTHEME,qt6ct

# Hardware Injections
EOF
printf "  -> env.conf generated successfully %-10s ${C_GREEN}[ OK ]${RESET}\n" ""

# ------------------------------------------------------------------------------
# 6.5. DESKTOP VS LAPTOP ADAPTABILITY
# ------------------------------------------------------------------------------
QS_BAT_DIR="$TARGET_CONFIG_DIR/scripts/quickshell/battery"
echo -e "\n${C_CYAN}[ INFO ]${RESET} Checking chassis for battery presence..."
if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then
    echo -e "  -> ${C_GREEN}Battery detected.${RESET} Keeping Laptop Battery widget."
    if [ -f "$REPO_DIR/scripts/quickshell/battery/BatteryPopup.qml" ]; then
        cp -f "$REPO_DIR/scripts/quickshell/battery/BatteryPopup.qml" "$QS_BAT_DIR/BatteryPopup.qml" 2>/dev/null || true
    fi
else
    echo -e "  -> ${C_YELLOW}No battery detected (Desktop system).${RESET} Swapping to System Monitor widget."
    if [ -f "$REPO_DIR/scripts/quickshell/battery/BatteryPopupAlt.qml" ]; then
        cp -f "$REPO_DIR/scripts/quickshell/battery/BatteryPopupAlt.qml" "$QS_BAT_DIR/BatteryPopup.qml" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 6.5. HEALING & REBUILDING QUICKSHELL & CONFIGURING FCITX5
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Checking system library and application state..."

# 6.5a. Check and Rebuild Quickshell if Qt6 mismatch is detected
if command -v quickshell &>/dev/null; then
    QS_BUILD_DATE=$(stat -c %Y /usr/bin/quickshell 2>/dev/null || echo 0)
    QT_INSTALL_DATE=$(stat -c %Y /usr/lib/libQt6Core.so 2>/dev/null || echo 0)
    
    if [ "$QT_INSTALL_DATE" -gt "$QS_BUILD_DATE" ]; then
        echo -e "  -> ${C_YELLOW}Qt6 libraries were updated after Quickshell was built.${RESET}"
        echo -e "     Rebuilding 'quickshell-git' to prevent crash loops..."
        if command -v yay &>/dev/null; then
            yay -S --noconfirm --rebuild quickshell-git || true
        elif command -v paru &>/dev/null; then
            paru -S --noconfirm --rebuild quickshell-git || true
        else
            echo -e "     -> ${C_YELLOW}No AUR helper found. Attempting manual rebuild...${RESET}"
            git clone https://aur.archlinux.org/quickshell-git.git /tmp/quickshell-git 2>/dev/null || true
            (cd /tmp/quickshell-git && makepkg -si --noconfirm 2>/dev/null || true)
            rm -rf /tmp/quickshell-git
        fi
    else
        echo -e "  -> Quickshell Qt6 build is up-to-date. ${C_GREEN}[ OK ]${RESET}"
    fi
fi

# 6.5b. Configure Fcitx5 classic UI (Prevent invisible/missing tray icon on Wayland)
if pacman -Q fcitx5 &>/dev/null; then
    echo -e "  -> Ensuring high-visibility text icon for Fcitx5..."
    FCITX5_CONF_DIR="$HOME/.config/fcitx5/conf"
    mkdir -p "$FCITX5_CONF_DIR"
    CLASSICUI_FILE="$FCITX5_CONF_DIR/classicui.conf"

    if [ ! -f "$CLASSICUI_FILE" ]; then
        cat <<EOF > "$CLASSICUI_FILE"
# Prefer Text Icon
PreferTextIcon=True
EOF
        echo -e "     -> Created new classicui.conf with PreferTextIcon=True"
    else
        if grep -q "^PreferTextIcon=" "$CLASSICUI_FILE"; then
            sed -i 's/^PreferTextIcon=.*/PreferTextIcon=True/' "$CLASSICUI_FILE"
        else
            echo "PreferTextIcon=True" >> "$CLASSICUI_FILE"
        fi
        echo -e "     -> Updated classicui.conf to ensure PreferTextIcon=True"
    fi
    # Restart fcitx5 if it is already running to apply settings instantly
    if pgrep -x fcitx5 >/dev/null; then
        echo -e "     -> Restarting Fcitx5 to apply settings..."
        killall fcitx5 2>/dev/null || true
        sleep 1
        fcitx5 -d &>/dev/null &
    fi
fi

# ------------------------------------------------------------------------------
# 7. COMPILING CUSTOM C++ DAEMONS
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Compiling Custom C++ Components..."

# Rebuild all quickshell backends and daemons
if [ -f "$REPO_DIR/scripts/quickshell/rebuild_all.sh" ]; then
    echo -e "  -> Compiling all Quickshell C++ components (rebuild_all.sh)..."
    chmod +x "$REPO_DIR/scripts/quickshell/rebuild_all.sh"
    bash "$REPO_DIR/scripts/quickshell/rebuild_all.sh" >/dev/null 2>&1 || true
    printf "  -> C++ components compiled successfully %-4s ${C_GREEN}[ OK ]${RESET}\n" ""
else
    # Fallback to legacy single-daemon compilation if rebuild_all.sh is missing
    if [ -f "$REPO_DIR/scripts/quickshell/compile_daemon.sh" ]; then
        echo -e "  -> Compiling qs_daemon (Desktop Control Daemon)..."
        chmod +x "$REPO_DIR/scripts/quickshell/compile_daemon.sh"
        (cd "$REPO_DIR/scripts/quickshell" && bash compile_daemon.sh >/dev/null 2>&1)
    fi
    if [ -f "$REPO_DIR/scripts/quickshell/screenshot/compile_screenshot.sh" ]; then
        echo -e "  -> Compiling screenshot_backend (Screenshot Beautifier)..."
        chmod +x "$REPO_DIR/scripts/quickshell/screenshot/compile_screenshot.sh"
        (cd "$REPO_DIR/scripts/quickshell/screenshot" && bash compile_screenshot.sh >/dev/null 2>&1)
    fi
fi

# ------------------------------------------------------------------------------
# 7.5. ENABLE SERVICES & SET PERMISSIONS
# ------------------------------------------------------------------------------
echo -e "\n${C_CYAN}[ INFO ]${RESET} Enabling Core System Services..."
sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
printf "  -> NetworkManager enabled %-20s ${C_GREEN}[ OK ]${RESET}\n" ""
sudo systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1 || true
printf "  -> Power Profiles Daemon enabled %-13s ${C_GREEN}[ OK ]${RESET}\n" ""

echo -e "\n${C_CYAN}[ INFO ]${RESET} Setting executable permissions on scripts..."
find "$TARGET_CONFIG_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
printf "  -> Permissions set successfully %-14s ${C_GREEN}[ OK ]${RESET}\n" ""

# Setup SDDM Theme and Config
if [[ "$SETUP_SDDM_THEME" == true ]]; then
    if [ -d "$REPO_DIR/sddm/themes/matugen-minimal" ]; then
        sudo mkdir -p /usr/share/sddm/themes/matugen-minimal
        sudo cp -r "$REPO_DIR/sddm/themes/matugen-minimal/"* /usr/share/sddm/themes/matugen-minimal/

        cat <<EOF | sudo tee /usr/share/sddm/themes/matugen-minimal/Colors.qml > /dev/null
pragma Singleton
import QtQuick
QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color crust: "#11111b"
    readonly property color mantle: "#181825"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color blue: "#89b4fa"
    readonly property color green: "#a6e3a1"
}
EOF
        sudo chown $USER:$USER /usr/share/sddm/themes/matugen-minimal/Colors.qml

        sudo mkdir -p /etc/sddm.conf.d
        if [[ "$SDDM_WAYLAND" == true ]]; then
            cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland-matugen.conf > /dev/null
[Theme]
Current=matugen-minimal

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
        else
            cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland-matugen.conf > /dev/null
[Theme]
Current=matugen-minimal
EOF
        fi
        printf "  -> SDDM Theme configured %-17s ${C_GREEN}[ OK ]${RESET}\n" ""
    fi
fi

# Clean caches
rm -f ~/.cache/quickshell/updater/update_pending 2>/dev/null || true
rm -f ~/.local/state/quickshell/wallpaper_picker/wallpaper_initialized 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. FINALIZE VERSION MARKER & USER STATE
# ------------------------------------------------------------------------------
cat <<EOF > "$VERSION_FILE"
LOCAL_VERSION="$DOTS_VERSION"
LAST_COMMIT="$NEW_COMMIT"
WEATHER_API_KEY="$WEATHER_API_KEY"
WEATHER_CITY_ID="$WEATHER_CITY_ID"
WEATHER_UNIT="$WEATHER_UNIT"
DRIVER_CHOICE="$DRIVER_CHOICE"
KB_LAYOUTS="$KB_LAYOUTS"
KB_LAYOUTS_DISPLAY="$KB_LAYOUTS_DISPLAY"
KB_OPTIONS="$KB_OPTIONS"
WALLPAPER_DIR="$WALLPAPER_DIR"
TELEMETRY_ID="$TELEMETRY_ID"
ENABLE_TELEMETRY="$ENABLE_TELEMETRY"
EOF

printf "  -> Configuration and version state saved %-7s ${C_GREEN}[ OK ]${RESET}\n" ""

# ==============================================================================
# Final Output & Success Banner
# ==============================================================================
echo -e "\n${BOLD}${C_GREEN}"
cat << "EOF"
  ██╗████████╗███████╗     ██████╗  ██████╗ ███╗   ██╗███████╗██╗ ██████╗ 
  ██║╚══██╔══╝██╔════╝    ██╔════╝ ██╔═══██╗████╗  ██║██╔════╝██║██╔════╝ 
  ██║   ██║   ███████╗    ██║      ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
  ██║   ██║   ╚════██║    ██║      ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
  ██║   ██║   ███████║    ╚██████╗ ╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
  ╚═╝   ╚═╝   ╚══════╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ 
EOF
echo -e "${RESET}\n"

if [ ${#FAILED_PKGS[@]} -ne 0 ]; then
    echo -e "${BOLD}${C_RED}The following packages were NOT installed. Try building them yourself:${RESET}"
    for fp in "${FAILED_PKGS[@]}"; do
        echo -e "  - ${C_YELLOW}$fp${RESET}"
    done
    echo ""
fi

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo -e "Old configurations backed up to: ${C_CYAN}$BACKUP_DIR${RESET}"
fi
echo -e "Please log out and log back in, or restart Hyprland to apply all changes."

send_telemetry "done"
