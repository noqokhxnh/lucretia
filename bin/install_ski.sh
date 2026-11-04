#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Lucretia - Ski File Manager & Portal Installer
# Bundles Ski (v0.5.1) as the default file manager, file picker,
# and dock app with dynamic Material You theming.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SKI_VERSION="0.5.1"
SKI_TAG="v${SKI_VERSION}"
SKI_SHA256="b5bc1c00ebdf5b7700419f6aaf59e17e46a42262ef1388113909e6f81591edf6"
SKI_TARBALL="ski-${SKI_VERSION}-x86_64-linux.tar.gz"
SKI_URL="https://github.com/ilyamiro/Ski/releases/download/${SKI_TAG}/${SKI_TARBALL}"

# Determine installation prefix: prefer /usr/local if root or passwordless sudo available, otherwise ~/.local
if [ "$(id -u)" -eq 0 ]; then
    PREFIX="/usr/local"
    SUDO=""
elif sudo -n true 2>/dev/null; then
    PREFIX="/usr/local"
    SUDO="sudo"
else
    PREFIX="${HOME}/.local"
    SUDO=""
fi

echo -e "\e[36m:: [Ski]\e[0m Đang cài đặt Ski File Manager ${SKI_VERSION} vào ${PREFIX}..."

# Check system architecture
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
    echo -e "\e[31m:: [LỖI]\e[0m Kiến trúc ${ARCH} không được hỗ trợ bởi bản prebuilt binary của Ski." >&2
    exit 1
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/lucretia-ski"
mkdir -p "$CACHE_DIR"
ARCHIVE="${CACHE_DIR}/${SKI_TARBALL}"

# Download release archive if not cached or checksum mismatch
NEED_DOWNLOAD=true
if [ -f "$ARCHIVE" ]; then
    if echo "${SKI_SHA256}  ${ARCHIVE}" | sha256sum -c --quiet - 2>/dev/null; then
        NEED_DOWNLOAD=false
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo -e "\e[34m:: [Ski]\e[0m Đang tải ${SKI_URL}..."
    if ! curl -fL# --connect-timeout 15 --retry 3 "$SKI_URL" -o "$ARCHIVE"; then
        wget -c -q --show-progress "$SKI_URL" -O "$ARCHIVE" || true
    fi
fi

# Verify SHA256 checksum
echo -e "\e[34m:: [Ski]\e[0m Đang kiểm tra mã băm SHA256..."
if ! echo "${SKI_SHA256}  ${ARCHIVE}" | sha256sum -c --quiet -; then
    echo -e "\e[31m:: [LỖI]\e[0m Mã băm SHA256 không hợp lệ cho ${ARCHIVE}" >&2
    rm -f "$ARCHIVE"
    exit 1
fi

STAGE_DIR="$(mktemp -d "${CACHE_DIR}/stage.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

tar -xzf "$ARCHIVE" -C "$STAGE_DIR"

STAGE_ROOT="$STAGE_DIR/usr"
[ ! -d "$STAGE_ROOT" ] && STAGE_ROOT="$STAGE_DIR"

# Install files
echo -e "\e[34m:: [Ski]\e[0m Đang triển khai các tệp tin hệ thống..."

$SUDO install -Dm755 "${STAGE_ROOT}/bin/ski" "${PREFIX}/bin/ski"
$SUDO install -Dm644 "${STAGE_ROOT}/share/applications/ski.desktop" "${PREFIX}/share/applications/ski.desktop"
$SUDO install -Dm644 "${STAGE_ROOT}/share/icons/hicolor/scalable/apps/ski.svg" "${PREFIX}/share/icons/hicolor/scalable/apps/ski.svg"
$SUDO install -Dm644 "${STAGE_ROOT}/share/xdg-desktop-portal/portals/ski.portal" "${PREFIX}/share/xdg-desktop-portal/portals/ski.portal"

$SUDO install -d "${PREFIX}/share/dbus-1/services"
for service in org.freedesktop.impl.portal.desktop.ski org.freedesktop.FileManager1; do
    if [ -f "${STAGE_ROOT}/share/dbus-1/services/${service}.service" ]; then
        sed "s|/usr/bin/ski|${PREFIX}/bin/ski|" "${STAGE_ROOT}/share/dbus-1/services/${service}.service" \
            | $SUDO tee "${PREFIX}/share/dbus-1/services/${service}.service" >/dev/null
    fi
done

if [ -f "${STAGE_ROOT}/share/licenses/ski/LICENSE" ]; then
    $SUDO install -Dm644 "${STAGE_ROOT}/share/licenses/ski/LICENSE" "${PREFIX}/share/licenses/ski/LICENSE" 2>/dev/null || true
fi

# Update desktop and icon databases
if command -v update-desktop-database >/dev/null 2>&1; then
    $SUDO update-desktop-database "${PREFIX}/share/applications" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    $SUDO gtk-update-icon-cache -qf "${PREFIX}/share/icons/hicolor" 2>/dev/null || true
fi

# ──────────────────────────────────────────────────────────────
# 1. Preferred FileChooser portal configuration
# ──────────────────────────────────────────────────────────────
PORTAL_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
PORTAL_CONF="${PORTAL_CONF_DIR}/portals.conf"
KEY="org.freedesktop.impl.portal.FileChooser"

mkdir -p "$PORTAL_CONF_DIR"
if [ ! -f "$PORTAL_CONF" ]; then
    printf '[preferred]\ndefault=gtk\n%s=ski\n' "$KEY" > "$PORTAL_CONF"
elif grep -q "^$KEY=" "$PORTAL_CONF"; then
    sed -i "s|^$KEY=.*|$KEY=ski|" "$PORTAL_CONF"
elif grep -q '^\[preferred\]' "$PORTAL_CONF"; then
    sed -i "/^\[preferred\]/a $KEY=ski" "$PORTAL_CONF"
else
    printf '\n[preferred]\n%s=ski\n' "$KEY" >> "$PORTAL_CONF"
fi
echo -e "\e[32m:: [Ski]\e[0m Đã cấu hình FileChooser portal ưu tiên = ski (${PORTAL_CONF})"

# ──────────────────────────────────────────────────────────────
# 2. GTK Use Portal Environment variable
# ──────────────────────────────────────────────────────────────
ENV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
mkdir -p "$ENV_DIR"
printf 'GTK_USE_PORTAL=1\n' > "$ENV_DIR/50-lucretia-portal.conf"
echo -e "\e[32m:: [Ski]\e[0m Đã thiết lập GTK_USE_PORTAL=1 trong environment.d"

# ──────────────────────────────────────────────────────────────
# 3. MIME Default Association
# ──────────────────────────────────────────────────────────────
if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default ski.desktop inode/directory 2>/dev/null || true
fi

MIMEAPPS="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
if [ -f "$MIMEAPPS" ]; then
    if grep -q "^inode/directory=" "$MIMEAPPS"; then
        sed -i 's|^inode/directory=.*|inode/directory=ski.desktop;|' "$MIMEAPPS"
    elif grep -q '^\[Default Applications\]' "$MIMEAPPS"; then
        sed -i '/^\[Default Applications\]/a inode/directory=ski.desktop;' "$MIMEAPPS"
    else
        printf '\n[Default Applications]\ninode/directory=ski.desktop;\n' >> "$MIMEAPPS"
    fi
else
    printf '[Default Applications]\ninode/directory=ski.desktop;\n' > "$MIMEAPPS"
fi
echo -e "\e[32m:: [Ski]\e[0m Đã đặt Ski làm trình quản lý tệp mặc định cho inode/directory"

# ──────────────────────────────────────────────────────────────
# 4. Material You Theme Synchronization
# ──────────────────────────────────────────────────────────────
# Ski natively watches ~/.local/state/serpantinum/qs_colors.json
SERP_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum"
LUCR_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/lucretia"
mkdir -p "$SERP_STATE_DIR"
if [ -f "${LUCR_STATE_DIR}/qs_colors.json" ]; then
    ln -sf "${LUCR_STATE_DIR}/qs_colors.json" "${SERP_STATE_DIR}/qs_colors.json"
elif [ -f "${HOME}/.config/niri/bin/quickshell/qs_colors.json" ]; then
    ln -sf "${HOME}/.config/niri/bin/quickshell/qs_colors.json" "${SERP_STATE_DIR}/qs_colors.json"
fi
echo -e "\e[32m:: [Ski]\e[0m Đã liên kết bảng màu Material You (${SERP_STATE_DIR}/qs_colors.json)"

# ──────────────────────────────────────────────────────────────
# 5. Dock Settings Update
# ──────────────────────────────────────────────────────────────
SETTINGS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/niri/settings.json"
if [ -f "$SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1; then
    UPDATED_SETTINGS="$(jq '
        if (.dock.apps // null) == null then .
        else .dock.apps |= map(
            if (((.desktop_id // "") | test("^org\\.gnome\\.Nautilus(\\.desktop)?$")) or ((.name // "") == "Files"))
            then .desktop_id = "ski" | .icon = "ski" | .name = "Files"
            else . end)
        end' "$SETTINGS_FILE" 2>/dev/null || true)"
    if [ -n "$UPDATED_SETTINGS" ] && [ "$UPDATED_SETTINGS" != "null" ]; then
        echo "$UPDATED_SETTINGS" > "$SETTINGS_FILE"
        echo -e "\e[32m:: [Ski]\e[0m Đã cập nhật mục Files trên Dock sang Ski trong settings.json"
    fi
fi

echo -e "\e[32m:: [Ski]\e[0m Cài đặt và tích hợp Ski ${SKI_VERSION} hoàn tất!"
