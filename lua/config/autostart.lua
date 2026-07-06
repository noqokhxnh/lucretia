
hl.on("hyprland.start", function()
    -- === ĐỒNG BỘ BIẾN MÔI TRƯỜNG LÊN SYSTEMD & DBUS (BẮT BUỘC ĐỂ SỬA LỖI SUDO/POLKIT) ===
    -- Chạy qua script blocking để đảm bảo D-Bus và systemd --user nhận đủ session identity
    -- TRƯỚC KHI user kịp mở terminal. Tránh race condition với hl.exec_cmd() song song.
    hl.exec_cmd("~/.config/niri/scripts/sync-session-env.sh")

    -- === KHỞI ĐỘNG CÁC DAEMONS HỆ THỐNG ===
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("quickshell -p ~/.config/niri/scripts/quickshell/Shell.qml")
    hl.exec_cmd("~/.config/niri/scripts/init.sh")
    hl.exec_cmd("playerctld")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("~/.config/niri/scripts/volume_listener.sh")
    hl.exec_cmd("~/.config/niri/scripts/update_notifier.sh")
    hl.exec_cmd("~/.config/niri/scripts/battery_power_saver.sh")
    hl.exec_cmd("fcitx5 -d")
end)
