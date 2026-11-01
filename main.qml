import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

// ApplicationWindow is the main window container
ApplicationWindow {
    id: root
    visible: true
    width: 500
    height: 1050  // Increased height to accommodate telemetry box
    title: "ESP32-S3 LED Controller"
    color: "#0f0f1e"  // Dark background color
    
    // ==================== PROPERTIES ====================
    // Properties store state that can be bound to UI elements
    property int currentR: 0      // Current Red value (0-255)
    property int currentG: 0      // Current Green value (0-255)
    property int currentB: 0      // Current Blue value (0-255)
    property bool ledOn: false    // Whether LED is currently ON
    property string connectionStatus: "Disconnected"  // MQTT connection state
    property string qos0Log: "Waiting for data..."    // Telemetry log messages
    
    // ==================== CONNECTIONS ====================
    // Connections listen to signals from Python and update QML properties
    Connections {
        target: mqtt  // Connect to the MQTTBridge Python object
        
        // Called when connection status changes
        function onConnectionStatusChanged(status) { 
            root.connectionStatus = status 
        }
        
        // Called when LED ON/OFF state changes
        function onLedStatusChanged(isOn) { 
            root.ledOn = isOn
            // Update both switches to match the new state
            simpleToggle.checked = isOn
            rgbPowerSwitch.checked = isOn
        }
        
        // Called when RGB color changes
        function onRgbStatusChanged(r, g, b) {
            root.currentR = r
            root.currentG = g
            root.currentB = b
            // Update sliders to match ESP32 state (programmatic update, won't trigger onMoved)
            sliderR.value = r
            sliderG.value = g
            sliderB.value = b
        }
        
        // NEW: Called when telemetry message arrives from /topic/qos0
        function onQos0MessageReceived(msg) {
            // Add timestamp to the message
            var time = Qt.formatDateTime(new Date(), "hh:mm:ss")
            // Split existing log into lines
            var lines = root.qos0Log.split("\n")
            // Remove placeholder text on first message
            if (lines.length === 1 && lines[0] === "Waiting for data...") {
                lines = []
            }
            // Add new message at the top (newest first)
            lines.unshift("[" + time + "] " + msg)
            // Keep only the last 30 messages to prevent infinite growth
            if (lines.length > 30) {
                lines = lines.slice(0, 30)
            }
            // Join back into a single string
            root.qos0Log = lines.join("\n")
        }
    }
    
    // ==================== BACKGROUND ====================
    // Gradient background for visual appeal
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0f0f1e" }
            GradientStop { position: 1.0; color: "#1a1a2e" }
        }
    }
    
    // ==================== MAIN SCROLLABLE CONTAINER ====================
    // Flickable allows scrolling when content exceeds window height
    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: column.height
        clip: true  // Hide content outside bounds
        
        // Main column layout containing all UI sections
        ColumnLayout {
            id: column
            width: parent.width
            spacing: 20
            
            // ==================== SECTION 1: HEADER ====================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#667eea" }
                    GradientStop { position: 1.0; color: "#764ba2" }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    // Title text
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            text: "ESP32-S3 LED"
                            font.pixelSize: 26
                            font.bold: true
                            color: "#ffffff"
                        }
                        Label {
                            text: "Smart Controller"
                            font.pixelSize: 14
                            color: "#e0e0ff"
                        }
                    }
                    
                    // Connection status indicator (pulsing dot + text)
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            // Green when connected, red when disconnected
                            color: root.connectionStatus === "Connected" ? "#4ade80" : "#f87171"
                            border.color: "#ffffff"
                            border.width: 2
                            
                            // Pulse animation when connected
                            NumberAnimation on opacity {
                                running: root.connectionStatus === "Connected"
                                from: 1.0; to: 0.5; duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                        Label {
                            text: root.connectionStatus
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }
            }
            
            // ==================== SECTION 2: MODE SELECTOR ====================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Label {
                    text: "CONTROL MODE"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#a0a0c0"
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1
                }
                
                // Dropdown to choose between Simple and RGB modes
                ComboBox {
                    id: modeSelector
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    model: ["Simple White ON/OFF", "RGB Color Control"]
                    
                    // Styling for dropdown items
                    delegate: ItemDelegate {
                        width: modeSelector.width
                        height: 45
                        highlighted: modeSelector.highlightedIndex === index
                        contentItem: Text {
                            text: modelData
                            color: "#ffffff"
                            font.pixelSize: 15
                            leftPadding: 15
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: modeSelector.highlightedIndex === index ? "#667eea" : "#1e1e3f"
                        }
                    }
                    
                    // Styling for selected item display
                    contentItem: Text {
                        text: modeSelector.displayText
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.bold: true
                        leftPadding: 15
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    // Styling for the dropdown button itself
                    background: Rectangle {
                        radius: 10
                        color: "#1e1e3f"
                        border.color: "#667eea"
                        border.width: 2
                    }
                    
                    // Dropdown popup (parented to Overlay to float above everything)
                    popup: Popup {
                        parent: Overlay.overlay
                        x: modeSelector.mapToItem(Overlay.overlay, 0, 0).x
                        y: modeSelector.mapToItem(Overlay.overlay, 0, 0).y + modeSelector.height + 4
                        width: modeSelector.width
                        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                        padding: 6
                        
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: modeSelector.popup.visible ? modeSelector.delegateModel : null
                            currentIndex: modeSelector.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }
                        
                        background: Rectangle {
                            radius: 10
                            color: "#1e1e3f"
                            border.color: "#667eea"
                            border.width: 2
                        }
                    }
                    
                    // Turn off LED when switching modes (safety feature)
                    onCurrentIndexChanged: { 
                        if (currentIndex !== -1) mqtt.set_led(false) 
                    }
                }
            }
            
            // ==================== TELEMETRY BOX ====================
            // Live display of messages from ESP32's /topic/qos0
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200  // Taller to show more history
                radius: 16
                color: "#1e1e3f"
                border.color: "#4ade80"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "LIVE TELEMETRY"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#a0a0c0"
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1
                            Layout.fillWidth: true
                        }
                        Label {
                            text: "/topic/qos0"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#4ade80"
                        }
                    }

                    // SCROLLABLE AREA
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        
                        // FIX: Put 'policy' INSIDE the ScrollBar definition
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 4
                                color: "#4ade80"
                                opacity: parent.pressed ? 1.0 : 0.5
                            }
                        }

                        TextArea {
                            id: qos0Box
                            readOnly: true
                            selectByMouse: true
                            text: root.qos0Log
                            color: "#a6e3a1"
                            font.family: "Monospace"
                            font.pixelSize: 13
                            wrapMode: TextArea.Wrap
                            
                            background: Rectangle {
                                color: "#0f0f1e"
                                radius: 8
                                border.color: "#3f3f7f"
                                border.width: 1
                            }
                        }
                    }
                }
            }
            
            // ==================== SECTION 3: SIMPLE MODE FRAME ====================
            // Visible only when mode 0 (Simple White) is selected
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 16
                color: "#1e1e3f"
                // Highlight border when this mode is active
                border.color: modeSelector.currentIndex === 0 ? "#667eea" : "#3f3f7f"
                border.width: modeSelector.currentIndex === 0 ? 3 : 1
                visible: modeSelector.currentIndex === 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    // Status indicator and title
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15
                        
                        // Large status indicator (ON/OFF)
                        Rectangle {
                            width: 60; height: 60; radius: 12
                            color: root.ledOn ? "#4ade80" : "#f87171"
                            
                            Label {
                                anchors.centerIn: parent
                                text: root.ledOn ? "ON" : "OFF"
                                font.pixelSize: 20
                                font.bold: true
                                color: "#ffffff"
                            }
                        }
                        
                        // Mode title and description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                text: "Simple Mode"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#ffffff"
                            }
                            Label {
                                text: "Bright white LED control"
                                font.pixelSize: 13
                                color: "#a0a0c0"
                            }
                        }
                    }
                    
                    // Power switch container
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        radius: 12
                        color: "#2a2a5a"
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            
                            Label {
                                text: "Power"
                                font.pixelSize: 16
                                color: "#c0c0e0"
                            }
                            
                            // ON/OFF Switch (no 'checked' binding to prevent fighting)
                            Switch {
                                id: simpleToggle
                                onToggled: mqtt.set_led(checked)
                                
                                // Custom switch indicator styling
                                indicator: Rectangle {
                                    implicitWidth: 70; implicitHeight: 36; radius: 18
                                    x: simpleToggle.leftPadding
                                    y: simpleToggle.topPadding + (simpleToggle.availableHeight - height) / 2
                                    color: simpleToggle.checked ? "#667eea" : "#3f3f7f"
                                    border.color: "#667eea"
                                    border.width: 2
                                    
                                    // The sliding white circle
                                    Rectangle {
                                        x: simpleToggle.checked ? parent.width - width - 6 : 6
                                        y: 6; width: 24; height: 24; radius: 12
                                        color: "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // ==================== SECTION 4: RGB MODE FRAME ====================
            // Visible only when mode 1 (RGB Color) is selected
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modeSelector.currentIndex === 1 ? 550 : 0
                radius: 16
                color: "#1e1e3f"
                // Highlight border when this mode is active
                border.color: modeSelector.currentIndex === 1 ? "#f472b6" : "#3f3f7f"
                border.width: modeSelector.currentIndex === 1 ? 3 : 1
                visible: modeSelector.currentIndex === 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    // RGB Power Switch
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "RGB Power"
                            font.pixelSize: 16
                            color: "#c0c0e0"
                            Layout.fillWidth: true
                        }
                        Switch {
                            id: rgbPowerSwitch
                            onToggled: mqtt.set_rgb_power(checked)
                            
                            indicator: Rectangle {
                                implicitWidth: 70; implicitHeight: 36; radius: 18
                                x: rgbPowerSwitch.leftPadding
                                y: rgbPowerSwitch.topPadding + (rgbPowerSwitch.availableHeight - height) / 2
                                color: rgbPowerSwitch.checked ? "#f472b6" : "#3f3f7f"
                                border.color: "#f472b6"
                                border.width: 2
                                
                                Rectangle {
                                    x: rgbPowerSwitch.checked ? parent.width - width - 6 : 6
                                    y: 6; width: 24; height: 24; radius: 12
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                    
                    // Color Preview Box (shows current RGB color)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 12
                        // Background color matches current RGB values
                        color: root.ledOn ? Qt.rgba(root.currentR/255, root.currentG/255, root.currentB/255, 1) : "#0f0f1e"
                        border.color: root.ledOn ? "#ffffff" : "#3f3f7f"
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            // Show RGB values or "LED OFF"
                            text: root.ledOn ? `RGB(${root.currentR}, ${root.currentG}, ${root.currentB})` : "LED OFF"
                            font.pixelSize: 22
                            font.bold: true
                            // Choose text color based on background brightness
                            color: root.ledOn ? (root.currentR + root.currentG + root.currentB > 400 ? "#0f0f1e" : "#ffffff") : "#606080"
                        }
                    }
                    
                    // ==================== RED SLIDER ====================
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "R"; color: "#f87171"; font.bold: true; font.pixelSize: 18; Layout.preferredWidth: 25 }
                        Slider {
                            id: sliderR
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44  // Gives slider a clickable area
                            implicitHeight: 44
                            from: 0; to: 255; stepSize: 1  // Integer steps for clean MQTT payloads
                            value: root.currentR

                            // Track background with filled portion
                            background: Rectangle {
                                x: sliderR.leftPadding
                                y: sliderR.topPadding + sliderR.availableHeight / 2 - height / 2
                                width: sliderR.availableWidth
                                height: 8; radius: 4; color: "#2a2a5a"
                                // Filled portion (red)
                                Rectangle {
                                    width: sliderR.visualPosition * parent.width
                                    height: parent.height; radius: 4; color: "#f87171"
                                }
                            }
                            // Draggable handle
                            handle: Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                x: sliderR.leftPadding + sliderR.visualPosition * (sliderR.availableWidth - width)
                                y: sliderR.topPadding + sliderR.availableHeight / 2 - height / 2
                                width: 24; height: 24; radius: 12
                                color: "#ffffff"; border.color: "#f87171"; border.width: 3
                            }

                            // onMoved fires ONLY on user drag (not programmatic updates)
                            onMoved: {
                                root.currentR = value
                                root.ledOn = true
                                mqtt.set_rgb(sliderR.value, sliderG.value, sliderB.value)
                            }
                        }
                        // Value display
                        Label { text: sliderR.value.toFixed(0); color: "#f87171"; font.bold: true; font.pixelSize: 16; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }
                    
                    // ==================== GREEN SLIDER ====================
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "G"; color: "#4ade80"; font.bold: true; font.pixelSize: 18; Layout.preferredWidth: 25 }
                        Slider {
                            id: sliderG
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            implicitHeight: 44
                            from: 0; to: 255; stepSize: 1
                            value: root.currentG

                            background: Rectangle {
                                x: sliderG.leftPadding
                                y: sliderG.topPadding + sliderG.availableHeight / 2 - height / 2
                                width: sliderG.availableWidth
                                height: 8; radius: 4; color: "#2a2a5a"
                                Rectangle {
                                    width: sliderG.visualPosition * parent.width
                                    height: parent.height; radius: 4; color: "#4ade80"
                                }
                            }
                            handle: Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                x: sliderG.leftPadding + sliderG.visualPosition * (sliderG.availableWidth - width)
                                y: sliderG.topPadding + sliderG.availableHeight / 2 - height / 2
                                width: 24; height: 24; radius: 12
                                color: "#ffffff"; border.color: "#4ade80"; border.width: 3
                            }

                            onMoved: {
                                root.currentG = value
                                root.ledOn = true
                                mqtt.set_rgb(sliderR.value, sliderG.value, sliderB.value)
                            }
                        }
                        Label { text: sliderG.value.toFixed(0); color: "#4ade80"; font.bold: true; font.pixelSize: 16; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }
                    
                    // ==================== BLUE SLIDER ====================
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "B"; color: "#60a5fa"; font.bold: true; font.pixelSize: 18; Layout.preferredWidth: 25 }
                        Slider {
                            id: sliderB
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            implicitHeight: 44
                            from: 0; to: 255; stepSize: 1
                            value: root.currentB

                            background: Rectangle {
                                x: sliderB.leftPadding
                                y: sliderB.topPadding + sliderB.availableHeight / 2 - height / 2
                                width: sliderB.availableWidth
                                height: 8; radius: 4; color: "#2a2a5a"
                                Rectangle {
                                    width: sliderB.visualPosition * parent.width
                                    height: parent.height; radius: 4; color: "#60a5fa"
                                }
                            }
                            handle: Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                x: sliderB.leftPadding + sliderB.visualPosition * (sliderB.availableWidth - width)
                                y: sliderB.topPadding + sliderB.availableHeight / 2 - height / 2
                                width: 24; height: 24; radius: 12
                                color: "#ffffff"; border.color: "#60a5fa"; border.width: 3
                            }

                            onMoved: {
                                root.currentB = value
                                root.ledOn = true
                                mqtt.set_rgb(sliderR.value, sliderG.value, sliderB.value)
                            }
                        }
                        Label { text: sliderB.value.toFixed(0); color: "#60a5fa"; font.bold: true; font.pixelSize: 16; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }
                    
                    // Divider line
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#3f3f7f" }
                    
                    // ==================== COLOR PRESETS ====================
                    Label { text: "QUICK PRESETS"; font.pixelSize: 12; font.bold: true; color: "#a0a0c0"; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4; columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            // Array of preset colors
                            model: [
                                { name: "red", color: "#f87171", label: "Red" },
                                { name: "orange", color: "#fb923c", label: "Orange" },
                                { name: "yellow", color: "#facc15", label: "Yellow" },
                                { name: "green", color: "#4ade80", label: "Green" },
                                { name: "cyan", color: "#22d3ee", label: "Cyan" },
                                { name: "blue", color: "#60a5fa", label: "Blue" },
                                { name: "magenta", color: "#e879f9", label: "Magenta" },
                                { name: "white", color: "#ffffff", label: "White" }
                            ]
                            // Each preset is a colored button
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 10
                                color: modelData.color; border.color: "#ffffff"; border.width: 2
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    // Dark text on light colors, light text on dark colors
                                    color: (modelData.name === "yellow" || modelData.name === "white") ? "#0f0f1e" : "#ffffff"
                                    font.bold: true; font.pixelSize: 13
                                }
                                // Click handler
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { mqtt.send_preset(modelData.name) }
                                }
                            }
                        }
                    }
                }
            }
            
            // Spacer to push content up when window is tall
            Item { Layout.fillHeight: true }
        }
    }
}