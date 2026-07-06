#!/usr/bin/env bash
# sync-session-env.sh
# Đồng bộ biến môi trường session Wayland lên D-Bus và systemd --user.
# Chạy ĐỒNG BỘ (blocking) để đảm bảo PAM/logind nhận đúng session identity
# trước khi user kịp mở terminal và gõ sudo.
#
# Gọi từ autostart.lua:
#   hl.exec_cmd("~/.config/niri/scripts/sync-session-env.sh")
#   -- Đặt trước tất cả hl.exec_cmd() khác

# Đợi WAYLAND_DISPLAY sẵn sàng (tránh race condition với Hyprland compositor)
for i in $(seq 1 20); do
    [ -n "$WAYLAND_DISPLAY" ] && break
    sleep 0.1
done

# Đồng bộ lên D-Bus activation environment
dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_SESSION_DESKTOP \
    DISPLAY \
    DBUS_SESSION_BUS_ADDRESS

# Đồng bộ lên systemd --user
systemctl --user import-environment \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_SESSION_DESKTOP \
    DISPLAY \
    DBUS_SESSION_BUS_ADDRESS

# Khởi động lại các dịch vụ portal để áp dụng biến môi trường mới
systemctl --user stop xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal 2>/dev/null
systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal 2>/dev/null

# Khởi động swayosd-server sau khi môi trường hiển thị và D-Bus đã sẵn sàng
swayosd-server --top-margin 0.9 --style "$HOME/.config/swayosd/style.css" >/dev/null 2>&1 &

# Log để debug nếu cần
echo "[sync-session-env] Done at $(date)" >> /tmp/hypr-session-sync.log
