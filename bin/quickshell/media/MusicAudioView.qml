import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/guide"

Item {
    id: audioView
    required property var root
    property alias balanceSlider: balanceSlider

    Layout.fillWidth: true
    Layout.preferredHeight: contentCol.implicitHeight

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        spacing: root.s(8)

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(82)
            radius: ThemeBackend.borderRadius
            color: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity || 0.85)
            border.color: Qt.alpha(ThemeBackend.surface1 || "#45475a", 0.5)
            border.width: root.s(1)

            Item {
                id: balanceControl
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: root.s(14)
                anchors.rightMargin: root.s(14)
                anchors.topMargin: root.s(5)
                height: root.s(45)
                opacity: (root.eqData && root.eqData.mono === true) ? 0.45 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        x: index * (balanceControl.width - width) / 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.s(index === 4 ? 3 : 2)
                        height: root.s(index === 4 ? 33 : (index % 2 === 0 ? 25 : 18))
                        radius: width / 2
                        color: ThemeBackend.subtext1 || "#bac2de"
                        opacity: index === 4 ? 0.7 : 0.32
                    }
                }

                Slider {
                    id: balanceSlider
                    anchors.fill: parent
                    from: -1.0
                    to: 1.0
                    stepSize: 0.01
                    value: Number((root.eqData && root.eqData.balance) || 0)
                    hoverEnabled: true
                    enabled: !(root.eqData && root.eqData.mono === true)
                    readonly property real trackHeight: root.s(14)
                    readonly property real handleSize: root.s(22)

                    Connections {
                        target: root
                        function onEqDataChanged() {
                            if (!balanceSlider.pressed) {
                                var nextBalance = Number((root.eqData && root.eqData.balance) || 0);
                                if (!isNaN(nextBalance)) balanceSlider.value = nextBalance;
                            }
                        }
                    }

                    onPressedChanged: {
                        if (!pressed) root.setBalance(value);
                    }

                    background: Rectangle {
                        x: balanceSlider.leftPadding
                        y: balanceSlider.topPadding + balanceSlider.availableHeight / 2 - height / 2
                        width: balanceSlider.availableWidth
                        height: balanceSlider.trackHeight
                        radius: height / 2
                        color: Qt.alpha(ThemeBackend.surface2 || "#585b70", ThemeBackend.elementOpacity || 0.7)
                        clip: true

                        Item {
                            property real handleCenter: balanceSlider.handleSize / 2 + balanceSlider.visualPosition * (parent.width - balanceSlider.handleSize)
                            x: Math.min(parent.width / 2, handleCenter)
                            width: Math.abs(handleCenter - parent.width / 2)
                            height: parent.height
                            clip: true
                            opacity: width > 0.5 ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Rectangle {
                                id: balanceFillRect
                                x: balanceSlider.value < 0 ? 0 : -height / 2
                                width: parent.width + height / 2
                                height: parent.height
                                radius: height / 2

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: balanceSlider.value < 0 ? Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.10) : (ThemeBackend.mauve || "#cba6f7") }
                                    GradientStop { position: 0.5; color: Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.05) }
                                    GradientStop { position: 1.0; color: balanceSlider.value < 0 ? (ThemeBackend.mauve || "#cba6f7") : Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.10) }
                                }
                            }
                        }
                    }

                    handle: Rectangle {
                        id: balanceHandle
                        x: balanceSlider.leftPadding + balanceSlider.visualPosition * (balanceSlider.availableWidth - width)
                        y: balanceSlider.topPadding + balanceSlider.availableHeight / 2 - height / 2
                        width: balanceSlider.handleSize
                        height: balanceSlider.handleSize
                        radius: height / 2
                        color: balanceSlider.pressed
                            ? Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.30)
                            : (balanceSlider.hovered ? Qt.lighter(ThemeBackend.mauve || "#cba6f7", 1.15) : (ThemeBackend.mauve || "#cba6f7"))
                        scale: balanceSlider.pressed ? 1.25 : (balanceSlider.hovered ? 1.12 : 1.0)

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.s(14)
                anchors.rightMargin: root.s(14)
                anchors.bottomMargin: root.s(9)

                Text {
                    text: "L  " + Math.round((balanceSlider.value > 0 ? 1 - balanceSlider.value : 1) * 100) + "%"
                    color: ThemeBackend.subtext0 || "#a6adc8"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11.5)
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.abs(balanceSlider.value) >= 0.995
                        ? (balanceSlider.value < 0
                            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.left_only") : "Left only")
                            : (typeof I18n !== "undefined" ? I18n.t("music.audio.right_only") : "Right only"))
                        : (Math.abs(balanceSlider.value) < 0.005
                            ? (typeof I18n !== "undefined" ? I18n.t("music.audio.centered") : "Centered")
                            : (Math.abs(balanceSlider.value) < 0.25
                                ? (balanceSlider.value < 0
                                    ? (typeof I18n !== "undefined" ? I18n.t("music.audio.left_slightly_favored") : "Slightly left favored")
                                    : (typeof I18n !== "undefined" ? I18n.t("music.audio.right_slightly_favored") : "Slightly right favored"))
                                : (balanceSlider.value < 0
                                    ? (typeof I18n !== "undefined" ? I18n.t("music.audio.left_favored") : "Left favored")
                                    : (typeof I18n !== "undefined" ? I18n.t("music.audio.right_favored") : "Right favored"))))
                    color: ThemeBackend.mauve || "#cba6f7"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11.5)
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.round((balanceSlider.value < 0 ? 1 + balanceSlider.value : 1) * 100) + "%  R"
                    color: ThemeBackend.subtext0 || "#a6adc8"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11.5)
                    font.bold: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(8)

            Repeater {
                model: [
                    { key: "mono", label: typeof I18n !== "undefined" ? I18n.t("music.audio.mono") : "Mono audio" },
                    { key: "swap", label: typeof I18n !== "undefined" ? I18n.t("music.audio.swap") : "Swap L/R" }
                ]

                delegate: SettingsRow {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    rootObj: root
                    color: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity || 0.85)
                    border.color: Qt.alpha(ThemeBackend.surface1 || "#45475a", 0.5)
                    border.width: root.s(1)
                    radius: ThemeBackend.borderRadius
                    title: modelData.label
                    titlePixelSize: root.s(12)
                    titleBold: true
                    verticalPadding: root.s(9)
                    searchable: false

                    Toggle {
                        id: audioFlagToggle
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: root.s(44)
                        Layout.preferredHeight: root.s(24)
                        horizontalPadding: 0
                        checked: root.eqData && root.eqData[modelData.key] === true
                        accentColor: ThemeBackend.mauve || "#cba6f7"
                        baseColor: Qt.alpha(ThemeBackend.surface2 || "#585b70", ThemeBackend.elementOpacity || 0.8)
                        handleColor: ThemeBackend.base || "#1e1e2e"
                        handleOffColor: ThemeBackend.text || "#cdd6f4"
                        onToggled: checked => root.setAudioFlag(modelData.key, checked)

                        Connections {
                            target: root
                            function onEqDataChanged() {
                                audioFlagToggle.checked = root.eqData && root.eqData[modelData.key] === true;
                            }
                        }
                    }
                }
            }
        }

        SettingsRow {
            Layout.fillWidth: true
            rootObj: root
            color: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity || 0.85)
            border.color: Qt.alpha(ThemeBackend.surface1 || "#45475a", 0.5)
            border.width: root.s(1)
            radius: ThemeBackend.borderRadius
            title: typeof I18n !== "undefined" ? I18n.t("music.audio.dynamic_range") : "Dynamic range"
            titlePixelSize: root.s(12)
            titleBold: true
            verticalPadding: root.s(9)
            searchable: false

            Switch {
                id: dynamicsSwitch
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: root.s(210)
                Layout.preferredHeight: root.s(28)
                options: [
                    typeof I18n !== "undefined" ? I18n.t("music.audio.off") : "Off",
                    typeof I18n !== "undefined" ? I18n.t("music.audio.balanced") : "Balanced",
                    typeof I18n !== "undefined" ? I18n.t("music.audio.night") : "Night"
                ]
                currentIndex: String((root.eqData && root.eqData.dynamics) || "off") === "night" ? 2
                    : (String((root.eqData && root.eqData.dynamics) || "off") === "balanced" ? 1 : 0)
                accentColor: ThemeBackend.mauve || "#cba6f7"
                baseColor: Qt.alpha(ThemeBackend.surface2 || "#585b70", ThemeBackend.elementOpacity || 0.8)
                textColor: ThemeBackend.subtext0 || "#a6adc8"
                activeTextColor: ThemeBackend.base || "#1e1e2e"
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: root.s(10.5)
                onToggled: index => root.setDynamics(index === 2 ? "night" : (index === 1 ? "balanced" : "off"))

                Connections {
                    target: root
                    function onEqDataChanged() {
                        var value = String((root.eqData && root.eqData.dynamics) || "off");
                        dynamicsSwitch.currentIndex = value === "night" ? 2 : (value === "balanced" ? 1 : 0);
                    }
                }
            }
        }
    }
}
