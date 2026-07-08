#!/usr/bin/env bash
# master script to rebuild all quickshell daemons/backends

BASE_DIR="$(dirname "${BASH_SOURCE[0]}")"
cd "$BASE_DIR" || exit 1

echo "=== Starting Complete Rebuild of Quickshell Daemons ==="

# 1. Compile primary daemon
if [ -f "compile_daemon.sh" ]; then
    echo "-> Compiling core qs_daemon..."
    bash compile_daemon.sh >/dev/null
fi

# 2. Compile screenshot backend
if [ -f "screenshot/compile_screenshot.sh" ]; then
    echo "-> Compiling screenshot_backend..."
    (cd screenshot && bash compile_screenshot.sh >/dev/null)
fi

# 3. Compile music backend
if [ -f "music/compile_music.sh" ]; then
    echo "-> Compiling music_backend..."
    (cd music && bash compile_music.sh >/dev/null)
fi

# 4. Compile network backend
if [ -f "network/compile_network.sh" ]; then
    echo "-> Compiling network_backend..."
    (cd network && bash compile_network.sh >/dev/null)
fi

# 5. Compile notes backend
if [ -f "notes/compile_backend.sh" ]; then
    echo "-> Compiling notes_backend..."
    (cd notes && bash compile_backend.sh >/dev/null)
fi

# 6. Compile launcher backend
if [ -f "applauncher/compile_launcher.sh" ]; then
    echo "-> Compiling launcher backend..."
    (cd applauncher && bash compile_launcher.sh >/dev/null)
fi

# 7. Compile photobooth backend
if [ -f "photobooth/compile.sh" ]; then
    echo "-> Compiling photobooth backend..."
    (cd photobooth && bash compile.sh >/dev/null)
fi

# 8. Compile clipboard backend
if [ -f "clipboard/compile_clip.sh" ]; then
    echo "-> Compiling clipboard backend..."
    (cd clipboard && bash compile_clip.sh >/dev/null)
fi

# 9. Compile focus_daemon and get_stats (focustime)
if [ -f "../../src/focustime/focus_daemon.cpp" ]; then
    echo "-> Compiling focus_daemon..."
    g++ -O3 -std=c++20 -pthread ../../src/focustime/focus_daemon.cpp -o focustime/focus_daemon -lsqlite3 >/dev/null
fi
if [ -f "../../src/focustime/get_stats.cpp" ]; then
    echo "-> Compiling focus_stats..."
    g++ -O3 -std=c++20 ../../src/focustime/get_stats.cpp -o focustime/get_stats -lsqlite3 >/dev/null
fi

# 10. Compile sys_fetcher
if [ -f "../../src/watchers/sys_fetcher.cpp" ]; then
    echo "-> Compiling sys_fetcher..."
    g++ -O3 -std=c++20 ../../src/watchers/sys_fetcher.cpp -o watchers/sys_fetcher >/dev/null
fi

echo "=== All Quickshell C++ components rebuilt successfully! ==="
