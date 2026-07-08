#include <iostream>
#include <string>
#include <vector>
#include <cstdio>
#include <memory>
#include <sstream>
#include <algorithm>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// Function to execute a shell command and return its output as a string
std::string exec_command(const std::string& cmd) {
    char buffer[8192];
    std::string result = "";
    // Redirect stderr to null to keep output clean
    std::string full_cmd = cmd + " 2>/dev/null";
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(full_cmd.c_str(), "r"), pclose);
    if (!pipe) return "[]";
    while (fgets(buffer, sizeof(buffer), pipe.get()) != nullptr) {
        result += buffer;
    }
    return result.empty() ? "[]" : result;
}

// Safely gets the first valid string from a list of properties
std::string get_valid_string(const std::vector<std::string>& candidates) {
    for (const auto& s : candidates) {
        if (!s.empty() && s != "null" && s != "None") {
            return s;
        }
    }
    return "";
}

// Gets the default node name using wpctl
std::string get_wpctl_default(const std::string& node_target) {
    std::string out = exec_command("wpctl inspect " + node_target);
    std::stringstream ss(out);
    std::string line;
    while (std::getline(ss, line)) {
        if (line.find("node.name") != std::string::npos) {
            size_t pos = line.find('=');
            if (pos != std::string::npos) {
                std::string name = line.substr(pos + 1);
                // Trim quotes and whitespace
                name.erase(0, name.find_first_not_of(" \t\""));
                name.erase(name.find_last_not_of(" \t\"") + 1);
                return name;
            }
        }
    }
    return "";
}

// Formats a PulseAudio node into the expected JSON structure
json format_node(const json& n, bool is_default = false, bool is_app = false) {
    int vol = 0;
    if (n.contains("volume") && n["volume"].is_object()) {
        if (n["volume"].contains("front-left") && n["volume"]["front-left"].is_object()) {
            std::string val = n["volume"]["front-left"].value("value_percent", "0%");
            try { vol = std::stoi(val.substr(0, val.find('%'))); } catch (...) {}
        } else if (n["volume"].contains("mono") && n["volume"]["mono"].is_object()) {
            std::string val = n["volume"]["mono"].value("value_percent", "0%");
            try { vol = std::stoi(val.substr(0, val.find('%'))); } catch (...) {}
        }
    }

    auto props = n.value("properties", json::object());
    std::string display_name, sub_desc, icon;

    if (is_app) {
        display_name = get_valid_string({
            props.value("application.name", ""),
            props.value("application.process.binary", ""),
            "Unknown App"
        });
        sub_desc = get_valid_string({
            props.value("media.name", ""),
            props.value("window.title", ""),
            props.value("media.role", ""),
            "Audio Stream"
        });
    } else {
        display_name = get_valid_string({
            props.value("device.description", ""),
            n.value("name", ""),
            "Unknown Device"
        });
        sub_desc = n.value("name", "Unknown");
    }

    icon = get_valid_string({
        props.value("application.icon_name", ""),
        props.value("device.icon_name", ""),
        "audio-card"
    });

    return {
        {"id", std::to_string(n.value("index", 0))},
        {"name", sub_desc},
        {"description", display_name},
        {"volume", vol},
        {"mute", n.value("mute", false)},
        {"is_default", is_default},
        {"icon", icon}
    };
}

int main() {
    // Fetch all needed data from pactl in JSON format
    json sinks, sources, sink_inputs;
    try {
        sinks = json::parse(exec_command("pactl -f json list sinks"));
    } catch (...) { sinks = json::array(); }
    
    try {
        sources = json::parse(exec_command("pactl -f json list sources"));
    } catch (...) { sources = json::array(); }
    
    try {
        sink_inputs = json::parse(exec_command("pactl -f json list sink-inputs"));
    } catch (...) { sink_inputs = json::array(); }
    
    // Get default nodes
    std::string default_sink = get_wpctl_default("@DEFAULT_AUDIO_SINK@");
    std::string default_source = get_wpctl_default("@DEFAULT_AUDIO_SOURCE@");

    // Fallback for default nodes if wpctl fails
    if (default_sink.empty() || default_source.empty()) {
        try {
            json info = json::parse(exec_command("pactl -f json info"));
            if (default_sink.empty()) default_sink = info.value("default_sink_name", "");
            if (default_source.empty()) default_source = info.value("default_source_name", "");
        } catch (...) {}
    }

    // Process Sinks (Outputs)
    json out_sinks = json::array();
    if (sinks.is_array()) {
        for (const auto& s : sinks) {
            out_sinks.push_back(format_node(s, s.value("name", "") == default_sink));
        }
    }

    // Process Sources (Inputs)
    json out_inputs = json::array();
    if (sources.is_array()) {
        for (const auto& s : sources) {
            auto props = s.value("properties", json::object());
            // Filter out monitor sources
            if (props.value("device.class", "") == "monitor" || s.value("name", "").find(".monitor") != std::string::npos) {
                continue;
            }
            out_inputs.push_back(format_node(s, s.value("name", "") == default_source));
        }
    }

    // Process Sink Inputs (Apps)
    json out_apps = json::array();
    if (sink_inputs.is_array()) {
        for (const auto& s : sink_inputs) {
            auto props = s.value("properties", json::object());
            // Filter out pavucontrol itself to avoid recursive UI noise
            if (props.value("application.id", "") != "org.PulseAudio.pavucontrol") {
                out_apps.push_back(format_node(s, false, true));
            }
        }
    }

    // Final aggregated output
    json final_out = {
        {"outputs", out_sinks},
        {"inputs", out_inputs},
        {"apps", out_apps}
    };

    std::cout << final_out.dump() << std::endl;

    return 0;
}
