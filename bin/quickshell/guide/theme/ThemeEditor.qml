import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../"
import "../../reusables"

Popup {
    id: themeEditorPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: 620
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property real tileWidth: 180
    property var colorKeys: [
        { key: "base",      label: I18n.t("guide.theme_editor.colors.base") },
        { key: "mantle",    label: I18n.t("guide.theme_editor.colors.mantle") },
        { key: "crust",     label: I18n.t("guide.theme_editor.colors.crust") },
        { key: "text",      label: I18n.t("guide.theme_editor.colors.text") },
        { key: "subtext0",  label: I18n.t("guide.theme_editor.colors.sub0") },
        { key: "subtext1",  label: I18n.t("guide.theme_editor.colors.sub1") },
        { key: "surface0",  label: I18n.t("guide.theme_editor.colors.surf0") },
        { key: "surface1",  label: I18n.t("guide.theme_editor.colors.surf1") },
        { key: "surface2",  label: I18n.t("guide.theme_editor.colors.surf2") },
        { key: "overlay0",  label: I18n.t("guide.theme_editor.colors.over0") },
        { key: "overlay1",  label: I18n.t("guide.theme_editor.colors.over1") },
        { key: "overlay2",  label: I18n.t("guide.theme_editor.colors.over2") },
        { key: "blue",      label: I18n.t("guide.theme_editor.colors.blue") },
        { key: "lavender",  label: I18n.t("guide.theme_editor.colors.lavender") },
        { key: "sapphire",  label: I18n.t("guide.theme_editor.colors.sapphire") },
        { key: "sky",       label: I18n.t("guide.theme_editor.colors.sky") },
        { key: "teal",      label: I18n.t("guide.theme_editor.colors.teal") },
        { key: "green",     label: I18n.t("guide.theme_editor.colors.green") },
        { key: "yellow",    label: I18n.t("guide.theme_editor.colors.yellow") },
        { key: "peach",     label: I18n.t("guide.theme_editor.colors.peach") },
        { key: "maroon",    label: I18n.t("guide.theme_editor.colors.maroon") },
        { key: "red",       label: I18n.t("guide.theme_editor.colors.red") },
        { key: "mauve",     label: I18n.t("guide.theme_editor.colors.mauve") },
        { key: "pink",      label: I18n.t("guide.theme_editor.colors.pink") },
        { key: "flamingo",  label: I18n.t("guide.theme_editor.colors.flamingo") },
        { key: "rosewater", label: I18n.t("guide.theme_editor.colors.rosewater") }
    ]

    property var editColors: ({})
    property string editingKey: ""
    property string themeName: ""

    signal saveRequested(var themeObj)

    Connections {
        target: themeEditorPopup.rootObj ? themeEditorPopup.rootObj : null
        function onVisibleChanged() {
            if (themeEditorPopup.rootObj && !themeEditorPopup.rootObj.visible) {
                themeEditorPopup.close();
            }
        }
    }

    Connections {
        target: themeEditorPopup.parent && themeEditorPopup.parent !== themeEditorPopup.rootObj ? themeEditorPopup.parent : null
        function onVisibleChanged() {
            if (themeEditorPopup.parent && !themeEditorPopup.parent.visible) {
                themeEditorPopup.close();
            }
        }
    }

    function openForNew() {
        themeName = "";
        let defaults = {};
        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i].key;
            defaults[k] = ThemeBackend[k] !== undefined ? Qt.color(ThemeBackend[k]).toString() : "#ffffff";
        }
        editColors = defaults;
        editingKey = "base";
        open();
    }

    function hexOf(c) {
        if (!c) return "";
        return Qt.color(c).toString().toUpperCase();
    }

    background: Rectangle {
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.mantle
        border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text { text: I18n.t("guide.theme_editor.title"); color: ThemeBackend.text; font.pixelSize: 16; font.weight: Font.Bold; Layout.fillWidth: true }
            IconButton {
                width: 30
                height: 30
                cornerRadius: 10
                buttonIcon: "󰅖"
                iconFontSize: 14
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: themeEditorPopup.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Input {
                Layout.fillWidth: true
                Layout.minimumWidth: 150
                Layout.preferredHeight: 44
                text: themeEditorPopup.themeName
                placeholderText: I18n.t("guide.theme_editor.name_placeholder")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: 14
                charSpacing: 1
                onTextEdited: newText => themeEditorPopup.themeName = newText
            }

            Rectangle {
                Layout.preferredWidth: themeEditorPopup.tileWidth
                Layout.maximumWidth: themeEditorPopup.tileWidth
                Layout.preferredHeight: 44
                radius: ThemeBackend.borderRadius
                color: themeEditorPopup.editColors.base || ThemeBackend.base
                border.color: Qt.alpha(themeEditorPopup.editColors.text || ThemeBackend.text, 0.3)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 6

                    Text {
                        text: themeEditorPopup.themeName || I18n.t("guide.theme_editor.preview")
                        color: themeEditorPopup.editColors.text || ThemeBackend.text
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4
                        Repeater {
                            model: [themeEditorPopup.editColors.text, themeEditorPopup.editColors.blue, themeEditorPopup.editColors.mauve,
                                    themeEditorPopup.editColors.peach, themeEditorPopup.editColors.green, themeEditorPopup.editColors.red]
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData || "transparent" }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            GridLayout {
                Layout.alignment: Qt.AlignTop
                columns: 6
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: themeEditorPopup.colorKeys
                    delegate: ColumnLayout {
                        spacing: 4
                        Rectangle {
                            Layout.preferredWidth: 44; Layout.preferredHeight: 32
                            radius: 6
                            color: themeEditorPopup.editColors[modelData.key] || "#000000"
                            border.width: themeEditorPopup.editingKey === modelData.key ? 2 : 1
                            border.color: themeEditorPopup.editingKey === modelData.key ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.subtext0, 0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: themeEditorPopup.editingKey = (themeEditorPopup.editingKey === modelData.key ? "" : modelData.key)
                            }
                        }
                        Text { text: modelData.label; font.pixelSize: 10; color: ThemeBackend.subtext0; Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }

            ColumnLayout {
                id: pickerColumn
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 200
                visible: themeEditorPopup.editingKey !== ""
                spacing: 12

                property real hue: 0
                property real sat: 1.0
                property real val: 1.0

                Component.onCompleted: syncFromColor()
                onVisibleChanged: if (visible) syncFromColor()

                Connections {
                    target: themeEditorPopup
                    function onEditingKeyChanged() {
                        if (pickerColumn.visible) pickerColumn.syncFromColor()
                    }
                }

                function syncFromColor() {
                    let key = themeEditorPopup.editingKey;
                    if (!key) return;
                    let valStr = themeEditorPopup.editColors[key];
                    if (!valStr) return;
                    let c = Qt.color(valStr);
                    if (c.hsvHue >= 0) hue = c.hsvHue;
                    sat = c.hsvSaturation;
                    val = c.hsvValue;
                }

                Timer {
                    id: commitTimer
                    interval: 16
                    repeat: false
                    onTriggered: {
                        let c = Qt.hsva(pickerColumn.hue, pickerColumn.sat, pickerColumn.val, 1.0);
                        let updated = Object.assign({}, themeEditorPopup.editColors);
                        updated[themeEditorPopup.editingKey] = c.toString();
                        themeEditorPopup.editColors = updated;
                    }
                }

                function commit() {
                    commitTimer.restart()
                }

                Rectangle {
                    id: svSquare
                    Layout.fillWidth: true; Layout.preferredHeight: 160
                    color: Qt.hsva(pickerColumn.hue, 1, 1, 1)
                    radius: ThemeBackend.borderRadius
                    clip: true
                    Rectangle { anchors.fill: parent; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#ffffffff" } GradientStop { position: 1; color: "#00ffffff" } } }
                    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#ff000000" } } }
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        border.color: "white"; border.width: 2; color: "transparent"
                        x: svSquare.width * pickerColumn.sat - 7
                        y: svSquare.height * (1 - pickerColumn.val) - 7
                        scale: svHandleArea.pressed ? 1.2 : (svHandleArea.containsMouse ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "white"
                            opacity: svHandleArea.pressed ? 0.3 : (svHandleArea.containsMouse ? 0.1 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                    MouseArea {
                        id: svHandleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        function update(mx, my) {
                            pickerColumn.sat = Math.max(0, Math.min(1, mx / width));
                            pickerColumn.val = 1 - Math.max(0, Math.min(1, my / height));
                            pickerColumn.commit();
                        }
                        onPressed: mouse => update(mouse.x, mouse.y)
                        onPositionChanged: mouse => { if (pressed) update(mouse.x, mouse.y); }
                    }
                }

                Rectangle {
                    id: hueSlider
                    Layout.fillWidth: true; height: 16; radius: ThemeBackend.borderRadius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.000; color: "#ff0000" }
                        GradientStop { position: 0.166; color: "#ffff00" }
                        GradientStop { position: 0.333; color: "#00ff00" }
                        GradientStop { position: 0.500; color: "#00ffff" }
                        GradientStop { position: 0.666; color: "#0000ff" }
                        GradientStop { position: 0.833; color: "#ff00ff" }
                        GradientStop { position: 1.000; color: "#ff0000" }
                    }
                    Rectangle {
                        width: 10; height: parent.height + 4; radius: 5
                        border.color: "white"; border.width: 2; color: "transparent"
                        y: -2
                        x: hueSlider.width * pickerColumn.hue - 5
                        scale: hueHandleArea.pressed ? 1.15 : (hueHandleArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150 } }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "white"
                            opacity: hueHandleArea.pressed ? 0.3 : (hueHandleArea.containsMouse ? 0.1 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                    MouseArea {
                        id: hueHandleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        function update(mx) {
                            pickerColumn.hue = Math.max(0, Math.min(1, mx / width));
                            pickerColumn.commit();
                        }
                        onPressed: mouse => update(mouse.x)
                        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
                    }
                }

                Input {
                    Layout.fillWidth: true
                    text: themeEditorPopup.editColors[themeEditorPopup.editingKey] ? themeEditorPopup.hexOf(themeEditorPopup.editColors[themeEditorPopup.editingKey]) : ""
                    placeholderText: "#HEX"
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    charSpacing: 2
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: 14
                    onAccepted: finalText => {
                        let hex = finalText.startsWith("#") ? finalText : "#" + finalText;
                        if (/^#[0-9A-Fa-f]{6,8}$/.test(hex)) {
                            let updated = Object.assign({}, themeEditorPopup.editColors);
                            updated[themeEditorPopup.editingKey] = hex;
                            themeEditorPopup.editColors = updated;
                            pickerColumn.syncFromColor();
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 12
            Item { Layout.fillWidth: true }
            ClickButton {
                buttonText: I18n.t("guide.theme_editor.cancel")
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                cornerRadius: ThemeBackend.borderRadius
                onClicked: themeEditorPopup.close()
            }
            ClickButton {
                buttonText: I18n.t("guide.theme_editor.save")
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                onClicked: {
                    themeEditorPopup.saveRequested({
                        name: themeEditorPopup.themeName !== "" ? themeEditorPopup.themeName : I18n.t("guide.theme_editor.default_name"),
                        isMatugen: false,
                        isColorFocused: true,
                        isCustom: true,
                        category: "user",
                        colors: themeEditorPopup.editColors
                    });
                    themeEditorPopup.close();
                }
            }
        }
    }
}
