import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../components" as Components
Item {
    id: window
    focus: true

    Caching { id: paths }

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    MatugenColors { id: _theme }
    
    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue

    property var allClips: []
    
    // Pagination properties
    property int currentOffset: 0
    property int fetchLimit: 24 
    property bool isLoading: false
    property bool hasMore: true
    
    // Global state
    property int navDuration: 0
    property bool previewMode: false
    property bool previewAnimationDone: false
    property string fullTextPreview: ""
    property int pendingIndex: -1

    property real layoutWidth: width
    property real layoutHeight: height

    // Startup state to prevent accordion layout shifts
    property bool isInitialLoad: true

    onPreviewModeChanged: {
        if (!previewMode) {
            fullTextPreview = "";
            previewAnimationDone = false;
        }
    }

    function fetchClips() {
        window.isLoading = true;
        Components.QsDaemonClient.sendRequest("clipboard", "fetch", {
            offset: window.currentOffset,
            limit: window.fetchLimit,
            cache_dir: paths.getCacheDir("clipboard")
        }, function(newItems) {
            try {
                if (newItems && Array.isArray(newItems)) {
                    if (newItems.length < window.fetchLimit) {
                        window.hasMore = false;
                    }
                    
                    if (window.currentOffset === 0) {
                        let isDifferent = window.allClips.length !== newItems.length;
                        if (!isDifferent) {
                            for (let i = 0; i < newItems.length; i++) {
                                if (window.allClips[i].id !== newItems[i].id || window.allClips[i].pinned !== newItems[i].pinned) {
                                    isDifferent = true;
                                    break;
                                }
                            }
                        }

                        if (isDifferent || window.allClips.length === 0) {
                            window.allClips = newItems;
                            window.filterClips(searchInput.text);
                        }
                    } else {
                        window.appendClips(newItems);
                    }
                }
            } catch(e) {
                console.log("Error handling fetched clipboard items: ", e);
            } finally {
                window.isLoading = false;
                window.isInitialLoad = false;
            }
        });
    }

    function updatePreviewText() {
        window.fullTextPreview = "";
        let item = clipModel.get(clipList.currentIndex);
        if (item && item.type === "text") {
            Components.QsDaemonClient.sendRequest("clipboard", "decode", {
                item_id: item.id.toString()
            }, function(text) {
                window.fullTextPreview = text || "";
            });
        }
    }

    ListModel {
        id: clipModel
    }

    function loadMore() {
        if (isLoading || !hasMore) return;
        isLoading = true;
        currentOffset += fetchLimit;
        window.fetchClips();
    }

    function appendClips(newItems) {
        let q = searchInput.text.toLowerCase();
        for (let i = 0; i < newItems.length; i++) {
            allClips.push(newItems[i]);
            if (q === "" || newItems[i].type === "image" || newItems[i].content.toLowerCase().includes(q)) {
                clipModel.append(newItems[i]);
            }
        }
        
        if (window.pendingIndex !== -1) {
            if (window.pendingIndex < clipModel.count) {
                clipList.currentIndex = window.pendingIndex;
            } else {
                clipList.currentIndex = clipModel.count - 1;
            }
            window.pendingIndex = -1;
        }
    }

    function filterClips(query) {
        clipList.currentIndex = -1;
        clipList.positionViewAtBeginning();

        let q = query.toLowerCase();
        clipModel.clear();

        for (let i = 0; i < allClips.length; i++) {
            if (allClips[i].type === "image" || allClips[i].content.toLowerCase().includes(q)) {
                clipModel.append(allClips[i]);
            }
        }

        if (clipModel.count > 0) {
            clipList.currentIndex = 0;
        }
    }

    function togglePin(id) {
        console.log("Toggling pin for ID:", id);
        Components.QsDaemonClient.sendRequest("clipboard", "toggle-pin", {
            item_id: id.toString(),
            cache_dir: paths.getCacheDir("clipboard")
        }, function(res) {
            window.currentOffset = 0;
            window.fetchClips();
        });
    }

    function deleteItem(id, content, type) {
        console.log("Deleting item ID:", id);
        Components.QsDaemonClient.sendRequest("clipboard", "delete", {
            item_id: id.toString()
        }, function(res) {
            window.currentOffset = 0;
            window.fetchClips();
        });
    }

    function copyToClipboard(id) {
        Quickshell.execDetached(["bash", "-c", "cliphist decode " + id + " | wl-copy"]);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/scripts/qs_manager.sh", "close"]);
    }

    Timer {
        id: focusTimer
        interval: 50
        running: true
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    function initialize() {
        if (window.allClips.length === 0) {
            window.isInitialLoad = true;
        }

        focusTimer.restart();
        introPhaseAnim.restart();
        window.navDuration = 0; 
        window.previewMode = false;
        window.previewAnimationDone = false;
        window.fullTextPreview = "";
        window.pendingIndex = -1;
        
        window.currentOffset = 0;
        window.hasMore = true;
        window.isLoading = true;
        window.fetchClips();
    }

    function cleanup() {
        searchInput.text = "";
        window.pendingIndex = -1;
        
        window.filterClips("");
        if (clipModel.count > 0) {
            clipList.currentIndex = 0;
            clipList.positionViewAtBeginning();
        }
    }

    Component.onCompleted: {
        if (window.visible) {
            initialize();
        }
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                window.initialize();
            } else {
                window.cleanup();
            }
        }
    }



    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 600; easing.type: Easing.OutExpo; running: true 
    }

    Rectangle {
        id: mainBg
        width: layoutWidth
        
        property real searchHeight: window.s(65)
        property real separatorHeight: 1
        
        property int cols: 3
        property real cellH: window.s(145) 
        
        property real maxVisibleRows: 4 
        property real visibleRows: maxVisibleRows
        property real animatedListHeight: visibleRows * cellH
        property real animatedMargins: window.s(20)

        height: searchHeight + separatorHeight + animatedMargins + animatedListHeight

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window.s(16)
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 1.0)
        border.color: window.surface1
        border.width: 1
        clip: true

        transform: Translate { y: (window.introPhase - 1) * window.s(60) }
        opacity: window.introPhase

        OrbitBackground {
            color1: window.mauve
            color2: window.blue
            orbitScale: window.s(1)
        }

        Rectangle {
            id: headerArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: mainBg.searchHeight
            color: "transparent"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: window.s(15)
                anchors.leftMargin: window.s(20)
                anchors.rightMargin: window.s(20)
                spacing: window.s(15)

                Item {
                    width: window.s(18)
                    height: window.s(18)

                    Text {
                        anchors.centerIn: parent
                        text: "󰅌"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: searchInput.activeFocus ? window.mauve : window.subtext0
                        
                        opacity: !window.previewMode ? 1 : 0
                        scale: !window.previewMode ? 1 : 0.5
                        rotation: !window.previewMode ? 0 : -90
                        
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰈈"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: window.s(18)
                        color: window.mauve
                        
                        opacity: window.previewMode ? 1 : 0
                        scale: window.previewMode ? 1 : 0.5
                        rotation: window.previewMode ? 0 : 90
                        
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    }
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: Item {} 
                    color: window.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(16)
                    
                    placeholderText: "Search"
                    placeholderTextColor: window.subtext0 
                    
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true

                    onTextChanged: {
                        if (window.previewMode) { window.previewMode = false; }
                        window.pendingIndex = -1;
                        filterClips(text);
                    }

                    Keys.onTabPressed: {
                        if (clipModel.count > 0) {
                            window.previewMode = !window.previewMode;
                            if (window.previewMode) {
                                window.updatePreviewText();
                            }
                        }
                        event.accepted = true;
                    }

                    Keys.onRightPressed: {
                        window.previewMode = false;
                        window.navDuration = 250; 
                        window.pendingIndex = -1;
                        
                        let targetIdx = clipList.currentIndex + 1;
                        if (targetIdx < clipModel.count) { 
                            clipList.currentIndex = targetIdx; 
                        } else if (window.hasMore) {
                            window.pendingIndex = targetIdx;
                            window.loadMore();
                        }
                        event.accepted = true;
                    }
                    
                    Keys.onLeftPressed: {
                        window.previewMode = false;
                        window.navDuration = 250;
                        window.pendingIndex = -1;
                        
                        if (clipList.currentIndex > 0) { clipList.currentIndex--; }
                        event.accepted = true;
                    }
                    
                    Keys.onDownPressed: {
                        if (window.previewMode && textPreviewFlickable.visible) {
                            textPreviewFlickable.contentY = Math.min(textPreviewFlickable.contentY + window.s(60), Math.max(0, textPreviewFlickable.contentHeight - textPreviewFlickable.height));
                        } else {
                            window.previewMode = false;
                            window.navDuration = 250;
                            window.pendingIndex = -1;
                            
                            let targetIdx = clipList.currentIndex + mainBg.cols;
                            if (targetIdx < clipModel.count) {
                                clipList.currentIndex = targetIdx;
                            } else if (window.hasMore) {
                                window.pendingIndex = targetIdx;
                                window.loadMore();
                            } else {
                                clipList.currentIndex = clipModel.count - 1;
                            }
                        }
                        event.accepted = true;
                    }
                    
                    Keys.onUpPressed: {
                        if (window.previewMode && textPreviewFlickable.visible) {
                            textPreviewFlickable.contentY = Math.max(textPreviewFlickable.contentY - window.s(60), 0);
                        } else {
                            window.previewMode = false;
                            window.navDuration = 250;
                            window.pendingIndex = -1;
                            
                            if (clipList.currentIndex - mainBg.cols >= 0) { clipList.currentIndex -= mainBg.cols; }
                        }
                        event.accepted = true;
                    }
                    
                    Keys.onReturnPressed: {
                        if (clipList.currentIndex >= 0 && clipList.currentIndex < clipModel.count) {
                            copyToClipboard(clipModel.get(clipList.currentIndex).id);
                        }
                        event.accepted = true;
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            if (clipList.currentIndex >= 0) {
                                togglePin(clipModel.get(clipList.currentIndex).id);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete) {
                            if (clipList.currentIndex >= 0) {
                                let item = clipModel.get(clipList.currentIndex);
                                deleteItem(item.id, item.content, item.type);
                            }
                            event.accepted = true;
                        }
                    }
                    
                    Keys.onEscapePressed: {
                        if (window.previewMode) {
                            window.previewMode = false;
                        } else {
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/niri/scripts/qs_manager.sh", "close"]);
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            id: separatorLine
            anchors.top: headerArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: mainBg.separatorHeight
            color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5)
        }

        GridView {
            id: clipList
            anchors.top: separatorLine.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: mainBg.animatedMargins / 2
            anchors.bottomMargin: mainBg.animatedMargins / 2
            anchors.leftMargin: window.s(10)
            anchors.rightMargin: window.s(10)
            height: mainBg.animatedListHeight
            
            clip: true
            model: clipModel

            cellWidth: Math.floor((mainBg.width - window.s(20)) / mainBg.cols)
            cellHeight: mainBg.cellH
            
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds

            highlightFollowsCurrentItem: false

            populate: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 1; duration: 0 }
            }
            
            add: Transition {
                id: addTrans
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PropertyAction { property: "scale"; value: 0.8 }
                    PauseAnimation { duration: 10 }
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 1; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                }
            }
            
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutExpo }
            }
            
            onContentYChanged: {
                if (contentY + height >= contentHeight - window.s(80)) {
                    window.loadMore();
                }
            }

            Behavior on contentY {
                enabled: window.navDuration > 0
                NumberAnimation { duration: 250; easing.type: Easing.OutExpo }
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && clipList.model !== null) {
                    if (currentIndex >= clipModel.count - (mainBg.cols * 2)) {
                        window.loadMore();
                    }
                    
                    let row = Math.floor(currentIndex / mainBg.cols);
                    let targetTop = row * mainBg.cellH;
                    let targetBottom = targetTop + mainBg.cellH;

                    if (window.navDuration > 0) {
                        if (targetTop < contentY) {
                            contentY = targetTop;
                        } else if (targetBottom > contentY + height) {
                            contentY = targetBottom - height;
                        }
                    } else {
                        positionViewAtIndex(currentIndex, GridView.Contain);
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                active: true
                policy: ScrollBar.AsNeeded
                
                background: Rectangle {
                    implicitWidth: window.s(12)
                    color: "transparent"
                }

                contentItem: Item {
                    implicitWidth: window.s(12)
                    
                    Rectangle {
                        anchors.centerIn: parent
                        height: parent.height
                        width: (scrollBar.hovered || scrollBar.active) ? window.s(8) : window.s(4)
                        radius: width / 2
                        
                        color: (scrollBar.hovered || scrollBar.active) ? window.mauve : window.surface2
                        opacity: (scrollBar.hovered || scrollBar.active) ? 0.9 : 0.4

                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }
                }
            }


            highlight: Item {
                z: 0 
                Rectangle {
                    id: activeHighlight
                    width: clipList.cellWidth - window.s(10)
                    height: clipList.cellHeight - window.s(10)
                    radius: window.s(8)
                    color: window.mauve

                    property int curIdx: clipList.currentIndex
                    property real targetX: curIdx === -1 || clipList.model === null ? 0 : (curIdx % mainBg.cols) * clipList.cellWidth
                    property real targetY: curIdx === -1 || clipList.model === null ? 0 : Math.floor(curIdx / mainBg.cols) * clipList.cellHeight

                    Behavior on x { NumberAnimation { duration: window.navDuration > 0 ? window.navDuration : 350; easing.type: Easing.OutExpo } }
                    Behavior on y { NumberAnimation { duration: window.navDuration > 0 ? window.navDuration : 350; easing.type: Easing.OutExpo } }

                    x: targetX + window.s(5)
                    y: targetY + window.s(5)
                    opacity: clipList.count > 0 && clipList.currentIndex >= 0 && clipList.model !== null ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

            delegate: Item {
                id: delegateRoot
                width: clipList.cellWidth
                height: clipList.cellHeight
                
                z: index === clipList.currentIndex ? 50 : 1
                
                Rectangle {
                    id: cardBg
                    x: window.s(5)
                    y: window.s(5)
                    width: parent.width - window.s(10)
                    height: parent.height - window.s(10)
                    
                    radius: window.s(8)
                    
                    color: ma.containsMouse && index !== clipList.currentIndex ? Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.4) : "transparent"
                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutSine } }

                    Rectangle {
                        z: 2
                        x: window.s(8)
                        y: window.s(8)
                        width: window.s(22)
                        height: window.s(22)
                        radius: window.s(6)
                        
                        color: index === clipList.currentIndex ? window.crust : Qt.rgba(window.surface0.r, window.surface0.g, window.surface0.b, 0.85)
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.pinned ? "󰐃" : (index + 1)
                            font.family: model.pinned ? "Iosevka Nerd Font" : "JetBrains Mono"
                            font.pixelSize: model.pinned ? window.s(14) : window.s(11)
                            font.weight: Font.Bold
                            color: model.pinned ? window.blue : (index === clipList.currentIndex ? window.mauve : window.text)
                        }
                    }

                    // Action buttons overlay
                    Row {
                        z: 3
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: window.s(6)
                        spacing: window.s(4)
                        opacity: ma.containsMouse || index === clipList.currentIndex ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Components.QsButton {
                            width: window.s(24)
                            height: window.s(24)
                            radius: window.s(6)
                            baseColor: window.surface1
                            hoverColor: window.surface2
                            isActive: index === clipList.currentIndex
                            activeColor: window.crust
                            
                            icon: model.pinned ? "󰐃" : "󰐁"
                            iconSize: window.s(14)
                            iconColor: model.pinned ? window.blue : window.text
                            activeIconColor: model.pinned ? window.blue : window.text

                            onClicked: togglePin(model.id)
                        }

                        Components.QsButton {
                            width: window.s(24)
                            height: window.s(24)
                            radius: window.s(6)
                            baseColor: window.surface1
                            hoverColor: window.surface2
                            isActive: index === clipList.currentIndex
                            activeColor: window.crust
                            
                            icon: "󰆴"
                            iconSize: window.s(14)
                            iconColor: "#f38ba8" // red
                            activeIconColor: "#f38ba8" // red

                            onClicked: deleteItem(model.id, model.content, model.type)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: window.s(4)
                        visible: model.type === "image"
                        color: "transparent"
                        radius: window.s(6)
                        clip: true
                        
                        Image {
                            anchors.fill: parent
                            source: model.type === "image" ? "file://" + model.content : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true 
                            cache: true
                            smooth: true
                            mipmap: true
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: window.s(12)
                        anchors.topMargin: window.s(36)
                        visible: model.type === "text"
                        clip: true

                        Text {
                            id: contentText
                            anchors.fill: parent
                            text: model.content
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(13)
                            font.weight: index === clipList.currentIndex ? Font.Bold : Font.Medium
                            color: index === clipList.currentIndex ? window.base : window.text
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignTop
                            maximumLineCount: 4 
                            
                            property real textShift: index === clipList.currentIndex ? window.s(4) : 0
                            transform: Translate { x: contentText.textShift }
                            Behavior on textShift { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutExpo } }
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: !window.previewMode
                        enabled: !window.previewMode
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            window.navDuration = 250;
                            clipList.currentIndex = index;
                            
                            if (mouse.button === Qt.RightButton) {
                                window.previewMode = true;
                                window.updatePreviewText();
                            } else {
                                copyToClipboard(model.id);
                            }
                        }
                    }
                }
            }
        }

        // FULL SCREEN PREVIEW OVERLAY
        Rectangle {
            id: previewMorph
            z: 100
            
            property var curItem: clipList.currentIndex >= 0 && clipModel.count > 0 ? clipModel.get(clipList.currentIndex) : null
            property int curIdx: clipList.currentIndex !== -1 ? clipList.currentIndex : 0
            
            property real gridX: window.s(10)
            property real gridY: mainBg.searchHeight + mainBg.separatorHeight + mainBg.animatedMargins / 2
            property real gridW: mainBg.width - window.s(20)
            property real gridH: mainBg.animatedListHeight
            
            property real startX: gridX + (curIdx % mainBg.cols) * clipList.cellWidth + window.s(5)
            property real startY: gridY + Math.floor(curIdx / mainBg.cols) * clipList.cellHeight - clipList.contentY + window.s(5)
            property real startW: clipList.cellWidth - window.s(10)
            property real startH: clipList.cellHeight - window.s(10)
            
            color: window.crust
            border.color: window.mauve
            border.width: window.previewMode ? window.s(2) : 0
            Behavior on border.width { NumberAnimation { duration: 150 } }
            clip: true
            
            Image {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: window.s(20)
                
                source: (previewMorph.curItem && previewMorph.curItem.type === "image") ? "file://" + previewMorph.curItem.content : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true 
                visible: previewMorph.curItem && previewMorph.curItem.type === "image"
                
                opacity: window.previewMode ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150;  } }
            }
            
            Flickable {
                id: textPreviewFlickable
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: window.s(20)
                
                contentWidth: width
                contentHeight: textPreviewContent.paintedHeight
                clip: true
                
                Behavior on contentY { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                
                visible: previewMorph.curItem && previewMorph.curItem.type === "text"
                opacity: window.previewMode ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150;  } }
                
                TextEdit {
                    id: textPreviewContent
                    width: parent.width
                    
                    text: {
                        if (!window.previewMode || !previewMorph.curItem || previewMorph.curItem.type !== "text") return "";
                        
                        if (window.fullTextPreview !== "") {
                            if (!window.previewAnimationDone && window.fullTextPreview.length > 3000) {
                                return window.fullTextPreview.substring(0, 3000);
                            }
                            return window.fullTextPreview;
                        }
                        
                        return previewMorph.curItem.content; 
                    }
                    
                    color: window.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                    selectionColor: window.surface2
                    selectedTextColor: window.mauve
                }
            }
            
            states: [
                State {
                    name: "hidden"
                    when: !window.previewMode
                    PropertyChanges { 
                        target: previewMorph; 
                        opacity: 0; 
                        x: previewMorph.startX; 
                        y: previewMorph.startY; 
                        width: previewMorph.startW; 
                        height: previewMorph.startH; 
                        radius: window.s(8) 
                    }
                },
                State {
                    name: "visible"
                    when: window.previewMode
                    PropertyChanges { 
                        target: previewMorph; 
                        opacity: 1; 
                        x: previewMorph.gridX; 
                        y: previewMorph.gridY; 
                        width: previewMorph.gridW; 
                        height: previewMorph.gridH; 
                        radius: window.s(12) 
                    }
                }
            ]
            
            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: previewMorph; property: "opacity"; duration: 50 } 
                            NumberAnimation { properties: "x,y,width,height,radius"; duration: 300; easing.type: Easing.OutExpo } 
                        }
                        ScriptAction { script: { window.previewAnimationDone = true; } }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    ParallelAnimation {
                        NumberAnimation { properties: "x,y,width,height,radius"; duration: 250; easing.type: Easing.OutExpo } 
                        SequentialAnimation {
                            PauseAnimation { duration: 150 }
                            NumberAnimation { target: previewMorph; property: "opacity"; to: 0; duration: 100 }
                        }
                    }
                }
            ]
        }
    }
}
