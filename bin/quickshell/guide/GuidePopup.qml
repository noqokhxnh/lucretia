import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../singletons"
import "../reusables"

Item {
    id: root
    focus: true

    property int activationCounter: 0

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active) {
            activationCounter++;
        }
    }
    property var appPaths: Caching
    function closePopup() { closeSequence.start() }

    function s(val) {
        return Scaler.s(val);
    }

    function gotoTab(tabName) {
        if (tabName === undefined || tabName === null || tabName === "") return;
        let num = parseInt(tabName);
        if (!isNaN(num) && num >= 0 && num < tabsModel.length) {
            currentTab = num;
            return;
        }
        let lower = String(tabName).toLowerCase();
        let idx = tabsModel.findIndex(t => 
            t.id.toLowerCase() === lower || 
            t.name.toLowerCase() === lower || 
            t.key.toLowerCase() === lower
        );
        if (idx !== -1) currentTab = idx;
    }

    function resetAndPlayIntro() {
        introBase = 0.0;
        introSidebar = 0.0;
        introContent = 0.0;
        startupSequence.restart();
        Updater.checkUpdate();
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            startupSequence.stop();
            closeSequence.stop();
            introBase = 0.0;
            introSidebar = 0.0;
            introContent = 0.0;
            if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                Sounds.stopSfx(root.chargingSoundHandle);
                root.chargingSoundHandle = -1;
            }
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Keys.onEscapePressed: (event) => {
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onTabPressed: (event) => {
        currentTab = (currentTab + 1) % tabsModel.length;
        event.accepted = true;
    }
    Keys.onBacktabPressed: (event) => {
        currentTab = (currentTab - 1 + tabsModel.length) % tabsModel.length;
        event.accepted = true;
    }

    property real colorBlend: 0.0
    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }

    property color ambientPurple: Qt.tint(ThemeBackend.mauve, Qt.rgba(ThemeBackend.pink.r, ThemeBackend.pink.g, ThemeBackend.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(ThemeBackend.blue, Qt.rgba(ThemeBackend.sapphire.r, ThemeBackend.sapphire.g, ThemeBackend.sapphire.b, colorBlend))
    property int chargingSoundHandle: -1

    property int currentTab: 0

    onCurrentTabChanged: {
        Quickshell.execDetached(["bash", "-c", "echo " + currentTab + " > '" + Caching.getCacheDir("guide") + "/last_tab.txt'"]);
    }

    FileView {
        id: lastTabWatcher
        path: Caching.getCacheDir("guide") + "/last_tab.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") root.gotoTab(val);
            } catch(e) {}
        }
    }

    property var tabsModel: [
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "WelcomeTab.qml" },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "general/GeneralTab.qml"},
        { id: "Display", key: "display", name: "Display", icon: "󰃠", file: "DisplayTab.qml" },
        { id: "Bar", key: "bar", name: "Bar", icon: "󰹑", file: "BarTab.qml" },
        { id: "Launcher", key: "launcher", name: "Launcher", icon: "󰵆", file: "LauncherTab.qml" },
        { id: "Theme", key: "theme", name: "Theme", icon: "✦", file: "theme/ThemeTab.qml"},
        { id: "Notifications", key: "notifications", name: "Notifications", icon: "󰂚", file: "notifications/NotificationsTab.qml" },
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "IdleTab.qml" },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", file: "wellbeing/DigitalWellbeingTab.qml" },
        { id: "About", key: "about", name: "About", icon: "", file: "AboutTab.qml" }
    ]

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    property var tutorialSections: []

    FileView {
        id: tutorialWatcher
        path: Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/tutorial.json") : ""
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                if (Array.isArray(data)) {
                    root.tutorialSections = data;
                }
            } catch(e) {}
        }
    }

    ParallelAnimation {
        id: startupSequence
        running: false
        NumberAnimation {
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 900
            easing.type: Easing.OutExpo
        }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation {
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: 1800
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation {
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 1100
                easing.type: Easing.OutBack
                easing.overshoot: 1.02
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction {
            script: {
                if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(root.chargingSoundHandle);
                    root.chargingSoundHandle = -1;
                }
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "introContent"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introSidebar"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
        }
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"])
        }
    }

    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base
            border.color: ThemeBackend.surface0

            property real time: 0
            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: root.visible
            }


            Rectangle {
                id: sidebar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.s(260)
                
                topLeftRadius: ThemeBackend.clampedBorderRadius
                bottomLeftRadius: ThemeBackend.clampedBorderRadius
                topRightRadius: 8
                bottomRightRadius: 8
                
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.color: ThemeBackend.surface1
                border.width: 1
                opacity: introSidebar
                transform: Translate { x: root.s(-30) * (1.0 - introSidebar) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(15)
                    spacing: root.s(10)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.tabsModel.length * root.s(44)

                        Rectangle {
                            id: activeHighlight
                            width: parent.width
                            height: root.s(44)
                            radius: ThemeBackend.borderRadius
                            color: ThemeBackend.mauve
                            z: 0

                            property int curIdx: root.currentTab
                            property real targetY: curIdx * root.s(44)
                            y: targetY

                            Behavior on y {
                                NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                            }
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: root.tabsModel

                                Rectangle {
                                    id: tabItem
                                    width: parent.width
                                    height: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    property bool isActive: root.currentTab === index
                                    color: isActive ? "transparent" : (tabMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent")

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    scale: tabMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(15) + (tabItem.isActive ? root.s(6) : 0)
                                        anchors.rightMargin: root.s(15)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        Item {
                                            Layout.preferredWidth: root.s(24)
                                            Layout.alignment: Qt.AlignVCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: root.s(18)
                                                color: tabItem.isActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs." + modelData.key)
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabItem.isActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabItem.isActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.currentTab = index;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    ClickButton {
                        visible: Updater.updateAvailable
                        Layout.fillWidth: true
                        implicitHeight: root.s(38)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: I18n.t("guide.update_available")
                        buttonIcon: "󰚰"
                        iconFontSize: root.s(16)
                        textFontSize: root.s(13)
                        accentColor: ThemeBackend.green
                        textColor: ThemeBackend.crust
                        onClicked: {
                            root.gotoTab("about");
                        }
                    }
                }
            }

            Item {
                id: contentArea
                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: root.s(10)

                opacity: introContent
                scale: 0.95 + (0.05 * introContent)
                transform: Translate { y: root.s(20) * (1.0 - introContent) }

                Repeater {
                    id: contentRepeater
                    model: root.tabsModel
                    delegate: Loader {
                        id: tabItemLoader
                        anchors.fill: parent
                        asynchronous: false
                        visible: root.currentTab === index

                        function ensureLoaded() {
                            if (status === Loader.Null) {
                                setSource(modelData.file, {
                                    "rootObj": root,
                                    "tabIndex": index
                                })
                            }
                        }

                        Component.onCompleted: {
                            if (index === root.currentTab) ensureLoaded()
                        }

                        Connections {
                            target: root
                            function onCurrentTabChanged() {
                                if (root.currentTab === index) tabItemLoader.ensureLoaded()
                            }
                        }
                    }
                }
            }
        }
    }
}
