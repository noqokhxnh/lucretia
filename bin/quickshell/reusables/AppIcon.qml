import QtQuick
import "../singletons"

Item {
    id: root

    property string iconName: ""
    property string appId: ""
    property string appName: ""
    property real iconSize: Math.min(width, height)
    property color fallbackColor: ThemeBackend.subtext0

    property var candidates: []
    property int currentCandidateIndex: 0
    property bool hasValidImage: srcImage.status === Image.Ready && !srcImage.hasFailed

    function buildCandidates() {
        let list = [];
        let ic = (root.iconName || "").trim();
        let id = (root.appId || "").trim().replace(".desktop", "");
        let name = (root.appName || "").trim().toLowerCase();

        // Direct paths or urls
        if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) {
            list.push(ic);
        } else if (ic.startsWith("/")) {
            list.push("file://" + ic);
        } else if (ic.length > 0) {
            list.push("image://icon/" + ic);
            let cleanIc = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
            if (cleanIc !== ic) {
                list.push("image://icon/" + cleanIc);
            }
            if (cleanIc.includes("-desktop")) {
                list.push("image://icon/" + cleanIc.replace("-desktop", "-browser"));
                list.push("image://icon/" + cleanIc.replace("-desktop", ""));
            }
            if (cleanIc.includes("-browser")) {
                list.push("image://icon/" + cleanIc.replace("-browser", "-desktop"));
                list.push("image://icon/" + cleanIc.replace("-browser", ""));
            }
        }

        // Check common hardcoded icon locations for apps like Brave
        if (id.includes("brave") || name.includes("brave") || ic.includes("brave")) {
            list.push("image://icon/brave-browser");
            list.push("image://icon/brave-desktop");
            list.push("image://icon/brave");
            list.push("image://icon/com.brave.Browser");
            list.push("file:///usr/share/icons/hicolor/128x128/apps/brave-desktop.png");
            list.push("file:///usr/share/icons/Papirus/64x64/apps/brave-browser.svg");
            list.push("file:///usr/share/icons/Papirus/64x64/apps/brave-desktop.svg");
        }

        // App ID variations
        if (id.length > 0 && !list.includes("image://icon/" + id)) {
            list.push("image://icon/" + id);
            let lowerId = id.toLowerCase();
            if (lowerId !== id && !list.includes("image://icon/" + lowerId)) {
                list.push("image://icon/" + lowerId);
            }
        }

        // App Name variations
        if (name.length > 0) {
            let slugName = name.replace(/[^a-z0-9_-]/g, "-");
            if (!list.includes("image://icon/" + slugName)) {
                list.push("image://icon/" + slugName);
            }
        }

        candidates = list;
        currentCandidateIndex = 0;
        srcImage.hasFailed = false;
        srcImage.source = candidates.length > 0 ? candidates[0] : "";
    }

    onIconNameChanged: buildCandidates()
    onAppIdChanged: buildCandidates()
    onAppNameChanged: buildCandidates()
    Component.onCompleted: buildCandidates()

    function getSmartFontIcon() {
        let text = (root.appId + " " + root.appName + " " + root.iconName).toLowerCase();
        
        // Web Browsers
        if (text.includes("brave") || text.includes("firefox") || text.includes("chrome") || 
            text.includes("chromium") || text.includes("edge") || text.includes("vivaldi") || 
            text.includes("opera") || text.includes("zen") || text.includes("browser") || text.includes("waterfox")) {
            if (text.includes("firefox")) return "󰈹";
            if (text.includes("chrome")) return "";
            if (text.includes("edge")) return "󰇩";
            return "󰖟";
        }
        
        // Terminals
        if (text.includes("terminal") || text.includes("kitty") || text.includes("foot") || 
            text.includes("alacritty") || text.includes("wezterm") || text.includes("console") || 
            text.includes("pty") || text.includes("byobu")) {
            return "󰆍";
        }

        // Code / IDE
        if (text.includes("code") || text.includes("codium") || text.includes("nvim") || 
            text.includes("vim") || text.includes("emacs") || text.includes("ide") || 
            text.includes("studio") || text.includes("antigravity") || text.includes("cursor")) {
            return "󰨞";
        }

        // Media & Music
        if (text.includes("spotify") || text.includes("music") || text.includes("amberol") || 
            text.includes("rhythm") || text.includes("player") || text.includes("audio")) {
            return "󰎈";
        }

        // Video & Streaming
        if (text.includes("video") || text.includes("vlc") || text.includes("mpv") || 
            text.includes("obs") || text.includes("kdenlive") || text.includes("shotcut")) {
            return "󰕧";
        }

        // Chat & Social
        if (text.includes("discord") || text.includes("vesktop") || text.includes("slack") || 
            text.includes("telegram") || text.includes("signal") || text.includes("matrix") || 
            text.includes("element") || text.includes("chat")) {
            return "󰙯";
        }

        // Games
        if (text.includes("steam") || text.includes("lutris") || text.includes("heroic") || 
            text.includes("game") || text.includes("retroarch") || text.includes("bottles")) {
            return "󰓓";
        }

        // Graphics & Design
        if (text.includes("gimp") || text.includes("inkscape") || text.includes("blender") || 
            text.includes("krita") || text.includes("figma") || text.includes("image") || 
            text.includes("photo") || text.includes("draw")) {
            return "󰋩";
        }

        // Files
        if (text.includes("nemo") || text.includes("nautilus") || text.includes("thunar") || 
            text.includes("dolphin") || text.includes("file") || text.includes("archive")) {
            return "󰉋";
        }

        // Settings / Tools
        if (text.includes("setting") || text.includes("config") || text.includes("control") || 
            text.includes("tweak") || text.includes("preference")) {
            return "󰒓";
        }

        if (text.includes("calc")) return "󰃬";

        return "󰀻";
    }

    Image {
        id: srcImage
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        smooth: true
        mipmap: true
        property bool hasFailed: false

        visible: !hasFailed && status === Image.Ready

        onStatusChanged: {
            if (status === Image.Error) {
                // Try next candidate
                if (root.currentCandidateIndex + 1 < root.candidates.length) {
                    root.currentCandidateIndex += 1;
                    srcImage.source = root.candidates[root.currentCandidateIndex];
                } else {
                    hasFailed = true;
                }
            } else if (status === Image.Ready) {
                hasFailed = false;
            }
        }
    }

    Text {
        id: fontIconLabel
        anchors.centerIn: parent
        visible: srcImage.hasFailed || root.candidates.length === 0
        text: root.getSmartFontIcon()
        font.family: ThemeBackend.fontFamily
        font.pixelSize: root.iconSize * 0.7
        color: root.fallbackColor
    }
}
