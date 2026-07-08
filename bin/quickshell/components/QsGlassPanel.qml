import QtQuick

Rectangle {
    id: root

    // Core Properties
    property bool isActive: false
    property bool isHovered: false
    property bool enableHover: true

    // Colors
    property color activeColor: "#20ffffff"
    property color defaultColor: "#05ffffff"
    property color hoverColor: "#0affffff"
    
    property color activeBorderColor: "#30ffffff"
    property color defaultBorderColor: "#1affffff"

    // Default Glass Styling
    color: isActive ? activeColor : (enableHover && isHovered ? hoverColor : defaultColor)
    border.color: isActive ? activeBorderColor : defaultBorderColor
    border.width: isActive ? 2 : 1
    
    // Default Radius (Override when instantiated)
    radius: 14 

    // Smooth Transitions
    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on border.color { ColorAnimation { duration: 300 } }
}
