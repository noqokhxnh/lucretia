import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    
    // Core Signals
    signal clicked()
    signal pressAndHold()
    
    // Content Properties
    property string text: ""
    property string icon: ""
    
    // State Aliases
    property alias isHovered: ma.containsMouse
    
    // Font Properties
    property int iconSize: 18
    property int textSize: 13
    property string iconFont: "Iosevka Nerd Font"
    property string textFont: "JetBrains Mono"
    property int textWeight: Font.Black
    
    // Colors
    property color baseColor: "transparent"
    property color hoverColor: "#1affffff"
    property color textColor: "#ffffff"
    property color iconColor: "#ffffff"
    
    // Active State Colors
    property bool isActive: false
    property color activeColor: "#20ffffff"
    property color activeTextColor: "#ffffff"
    property color activeIconColor: "#ffffff"

    // Optional border
    property color borderColor: "transparent"
    border.color: borderColor
    border.width: borderColor !== "transparent" ? 1 : 0
    
    // Layout and Shape
    radius: height / 2 // Default pill shape
    
    // Dynamic State Colors
    color: isActive ? activeColor : (ma.containsMouse ? hoverColor : baseColor)
    
    // Animations
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

    // Press Effect
    scale: ma.pressed ? 0.9 : 1.0

    // Content Layout
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        visible: root.text !== "" || root.icon !== ""
        
        Text {
            visible: root.icon !== ""
            font.family: root.iconFont
            font.pixelSize: root.iconSize
            color: root.isActive ? root.activeIconColor : root.iconColor
            text: root.icon
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        
        Text {
            visible: root.text !== ""
            font.family: root.textFont
            font.weight: root.textWeight
            font.pixelSize: root.textSize
            color: root.isActive ? root.activeTextColor : root.textColor
            text: root.text
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // Interaction Area
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
}
