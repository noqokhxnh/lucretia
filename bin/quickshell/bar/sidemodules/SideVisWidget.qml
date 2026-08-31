import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: sideVisRoot

    property var barWindow
    property var paths
    property bool isSolid: false
    property bool moduleActive: true
    property bool isGrouped: false
    property real targetY: 0
    property int barCount: 12

    y: targetY

    color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.width: (isGrouped || isSolid) ? 0 : 1
    border.color: (isGrouped || isSolid) ? "transparent" : ThemeBackend.surface0
    clip: true

    property real targetHeight: barWindow ? barWindow.s(110) : 110
    property real targetWidth: barWindow ? barWindow.barHeight : 40

    width: targetWidth
    height: targetHeight

    property var barLevels: {
        let source = Cava.barLevels;
        let count = barCount;
        let out = [];
        if (!source || source.length === 0) {
            for (let i = 0; i < count; i++) out.push(0.0);
            return out;
        }
        for (let i = 0; i < count; i++) {
            let norm = count > 1 ? (i / (count - 1)) : 0;
            let srcIdx = Math.min(source.length - 1, Math.floor(Math.pow(norm, 1.4) * (source.length - 1)));
            let val = source[srcIdx] || 0.0;
            out.push(val < 0.04 ? 0.0 : Math.pow((val - 0.04) / 0.96, 1.25));
        }
        return out;
    }

    Column {
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(3) : 3

        Repeater {
            model: sideVisRoot.barCount
            delegate: Rectangle {
                height: barWindow ? barWindow.s(4) : 4
                property real level: (sideVisRoot.barLevels && index < sideVisRoot.barLevels.length) ? sideVisRoot.barLevels[index] : 0.0
                property real minW: barWindow ? barWindow.s(4) : 4
                property real maxW: sideVisRoot.width * 0.7
                width: Math.max(minW, level * maxW)
                radius: height * 0.5
                color: ThemeBackend.mauve
                opacity: 0.45 + (level * 0.55)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
