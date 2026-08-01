// flatten_colors.cpp — C++ replacement for the inline Python snippet in
// bin/quickshell/wallpaper/matugen_reload.sh
//
// Flattens Matugen v4.0 nested JSON: any object of the form {"color": "#hex"}
// collapses to the plain string "#hex", recursively (arrays are traversed too).
// The result is written back to the same file with indent 4, matching the
// original Python behaviour exactly.
//
// Usage: flatten_colors <json-file>
#include <iostream>
#include <string>
#include <fstream>
#include <filesystem>
#include <nlohmann/json.hpp>

using json = nlohmann::ordered_json;   // preserves key insertion order like Python dicts
namespace fs = std::filesystem;

static json flatten(const json& obj) {
    if (obj.is_object()) {
        // {"color": "#hex"} (string value) collapses to the string itself.
        if (auto it = obj.find("color"); it != obj.end() && it->is_string()) {
            return *it;
        }
        json out = json::object();
        for (auto it = obj.begin(); it != obj.end(); ++it) {
            out[it.key()] = flatten(it.value());
        }
        return out;
    }
    if (obj.is_array()) {
        json out = json::array();
        for (const auto& el : obj) {
            out.push_back(flatten(el));
        }
        return out;
    }
    return obj;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: flatten_colors <json-file>\n";
        return 2;
    }
    const std::string path = argv[1];

    // Original Python swallowed FileNotFoundError silently.
    if (!fs::exists(path)) {
        return 0;
    }

    try {
        std::ifstream in(path);
        if (!in) {
            std::cerr << "Error flattening JSON: cannot open " << path << "\n";
            return 1;
        }
        json data = json::parse(in);

        json flat = flatten(data);

        std::ofstream out(path, std::ios::trunc);
        if (!out) {
            std::cerr << "Error flattening JSON: cannot write " << path << "\n";
            return 1;
        }
        out << flat.dump(4);
        out.close();
        if (!out) {
            std::cerr << "Error flattening JSON: write failed for " << path << "\n";
            return 1;
        }
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error flattening JSON: " << e.what() << "\n";
        return 1;
    }
}
