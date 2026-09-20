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
    # Resolve remote reference & check divergence
    # ─────────────────────────────────────────────
    current_branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    remote_ref=""
    for ref in "@{u}" "origin/$current_branch" "origin/main"; do
        if git -C "$REPO_DIR" rev-parse --verify "$ref" &>/dev/null 2>&1; then
            remote_ref="$ref"
            break
        fi
    done

    # ─────────────────────────────────────────────
    # Show changelog
    # ─────────────────────────────────────────────
    info "Các thay đổi mới nhất:"
    echo ""
    if [ -n "$remote_ref" ]; then
        git -C "$REPO_DIR" log --oneline --decorate -10 "$remote_ref" 2>/dev/null || true
    else
        echo "   (Không tìm thấy remote branch nào để hiển thị changelog)"
    fi
    echo ""

    # Pause for user to read changelog if running in an interactive terminal
    if [ -t 0 ]; then
        echo -e "${C_YELLOW}:: Nhấn Enter để tiếp tục cập nhật...${C_RESET}"
        read -r || true
        echo ""
    fi

    behind_count=0
    ahead_count=0
    if [ -n "$remote_ref" ]; then
        behind_count=$(git -C "$REPO_DIR" rev-list --count HEAD.."$remote_ref" 2>/dev/null || echo 0)
        ahead_count=$(git -C "$REPO_DIR" rev-list --count "$remote_ref"..HEAD 2>/dev/null || echo 0)
    fi

    has_updates=false
    if [ "$behind_count" -gt 0 ]; then
        has_updates=true
        info "Phát hiện $behind_count commit mới từ remote ($remote_ref)."
    elif [ "$ahead_count" -gt 0 ]; then
        info "Cấu hình local của bạn đang có $ahead_count commit đi trước remote ($remote_ref)."
    fi

    # Pull updates if any, stashing dirty changes (including untracked) if needed
    if [ "$has_updates" = true ]; then
        info "Đang kéo (pull) cập nhật mới nhất từ GitHub remote..."

        # Check for dirty work tree (including untracked files)
        stashed=false
        if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
            info "Phát hiện thay đổi chưa lưu hoặc file mới. Đang tự động lưu tạm (stash)..."
            if git -C "$REPO_DIR" stash push -u -m "updater auto-stash $(date +%s)" --quiet 2>/dev/null; then
                stashed=true
            else
                warn "Không thể tự động stash. Tiếp tục thử pull..."
            fi
        fi

        # Pull updates
        pull_success=true
        if ! git -C "$REPO_DIR" pull; then
            pull_success=false
            error "Không thể tự động 'git pull'. Có thể do xung đột lịch sử commit hoặc mạng."
        fi

        # Restore dirty changes if stashed
        if [ "$stashed" = true ]; then
            info "Đang khôi phục các thay đổi cục bộ trước đó (stash pop)..."
            if ! git -C "$REPO_DIR" stash pop --quiet; then
                warn "Xung đột xảy ra khi khôi phục các thay đổi cục bộ của bạn!"
                unmerged=$(git -C "$REPO_DIR" diff --name-only --diff-filter=U 2>/dev/null || true)
                if [ -n "$unmerged" ]; then
                    error "Các file đang gặp xung đột merge:"
                    echo -e "${C_YELLOW}$unmerged${C_RESET}"
                    die "ĐÃ DỪNG CẬP NHẬT để bảo vệ dữ liệu cấu hình. Vui lòng giải quyết xung đột thủ công trước khi chạy installer."
                fi
            fi
        fi

        if [ "$pull_success" = false ]; then
            die "Cập nhật bị hủy vì git pull thất bại. Dữ liệu của bạn được giữ an toàn."
        fi

        success "Đã cập nhật repository thành công."
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
    bash "$REPO_DIR/install.sh" --non-interactive "$@"
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
