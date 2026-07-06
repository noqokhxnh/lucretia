#!/bin/bash

# Arch Linux Setup Script
# Cài đặt môi trường phát triển cơ bản và cấu hình Hyprland/Quickshell

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

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Không nên chạy script này với quyền root!"
    exit 1
fi

# Check and install fzf first for the installer menu
if ! command -v fzf &> /dev/null; then
    print_status "Cài đặt fzf cho menu lựa chọn..."
    sudo pacman -Sy --noconfirm --needed fzf > /dev/null 2>&1 || true
fi

# Set default selection states
OPT_UPDATE=true
OPT_BASE_DEV=true
OPT_YAY=true
OPT_JAVA=true
OPT_PYTHON=true
OPT_DOCKER=true
OPT_NEOVIM=true
OPT_ZED=true
OPT_GIT_CONFIG=true
OPT_MODERN_CLI=true
OPT_ZEN=true
OPT_LOCALSEND=true
OPT_HYPR_CONFIG=true
OPT_NVM=true
OPT_ALIASES=true

# Main Menu Loop using fzf
while true; do
    clear
    echo -e "${BOLD}${GREEN}==================================================${NC}"
    echo -e "${BOLD}${GREEN}     Arch Linux Setup - Trình cấu hình hệ thống   ${NC}"
    echo -e "${BOLD}${GREEN}==================================================${NC}"
    echo -e "Thiết bị: ${BOLD}$(uname -n)${NC} | Người dùng: ${BOLD}$USER${NC}"
    echo ""

    # State markers
    S_UPDATE=$( [ "$OPT_UPDATE" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_BASE_DEV=$( [ "$OPT_BASE_DEV" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_YAY=$( [ "$OPT_YAY" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_JAVA=$( [ "$OPT_JAVA" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_PYTHON=$( [ "$OPT_PYTHON" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_DOCKER=$( [ "$OPT_DOCKER" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_NEOVIM=$( [ "$OPT_NEOVIM" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ZED=$( [ "$OPT_ZED" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_GIT_CONFIG=$( [ "$OPT_GIT_CONFIG" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_MODERN_CLI=$( [ "$OPT_MODERN_CLI" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ZEN=$( [ "$OPT_ZEN" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_LOCALSEND=$( [ "$OPT_LOCALSEND" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_HYPR_CONFIG=$( [ "$OPT_HYPR_CONFIG" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_NVM=$( [ "$OPT_NVM" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )
    S_ALIASES=$( [ "$OPT_ALIASES" = true ] && echo -e "${GREEN}[✓]${NC}" || echo -e "${RED}[ ]${NC}" )

    MENU_ITEMS="1. $S_UPDATE Cập nhật hệ thống (pacman -Syu)\n"
    MENU_ITEMS+="2. $S_BASE_DEV Công cụ cơ bản & phát triển (base-devel, git, curl, ...)\n"
    MENU_ITEMS+="3. $S_YAY Yay AUR helper (cần thiết cho các phần mềm AUR)\n"
    MENU_ITEMS+="4. $S_JAVA Java (OpenJDK 21)\n"
    MENU_ITEMS+="5. $S_PYTHON Python (python, pip, virtualenv)\n"
    MENU_ITEMS+="6. $S_DOCKER Docker & Docker Compose\n"
    MENU_ITEMS+="7. $S_NEOVIM Neovim (Trình soạn thảo terminal)\n"
    MENU_ITEMS+="8. $S_ZED Zed Editor (Trình soạn thảo đồ họa hiện đại)\n"
    MENU_ITEMS+="9. $S_GIT_CONFIG Cấu hình Git user (noqokhxnh & email)\n"
    MENU_ITEMS+="10. $S_MODERN_CLI CLI hiện đại & Giải nén (lazygit, bat, eza, zoxide, ripgrep, ...)\n"
    MENU_ITEMS+="11. $S_ZEN Zen Browser (Trình duyệt web tối ưu bảo mật)\n"
    MENU_ITEMS+="12. $S_LOCALSEND LocalSend (Chia sẻ file nội bộ)\n"
    MENU_ITEMS+="13. $S_HYPR_CONFIG Premium Hyprland & Quickshell Desktop Environment\n"
    MENU_ITEMS+="14. $S_NVM NVM & Node.js LTS (Trình quản lý phiên bản Node.js)\n"
    MENU_ITEMS+="15. $S_ALIASES Thiết lập bash aliases cho CLI hiện đại (~/.bashrc)\n"
    MENU_ITEMS+="16. ${BOLD}${GREEN}[ BẮT ĐẦU CÀI ĐẶT CÁC MỤC ĐÃ CHỌN ]${NC}\n"
    MENU_ITEMS+="17. ${RED}[ Thoát và Hủy ]${NC}"

    choice=$(echo -e "$MENU_ITEMS" | fzf \
        --ansi \
        --layout=reverse \
        --border=rounded \
        --margin=1,2 \
        --height=23 \
        --prompt=" Chọn mục cần thay đổi > " \
        --pointer=">" \
        --header=" Dùng phím MŨI TÊN và nhấn ENTER để Bật/Tắt. Chọn 'BẮT ĐẦU CÀI ĐẶT' để tiến hành. ") || true

    if [ -z "$choice" ] || [[ "$choice" == *"17."* ]]; then
        print_warning "Đã hủy bỏ cài đặt hệ thống."
        exit 0
    fi

    case "$choice" in
        *"1."*) OPT_UPDATE=$([ "$OPT_UPDATE" = true ] && echo false || echo true) ;;
        *"2."*) OPT_BASE_DEV=$([ "$OPT_BASE_DEV" = true ] && echo false || echo true) ;;
        *"3."*) OPT_YAY=$([ "$OPT_YAY" = true ] && echo false || echo true) ;;
        *"4."*) OPT_JAVA=$([ "$OPT_JAVA" = true ] && echo false || echo true) ;;
        *"5."*) OPT_PYTHON=$([ "$OPT_PYTHON" = true ] && echo false || echo true) ;;
        *"6."*) OPT_DOCKER=$([ "$OPT_DOCKER" = true ] && echo false || echo true) ;;
        *"7."*) OPT_NEOVIM=$([ "$OPT_NEOVIM" = true ] && echo false || echo true) ;;
        *"8."*) OPT_ZED=$([ "$OPT_ZED" = true ] && echo false || echo true) ;;
        *"9."*) OPT_GIT_CONFIG=$([ "$OPT_GIT_CONFIG" = true ] && echo false || echo true) ;;
        *"10."*) OPT_MODERN_CLI=$([ "$OPT_MODERN_CLI" = true ] && echo false || echo true) ;;
        *"11."*) OPT_ZEN=$([ "$OPT_ZEN" = true ] && echo false || echo true) ;;
        *"12."*) OPT_LOCALSEND=$([ "$OPT_LOCALSEND" = true ] && echo false || echo true) ;;
        *"13."*) OPT_HYPR_CONFIG=$([ "$OPT_HYPR_CONFIG" = true ] && echo false || echo true) ;;
        *"14."*) OPT_NVM=$([ "$OPT_NVM" = true ] && echo false || echo true) ;;
        *"15."*) OPT_ALIASES=$([ "$OPT_ALIASES" = true ] && echo false || echo true) ;;
        *"16."*) break ;;
        *) ;;
    esac
done

clear
print_status "Bắt đầu cài đặt các mục đã chọn..."
set -e

# 1. Update system
if [ "$OPT_UPDATE" = true ]; then
    print_status "Cập nhật hệ thống..."
    sudo pacman -Syu --noconfirm
fi

# 2. Install base-devel (required for AUR)
if [ "$OPT_BASE_DEV" = true ]; then
    print_status "Cài đặt base-devel và các công cụ cơ bản..."
    sudo pacman -S --needed --noconfirm base-devel git curl wget openssh
fi

# 3. Install Yay AUR helper
if [ "$OPT_YAY" = true ]; then
    if ! command -v yay &> /dev/null; then
        print_status "Cài đặt Yay AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
        rm -rf /tmp/yay
    else
        print_warning "Yay đã được cài đặt"
    fi
fi

# 4. Install programming languages
if [ "$OPT_JAVA" = true ]; then
    print_status "Cài đặt Java (OpenJDK 21)..."
    sudo pacman -S --needed --noconfirm jdk21-openjdk
fi

if [ "$OPT_PYTHON" = true ]; then
    print_status "Cài đặt Python..."
    sudo pacman -S --needed --noconfirm python python-pip python-virtualenv
fi

# 5. Install Docker
if [ "$OPT_DOCKER" = true ]; then
    print_status "Cài đặt Docker..."
    sudo pacman -S --needed --noconfirm docker docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    print_warning "Bạn cần logout/login lại để sử dụng Docker không cần sudo"
fi

# 6. Install editors
if [ "$OPT_NEOVIM" = true ]; then
    print_status "Cài đặt Neovim..."
    sudo pacman -S --needed --noconfirm neovim
fi

if [ "$OPT_ZED" = true ]; then
    print_status "Cài đặt Zed Editor..."
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm zed
    else
        print_error "Cần có Yay để cài đặt Zed Editor từ AUR!"
    fi
fi

# 7. Configure Git
if [ "$OPT_GIT_CONFIG" = true ]; then
    print_status "Cấu hình Git..."
    git config --global user.name "noqokhxnh"
    git config --global user.email "khanh2k5xxx@gmail.com"
    git config --global init.defaultBranch main
    git config --global core.editor nvim
    print_status "Git đã được cấu hình với user: noqokhxnh"
fi

# 8. Install modern CLI and compression tools
if [ "$OPT_MODERN_CLI" = true ]; then
    print_status "Cài đặt các công cụ CLI hiện đại và giải nén..."
    sudo pacman -S --needed --noconfirm lazygit bat eza zoxide ripgrep fd fzf btop unzip unrar p7zip
fi

# 9. Install Zen Browser
if [ "$OPT_ZEN" = true ]; then
    print_status "Cài đặt Zen Browser..."
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm zen-browser-bin
    else
        print_error "Cần có Yay để cài đặt Zen Browser!"
    fi
fi

# 10. Install LocalSend
if [ "$OPT_LOCALSEND" = true ]; then
    print_status "Cài đặt LocalSend..."
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm localsend-bin
    else
        print_error "Cần có Yay để cài đặt LocalSend!"
    fi
fi

# 11. Install Premium Hyprland & Quickshell Desktop Environment
if [ "$OPT_HYPR_CONFIG" = true ]; then
    print_status "Cài đặt cấu hình Premium Hyprland & Quickshell Desktop..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/install.sh" ]; then
        print_status "Tìm thấy install.sh cục bộ, tiến hành cài đặt..."
        bash "$SCRIPT_DIR/install.sh"
    else
        print_status "Không tìm thấy install.sh cục bộ, tải và chạy từ GitHub..."
        curl -sL https://raw.githubusercontent.com/noqokhxnh/niri/main/install.sh | bash
    fi
fi

# 12. Install Node.js via nvm
if [ "$OPT_NVM" = true ]; then
    print_status "Cài đặt NVM (Node Version Manager)..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        print_status "Cài đặt Node.js LTS..."
        nvm install --lts
        nvm use --lts
    else
        print_warning "NVM đã được cài đặt"
    fi
fi

# 13. Setup shell aliases for modern tools
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
alias cd='z'

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
echo ""

if [ "$OPT_GIT_CONFIG" = true ]; then
    print_status "Git đã được cấu hình:"
    echo "  • User: noqokhxnh"
    echo "  • Email: khanh2k5xxx@gmail.com"
    echo "  • Editor: nvim"
    echo "  • Default branch: main"
    echo ""
fi

print_status "Các công cụ đã cài đặt thành công:"
[ "$OPT_NVM" = true ] && echo "  • Node.js (via nvm)"
[ "$OPT_DOCKER" = true ] && echo "  • Docker & Docker Compose"
[ "$OPT_NEOVIM" = true ] && echo "  • Neovim"
[ "$OPT_ZED" = true ] && echo "  • Zed Editor"
[ "$OPT_GIT_CONFIG" = true ] && echo "  • Git"
[ "$OPT_MODERN_CLI" = true ] && echo "  • Lazygit, bat, eza, zoxide, ripgrep, fd, fzf, btop"
[ "$OPT_JAVA" = true ] && echo "  • Java 21 (OpenJDK)"
[ "$OPT_PYTHON" = true ] && echo "  • Python, pip, virtualenv"
[ "$OPT_ZEN" = true ] && echo "  • Zen Browser"
[ "$OPT_LOCALSEND" = true ] && echo "  • LocalSend (chia sẻ file)"
[ "$OPT_HYPR_CONFIG" = true ] && echo "  • Premium Hyprland & Quickshell Desktop Environment"
[ "$OPT_MODERN_CLI" = true ] && echo "  • Gói giải nén (unzip, unrar, p7zip)"
echo ""
echo ""
