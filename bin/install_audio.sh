#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Lucretia - serpantinum-audio Installer & EasyEffects Migrator
# Bundles serpantinum-audio (v0.3.0) as the native PipeWire
# virtual sink (serpantinum_sink), 10-band EQ, Dynamic EQ,
# balance, mono, channel swap, compressor & look-ahead limiter.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

AUDIO_VERSION="0.3.0"
AUDIO_TAG="v${AUDIO_VERSION}"
AUDIO_SHA256="1f31e0ae00abb731c0a5633447ce773642da6543dfe1f586cd3a88f8cecb2541"
AUDIO_TARBALL="serpantinum-audio-${AUDIO_VERSION}-x86_64-linux.tar.gz"
AUDIO_URL="https://github.com/ilyamiro/serpantinum-audio/releases/download/${AUDIO_TAG}/${AUDIO_TARBALL}"

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

echo -e "\e[36m:: [Audio Engine]\e[0m Đang cài đặt serpantinum-audio ${AUDIO_VERSION} vào ${PREFIX}..."

# Check system architecture
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
    echo -e "\e[33m:: [Audio Engine]\e[0m Kiến trúc ${ARCH} không có bản prebuilt official binary, thử biên dịch từ nguồn..."
    if command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1 && command -v g++ >/dev/null 2>&1; then
        BUILD_DIR="$(mktemp -d /tmp/serpantinum-audio-build.XXXXXX)"
        trap 'rm -rf "$BUILD_DIR"' EXIT
        git clone --depth 1 --branch "${AUDIO_TAG}" https://github.com/ilyamiro/serpantinum-audio.git "$BUILD_DIR"
        (cd "$BUILD_DIR" && make -j"$(nproc)" && $SUDO make install PREFIX="$PREFIX")
        echo -e "\e[32m:: [Audio Engine]\e[0m Đã biên dịch và cài đặt serpantinum-audio từ mã nguồn thành công!"
    else
        echo -e "\e[31m:: [LỖI]\e[0m Cần git, make, g++ và pipewire headers để biên dịch serpantinum-audio." >&2
        exit 1
    fi
else
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/lucretia-audio"
    mkdir -p "$CACHE_DIR"
    ARCHIVE="${CACHE_DIR}/${AUDIO_TARBALL}"

    # Download release archive if not cached or checksum mismatch
    NEED_DOWNLOAD=true
    if [ -f "$ARCHIVE" ]; then
        if echo "${AUDIO_SHA256}  ${ARCHIVE}" | sha256sum -c --quiet - 2>/dev/null; then
            NEED_DOWNLOAD=false
        fi
    fi

    if [ "$NEED_DOWNLOAD" = true ]; then
        echo -e "\e[34m:: [Audio Engine]\e[0m Đang tải ${AUDIO_URL}..."
        if ! curl -fL# --connect-timeout 15 --retry 3 "$AUDIO_URL" -o "$ARCHIVE"; then
            wget -c -q --show-progress "$AUDIO_URL" -O "$ARCHIVE" || true
        fi
    fi

    # Verify SHA256 checksum
    echo -e "\e[34m:: [Audio Engine]\e[0m Đang kiểm tra mã băm SHA256..."
    if ! echo "${AUDIO_SHA256}  ${ARCHIVE}" | sha256sum -c --quiet -; then
        echo -e "\e[31m:: [LỖI]\e[0m Mã băm SHA256 không hợp lệ cho ${ARCHIVE}" >&2
        rm -f "$ARCHIVE"
        exit 1
    fi

    STAGE_DIR="$(mktemp -d "${CACHE_DIR}/stage.XXXXXX")"
    trap 'rm -rf "$STAGE_DIR"' EXIT

    tar -xzf "$ARCHIVE" -C "$STAGE_DIR"

    STAGE_ROOT="$STAGE_DIR/usr"
    [ ! -d "$STAGE_ROOT" ] && STAGE_ROOT="$STAGE_DIR"

    # Install binary & license
    echo -e "\e[34m:: [Audio Engine]\e[0m Đang triển khai binary serpantinum-audio..."
    $SUDO install -Dm755 "${STAGE_ROOT}/bin/serpantinum-audio" "${PREFIX}/bin/serpantinum-audio"

    if [ -f "${STAGE_ROOT}/share/licenses/serpantinum-audio/LICENSE" ]; then
        $SUDO install -Dm644 "${STAGE_ROOT}/share/licenses/serpantinum-audio/LICENSE" "${PREFIX}/share/licenses/serpantinum-audio/LICENSE" 2>/dev/null || true
    fi
fi

# Ensure user directories and state symlinks exist
SERP_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum"
LUCR_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/lucretia"
mkdir -p "$SERP_STATE_DIR" "$LUCR_STATE_DIR"

# Link audio.state if present
if [ -f "${LUCR_STATE_DIR}/audio.state" ] && [ ! -f "${SERP_STATE_DIR}/audio.state" ]; then
    ln -sf "${LUCR_STATE_DIR}/audio.state" "${SERP_STATE_DIR}/audio.state"
elif [ -f "${SERP_STATE_DIR}/audio.state" ] && [ ! -f "${LUCR_STATE_DIR}/audio.state" ]; then
    ln -sf "${SERP_STATE_DIR}/audio.state" "${LUCR_STATE_DIR}/audio.state"
fi

# ──────────────────────────────────────────────────────────────
# EasyEffects Migration & Cleanup
# ──────────────────────────────────────────────────────────────
echo -e "\e[34m:: [Audio Engine]\e[0m Đang dọn dẹp cấu hình EasyEffects cũ..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop easyeffects 2>/dev/null || true
    systemctl --user disable easyeffects 2>/dev/null || true
    systemctl --user stop ee-eq.service 2>/dev/null || true
fi

# Kill old easyeffects processes if running
pkill -f "easyeffects" 2>/dev/null || true

# Remove generated live_eq preset to prevent interference
rm -f "$HOME/.local/share/easyeffects/output/live_eq.json" \
      "$HOME/.config/easyeffects/output/live_eq.json" 2>/dev/null || true

echo -e "\e[32m:: [Audio Engine]\e[0m Cài đặt và cấu hình serpantinum-audio ${AUDIO_VERSION} hoàn tất!"
