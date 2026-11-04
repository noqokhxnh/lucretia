import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

RowLayout {
    id: bottomHeader
    required property var root
    property alias bottomSectionSwitch: bottomSectionSwitch

    Layout.fillWidth: true
    spacing: root.s(8)

    Switch {
        id: bottomSectionSwitch
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(180)
        implicitHeight: root.s(26)
        implicitWidth: root.s(180)
        options: [
            typeof I18n !== "undefined" ? I18n.t("music.equalizer") : "Equalizer",
            typeof I18n !== "undefined" ? I18n.t("music.audio.title") : "Audio"
        ]
        currentIndex: root.bottomSectionIndex
        accentColor: ThemeBackend.mauve || "#cba6f7"
        baseColor: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity || 0.85)
        textColor: ThemeBackend.subtext0 || "#a6adc8"
        activeTextColor: ThemeBackend.base || "#1e1e2e"
        cornerRadius: ThemeBackend.borderRadius
        fontPixelSize: root.s(11.5)
        onCurrentIndexChanged: {
            root.bottomSectionIndex = currentIndex;
            if (currentIndex !== 1 && root.audioTestRunning) {
                root.toggleAudioTest();
            }
        }
        onToggled: index => {
            currentIndex = index;
        }
    }

    Item { Layout.fillWidth: true }

    ClickButton {
        id: audioTestBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(76)
        visible: root.bottomSectionIndex === 1
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(8)
        buttonIcon: root.audioTestRunning ? "󰓛" : "󰋋"
        buttonText: root.audioTestRunning
            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.stop_test") : "Stop")
            : (typeof I18n !== "undefined" ? I18n.t("music.audio.test") : "Test")
        textFontSize: root.s(11.5)
        iconFontSize: root.s(12)
        accentColor: root.audioTestRunning
            ? (ThemeBackend.mauve || "#cba6f7")
            : (ThemeBackend.surface0 || "#313244")
        textColor: root.audioTestRunning
            ? (ThemeBackend.base || "#1e1e2e")
            : (ThemeBackend.text || "#cdd6f4")
        onClicked: root.toggleAudioTest()
    }

    ClickButton {
        id: dynamicEqBtn
        readonly property bool dynamicOn: !!root.eqData && root.eqData.dyneq === true
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(104)
        visible: root.bottomSectionIndex === 0
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(8)
        contentAlignment: Qt.AlignLeft
        buttonText: typeof I18n !== "undefined" ? I18n.t("music.eq.dynamic") : "Dynamic"
        textFontSize: root.s(11.5)
        accentColor: dynamicOn
            ? Qt.alpha(ThemeBackend.mauve || "#cba6f7", 0.25)
            : (ThemeBackend.surface0 || "#313244")
        textColor: dynamicOn
            ? (ThemeBackend.mauve || "#cba6f7")
            : (ThemeBackend.text || "#cdd6f4")
        onClicked: root.setAudioFlag("dyneq", !dynamicOn)

        Rectangle {
            id: dynamicIndicator
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.s(6)
            width: root.s(26)
            height: root.s(14)
            radius: height / 2
            color: dynamicEqBtn.dynamicOn ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface2 || "#585b70")
            Behavior on color { ColorAnimation { duration: 180 } }

            Rectangle {
                width: parent.height - root.s(4)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: dynamicEqBtn.dynamicOn ? parent.width - width - root.s(2) : root.s(2)
                color: dynamicEqBtn.dynamicOn ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.subtext0 || "#a6adc8")
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    ClickButton {
        id: actionBtn
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: root.s(72)
        cornerRadius: ThemeBackend.borderRadius
        horizontalPadding: root.s(10)
        buttonIcon: root.bottomSectionIndex === 1 ? "󰑐" : ""
        buttonText: {
            if (root.bottomSectionIndex === 1) {
                return typeof I18n !== "undefined" ? I18n.t("music.audio.reset") : "Reset";
            }
            return (root.eqData && root.eqData.pending) ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved");
        }
        textFontSize: root.s(11.5)
        iconFontSize: root.s(12)
        accentColor: {
            if (root.bottomSectionIndex === 1) {
                return ThemeBackend.surface0 || "#313244";
            }
            return (root.eqData && root.eqData.pending) ? (ThemeBackend.mauve || "#cba6f7") : (ThemeBackend.surface1 || "#45475a");
        }
        textColor: {
            if (root.bottomSectionIndex === 1) {
                return ThemeBackend.text || "#cdd6f4";
            }
            return (root.eqData && root.eqData.pending) ? (ThemeBackend.base || "#1e1e2e") : (ThemeBackend.subtext0 || "#a6adc8");
        }
        enabled: {
            if (root.bottomSectionIndex === 1) {
                return Math.abs(Number((root.eqData && root.eqData.balance) || 0)) >= 0.005
                    || (root.eqData && root.eqData.mono === true)
                    || (root.eqData && root.eqData.swap === true)
                    || String((root.eqData && root.eqData.dynamics) || "off") !== "off";
            }
            return (root.eqData && root.eqData.pending) && !(root.eqData && root.eqData.dyneq === true);
        }
        opacity: enabled ? 1.0 : 0.5
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onClicked: {
            if (root.bottomSectionIndex === 1) {
                root.resetAudio();
            } else if (root.eqData && root.eqData.pending) {
                var temp = Object.assign({}, root.eqData);
                temp.pending = false;
                root.eqData = temp;
                root.savedEqData = Object.assign({}, temp);
                root.lastEqUpdate = Date.now();
                root.triggerEqLightning();
                root.execCmd(Caching.qsDir + "/media/equalizer.sh apply");
            }
        }
    }

    Item {
        id: presetTextContainer
        Layout.preferredHeight: root.s(26)
        Layout.preferredWidth: presetLabelText.implicitWidth + root.s(8)
        visible: root.bottomSectionIndex === 0
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: presetLabelText
            anchors.verticalCenter: parent.verticalCenter
            text: (root.eqData && root.eqData.preset) ? I18n.t("music.presets." + root.eqData.preset.toLowerCase()) : I18n.t("music.presets.flat")
            color: ThemeBackend.subtext0 || "#a6adc8"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            font.bold: true
        }
    }
}
