import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../components" as Components

Item {
    id: root
    width: layoutWidth || 900
    height: layoutHeight || 700

    property real layoutWidth: 900
    property real layoutHeight: 700
    
    MatugenColors { id: theme }
    Scaler { id: scaler; currentWidth: root.width }
    function s(val) { return scaler.s(val); }

    ListModel { id: servicesModel }
    ListModel { id: filteredModel }

    property string searchQuery: ""

    function updateFilter() {
        filteredModel.clear();
        let q = searchQuery.toLowerCase().trim();
        for (let i = 0; i < servicesModel.count; i++) {
            let item = servicesModel.get(i);
            if (q === "" || item.name.toLowerCase().includes(q) || item.desc.toLowerCase().includes(q) || item.unit.toLowerCase().includes(q)) {
                filteredModel.append(item);
            }
        }
    }

    onSearchQueryChanged: updateFilter()

    function fetchServices() {
        Components.QsDaemonClient.sendRequest("services", "list", {}, function(data) {
            if (!data) return;
            try {
                servicesModel.clear();
                for (let i = 0; i < data.length; i++) {
                    servicesModel.append(data[i]);
                }
                updateFilter();
            } catch (e) {
                console.log("Error handling services list: ", e);
            }
        });
    }

    function controlService(action, unit, isUser) {
        Components.QsDaemonClient.sendRequest("services", "control", {
            command: action,
            unit: unit,
            is_user: isUser
        }, function(res) {
            root.fetchServices();
        });
    }

    Component.onCompleted: root.fetchServices()
    onVisibleChanged: {
        if (visible) {
            root.fetchServices();
            searchField.forceActiveFocus();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.85)
        border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.1)
        border.width: s(1)
        radius: s(24)
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: s(24)
            spacing: s(20)

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰒓 Services Dashboard"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.pixelSize: s(28)
                    color: theme.text
                    Layout.fillWidth: true
                }
                
                Rectangle {
                    width: s(44); height: s(44); radius: s(12)
                    color: hoverRefresh.containsMouse ? theme.surface1 : theme.surface0
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: s(24)
                        color: theme.text
                    }
                    MouseArea {
                        id: hoverRefresh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchServices()
                    }
                }
            }

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                height: s(56)
                color: theme.surface0
                radius: s(14)
                border.color: searchField.activeFocus ? theme.mauve : "transparent"
                border.width: s(1)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: s(12)
                    spacing: s(12)
                    Text {
                        text: "󰍉"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: s(20)
                        color: searchField.activeFocus ? theme.mauve : theme.subtext0
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search services..."
                        font.family: "JetBrains Mono"
                        font.pixelSize: s(18)
                        color: theme.text
                        background: null
                        onTextChanged: root.searchQuery = text
                        
                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = "";
                            } else {
                                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/scripts/qs_manager.sh", "close"]);
                            }
                        }
                    }
                }
            }

            // List
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: filteredModel
                clip: true
                spacing: s(10)
                
                delegate: Rectangle {
                    width: listView.width
                    height: s(84)
                    radius: s(18)
                    color: itemHover.containsMouse ? theme.surface0 : "transparent"
                    border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05)
                    border.width: s(1)
                    
                    MouseArea { id: itemHover; anchors.fill: parent; hoverEnabled: true }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: s(18)
                        spacing: s(20)

                        // Status indicator
                        Rectangle {
                            width: s(14); height: s(14); radius: s(7)
                            color: model.active === "active" ? theme.green : (model.active === "failed" ? theme.red : theme.subtext0)
                        }

                        // Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: s(4)
                            RowLayout {
                                Text {
                                    text: model.name
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: s(20)
                                    color: theme.text
                                }
                                Rectangle {
                                    Layout.leftMargin: s(8)
                                    color: model.is_user ? Qt.alpha(theme.blue, 0.1) : Qt.alpha(theme.mauve, 0.1)
                                    radius: s(6)
                                    width: userText.implicitWidth + s(14); height: userText.implicitHeight + s(6)
                                    Text {
                                        id: userText
                                        anchors.centerIn: parent
                                        text: model.is_user ? "USER" : "SYSTEM"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: s(12)
                                        color: model.is_user ? theme.blue : theme.mauve
                                    }
                                }
                            }
                            Text {
                                text: model.desc
                                font.family: "JetBrains Mono"
                                font.pixelSize: s(14)
                                color: theme.subtext0
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Actions
                        RowLayout {
                            spacing: s(10)
                            
                            component ActionBtn: Rectangle {
                                property string iconTxt: ""
                                property string actionName: ""
                                property color baseColor: theme.surface1
                                width: s(40); height: s(40); radius: s(20)
                                color: btnArea.containsMouse ? Qt.lighter(baseColor, 1.1) : baseColor
                                Text { anchors.centerIn: parent; text: parent.iconTxt; font.family: "Iosevka Nerd Font"; font.pixelSize: s(20); color: theme.text }
                                MouseArea {
                                    id: btnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.controlService(parent.actionName, model.unit, model.is_user);
                                    }
                                }
                            }

                            ActionBtn { 
                                visible: model.active !== "active"
                                iconTxt: "󰐊"
                                actionName: "start"
                                baseColor: Qt.alpha(theme.green, 0.15)
                            }
                            ActionBtn { 
                                visible: model.active === "active"
                                iconTxt: "󰏤"
                                actionName: "stop"
                                baseColor: Qt.alpha(theme.red, 0.15)
                            }
                            ActionBtn { 
                                visible: model.active === "active" || model.active === "failed"
                                iconTxt: "󰑐"
                                actionName: "restart"
                                baseColor: Qt.alpha(theme.yellow, 0.15)
                            }
                        }
                    }
                }
            }
        }
    }
}




