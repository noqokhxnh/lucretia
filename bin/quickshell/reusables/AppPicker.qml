import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../"
import "../singletons"

Popup {
    id: pickerRoot
    parent: {
        if (rootObj) {
            return rootObj.contentItem ? rootObj.contentItem : rootObj;
        }
        return Overlay.overlay ? Overlay.overlay : undefined;
    }
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    z: 350000
    width: Scaler.s(720)
    height: Scaler.s(520)
    padding: Scaler.s(16)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property bool isMultiSelect: false
    property var selectedAppIds: []
    property string titleText: isMultiSelect ? (typeof I18n !== "undefined" ? I18n.t("widgets.picker.select_apps") : "Select Applications") : (typeof I18n !== "undefined" ? I18n.t("widgets.picker.select_app") : "Select Application")

    property real crLarge: ThemeBackend.borderRadius
    property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
    property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

    signal appSelected(string desktopId, string appName, string appIcon)
    signal appsSelected(var appIds)

    property var allAppsList: []
    property var filteredAppsList: []

    function loadApplications() {
        let entries = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications.values : [];
        let list = [];
        for (let i = 0; i < entries.length; i++) {
            let e = entries[i];
            if (e.noDisplay) continue;
            list.push({
                id: e.id,
                name: e.name || e.id.replace(".desktop", ""),
                icon: e.icon || "",
                comment: e.comment || "",
                exec: e.exec || ""
            });
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        allAppsList = list;
        filterApps(searchInput.text);
    }

    function filterApps(query) {
        let q = (query || "").trim().toLowerCase();
        if (q === "") {
            filteredAppsList = allAppsList;
            return;
        }
        let res = [];
        for (let i = 0; i < allAppsList.length; i++) {
            let app = allAppsList[i];
            if (app.name.toLowerCase().includes(q) || app.id.toLowerCase().includes(q) || app.comment.toLowerCase().includes(q)) {
                res.push(app);
            }
        }
        filteredAppsList = res;
    }

    function openPicker(initialIds, multi) {
        if (multi !== undefined) isMultiSelect = Boolean(multi);
        if (Array.isArray(initialIds)) {
            selectedAppIds = initialIds.slice();
        } else if (typeof initialIds === "string" && initialIds.trim() !== "") {
            try {
                let parsed = JSON.parse(initialIds);
                if (Array.isArray(parsed)) {
                    selectedAppIds = parsed;
                } else if (typeof parsed === "object" && parsed.id) {
                    selectedAppIds = [parsed.id];
                } else {
                    selectedAppIds = [initialIds.trim()];
                }
            } catch(e) {
                selectedAppIds = [initialIds.trim()];
            }
        } else {
            selectedAppIds = [];
        }
        searchInput.text = "";
        loadApplications();
        open();
        searchInput.forceActiveFocus();
    }

    function isSelected(id) {
        if (!Array.isArray(selectedAppIds)) return false;
        return selectedAppIds.indexOf(id) !== -1;
    }

    function toggleApp(id) {
        let copy = Array.isArray(selectedAppIds) ? selectedAppIds.slice() : [];
        let idx = copy.indexOf(id);
        if (idx !== -1) {
            copy.splice(idx, 1);
        } else {
            copy.push(id);
        }
        selectedAppIds = copy;
    }

    function removeSelected(id) {
        let copy = Array.isArray(selectedAppIds) ? selectedAppIds.slice() : [];
        let idx = copy.indexOf(id);
        if (idx !== -1) {
            copy.splice(idx, 1);
            selectedAppIds = copy;
        }
    }

    function confirmSelection() {
        if (isMultiSelect) {
            pickerRoot.appsSelected(selectedAppIds);
        }
        close();
    }

    background: Rectangle {
        color: ThemeBackend.base
        radius: pickerRoot.crLarge
        border.color: ThemeBackend.surface1
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
        }
    }

    contentItem: ColumnLayout {
        spacing: Scaler.s(12)

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: Scaler.s(10)

            Text {
                text: "󰀻"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(20)
                color: ThemeBackend.mauve
            }

            Text {
                text: pickerRoot.titleText
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(16)
                font.bold: true
                color: ThemeBackend.text
                Layout.fillWidth: true
            }

            ClickButton {
                visible: pickerRoot.isMultiSelect
                buttonText: (typeof I18n !== "undefined" ? I18n.t("widgets.redactor.done") : "Done") + " (" + (pickerRoot.selectedAppIds ? pickerRoot.selectedAppIds.length : 0) + ")"
                buttonIcon: "󰄬"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: pickerRoot.confirmSelection()
            }

            IconButton {
                size: Scaler.s(32)
                buttonIcon: "󰅖"
                iconFontSize: Scaler.s(14)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.subtext0
                onClicked: pickerRoot.close()
            }
        }

        // Search Box
        Input {
            id: searchInput
            Layout.fillWidth: true
            implicitHeight: Scaler.s(38)
            placeholderText: typeof I18n !== "undefined" ? I18n.t("search") || "Search applications..." : "Search applications..."
            leadingIcon: "󰍉"
            showClearButton: true
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.text
            cornerRadius: pickerRoot.crMedium
            onTextChanged: pickerRoot.filterApps(text)
        }

        // Selected Chips (For MultiSelect Mode)
        ScrollView {
            visible: pickerRoot.isMultiSelect && pickerRoot.selectedAppIds && pickerRoot.selectedAppIds.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: (pickerRoot.isMultiSelect && pickerRoot.selectedAppIds && pickerRoot.selectedAppIds.length > 0) ? Scaler.s(40) : 0
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            clip: true

            RowLayout {
                spacing: Scaler.s(6)

                Repeater {
                    model: pickerRoot.selectedAppIds || []

                    delegate: Rectangle {
                        id: chipRect
                        required property string modelData
                        implicitHeight: Scaler.s(32)
                        implicitWidth: chipRow.implicitWidth + Scaler.s(16)
                        radius: Scaler.s(16)
                        color: ThemeBackend.surface1
                        border.color: ThemeBackend.mauve
                        border.width: 1

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Scaler.s(6)

                            AppIcon {
                                width: Scaler.s(20)
                                height: Scaler.s(20)
                                appId: chipRect.modelData
                                appName: {
                                    let app = pickerRoot.allAppsList.find(a => a.id === chipRect.modelData);
                                    return app ? app.name : chipRect.modelData.replace(".desktop", "");
                                }
                                iconName: {
                                    let app = pickerRoot.allAppsList.find(a => a.id === chipRect.modelData);
                                    return app ? app.icon : "";
                                }
                            }

                            Text {
                                text: {
                                    let app = pickerRoot.allAppsList.find(a => a.id === chipRect.modelData);
                                    return app ? app.name : chipRect.modelData.replace(".desktop", "");
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(12)
                                color: ThemeBackend.text
                            }

                            Text {
                                text: "󰅖"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(11)
                                color: ThemeBackend.subtext0

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pickerRoot.removeSelected(chipRect.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // App List
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ListView {
                id: appsListView
                model: pickerRoot.filteredAppsList
                spacing: Scaler.s(4)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    required property int index
                    width: appsListView.width
                    height: Scaler.s(52)
                    radius: pickerRoot.crMedium
                    color: {
                        let sel = pickerRoot.isSelected(modelData.id);
                        if (sel) return Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2);
                        return mouseArea.containsMouse ? ThemeBackend.surface0 : "transparent";
                    }
                    border.color: pickerRoot.isSelected(modelData.id) ? ThemeBackend.mauve : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Scaler.s(12)
                        anchors.rightMargin: Scaler.s(12)
                        spacing: Scaler.s(12)

                        Rectangle {
                            width: Scaler.s(36)
                            height: Scaler.s(36)
                            radius: Scaler.s(8)
                            color: ThemeBackend.surface0

                            AppIcon {
                                anchors.centerIn: parent
                                width: Scaler.s(28)
                                height: Scaler.s(28)
                                appId: itemDelegate.modelData.id
                                appName: itemDelegate.modelData.name
                                iconName: itemDelegate.modelData.icon
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Scaler.s(2)

                            Text {
                                text: itemDelegate.modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(13)
                                font.bold: true
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: itemDelegate.modelData.comment !== "" ? itemDelegate.modelData.comment : itemDelegate.modelData.id
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(11)
                                color: ThemeBackend.subtext0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            visible: pickerRoot.isMultiSelect
                            width: Scaler.s(22)
                            height: Scaler.s(22)
                            radius: Scaler.s(6)
                            color: pickerRoot.isSelected(itemDelegate.modelData.id) ? ThemeBackend.mauve : ThemeBackend.surface1
                            border.color: pickerRoot.isSelected(itemDelegate.modelData.id) ? ThemeBackend.mauve : ThemeBackend.surface2
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: Scaler.s(13)
                                color: ThemeBackend.crust
                                visible: pickerRoot.isSelected(itemDelegate.modelData.id)
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pickerRoot.isMultiSelect) {
                                pickerRoot.toggleApp(itemDelegate.modelData.id);
                            } else {
                                pickerRoot.appSelected(itemDelegate.modelData.id, itemDelegate.modelData.name, itemDelegate.modelData.icon);
                                pickerRoot.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
