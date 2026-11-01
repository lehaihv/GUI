import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    visible: true
    width: 500
    height: 800
    title: "ESP32-S3 LED Controller"
    color: "#0f0f1e"
    
    property int currentR: 0
    property int currentG: 0
    property int currentB: 0
    property bool ledOn: false
    property string connectionStatus: "Disconnected"
    
    // Listen to Python signals
    Connections {
        target: mqtt
        function onConnectionStatusChanged(status) { 
            root.connectionStatus = status 
        }
        function onLedStatusChanged(isOn) { 
            // Update state and force switches to match (prevents fighting)
            root.ledOn = isOn
            simpleToggle.checked = isOn
            rgbPowerSwitch.checked = isOn
        }
        function onRgbStatusChanged(r, g, b) {
            root.currentR = r
            root.currentG = g
            root.currentB = b
            // Update sliders to match ESP32 state
            sliderR.value = r
            sliderG.value = g
            sliderB.value = b
        }
    }
    
    // Background Gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0f0f1e" }
            GradientStop { position: 1.0; color: "#1a1a2e" }
        }
    }
    
    Flickable {
        anchors.fill: parent
        anchors.margins: 20
        contentHeight: column.height
        clip: true
        
        ColumnLayout {
            id: column
            width: parent.width
            spacing: 20
            
            // === 1. Beautiful Header with Clear Connection Status ===
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
                    
                    // Large, clear connection indicator
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: root.connectionStatus === "Connected" ? "#4ade80" : "#f87171"
                            border.color: "#ffffff"
                            border.width: 2
                            
                            // Pulse animation if connected
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
            
            // === 2. Mode Selector (Popup fixed to float above everything) ===
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
                
                ComboBox {
                    id: modeSelector
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    model: ["Simple White ON/OFF", "RGB Color Control"]
                    
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
                    
                    contentItem: Text {
                        text: modeSelector.displayText
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.bold: true
                        leftPadding: 15
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        radius: 10
                        color: "#1e1e3f"
                        border.color: "#667eea"
                        border.width: 2
                    }
                    
                    // THE FIX: Parent the popup to the Overlay (top-most layer of the window)
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
                    
                    // Turn off LED when switching modes
                    onCurrentIndexChanged: { 
                        if (currentIndex !== -1) mqtt.set_led(false) 
                    }
                }
            }
            
            // === 3. FRAME 1: Simple ON/OFF ===
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 16
                color: "#1e1e3f"
                border.color: modeSelector.currentIndex === 0 ? "#667eea" : "#3f3f7f"
                border.width: modeSelector.currentIndex === 0 ? 3 : 1
                visible: modeSelector.currentIndex === 0
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15
                        
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
                    
                    // The Switch (NO 'checked' binding here to prevent fighting)
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
                            
                            Switch {
                                id: simpleToggle
                                // DO NOT BIND checked HERE. It is updated via Connections block.
                                onToggled: mqtt.set_led(checked)
                                
                                indicator: Rectangle {
                                    implicitWidth: 70; implicitHeight: 36; radius: 18
                                    x: simpleToggle.leftPadding
                                    y: simpleToggle.topPadding + (simpleToggle.availableHeight - height) / 2
                                    color: simpleToggle.checked ? "#667eea" : "#3f3f7f"
                                    border.color: "#667eea"
                                    border.width: 2
                                    
                                    // The White Circle Handle
                                    Rectangle {
                                        // FIX: Use simpleToggle.checked instead of parent.checked
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
            
            // === 4. FRAME 2: RGB Color Control ===
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modeSelector.currentIndex === 1 ? 550 : 0
                radius: 16
                color: "#1e1e3f"
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
                            // DO NOT BIND checked HERE. It is updated via Connections block.
                            onToggled: mqtt.set_rgb_power(checked)
                            
                            indicator: Rectangle {
                                implicitWidth: 70; implicitHeight: 36; radius: 18
                                x: rgbPowerSwitch.leftPadding
                                y: rgbPowerSwitch.topPadding + (rgbPowerSwitch.availableHeight - height) / 2
                                color: rgbPowerSwitch.checked ? "#f472b6" : "#3f3f7f"
                                border.color: "#f472b6"
                                border.width: 2
                                
                                // The White Circle Handle
                                Rectangle {
                                    // FIX: Use rgbPowerSwitch.checked instead of parent.checked
                                    x: rgbPowerSwitch.checked ? parent.width - width - 6 : 6
                                    y: 6; width: 24; height: 24; radius: 12
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                    
                    // Color Preview
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 12
                        color: root.ledOn ? Qt.rgba(root.currentR/255, root.currentG/255, root.currentB/255, 1) : "#0f0f1e"
                        border.color: root.ledOn ? "#ffffff" : "#3f3f7f"
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: root.ledOn ? `RGB(${root.currentR}, ${root.currentG}, ${root.currentB})` : "LED OFF"
                            font.pixelSize: 22
                            font.bold: true
                            color: root.ledOn ? (root.currentR + root.currentG + root.currentB > 400 ? "#0f0f1e" : "#ffffff") : "#606080"
                        }
                    }
                    
                    // RED SLIDER (Fixed: Removed MouseArea that was blocking drag)
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "R"; color: "#f87171"; font.bold: true; font.pixelSize: 18; Layout.preferredWidth: 25 }
                        Slider {
                            id: sliderR
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44   // <-- THE FIX: gives the slider a real clickable area
                            implicitHeight: 44
                            from: 0; to: 255; stepSize: 1
                            value: root.currentR

                            background: Rectangle {
                                x: sliderR.leftPadding
                                y: sliderR.topPadding + sliderR.availableHeight / 2 - height / 2
                                width: sliderR.availableWidth
                                height: 8; radius: 4; color: "#2a2a5a"
                                Rectangle {
                                    width: sliderR.visualPosition * parent.width
                                    height: parent.height; radius: 4; color: "#f87171"
                                }
                            }
                            handle: Rectangle {
                                implicitWidth: 24        // <-- lets the Slider compute its size
                                implicitHeight: 24
                                x: sliderR.leftPadding + sliderR.visualPosition * (sliderR.availableWidth - width)
                                y: sliderR.topPadding + sliderR.availableHeight / 2 - height / 2
                                width: 24; height: 24; radius: 12
                                color: "#ffffff"; border.color: "#f87171"; border.width: 3
                            }

                            onMoved: {   // fires ONLY on user drag
                                root.currentR = value
                                root.ledOn = true
                                mqtt.set_rgb(sliderR.value, sliderG.value, sliderB.value)
                            }
                        }
                        Label { text: sliderR.value.toFixed(0); color: "#f87171"; font.bold: true; font.pixelSize: 16; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }
                    
                    // GREEN SLIDER
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
                    
                    // BLUE SLIDER
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
                    
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#3f3f7f" }
                    
                    // Presets
                    Label { text: "QUICK PRESETS"; font.pixelSize: 12; font.bold: true; color: "#a0a0c0"; font.capitalization: Font.AllUppercase; font.letterSpacing: 1 }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4; columnSpacing: 10; rowSpacing: 10
                        Repeater {
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
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 10
                                color: modelData.color; border.color: "#ffffff"; border.width: 2
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: (modelData.name === "yellow" || modelData.name === "white") ? "#0f0f1e" : "#ffffff"
                                    font.bold: true; font.pixelSize: 13
                                }
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
            
            Item { Layout.fillHeight: true }
        }
    }
}