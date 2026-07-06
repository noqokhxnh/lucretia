#!/usr/bin/env bash
# ~/.config/niri/scripts/apply_v055_migration.sh
# ─────────────────────────────────────────────────────────────────────────────
# Run this ONCE after upgrading Hyprland to v0.55+.
# It swaps the lua/ directory to the v0.55-compatible version and activates
# native Lua config by creating hyprland.lua in the config root.
# ─────────────────────────────────────────────────────────────────────────────

set -e

HYPR_DIR="$HOME/.config/niri"
NEW_LUA="$HYPR_DIR/lua-v055"
OLD_LUA="$HYPR_DIR/lua"
BACKUP_LUA="$HYPR_DIR/lua-legacy"

# ── Verify Hyprland version ──────────────────────────────────────────────────
CURRENT_VERSION=$(hyprctl version 2>/dev/null | grep -oP 'Hyprland \K[\d.]+' | head -1)
echo "Detected Hyprland version: $CURRENT_VERSION"

MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)

if [[ "$MAJOR" -lt 1 && "$MINOR" -lt 55 ]]; then
    echo "ERROR: This migration requires Hyprland v0.55+. Current: $CURRENT_VERSION"
    echo "Please run 'sudo pacman -Syu hyprland' first."
    exit 1
fi

echo "✓ Version check passed: v$CURRENT_VERSION >= v0.55"

# ── Backup legacy lua/ ───────────────────────────────────────────────────────
if [ -d "$OLD_LUA" ]; then
    echo "→ Backing up lua/ → lua-legacy/ ..."
    mv "$OLD_LUA" "$BACKUP_LUA"
fi

# ── Move lua-v055/ → lua/ ───────────────────────────────────────────────────
if [ -d "$NEW_LUA" ]; then
    echo "→ Activating lua-v055/ as new lua/ ..."
    mv "$NEW_LUA" "$OLD_LUA"
else
    echo "ERROR: lua-v055/ directory not found at $NEW_LUA"
    exit 1
fi

# ── Create hyprland.lua → activates native Lua in Hyprland ──────────────────
HYPRLAND_LUA="$HYPR_DIR/hyprland.lua"
if [ -f "$HYPRLAND_LUA" ]; then
    echo "→ Backing up existing hyprland.lua → hyprland.lua.bak ..."
    mv "$HYPRLAND_LUA" "$HYPRLAND_LUA.bak"
fi

echo "→ Creating hyprland.lua (symlink to lua/hyprland.lua) ..."
ln -sf "$HYPR_DIR/lua/hyprland.lua" "$HYPRLAND_LUA"

# ── Kill the lua watcher (no longer needed) ──────────────────────────────────
if [ -f /tmp/hypr_lua_watcher.pid ]; then
    OLD_PID=$(cat /tmp/hypr_lua_watcher.pid 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "→ Stopping legacy Lua watcher (PID $OLD_PID) ..."
        kill -9 "$OLD_PID" 2>/dev/null || true
    fi
    rm -f /tmp/hypr_lua_watcher.pid
fi

# ── Reload Hyprland ──────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " Migration complete! Reloading Hyprland..."
echo "═══════════════════════════════════════════════════════"
echo ""
echo " If you see errors after reload:"
echo "   1. Check: journalctl --user -u hyprland -n 50"
echo "   2. Rollback: mv $OLD_LUA $NEW_LUA && mv $BACKUP_LUA $OLD_LUA && rm $HYPRLAND_LUA"
echo ""

hyprctl reload
notify-send -t 3000 "Hyprland v0.55" "Migrated to native Lua config!"

echo "Done."
