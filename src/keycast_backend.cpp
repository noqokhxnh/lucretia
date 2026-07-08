#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <filesystem>
#include <fcntl.h>
#include <unistd.h>
#include <sys/select.h>
#include <linux/input.h>
#include <cctype>
#include <cstring>
#include <errno.h>

namespace fs = std::filesystem;

// Standard Linux keycode mapping
const std::map<int, std::string> KEY_MAP = {
    {1, "Esc"}, {2, "1"}, {3, "2"}, {4, "3"}, {5, "4"}, {6, "5"}, {7, "6"}, {8, "7"}, {9, "8"}, {10, "9"}, {11, "0"},
    {12, "-"}, {13, "="}, {14, "Backspace"}, {15, "Tab"},
    {16, "q"}, {17, "w"}, {18, "e"}, {19, "r"}, {20, "t"}, {21, "y"}, {22, "u"}, {23, "i"}, {24, "o"}, {25, "p"},
    {26, "["}, {27, "]"}, {28, "Enter"}, {29, "LCtrl"},
    {30, "a"}, {31, "s"}, {32, "d"}, {33, "f"}, {34, "g"}, {35, "h"}, {36, "j"}, {37, "k"}, {38, "l"}, {39, ";"},
    {40, "'"}, {41, "`"}, {42, "LShift"}, {43, "\\"},
    {44, "z"}, {45, "x"}, {46, "c"}, {47, "v"}, {48, "b"}, {49, "n"}, {50, "m"}, {51, ","}, {52, "."}, {53, "/"},
    {54, "RShift"}, {56, "LAlt"}, {57, "Space"}, {58, "CapsLock"},
    {97, "RCtrl"}, {100, "RAlt"}, {125, "Super"},
    {103, "Up"}, {108, "Down"}, {105, "Left"}, {106, "Right"},
    {71, "7"}, {72, "8"}, {73, "9"}, {74, "-"}, {75, "4"}, {76, "5"}, {77, "6"}, {78, "+"}, {79, "1"}, {80, "2"},
    {81, "3"}, {82, "0"}, {83, "."}, {96, "KPEnter"}, {98, "/"}
};

// Shipped values when Shift is active
const std::map<std::string, std::string> SHIFT_MAP = {
    {"1", "!"}, {"2", "@"}, {"3", "#"}, {"4", "$"}, {"5", "%"}, {"6", "^"}, {"7", "&"}, {"8", "*"}, {"9", "("}, {"0", ")"},
    {"-", "_"}, {"=", "+"}, {"[", "{"}, {"]", "}"}, {";", ":"}, {"'", "\""}, {"`", "~"}, {",", "<"}, {".", ">"}, {"/", "?"},
    {"\\", "|"}
};

// Scan and locate event keyboard devices
std::vector<std::string> get_keyboard_devices() {
    std::vector<std::string> devices;
    
    // 1. Try by-id first (cleanest and most specific)
    std::string by_id_dir = "/dev/input/by-id";
    if (fs::exists(by_id_dir) && fs::is_directory(by_id_dir)) {
        for (const auto& entry : fs::directory_iterator(by_id_dir)) {
            std::string path = entry.path().string();
            if (path.find("-event-kbd") != std::string::npos) {
                devices.push_back(path);
            }
        }
    }
    
    // 2. Fallback to general event devices if nothing in by-id
    if (devices.empty()) {
        std::string input_dir = "/dev/input";
        if (fs::exists(input_dir) && fs::is_directory(input_dir)) {
            for (const auto& entry : fs::directory_iterator(input_dir)) {
                std::string path = entry.path().string();
                std::string filename = entry.path().filename().string();
                if (filename.rfind("event", 0) == 0) { // starts with "event"
                    devices.push_back(path);
                }
            }
        }
    }
    
    return devices;
}

// Minimal JSON escape logic
std::string escape_json(const std::string& s) {
    std::string result;
    for (char c : s) {
        if (c == '"') {
            result += "\\\"";
        } else if (c == '\\') {
            result += "\\\\";
        } else {
            result += c;
        }
    }
    return result;
}

int main() {
    // Disable stdin buffering for clean execution
    std::ios_base::sync_with_stdio(false);
    std::cin.tie(NULL);

    std::vector<std::string> devices = get_keyboard_devices();
    if (devices.empty()) {
        std::cout << "{\"error\": \"No keyboard devices found.\"}" << std::endl;
        return 1;
    }
    
    std::vector<int> fds;
    for (const auto& path : devices) {
        int fd = open(path.c_str(), O_RDONLY | O_NONBLOCK);
        if (fd >= 0) {
            fds.push_back(fd);
        }
    }
    
    if (fds.empty()) {
        std::cout << "{\"error\": \"Failed to open any input devices. Are you in the 'input' group?\"}" << std::endl;
        return 1;
    }
    
    bool shift_pressed = false;
    bool ctrl_pressed = false;
    bool alt_pressed = false;
    bool meta_pressed = false;
    bool caps_lock = false;
    
    int max_fd = -1;
    fd_set read_fds;
    
    for (int fd : fds) {
        if (fd > max_fd) max_fd = fd;
    }
    
    struct input_event ev;
    
    while (true) {
        FD_ZERO(&read_fds);
        for (int fd : fds) {
            FD_SET(fd, &read_fds);
        }
        
        int activity = select(max_fd + 1, &read_fds, nullptr, nullptr, nullptr);
        if (activity < 0) {
            if (errno == EINTR) continue;
            break;
        }
        
        for (int fd : fds) {
            if (FD_ISSET(fd, &read_fds)) {
                while (read(fd, &ev, sizeof(struct input_event)) > 0) {
                    if (ev.type == EV_KEY) {
                        // Update modifier states on press (1), release (0), and repeat (2)
                        if (ev.code == 42 || ev.code == 54) { // Shift
                            shift_pressed = (ev.value != 0);
                            continue;
                        } else if (ev.code == 29 || ev.code == 97) { // Ctrl
                            ctrl_pressed = (ev.value != 0);
                            continue;
                        } else if (ev.code == 56 || ev.code == 100) { // Alt
                            alt_pressed = (ev.value != 0);
                            continue;
                        } else if (ev.code == 125) { // Super / Win
                            meta_pressed = (ev.value != 0);
                            continue;
                        } else if (ev.code == 58) { // CapsLock
                            if (ev.value == 1) {
                                caps_lock = !caps_lock;
                            }
                            continue;
                        }
                        
                        // We only process Key Down (1) and Key Repeat (2)
                        if (ev.value == 1 || ev.value == 2) {
                            auto it = KEY_MAP.find(ev.code);
                            if (it != KEY_MAP.end()) {
                                std::string key_name = it->second;
                                
                                std::vector<std::string> active_mods;
                                if (ctrl_pressed) active_mods.push_back("Ctrl");
                                if (alt_pressed) active_mods.push_back("Alt");
                                if (meta_pressed) active_mods.push_back("Super");
                                
                                bool is_modifier_combo = !active_mods.empty();
                                
                                if (is_modifier_combo) {
                                    if (shift_pressed) active_mods.push_back("Shift");
                                    
                                    std::string display_key = key_name;
                                    if (display_key.length() == 1) {
                                        display_key[0] = std::toupper(display_key[0]);
                                    }
                                    
                                    std::string combo_str = "";
                                    for (size_t i = 0; i < active_mods.size(); ++i) {
                                        combo_str += active_mods[i] + "+";
                                    }
                                    combo_str += display_key;
                                    
                                    std::cout << "{\"key\": \"" << escape_json(combo_str) << "\", \"is_modifier\": true}" << std::endl;
                                    std::cout.flush();
                                } else {
                                    std::string display_key = key_name;
                                    if (display_key.length() == 1) {
                                        bool is_letter = std::isalpha(display_key[0]);
                                        if (is_letter) {
                                            bool use_caps = caps_lock ^ shift_pressed;
                                            display_key[0] = use_caps ? std::toupper(display_key[0]) : std::tolower(display_key[0]);
                                        } else {
                                            if (shift_pressed) {
                                                auto sit = SHIFT_MAP.find(display_key);
                                                if (sit != SHIFT_MAP.end()) {
                                                    display_key = sit->second;
                                                }
                                            }
                                        }
                                    }
                                    
                                    if (display_key == "Space") {
                                        display_key = "Space";
                                    }
                                    
                                    std::cout << "{\"key\": \"" << escape_json(display_key) << "\", \"is_modifier\": false}" << std::endl;
                                    std::cout.flush();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    for (int fd : fds) {
        close(fd);
    }
    
    return 0;
}
