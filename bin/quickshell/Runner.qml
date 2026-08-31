import QtQuick
import Quickshell
import "."

Scope {
    id: runnerRoot

    property string targetFile: Quickshell.env("LUCRETIA_TARGET_FILE") || Quickshell.env("SERPANTINUM_TARGET_FILE") || ""

    Loader {
        active: runnerRoot.targetFile !== ""
        source: runnerRoot.targetFile
    }
}
