import QtQuick

Item {
    id: root
    anchors.fill: parent

    property color color1: "transparent"
    property color color2: "transparent"
    property real opacity1: 0.08
    property real opacity2: 0.06
    property real orbitScale: 1.0

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: root.visible
    }

    Rectangle {
        width: parent.width * 0.8; height: width; radius: width / 2
        x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * (150 * root.orbitScale)
        y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * (100 * root.orbitScale)
        opacity: root.opacity1
        color: root.color1
        Behavior on color { ColorAnimation { duration: 1000 } }
    }
    
    Rectangle {
        width: parent.width * 0.9; height: width; radius: width / 2
        x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * (-150 * root.orbitScale)
        y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * (-100 * root.orbitScale)
        opacity: root.opacity2
        color: root.color2
        Behavior on color { ColorAnimation { duration: 1000 } }
    }
}
