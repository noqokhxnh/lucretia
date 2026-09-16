#!/usr/bin/env python3
"""
display_mode.py - Multi-display mode manager for Niri + Quickshell
Supported modes:
  - extend:   All monitors enabled with separate workspaces
  - mirror:   Clone primary display to secondary using wl-mirror
  - internal: PC/Laptop screen only (external screen off)
  - external: Second screen only (laptop screen off)
"""

import sys
import os
import json
import re
import subprocess

HOME = os.path.expanduser("~")
NIRI_CONFIG_PATHS = [
    os.path.join(HOME, ".config/niri/config.kdl"),
    "/home/khxnh/orca/workspaces/niri/nuckelavee/config.kdl"
]
CACHE_FILE = os.path.join(HOME, ".cache/lucretia/monitors/display_mode_state.json")


def run_cmd(cmd, check=False):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=check)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return 1, "", str(e)


def is_wl_mirror_running():
    code, _, _ = run_cmd(["pgrep", "-x", "wl-mirror"])
    return code == 0


def stop_wl_mirror():
    run_cmd(["killall", "-9", "wl-mirror"])


def get_niri_outputs():
    code, out, _ = run_cmd(["niri", "msg", "--json", "outputs"])
    if code == 0 and out:
        try:
            return json.loads(out)
        except Exception:
            pass
    return {}


def detect_monitors():
    outputs = get_niri_outputs()
    internal = None
    external = None

    # Identify internal (eDP, LVDS, DSI) vs external (HDMI, DP, etc.)
    for name in outputs.keys():
        if re.match(r"^(eDP|LVDS|DSI)", name, re.IGNORECASE):
            if not internal:
                internal = name
        else:
            if not external:
                external = name

    names = list(outputs.keys())
    if not internal and names:
        internal = names[0]
    if not external and len(names) > 1:
        external = [n for n in names if n != internal][0] if any(n != internal for n in names) else names[1]

    return internal, external, outputs


def get_current_mode(internal, external, outputs):
    if is_wl_mirror_running():
        return "mirror"

    # Check if either output is off in config.kdl or niri
    int_info = outputs.get(internal, {}) if internal else {}
    ext_info = outputs.get(external, {}) if external else {}

    int_on = int_info.get("logical") is not None
    ext_on = ext_info.get("logical") is not None

    # Also inspect active config.kdl
    active_config = NIRI_CONFIG_PATHS[0]
    if os.path.exists(active_config):
        try:
            with open(active_config, "r", encoding="utf-8") as f:
                content = f.read()
            if external and re.search(r'output\s+"' + re.escape(external) + r'"\s*\{\s*off\b', content):
                ext_on = False
            if internal and re.search(r'output\s+"' + re.escape(internal) + r'"\s*\{\s*off\b', content):
                int_on = False
        except Exception:
            pass

    if int_on and not ext_on:
        return "internal"
    elif ext_on and not int_on:
        return "external"
    else:
        return "extend"


def get_saved_state():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_state(state):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass


def update_niri_config(output_blocks):
    """Replace all output blocks in config.kdl files and reload niri."""
    for cfg_path in NIRI_CONFIG_PATHS:
        if not os.path.exists(cfg_path):
            continue
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                content = f.read()

            # Strip existing output blocks (including off blocks)
            # Matches: output "..." { ... }
            content_stripped = re.sub(r'\noutput\s+"[^"]+"\s*\{[^}]*\}', '', content)
            # Clean up trailing blank lines
            content_stripped = content_stripped.rstrip() + "\n"

            # Append new output blocks
            blocks_text = "\n" + "\n\n".join(output_blocks) + "\n"
            new_content = content_stripped + blocks_text

            with open(cfg_path, "w", encoding="utf-8") as f:
                f.write(new_content)
        except Exception as e:
            print(f"Error updating {cfg_path}: {e}", file=sys.stderr)

    # Reload niri
    run_cmd(["niri", "msg", "action", "load-config-file"])


def build_output_block(name, mode_str=None, pos_x=0, pos_y=0, scale=1.0, is_off=False):
    if is_off:
        return f'output "{name}" {{\n    off\n}}'

    lines = [f'output "{name}" {{']
    if mode_str:
        lines.append(f'    mode "{mode_str}"')
    lines.append(f'    position x={int(pos_x)} y={int(pos_y)}')
    lines.append(f'    scale {scale:.2f}')
    lines.append('}')
    return "\n".join(lines)


def cmd_status():
    internal, external, outputs = detect_monitors()
    mode = get_current_mode(internal, external, outputs)
    mirror_active = is_wl_mirror_running()

    res = {
        "mode": mode,
        "internal": internal or "",
        "external": external or "",
        "is_mirror": mirror_active,
        "internal_active": outputs.get(internal, {}).get("logical") is not None if internal else False,
        "external_active": outputs.get(external, {}).get("logical") is not None if external else False,
        "outputs_count": len(outputs),
        "outputs": {}
    }

    for name, out in outputs.items():
        mode_idx = out.get("current_mode")
        modes = out.get("modes", [])
        m = modes[mode_idx] if mode_idx is not None and mode_idx < len(modes) else (modes[0] if modes else None)
        res["outputs"][name] = {
            "width": m["width"] if m else 1920,
            "height": m["height"] if m else 1080,
            "rate": round(m["refresh_rate"] / 1000) if m else 60,
            "on": out.get("logical") is not None,
            "scale": out.get("logical", {}).get("scale", 1.0) if out.get("logical") else 1.0,
            "x": out.get("logical", {}).get("x", 0) if out.get("logical") else 0,
            "y": out.get("logical", {}).get("y", 0) if out.get("logical") else 0
        }

    print(json.dumps(res, indent=2))
    return 0


def cmd_set_mode(target_mode):
    internal, external, outputs = detect_monitors()
    saved = get_saved_state()

    # Determine resolution/refresh modes
    # Laptop screen default: 1920x1080@60
    int_mode = "1920x1080@60"
    if internal and internal in outputs and outputs[internal].get("modes"):
        m = outputs[internal]["modes"][0]
        int_mode = f"{m['width']}x{m['height']}@{round(m['refresh_rate']/1000)}"

    # External screen default: 1920x1080@60 or saved
    ext_mode = saved.get("ext_mode", "1920x1080@60")

    if target_mode == "extend":
        stop_wl_mirror()
        blocks = []
        if external:
            blocks.append(build_output_block(external, mode_str=ext_mode, pos_x=622, pos_y=0, scale=1.00))
        if internal:
            blocks.append(build_output_block(internal, mode_str=int_mode, pos_x=0, pos_y=1080, scale=1.00))

        update_niri_config(blocks)
        save_state({"last_mode": "extend", "ext_mode": ext_mode, "int_mode": int_mode})
        run_cmd(["notify-send", "-a", "Monitor Settings", "Display Mode: Extend", "Mở rộng không gian làm việc cả 2 màn hình"])

    elif target_mode == "mirror":
        stop_wl_mirror()
        # Both outputs must be ON in niri
        blocks = []
        if external:
            blocks.append(build_output_block(external, mode_str=ext_mode, pos_x=1920, pos_y=0, scale=1.00))
        if internal:
            blocks.append(build_output_block(internal, mode_str=int_mode, pos_x=0, pos_y=0, scale=1.00))
        update_niri_config(blocks)

        # Wait briefly for niri output reconfiguration before launching wl-mirror
        subprocess.run(["sleep", "0.3"])

        # Launch wl-mirror in background
        target_out = external if external else "HDMI-A-1"
        source_out = internal if internal else "eDP-1"

        subprocess.Popen(
            ["wl-mirror", "--fullscreen-output", target_out, source_out],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        save_state({"last_mode": "mirror", "ext_mode": ext_mode, "int_mode": int_mode})
        run_cmd(["notify-send", "-a", "Monitor Settings", "Display Mode: Mirror", f"Chiếu màn hình {source_out} sang {target_out}"])

    elif target_mode in ("internal", "pc-only"):
        stop_wl_mirror()
        blocks = []
        if external:
            blocks.append(build_output_block(external, is_off=True))
        if internal:
            blocks.append(build_output_block(internal, mode_str=int_mode, pos_x=0, pos_y=0, scale=1.00))

        update_niri_config(blocks)
        save_state({"last_mode": "internal", "ext_mode": ext_mode, "int_mode": int_mode})
        run_cmd(["notify-send", "-a", "Monitor Settings", "Display Mode: PC Only", "Chỉ sử dụng màn hình laptop, tắt màn ngoài"])

    elif target_mode in ("external", "second-only"):
        stop_wl_mirror()
        blocks = []
        if internal:
            blocks.append(build_output_block(internal, is_off=True))
        if external:
            blocks.append(build_output_block(external, mode_str=ext_mode, pos_x=0, pos_y=0, scale=1.00))

        update_niri_config(blocks)
        save_state({"last_mode": "external", "ext_mode": ext_mode, "int_mode": int_mode})
        run_cmd(["notify-send", "-a", "Monitor Settings", "Display Mode: Second Screen Only", "Chỉ sử dụng màn hình TV / Màn ngoài"])

    else:
        print(f"Unknown mode: {target_mode}", file=sys.stderr)
        return 1

    return 0


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("status", "get"):
        return cmd_status()
    elif sys.argv[1] in ("set", "switch"):
        if len(sys.argv) < 3:
            print("Usage: display_mode.py set <extend|mirror|internal|external>")
            return 1
        return cmd_set_mode(sys.argv[2])
    else:
        # Direct mode argument
        return cmd_set_mode(sys.argv[1])


if __name__ == "__main__":
    sys.exit(main())
