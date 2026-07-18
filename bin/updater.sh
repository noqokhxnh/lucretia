#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Terminal Self-Healing
# ─────────────────────────────────────────────
if ! tput colors &>/dev/null 2>&1; then
    export TERM=xterm-256color
fi

# ─────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────
C_BLUE="\e[1;34m"
C_GREEN="\e[1;32m"
C_YELLOW="\e[1;33m"
C_RED="\e[1;31m"
C_RESET="\e[0m"

info()    { echo -e "${C_BLUE}::${C_RESET} $*"; }
success() { echo -e "${C_GREEN}::${C_RESET} $*"; }
warn()    { echo -e "${C_YELLOW}:: [WARN]${C_RESET} $*"; }
error()   { echo -e "${C_RED}:: [ERROR]${C_RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

check_network() {
    info "Đang kiểm tra kết nối mạng..."
    if ! curl -I -s --connect-timeout 5 "https://github.com" &>/dev/null; then
        die "Không có kết nối mạng hoặc không thể kết nối tới GitHub. Vui lòng kiểm tra lại đường truyền."
    fi
}

check_network

# ─────────────────────────────────────────────
# Detect git repo
# ─────────────────────────────────────────────
IS_GIT=false
REPO_DIR="$HOME/.config/niri"
if [ -d "$REPO_DIR/.git" ]; then
    IS_GIT=true
fi

# ─────────────────────────────────────────────
# GIT MODE: Pull latest updates first
# ─────────────────────────────────────────────
if [ "$IS_GIT" = true ]; then
    info "Git repository detected tại $REPO_DIR"
    
    # Fetch remote changes
    info "Đang nạp (fetch) thông tin từ remote..."
    git -C "$REPO_DIR" fetch --quiet || warn "Không thể kết nối tới remote để fetch. Tiếp tục với phiên bản cục bộ..."

    # ─────────────────────────────────────────────
    # Show changelog
    # ─────────────────────────────────────────────
    info "Các thay đổi mới nhất:"
    echo ""
    # Try @{u} first, then origin/main, then origin/<current_branch>
    current_branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    remote_ref=""
    for ref in "@{u}" "origin/main" "origin/$current_branch"; do
        if git -C "$REPO_DIR" rev-parse "$ref" &>/dev/null 2>&1; then
            remote_ref="$ref"
            break
        fi
    done
    if [ -n "$remote_ref" ]; then
        git -C "$REPO_DIR" log --oneline --decorate -10 "$remote_ref" 2>/dev/null || true
    else
        echo "   (Không tìm thấy remote branch nào để hiển thị changelog)"
    fi
    echo ""

    # Pause for user to read changelog
    echo -e "${C_YELLOW}:: Nhấn Enter để tiếp tục cập nhật...${C_RESET}"
    read -r || true
    echo ""

    # Get local and remote HEAD commit hashes for the active branch
    local_head=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "")
    # Check if there is an upstream tracking branch configured
    upstream_branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    if [ -n "$upstream_branch" ]; then
        remote_head=$(git -C "$REPO_DIR" rev-parse @{u} 2>/dev/null || echo "")
    else
        # Fallback to local HEAD if no upstream tracking branch
        remote_head="$local_head"
    fi

    # Check if we actually have updates to pull
    has_updates=true
    if [ "$local_head" = "$remote_head" ] && [ -n "$local_head" ]; then
        has_updates=false
    fi

    # Pull updates if any, stashing dirty changes if needed
    if [ "$has_updates" = true ]; then
        info "Đang kéo (pull) cập nhật mới nhất từ GitHub remote..."
        
        # Check for dirty work tree
        stashed=false
        if ! git -C "$REPO_DIR" diff-index --quiet HEAD -- 2>/dev/null; then
            info "Phát hiện thay đổi chưa lưu (dirty working tree). Đang tự động lưu tạm (stash)..."
            if git -C "$REPO_DIR" stash push -m "updater auto-stash" --quiet; then
                stashed=true
            fi
        fi

        # Pull updates
        if git -C "$REPO_DIR" pull; then
            success "Đã cập nhật repository thành công."
        else
            warn "Không thể tự động 'git pull'. Có thể có xung đột cấu hình cục bộ."
        fi

        # Restore dirty changes if stashed
        if [ "$stashed" = true ]; then
            info "Đang khôi phục các thay đổi cục bộ trước đó (stash pop)..."
            git -C "$REPO_DIR" stash pop --quiet || warn "Có xung đột xảy ra khi khôi phục các thay đổi cục bộ của bạn."
        fi
    else
        success "Cấu hình local của bạn đã ở phiên bản mới nhất."
        
        # Prompt if run interactively, otherwise exit early
        if [ -t 0 ]; then
            echo -n -e "${C_YELLOW}:: Bạn có muốn chạy lại trình cài đặt (reinstall) để sửa lỗi/áp dụng lại cấu hình không? (y/N): ${C_RESET}"
            read -r choice
            if [[ ! "$choice" =~ ^[Yy]$ ]]; then
                success "Hoàn tất."
                exit 0
            fi
        else
            info "Chạy không tương tác. Bỏ qua chạy trình cài đặt."
            exit 0
        fi
    fi
    
    # Run the updated local installer
    info "Đang chạy installer để build/áp dụng cấu hình..."
    echo ""
    bash "$REPO_DIR/install.sh" "$@"
    exit 0
fi

# ─────────────────────────────────────────────
# NON-GIT MODE: Fetch and run remote installer
# ─────────────────────────────────────────────
INSTALLER_URL="https://raw.githubusercontent.com/noqokhxnh/lucretia/main/install.sh"
TMPFILE=$(mktemp /tmp/installer.XXXXXX.sh)

# Cleanup tmpfile khi script kết thúc (dù thành công hay lỗi)
trap 'rm -f "$TMPFILE"' EXIT

info "Fetching upstream installer..."
if ! curl -fsSL --max-time 30 "$INSTALLER_URL" -o "$TMPFILE"; then
    die "Không tải được installer từ: $INSTALLER_URL"
fi

# Validate file không rỗng
if [ ! -s "$TMPFILE" ]; then
    die "Installer tải về bị rỗng."
fi

# Validate có nội dung hợp lệ — kiểm tra signature hoặc marker của installer mới
if ! grep -q "Premium Niri" "$TMPFILE"; then
    die "Installer không hợp lệ: thiếu marker 'Premium Niri'. Upstream có thể đã thay đổi format."
fi

success "Installer hợp lệ. Bắt đầu chạy..."
echo ""

bash "$TMPFILE" "$@"
