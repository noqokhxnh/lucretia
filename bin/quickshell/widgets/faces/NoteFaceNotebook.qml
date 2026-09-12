import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../reusables"
import "../../"
import "../../singletons"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 230
    property real minHeight: 200
    property real maxWidth: 900
    property real maxHeight: 1200
    property real minAspect: 0.5
    property real maxAspect: 2.6
    property bool isRound: false
    property bool wantsKeyboardFocus: true

    property string wImagePath: ""
    property string currentNoteId: ""
    readonly property string effectiveNoteId: {
        if (wImagePath && wImagePath !== "") return wImagePath;
        if (currentNoteId && currentNoteId !== "") return currentNoteId;
        return Notes.activeNoteId || "";
    }
    onWImagePathChanged: {
        if (wImagePath && wImagePath !== "") {
            currentNoteId = wImagePath;
        }
    }

    readonly property var currentNote: (Notes.revision, Notes.getNote(effectiveNoteId))
    readonly property var tasks: (Notes.revision, Notes.parseTasks(currentNote ? currentNote.content : ""))
    readonly property int totalTasks: {
        let count = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (tasks[i].isTask) count++;
        }
        return count;
    }
    readonly property int completedTasks: {
        let count = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (tasks[i].isTask && tasks[i].checked) count++;
        }
        return count;
    }
    readonly property real progress: totalTasks > 0 ? (completedTasks / totalTasks) : 0

    property real savedScrollY: 0
    property string pendingScrollAction: ""

    onTasksChanged: {
        if (pendingScrollAction === "end") {
            Qt.callLater(() => {
                taskListView.positionViewAtEnd();
                pendingScrollAction = "";
                savedScrollY = taskListView.contentY;
            });
        } else if (pendingScrollAction === "preserve" || savedScrollY > 0) {
            let targetY = savedScrollY;
            Qt.callLater(() => {
                let maxY = Math.max(0, taskListView.contentHeight - taskListView.height + taskListView.topMargin + taskListView.bottomMargin);
                taskListView.contentY = Math.min(maxY, Math.max(-taskListView.topMargin, targetY));
                pendingScrollAction = "";
            });
        }
    }

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    function getNoteTitle() {
        if (!currentNote || !currentNote.content) return I18n.t("widgets.types.note");
        let lines = currentNote.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let t = lines[i].trim().replace(/^#+\s*/, "").replace(/^[-*•]\s*(\[[ xXvV]\]\s*)?/, "").trim();
            if (t.length > 0) {
                return t.length > 20 ? (t.substring(0, 18) + "…") : t;
            }
        }
        return I18n.t("widgets.types.note");
    }

    // Colors tailored for notebook aesthetic
    readonly property bool isDark: ThemeBackend.isDark
    readonly property color paperBg: isDark ? Qt.rgba(0.12, 0.12, 0.16, 0.96) : Qt.rgba(0.98, 0.97, 0.94, 0.98)
    readonly property color spineBg: isDark ? Qt.rgba(0.09, 0.09, 0.12, 0.98) : Qt.rgba(0.92, 0.90, 0.85, 0.98)
    readonly property color marginLineColor: isDark ? Qt.rgba(0.92, 0.42, 0.48, 0.45) : Qt.rgba(0.88, 0.35, 0.40, 0.55)
    readonly property color ruledLineColor: isDark ? Qt.rgba(0.50, 0.65, 0.90, 0.16) : Qt.rgba(0.45, 0.60, 0.85, 0.26)
    readonly property color spiralWireColor: isDark ? Qt.rgba(0.70, 0.72, 0.80, 0.85) : Qt.rgba(0.55, 0.58, 0.65, 0.85)
    readonly property color spiralHoleColor: isDark ? Qt.rgba(0.05, 0.05, 0.07, 0.95) : Qt.rgba(0.78, 0.75, 0.70, 0.95)

    readonly property real spiralWidth: Math.max(22, s(28))
    readonly property real lineSpacing: Math.max(28, s(32))

    // Main Notebook Card
    Rectangle {
        id: notebookCard
        anchors.fill: parent
        radius: ThemeBackend.borderRadius * 1.5
        color: root.paperBg
        border.color: root.isDark ? Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.7) : Qt.rgba(0.82, 0.79, 0.74, 0.9)
        border.width: 1
        antialiasing: true
        clip: true

        // 1. Ruled Paper Background Canvas (Đường kẻ vở & Lề đỏ)
        Canvas {
            id: ruledCanvas
            anchors.fill: parent
            anchors.leftMargin: root.spiralWidth
            renderStrategy: Canvas.Immediate
            renderTarget: Canvas.Image

            Connections {
                target: ThemeBackend
                function onBaseChanged() { ruledCanvas.requestPaint(); }
                function onTextChanged() { ruledCanvas.requestPaint(); }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let w = width;
                let h = height;
                let spacing = root.lineSpacing;
                let marginX = Math.round(root.s(16));

                // Vertical Red Margin Line (Đường kẻ lề đỏ vở học sinh)
                ctx.beginPath();
                ctx.strokeStyle = root.marginLineColor.toString();
                ctx.lineWidth = 1.5;
                ctx.moveTo(marginX + 0.5, 0);
                ctx.lineTo(marginX + 0.5, h);
                ctx.stroke();

                // Horizontal Ruled Lines (Đường kẻ ngang)
                // Header offset so lines align nicely with tasks
                let startY = Math.round(root.s(42)) + 0.5;
                ctx.strokeStyle = root.ruledLineColor.toString();
                ctx.lineWidth = 1;

                for (let y = startY; y < h - root.s(36); y += spacing) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(w, y);
                    ctx.stroke();
                }
            }
        }

        // 2. Spiral Binder Left Spine (Gáy sổ & lò xo)
        Rectangle {
            id: spineStrip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.spiralWidth
            color: root.spineBg

            // Spine division line
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: root.isDark ? Qt.rgba(0.3, 0.3, 0.38, 0.4) : Qt.rgba(0.75, 0.72, 0.67, 0.7)
            }

            // Subtle drop shadow onto the paper
            Rectangle {
                anchors.left: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.s(6)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.isDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(0, 0, 0, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Spiral Loops Canvas (Punched holes & wire rings)
            Canvas {
                id: spiralCanvas
                anchors.fill: parent
                renderStrategy: Canvas.Immediate
                renderTarget: Canvas.Image

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: ThemeBackend
                    function onBaseChanged() { spiralCanvas.requestPaint(); }
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();
                    let w = width;
                    let h = height;
                    let loopSpacing = Math.max(22, root.s(26));
                    let holeX = w - root.s(7);
                    let holeR = Math.max(2.5, root.s(3.5));

                    for (let y = loopSpacing * 0.8; y < h - root.s(8); y += loopSpacing) {
                        let curY = Math.round(y);

                        // Punched hole
                        ctx.beginPath();
                        ctx.fillStyle = root.spiralHoleColor.toString();
                        ctx.arc(holeX, curY, holeR, 0, 2 * Math.PI);
                        ctx.fill();

                        // Spiral Wire Ring (Double wire / metallic look)
                        ctx.beginPath();
                        ctx.strokeStyle = root.spiralWireColor.toString();
                        ctx.lineWidth = Math.max(1.8, root.s(2.2));
                        ctx.lineCap = "round";
                        
                        // Curved wire loop coming from left edge into the punched hole
                        ctx.moveTo(root.s(3), curY - root.s(4));
                        ctx.bezierCurveTo(w - root.s(2), curY - root.s(6), w + root.s(4), curY - root.s(1), holeX, curY);
                        ctx.stroke();

                        // Second wire strand for spiral effect
                        ctx.beginPath();
                        ctx.strokeStyle = Qt.rgba(root.spiralWireColor.r, root.spiralWireColor.g, root.spiralWireColor.b, 0.6);
                        ctx.lineWidth = Math.max(1.2, root.s(1.6));
                        ctx.moveTo(root.s(3), curY - root.s(2));
                        ctx.bezierCurveTo(w - root.s(3), curY - root.s(4), w + root.s(3), curY, holeX, curY + 1);
                        ctx.stroke();
                    }
                }
            }
        }

        // 3. Main Content Area (Layout inside notebook page)
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.spiralWidth
            spacing: 0

            // Header Bar (Notebook Title, Note Switcher, Washi Tape & Actions)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(38, root.s(44))
                color: "transparent"

                // Washi Tape Decoration at Top
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: -root.s(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(root.s(84), parent.width * 0.3)
                    height: root.s(11)
                    radius: root.s(2)
                    color: Qt.alpha(ThemeBackend.mauve, 0.45)
                    rotation: -1.2
                    border.color: Qt.alpha(ThemeBackend.mauve, 0.6)
                    border.width: 1
                    antialiasing: true

                    // Washi tape subtle diagonal stripes
                    Canvas {
                        anchors.fill: parent
                        opacity: 0.35
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#ffffff";
                            ctx.lineWidth = 1.5;
                            for (let x = -10; x < width + 10; x += 6) {
                                ctx.beginPath();
                                ctx.moveTo(x, 0);
                                ctx.lineTo(x + 8, height);
                                ctx.stroke();
                            }
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.s(14)
                    anchors.rightMargin: root.s(10)
                    anchors.topMargin: root.s(4)
                    spacing: root.s(6)

                    // Notebook Bookmark Tag / Title
                    Rectangle {
                        Layout.preferredHeight: root.s(24)
                        Layout.maximumWidth: parent.width * 0.55
                        implicitWidth: titleRow.implicitWidth + root.s(12)
                        radius: root.s(6)
                        color: root.isDark ? Qt.rgba(ThemeBackend.surface1.r, ThemeBackend.surface1.g, ThemeBackend.surface1.b, 0.5) : Qt.rgba(0.90, 0.88, 0.82, 0.7)
                        border.color: root.isDark ? Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.4) : Qt.rgba(0.78, 0.75, 0.70, 0.6)
                        border.width: 1

                        RowLayout {
                            id: titleRow
                            anchors.centerIn: parent
                            spacing: root.s(4)

                            // Prev Note Button
                            IconButton {
                                size: root.s(18)
                                cornerRadius: root.s(4)
                                buttonIcon: "‹"
                                iconFontSize: root.s(12)
                                accentColor: "transparent"
                                textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                                visible: Notes.count > 1
                                onClicked: {
                                    root.savedScrollY = -taskListView.topMargin;
                                    root.pendingScrollAction = "top";
                                    let prev = Notes.prevNote(root.effectiveNoteId);
                                    if (prev) root.currentNoteId = prev.id;
                                }
                            }

                            Text {
                                text: "󰠮 " + root.getNoteTitle()
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                font.bold: true
                                color: ThemeBackend.text
                                elide: Text.ElideRight
                                Layout.maximumWidth: root.s(110)
                            }

                            // Next Note Button
                            IconButton {
                                size: root.s(18)
                                cornerRadius: root.s(4)
                                buttonIcon: "›"
                                iconFontSize: root.s(12)
                                accentColor: "transparent"
                                textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                                visible: Notes.count > 1
                                onClicked: {
                                    root.savedScrollY = -taskListView.topMargin;
                                    root.pendingScrollAction = "top";
                                    let next = Notes.nextNote(root.effectiveNoteId);
                                    if (next) root.currentNoteId = next.id;
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Progress Stamp Badge
                    Rectangle {
                        visible: root.totalTasks > 0
                        implicitWidth: progressText.implicitWidth + root.s(12)
                        implicitHeight: root.s(20)
                        radius: root.s(4)
                        color: root.completedTasks === root.totalTasks ? Qt.alpha(ThemeBackend.green, 0.22) : Qt.alpha(ThemeBackend.mauve, 0.18)
                        border.color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                        border.width: 1

                        Text {
                            id: progressText
                            anchors.centerIn: parent
                            text: "✓ " + root.completedTasks + "/" + root.totalTasks
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10)
                            font.bold: true
                            color: root.completedTasks === root.totalTasks ? ThemeBackend.green : ThemeBackend.mauve
                        }
                    }

                    // Open Full Notes Popup
                    IconButton {
                        size: root.s(24)
                        cornerRadius: root.s(6)
                        buttonIcon: "󰅂"
                        iconFontSize: root.s(13)
                        accentColor: "transparent"
                        textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.subtext0
                        onClicked: Notes.openNotesPopup(root.effectiveNoteId)
                    }
                }
            }

            // Divider under header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.ruledLineColor
            }

            // Task List (Aligned with notebook lines)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: taskListView
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(10)
                    spacing: 0
                    model: root.tasks
                    boundsBehavior: Flickable.StopAtBounds

                    onContentYChanged: {
                        if (root.pendingScrollAction === "" && (moving || dragging || flicking || contentY > 0)) {
                            root.savedScrollY = contentY;
                        }
                    }

                    delegate: Item {
                        id: taskDelegate
                        width: taskListView.width
                        height: root.lineSpacing

                        property bool isHovered: itemMouseArea.containsMouse

                        // Soft yellow highlighter effect on hover
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: root.s(3)
                            anchors.bottomMargin: root.s(3)
                            radius: root.s(4)
                            color: taskDelegate.isHovered ? (root.isDark ? Qt.rgba(0.98, 0.88, 0.45, 0.12) : Qt.rgba(0.98, 0.90, 0.35, 0.25)) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Heading Delegate (e.g. # Chapter / Section)
                        RowLayout {
                            visible: modelData.isHeading
                            anchors.fill: parent
                            anchors.leftMargin: root.s(6)
                            spacing: root.s(6)

                            Rectangle {
                                width: root.s(3)
                                height: root.s(14)
                                radius: 1.5
                                color: ThemeBackend.mauve
                            }

                            Text {
                                text: modelData.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(12)
                                font.bold: true
                                color: ThemeBackend.mauve
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        // Task Delegate
                        RowLayout {
                            id: taskRow
                            visible: !modelData.isHeading
                            anchors.fill: parent
                            anchors.leftMargin: root.s(6)
                            anchors.rightMargin: root.s(6)
                            spacing: root.s(8)

                            // Hand-drawn Style Checkbox
                            Rectangle {
                                id: checkboxBox
                                Layout.preferredWidth: root.s(16)
                                Layout.preferredHeight: root.s(16)
                                Layout.alignment: Qt.AlignVCenter
                                radius: root.s(4)
                                color: modelData.checked ? ThemeBackend.mauve : (checkboxMouseArea.containsMouse ? Qt.alpha(ThemeBackend.mauve, 0.15) : "transparent")
                                border.color: modelData.checked ? ThemeBackend.mauve : (checkboxMouseArea.containsMouse ? ThemeBackend.mauve : (root.isDark ? Qt.rgba(0.6, 0.6, 0.7, 0.6) : Qt.rgba(0.4, 0.45, 0.55, 0.6)))
                                border.width: 1.5
                                antialiasing: true

                                scale: checkboxMouseArea.pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(10)
                                    font.bold: true
                                    color: ThemeBackend.crust
                                    visible: modelData.checked
                                }

                                MouseArea {
                                    id: checkboxMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -root.s(4)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.savedScrollY = taskListView.contentY;
                                        root.pendingScrollAction = "preserve";
                                        Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                    }
                                }
                            }

                            // Task Text sitting on the ruled line
                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11.5)
                                font.strikeout: modelData.checked
                                color: modelData.checked ? ThemeBackend.overlay1 : ThemeBackend.text
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap

                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: textMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.savedScrollY = taskListView.contentY;
                                        root.pendingScrollAction = "preserve";
                                        Notes.toggleTask(root.effectiveNoteId, modelData.lineIndex);
                                    }
                                }
                            }

                            // Delete Button (appears on hover)
                            IconButton {
                                Layout.preferredWidth: root.s(18)
                                Layout.preferredHeight: root.s(18)
                                Layout.alignment: Qt.AlignVCenter
                                cornerRadius: root.s(4)
                                buttonIcon: "×"
                                iconFontSize: root.s(13)
                                accentColor: "transparent"
                                textColor: isHoveredOrHighlighted ? ThemeBackend.red : ThemeBackend.overlay0
                                opacity: taskDelegate.isHovered ? 1.0 : 0.0
                                visible: taskDelegate.isHovered
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                onClicked: {
                                    root.savedScrollY = taskListView.contentY;
                                    root.pendingScrollAction = "preserve";
                                    Notes.deleteTask(root.effectiveNoteId, modelData.lineIndex);
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }

                    // Empty State inside notebook
                    Item {
                        anchors.centerIn: parent
                        width: parent.width - root.s(24)
                        height: emptyCol.implicitHeight
                        visible: root.tasks.length === 0

                        ColumnLayout {
                            id: emptyCol
                            anchors.centerIn: parent
                            spacing: root.s(4)

                            Text {
                                text: "󰏫"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(26)
                                color: ThemeBackend.mauve
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: I18n.t("notes.no_tasks")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11.5)
                                font.bold: true
                                color: ThemeBackend.subtext0
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: I18n.t("notes.add_task")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(10)
                                color: ThemeBackend.overlay1
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Bottom Add Task Bar (Pencil Line on Paper)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(34, root.s(38))
                color: root.isDark ? Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.4) : Qt.rgba(0.92, 0.90, 0.85, 0.5)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: root.ruledLineColor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.s(12)
                    anchors.rightMargin: root.s(10)
                    spacing: root.s(8)

                    Text {
                        text: "󰏫"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(14)
                        color: addInput.activeFocus ? ThemeBackend.mauve : ThemeBackend.subtext0
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: addInput.forceActiveFocus()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: addInput.forceActiveFocus()
                        }

                        TextInput {
                            id: addInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                            color: ThemeBackend.text
                            clip: true
                            selectByMouse: true

                            Text {
                                text: I18n.t("notes.add_task")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: root.s(11)
                                color: ThemeBackend.overlay0
                                visible: addInput.text.length === 0 && !addInput.activeFocus
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Keys.onEscapePressed: {
                                addInput.focus = false;
                            }

                            onAccepted: {
                                if (text.trim().length > 0) {
                                    root.pendingScrollAction = "end";
                                    Notes.addTask(root.effectiveNoteId, text);
                                    text = "";
                                }
                            }
                        }
                    }

                    IconButton {
                        size: root.s(22)
                        cornerRadius: root.s(4)
                        buttonIcon: "↵"
                        iconFontSize: root.s(12)
                        accentColor: addInput.text.trim().length > 0 ? ThemeBackend.mauve : "transparent"
                        textColor: addInput.text.trim().length > 0 ? ThemeBackend.crust : ThemeBackend.overlay1
                        enabled: addInput.text.trim().length > 0
                        onClicked: {
                            if (addInput.text.trim().length > 0) {
                                root.pendingScrollAction = "end";
                                Notes.addTask(root.effectiveNoteId, addInput.text);
                                addInput.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
