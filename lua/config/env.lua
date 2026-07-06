
-- === BIẾN MÔI TRƯỜNG ĐỊNH DANH SESSION (BẮT BUỘC ĐỂ SỬA LỖI SUDO) ===
hl.env("XDG_SESSION_TYPE",     "wayland")
hl.env("XDG_CURRENT_DESKTOP",   "Hyprland")
hl.env("XDG_SESSION_DESKTOP",   "Hyprland")

-- === Cấu hình Render cho Toolkit và Trình duyệt ===
hl.env("GDK_BACKEND",           "wayland,x11,*")
hl.env("QT_QPA_PLATFORM",       "wayland;xcb")
hl.env("NIXOS_OZONE_WL",        "1") -- Kích hoạt Wayland cho Chromium/Electron app

-- === Thư mục cá nhân và biến tùy chỉnh của bạn ===
hl.env("XDG_PICTURES_DIR",      "/home/khxnh/Pictures")
hl.env("XDG_VIDEOS_DIR",        "/home/khxnh/Videos")
hl.env("WALLPAPER_DIR",         "/home/khxnh/Pictures/Wallpapers")
hl.env("SCRIPT_DIR",            "/home/khxnh/.config/niri/scripts")
hl.env("QT_QPA_PLATFORMTHEME",  "qt6ct")
