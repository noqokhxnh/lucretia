pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string i18nDir: Caching.serpantinumDir + "/assets/languages"
    property string currentLang: "en"
    property var translations: ({})
    property bool isReady: false

    signal languageChanged()

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gen = Config.getSetting("general", {});
            if (gen && gen.language && gen.language !== root.currentLang) {
                root.currentLang = gen.language;
                root.languageChanged();
            }
        }
    }

    Process {
        id: i18nLoader
        command: [
            "bash",
            "-c",
            `ls "${root.i18nDir}"/*.json >/dev/null 2>&1 && jq -n 'reduce inputs as $i ( {}; . + { ($i | input_filename | split("/") | last | rtrimstr(".json")): $i } )' "${root.i18nDir}"/*.json || echo "{}"`
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt && txt.length > 0) {
                        root.translations = JSON.parse(txt);
                    } else {
                        root.translations = {};
                    }
                } catch (e) {
                    root.translations = {};
                }
                root.isReady = true;
                root.languageChanged();
            }
        }
    }

    function t(key, args) {
        if (!root.isReady || !root.translations || !root.translations[root.currentLang]) return key;

        let parts = key.split('.');
        let current = root.translations[root.currentLang];

        for (let i = 0; i < parts.length; i++) {
            if (current === null || current === undefined || current[parts[i]] === undefined) {
                return key;
            }
            current = current[parts[i]];
        }

        if (typeof current !== "string") return key;

        if (args && typeof args === "object") {
            for (let k in args) {
                current = current.replace(new RegExp("\\{" + k + "\\}", "g"), args[k]);
            }
        }

        return current;
    }

    Component.onCompleted: {
        let gen = Config.getSetting("general", {});
        if (gen && gen.language) {
            root.currentLang = gen.language;
        }
    }
}
