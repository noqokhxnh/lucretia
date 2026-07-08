import QtQuick

Item {
    id: root
    
    // Core Value Properties
    property real value: 0
    property real from: 0
    property real to: 100
    
    // Status
    property bool isMuted: false
    property bool isDragging: false
    
    // Colors
    property color activeColor: "#ffffff"
    property color mutedColor: "#888888"
    property color trackColor: "#0dffffff"
    property color borderColor: "#1affffff"
    
    // Signals
    signal dragStarted()
    signal dragEnded()

    // Internal Track
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        border.color: root.borderColor
        border.width: 1
        clip: true

        // Progress Fill
        Rectangle {
            height: parent.height
            
            // Mathematically precise progress calculation
            property real progress: Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))
            width: parent.width * progress
            radius: parent.radius
            
            // Hover/Mute Opacity Rules
            opacity: root.isMuted ? 0.3 : (sliderMa.containsMouse ? 1.0 : 0.85)
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            // Disable animation during drag to ensure immediate 1:1 follow
            Behavior on width { 
                enabled: !root.isDragging 
                NumberAnimation { duration: 300; easing.type: Easing.OutQuint } 
            }

            // Smooth Horizontal Gradient
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { 
                    position: 0.0; 
                    color: root.isMuted ? root.mutedColor : root.activeColor
                    Behavior on color { ColorAnimation { duration: 300 } } 
                }
                GradientStop { 
                    position: 1.0; 
                    color: root.isMuted ? Qt.lighter(root.mutedColor, 1.15) : Qt.lighter(root.activeColor, 1.25)
                    Behavior on color { ColorAnimation { duration: 300 } } 
                }
            }
        }
    }
    
    // Interaction
    MouseArea {
        id: sliderMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onPressed: (mouse) => { 
            root.isDragging = true; 
            root.dragStarted();
            updateValue(mouse.x); 
        }
        
        onPositionChanged: (mouse) => { 
            if (pressed) updateValue(mouse.x); 
        }
        
        onReleased: { 
            root.isDragging = false; 
            root.dragEnded();
        }
        
        function updateValue(mx) {
            let progress = Math.max(0, Math.min(1, mx / width));
            let newValue = root.from + progress * (root.to - root.from);
            root.value = newValue;
        }
    }
}
