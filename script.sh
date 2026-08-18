#!/bin/bash

# Arch Linux Setup Script
# Cài đặt môi trường phát triển cơ bản và cấu hình hệ thống

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Helper functions
_pacman() {
    sudo pacman -S --needed --noconfirm "$@"
}

_yay() {
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm "$@"
    else
        print_error "Cần có Yay (AUR helper) để cài đặt gói này!"
        return 1
    fi
}

_download() {
    curl -# -L -o "$2" "$1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Không nên chạy script này với quyền root!"
    exit 1
fi

# Check and install fzf first for the installer menu
if ! command -v fzf &> /dev/null; then
    print_status "Cài đặt fzf cho menu lựa chọn..."
    _pacman fzf > /dev/null 2>&1 || true
fi

# Set default selection states
OPT_UPDATE=true
OPT_BASE_DEV=true
OPT_YAY=true
OPT_JAVA=true
OPT_PYTHON=true
OPT_NVM=true
OPT_NEOVIM=true
OPT_ZED=true
OPT_MODERN_CLI=true
OPT_GIT_CONFIG=true
OPT_DOCKER=true
OPT_ZEN=true
OPT_BRAVE=true
OPT_ZALO=true
OPT_LOCALSEND=true
OPT_HYPR_CONFIG=true
OPT_ALIASES=true

# Main Menu Loop using fzf
while true; do
    clear
    echo -e "${BOLD}${GREEN}██╗  ██╗██╗  ██╗██╗  ██╗███╗   ██╗██╗  ██╗${NC}"
    echo -e "${BOLD}${GREEN}██║ ██╔╝██║  ██║╚██╗██╔╝████╗  ██║██║  ██║${NC}"
    echo -e "${BOLD}${GREEN}█████╔╝ ███████║ ╚███╔╝ ██╔██╗ ██║███████║${NC}"
    echo -e "${BOLD}${GREEN}██╔═██╗ ██╔══██║ ██╔██╗ ██║╚██╗██║██╔══██║${NC}"
    echo -e "${BOLD}${GREEN}██║  ██╗██║  ██║██╔╝ ██╗██║ ╚████║██║  ██║${NC}"
    echo -e "${BOLD}${GREEN}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝${NC}"
    echo -e "${BOLD}  Arch Linux Setup${NC} · by khxnh"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Thiết bị: ${BOLD}$(uname -n)${NC} · Người dùng: ${BOLD}$USER${NC}"
    echo ""

    # State markers
    S_UPDATE=$( [ "$OPT_UPDATE" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_BASE_DEV=$( [ "$OPT_BASE_DEV" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_YAY=$( [ "$OPT_YAY" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_JAVA=$( [ "$OPT_JAVA" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_PYTHON=$( [ "$OPT_PYTHON" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_NVM=$( [ "$OPT_NVM" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_NEOVIM=$( [ "$OPT_NEOVIM" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ZED=$( [ "$OPT_ZED" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_MODERN_CLI=$( [ "$OPT_MODERN_CLI" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_GIT_CONFIG=$( [ "$OPT_GIT_CONFIG" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_DOCKER=$( [ "$OPT_DOCKER" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ZEN=$( [ "$OPT_ZEN" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_BRAVE=$( [ "$OPT_BRAVE" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ZALO=$( [ "$OPT_ZALO" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_LOCALSEND=$( [ "$OPT_LOCALSEND" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_HYPR_CONFIG=$( [ "$OPT_HYPR_CONFIG" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ALIASES=$( [ "$OPT_ALIASES" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )

    MENU_ITEMS=""
    MENU_ITEMS+="━━━ HỆ THỐNG ━━━\n"
    MENU_ITEMS+="1. $S_UPDATE Cập nhật hệ thống (pacman -Syu)\n"
    MENU_ITEMS+="2. $S_BASE_DEV Công cụ cơ bản & phát triển (base-devel, git, curl, ...)\n"
    MENU_ITEMS+="3. $S_YAY Yay AUR helper (cần thiết cho các phần mềm AUR)\n"
    MENU_ITEMS+="━━━ NGÔN NGỮ LẬP TRÌNH ━━━\n"
    MENU_ITEMS+="4. $S_JAVA Java (OpenJDK 21)\n"
    MENU_ITEMS+="5. $S_PYTHON Python (python, pip, virtualenv)\n"
    MENU_ITEMS+="6. $S_NVM NVM & Node.js LTS (Trình quản lý phiên bản Node.js)\n"
    MENU_ITEMS+="━━━ CÔNG CỤ PHÁT TRIỂN ━━━\n"
    MENU_ITEMS+="7. $S_NEOVIM Neovim (Trình soạn thảo terminal)\n"
    MENU_ITEMS+="8. $S_ZED Zed Editor (Trình soạn thảo đồ họa hiện đại)\n"
    MENU_ITEMS+="9. $S_MODERN_CLI CLI hiện đại & Giải nén (lazygit, bat, eza, zoxide, ...)\n"
    MENU_ITEMS+="10. $S_GIT_CONFIG Cấu hình Git user (nhập tên & email)\n"
    MENU_ITEMS+="11. $S_DOCKER Docker & Docker Compose\n"
    MENU_ITEMS+="━━━ TRÌNH DUYỆT WEB ━━━\n"
    MENU_ITEMS+="12. $S_ZEN Zen Browser (Trình duyệt web tối ưu bảo mật)\n"
    MENU_ITEMS+="13. $S_BRAVE Brave Browser (Trình duyệt web bảo mật - AUR)\n"
    MENU_ITEMS+="━━━ NHẮN TIN & CHIA SẺ ━━━\n"
    MENU_ITEMS+="14. $S_ZALO Zalo (Unofficial Linux Port - AppImage)\n"
    MENU_ITEMS+="15. $S_LOCALSEND LocalSend (Chia sẻ file nội bộ)\n"
    MENU_ITEMS+="━━━ GIAO DIỆN MÀN HÌNH ━━━\n"
    MENU_ITEMS+="16. $S_HYPR_CONFIG Lucretia Desktop (Niri & Quickshell - Wayland)\n"
    MENU_ITEMS+="━━━ SHELL ━━━\n"
    MENU_ITEMS+="17. $S_ALIASES Thiết lập bash aliases cho CLI hiện đại (~/.bashrc)\n"
    MENU_ITEMS+="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    MENU_ITEMS+="18. ${BOLD}${GREEN}[ BẮT ĐẦU CÀI ĐẶT CÁC MỤC ĐÃ CHỌN ]${NC}\n"
    MENU_ITEMS+="19. ${RED}[ Thoát và Hủy ]${NC}"

    choice=$(echo -e "$MENU_ITEMS" | fzf \
        --ansi \
        --layout=reverse \
        --border=rounded \
        --margin=1,2 \
        --height=30 \
        --prompt=" ⚡ " \
        --pointer="▸ " \
        --marker="✓ " \
        --color='fg:#c0caf5,bg:#1a1b26,hl:#bb9af7,fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff,prompt:#7aa2f7,pointer:#f7768e,marker:#9ece6a,header:#565f89' \
        --header=" Space: chọn · Enter: toggle · 18/19: bắt đầu/thoát ") || true

    if [ -z "$choice" ] || [[ "$choice" == "19."* ]]; then
        print_warning "Đã hủy bỏ cài đặt hệ thống."
        exit 0
    fi

    case "$choice" in
        "1."*) OPT_UPDATE=$([ "$OPT_UPDATE" = true ] && echo false || echo true) ;;
        "2."*) OPT_BASE_DEV=$([ "$OPT_BASE_DEV" = true ] && echo false || echo true) ;;
        "3."*) OPT_YAY=$([ "$OPT_YAY" = true ] && echo false || echo true) ;;
        "4."*) OPT_JAVA=$([ "$OPT_JAVA" = true ] && echo false || echo true) ;;
        "5."*) OPT_PYTHON=$([ "$OPT_PYTHON" = true ] && echo false || echo true) ;;
        "6."*) OPT_NVM=$([ "$OPT_NVM" = true ] && echo false || echo true) ;;
        "7."*) OPT_NEOVIM=$([ "$OPT_NEOVIM" = true ] && echo false || echo true) ;;
        "8."*) OPT_ZED=$([ "$OPT_ZED" = true ] && echo false || echo true) ;;
        "9."*) OPT_MODERN_CLI=$([ "$OPT_MODERN_CLI" = true ] && echo false || echo true) ;;
        "10."*) OPT_GIT_CONFIG=$([ "$OPT_GIT_CONFIG" = true ] && echo false || echo true) ;;
        "11."*) OPT_DOCKER=$([ "$OPT_DOCKER" = true ] && echo false || echo true) ;;
        "12."*) OPT_ZEN=$([ "$OPT_ZEN" = true ] && echo false || echo true) ;;
        "13."*) OPT_BRAVE=$([ "$OPT_BRAVE" = true ] && echo false || echo true) ;;
        "14."*) OPT_ZALO=$([ "$OPT_ZALO" = true ] && echo false || echo true) ;;
        "15."*) OPT_LOCALSEND=$([ "$OPT_LOCALSEND" = true ] && echo false || echo true) ;;
        "16."*) OPT_HYPR_CONFIG=$([ "$OPT_HYPR_CONFIG" = true ] && echo false || echo true) ;;
        "17."*) OPT_ALIASES=$([ "$OPT_ALIASES" = true ] && echo false || echo true) ;;
        "18."*) break ;;
        *) ;;
    esac
done

clear
print_status "Bắt đầu cài đặt các mục đã chọn..."
set -e
trap 'print_error "Có lỗi xảy ra, dừng cài đặt..."' ERR

# ─── HỆ THỐNG ───────────────────────────────────────

# 1. Update system
if [ "$OPT_UPDATE" = true ]; then
    print_status "Cập nhật hệ thống..."
    sudo pacman -Syu --noconfirm
fi

# 2. Install base-devel (required for AUR)
if [ "$OPT_BASE_DEV" = true ]; then
    print_status "Cài đặt base-devel và các công cụ cơ bản..."
    _pacman base-devel git curl wget openssh
fi

# 3. Install Yay AUR helper
if [ "$OPT_YAY" = true ]; then
    if ! command -v yay &> /dev/null; then
        print_status "Cài đặt Yay AUR helper..."
        ( cd /tmp && git clone --depth 1 https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm )
        rm -rf /tmp/yay
    else
        print_warning "Yay đã được cài đặt"
    fi
fi

# ─── NGÔN NGỮ LẬP TRÌNH ─────────────────────────────

# 4. Install Java
if [ "$OPT_JAVA" = true ]; then
    print_status "Cài đặt Java (OpenJDK 21)..."
    _pacman jdk21-openjdk
fi

# 5. Install Python
if [ "$OPT_PYTHON" = true ]; then
    print_status "Cài đặt Python..."
    _pacman python python-pip python-virtualenv
fi

# 6. Install Node.js via nvm
if [ "$OPT_NVM" = true ]; then
    print_status "Cài đặt NVM (Node Version Manager)..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -# -L https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        print_status "Cài đặt Node.js LTS..."
        nvm install --lts
        nvm use --lts
    else
        print_warning "NVM đã được cài đặt"
    fi
fi

# ─── CÔNG CỤ PHÁT TRIỂN ─────────────────────────────

# 7. Install Neovim
if [ "$OPT_NEOVIM" = true ]; then
    print_status "Cài đặt Neovim..."
    _pacman neovim
fi

# 8. Install Zed Editor
if [ "$OPT_ZED" = true ]; then
    print_status "Cài đặt Zed Editor..."
    _yay zed
fi

# 9. Install modern CLI and compression tools
if [ "$OPT_MODERN_CLI" = true ]; then
    print_status "Cài đặt các công cụ CLI hiện đại và giải nén..."
    _pacman lazygit bat eza zoxide ripgrep fd fzf btop unzip unrar p7zip
fi

# 10. Configure Git
if [ "$OPT_GIT_CONFIG" = true ]; then
    print_status "Cấu hình Git..."
    read -p "Nhập Git user.name: " git_user
    read -p "Nhập Git user.email: " git_email
    [ -z "$git_user" ] && { print_error "user.name không được để trống!"; exit 1; }
    [ -z "$git_email" ] && { print_error "user.email không được để trống!"; exit 1; }
    git config --global user.name "$git_user"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global core.editor nvim
    print_status "Git đã được cấu hình với user: $git_user"
fi

# 11. Install Docker
if [ "$OPT_DOCKER" = true ]; then
    print_status "Cài đặt Docker..."
    _pacman docker docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    print_warning "Bạn cần logout/login lại để sử dụng Docker không cần sudo"
fi

# ─── TRÌNH DUYỆT WEB ─────────────────────────────────

# 12. Install Zen Browser
if [ "$OPT_ZEN" = true ]; then
    print_status "Cài đặt Zen Browser..."
    _yay zen-browser-bin
fi

# 13. Install Brave Browser
if [ "$OPT_BRAVE" = true ]; then
    print_status "Cài đặt Brave Browser..."
    _yay brave-bin
fi

# ─── NHẮN TIN & CHIA SẺ ─────────────────────────────

# 14. Install Zalo (Unofficial Linux Port)
if [ "$OPT_ZALO" = true ]; then
    print_status "Cài đặt Zalo (Unofficial Linux Port)..."
    
    ZALO_DIR="$HOME/.local/share/zalo"
    ZALO_APPIMAGE="$ZALO_DIR/Zalo.AppImage"
    DESKTOP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons"
    
    mkdir -p "$ZALO_DIR" "$DESKTOP_DIR" "$ICON_DIR"
    
    if [ -f "$ZALO_APPIMAGE" ] && [ -x "$ZALO_APPIMAGE" ]; then
        print_warning "Zalo AppImage đã tồn tại, kiểm tra phiên bản mới..."
    fi
    
    print_status "Tải Zalo AppImage v1.1.3 (220MB)..."
    _download "https://github.com/realdtn2/zalo-linux-2026/releases/download/v1.1.3/Zalo-v1.1.3-x86_64.AppImage" "$ZALO_APPIMAGE"
    chmod +x "$ZALO_APPIMAGE"
    
    # Tải icon từ repo
    _download "https://raw.githubusercontent.com/realdtn2/zalo-linux-2026/latest/pc-dist/favicon-96x96.v1.png" "$ICON_DIR/zalo.png" 2>/dev/null || true
    
    # Tạo desktop entry
    cat > "$DESKTOP_DIR/Zalo.desktop" << ZALOEOF
[Desktop Entry]
Name=Zalo
Comment=Zalo (Unofficial Linux Port)
Exec=$ZALO_APPIMAGE
Icon=$ICON_DIR/zalo.png
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=Zalo
ZALOEOF
    chmod +x "$DESKTOP_DIR/Zalo.desktop"
    
    # Copy ra Desktop nếu có
    if [ -d "$HOME/Desktop" ]; then
        cp "$DESKTOP_DIR/Zalo.desktop" "$HOME/Desktop/Zalo.desktop"
        chmod +x "$HOME/Desktop/Zalo.desktop"
        gio set "$HOME/Desktop/Zalo.desktop" metadata::trusted true 2>/dev/null || true
    fi
    
    gio set "$DESKTOP_DIR/Zalo.desktop" metadata::trusted true 2>/dev/null || true
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    
    print_status "Zalo đã được cài đặt!"
fi

# 15. Install LocalSend
if [ "$OPT_LOCALSEND" = true ]; then
    print_status "Cài đặt LocalSend..."
    _yay localsend-bin
fi

# ─── GIAO DIỆN MÀN HÌNH ─────────────────────────────

# 16. Install Lucretia Desktop (Niri & Quickshell)
if [ "$OPT_HYPR_CONFIG" = true ]; then
    print_status "Cài đặt Lucretia Desktop (Niri & Quickshell - Wayland)..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/install.sh" ]; then
        print_status "Tìm thấy install.sh cục bộ, tiến hành cài đặt..."
        bash "$SCRIPT_DIR/install.sh"
    else
        print_status "Không tìm thấy install.sh cục bộ, tải và chạy từ GitHub..."
        curl -# -L https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh | bash
    fi
fi

# ─── SHELL ───────────────────────────────────────────

# 17. Setup shell aliases for modern tools
if [ "$OPT_ALIASES" = true ]; then
    print_status "Thiết lập aliases cho bash..."
    BASHRC="$HOME/.bashrc"
    
    if ! grep -q "# Modern CLI aliases" "$BASHRC"; then
        cat >> "$BASHRC" << 'EOF'

# Modern CLI aliases
alias ls='eza --icons'
alias ll='eza -l --icons'
alias la='eza -la --icons'
alias cat='bat'
alias z='z'

# NVM setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Zoxide setup
eval "$(zoxide init bash)"
EOF
        print_status "Đã thêm aliases vào ~/.bashrc"
    else
        print_warning "Aliases đã tồn tại trong ~/.bashrc"
    fi
fi

# Final message
echo ""
print_status "=========================================="
print_status "Cài đặt hoàn tất!"
print_status "=========================================="
echo ""
print_warning "Các bước tiếp theo:"
if [ "$OPT_DOCKER" = true ]; then
    echo "1. Logout và login lại để áp dụng Docker group"
fi
if [ "$OPT_ALIASES" = true ]; then
    echo "2. Chạy 'source ~/.bashrc' để load aliases mới"
fi
if [ "$OPT_ZALO" = true ]; then
    echo "3. Tìm 'Zalo' trong ứng dụng hoặc chạy ~/.local/share/zalo/Zalo.AppImage"
fi
echo ""

if [ "$OPT_GIT_CONFIG" = true ]; then
    print_status "Git đã được cấu hình:"
    echo "  • User: $(git config --global user.name)"
    echo "  • Email: $(git config --global user.email)"
    echo "  • Editor: nvim"
    echo "  • Default branch: main"
    echo ""
fi

print_status "Các công cụ đã cài đặt thành công:"
[ "$OPT_JAVA" = true ] && echo "  • Java 21 (OpenJDK)"
[ "$OPT_PYTHON" = true ] && echo "  • Python, pip, virtualenv"
[ "$OPT_NVM" = true ] && echo "  • Node.js (via nvm)"
[ "$OPT_NEOVIM" = true ] && echo "  • Neovim"
[ "$OPT_ZED" = true ] && echo "  • Zed Editor"
[ "$OPT_MODERN_CLI" = true ] && echo "  • Lazygit, bat, eza, zoxide, ripgrep, fd, fzf, btop"
[ "$OPT_GIT_CONFIG" = true ] && echo "  • Git"
[ "$OPT_DOCKER" = true ] && echo "  • Docker & Docker Compose"
[ "$OPT_ZEN" = true ] && echo "  • Zen Browser"
[ "$OPT_BRAVE" = true ] && echo "  • Brave Browser"
[ "$OPT_ZALO" = true ] && echo "  • Zalo (Unofficial Linux Port)"
[ "$OPT_LOCALSEND" = true ] && echo "  • LocalSend (chia sẻ file)"
[ "$OPT_HYPR_CONFIG" = true ] && echo "  • Lucretia Desktop (Niri & Quickshell - Wayland)"
[ "$OPT_ALIASES" = true ] && echo "  • Bash Aliases"
[ "$OPT_MODERN_CLI" = true ] && echo "  • Gói giải nén (unzip, unrar, p7zip)"
echo ""
echo ""
