import sys
import ssl
import time
import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


class MQTTBridge(QObject):
    """
    Bridge class that connects Python MQTT client to QML UI.
    Signals are emitted to notify QML when data changes.
    Slots are callable from QML to send commands to ESP32.
    """
    
    # Signals: Python → QML (notify UI of changes)
    connectionStatusChanged = Signal(str)
    ledStatusChanged = Signal(bool)
    rgbStatusChanged = Signal(int, int, int)
    qos0MessageReceived = Signal(str)  # NEW: Emits telemetry messages from ESP32
    
    def __init__(self):
        super().__init__()
        
        # MQTT Broker Configuration
        self.broker = "broker.hivemq.com"
        self.port = 8883  # TLS port
        self.client_id = "python_gui_controller_v3" 
        
        # Internal State Tracking
        self._connected = False
        self._led_on = False
        
        # Active color (what sliders currently show)
        self._r = 0
        self._g = 0
        self._b = 0
        
        # Saved color (memory - restores when turning back ON after OFF)
        self._saved_r = 255
        self._saved_g = 255
        self._saved_b = 255
        
        # Message Lock: Prevents delayed MQTT echoes from causing UI glitches
        # When we send a command, we ignore incoming messages for 1.5 seconds
        self._ignore_until = 0 
        
        # Initialize MQTT Client
        self.client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=self.client_id,
            protocol=mqtt.MQTTv311
        )
        
        # Register callback handlers for MQTT events
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        
        # Enable TLS/SSL encryption for secure connection
        self.client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLS)
        
        # Emit initial state to QML
        self._emit_all()
    
    def _emit_all(self):
        """Send current state to QML on startup."""
        status = "Connected" if self._connected else "Disconnected"
        self.connectionStatusChanged.emit(status)
        self.ledStatusChanged.emit(self._led_on)
        self.rgbStatusChanged.emit(self._r, self._g, self._b)
    
    def connect_broker(self):
        """Connect to the MQTT broker and start the network loop."""
        try:
            self.client.connect(self.broker, self.port, keepalive=60)
            self.client.loop_start()  # Start background thread for MQTT communication
            self.connectionStatusChanged.emit("Connecting...")
        except Exception as e:
            self.connectionStatusChanged.emit(f"Error: {e}")
    
    def disconnect_broker(self):
        """Cleanly disconnect from broker when app closes."""
        self.client.loop_stop()
        self.client.disconnect()
        self._connected = False
        self.connectionStatusChanged.emit("Disconnected")
    
    def _on_connect(self, client, userdata, flags, reason_code, properties):
        """Callback: Called when connection to broker is established."""
        if reason_code == 0:
            self._connected = True
            # Subscribe to topics we want to receive messages from
            client.subscribe("esp32s3/led/status")
            client.subscribe("esp32s3/rgb/status")
            client.subscribe("/topic/qos0")  # NEW: Subscribe to telemetry
            self.connectionStatusChanged.emit("Connected")
        else:
            self.connectionStatusChanged.emit(f"Failed (rc={reason_code})")
    
    def _on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties):
        """Callback: Called when connection is lost."""
        self._connected = False
        self.connectionStatusChanged.emit("Disconnected")
    
    def _on_message(self, client, userdata, msg):
        """
        Callback: Called when a message arrives from the broker.
        This is where we process incoming data from the ESP32.
        """
        # CRITICAL: Ignore messages if we just sent a command (prevents echo glitches)
        if time.time() < self._ignore_until:
            return

        # Decode the message payload
        payload = msg.payload.decode().strip()
        topic = msg.topic
        
        # Handle LED ON/OFF status updates
        if topic == "esp32s3/led/status":
            new_state = (payload.upper() == "ON")
            if self._led_on != new_state:
                self._led_on = new_state
                self.ledStatusChanged.emit(new_state)
        
        # Handle RGB color status updates
        elif topic == "esp32s3/rgb/status":
            try:
                parts = payload.split(",")
                if len(parts) == 3:
                    r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
                    # Only update if values actually changed (prevents unnecessary UI updates)
                    if self._r != r or self._g != g or self._b != b:
                        self._r, self._g, self._b = r, g, b
                        # Update 'on' state based on whether any color channel is > 0
                        self._led_on = (r > 0 or g > 0 or b > 0)
                        self.rgbStatusChanged.emit(r, g, b)
                        self.ledStatusChanged.emit(self._led_on)
            except ValueError:
                pass
        
        # NEW: Handle telemetry messages from /topic/qos0
        elif topic == "/topic/qos0":
            self.qos0MessageReceived.emit(payload)
    
    def _lock_updates(self):
        """
        Temporarily ignore incoming MQTT messages for 1.5 seconds.
        This prevents delayed echoes from fighting with user actions.
        """
        self._ignore_until = time.time() + 1.5

    # ==================== SLOTS: Callable from QML ====================

    @Slot(bool)
    def set_led(self, on: bool):
        """
        Slot: Turn LED ON or OFF (Simple Mode).
        Called from QML when user toggles the simple power switch.
        """
        if self._connected:
            self._lock_updates()  # Ignore echoes for 1.5s
            payload = "ON" if on else "OFF"
            self.client.publish("esp32s3/led/control", payload, qos=1)
            self._led_on = on
            self.ledStatusChanged.emit(on)
    
    @Slot(int, int, int)
    def set_rgb(self, r: int, g: int, b: int):
        """
        Slot: Set RGB color.
        Called from QML when user drags a slider or clicks a preset.
        """
        if self._connected:
            self._lock_updates()  # Ignore echoes for 1.5s
            
            # Clamp values to valid range (0-255)
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            
            # Update both active color and saved color (memory)
            self._r, self._g, self._b = r, g, b
            self._saved_r, self._saved_g, self._saved_b = r, g, b
            
            # Publish to ESP32
            payload = f"{r},{g},{b}"
            self.client.publish("esp32s3/rgb", payload, qos=1)
            self._led_on = True
            self.rgbStatusChanged.emit(r, g, b)
            self.ledStatusChanged.emit(True)

    @Slot(bool)
    def set_rgb_power(self, is_on: bool):
        """
        Slot: Turn RGB LED ON or OFF (RGB Mode).
        When turning ON, restores the saved color.
        When turning OFF, saves current color to memory.
        """
        if self._connected:
            self._lock_updates()  # Ignore echoes for 1.5s
            
            if is_on:
                # TURNING ON: Restore saved color from memory
                r, g, b = self._saved_r, self._saved_g, self._saved_b
                
                # If saved color was 0,0,0, default to White so LED actually turns on
                if r == 0 and g == 0 and b == 0:
                    r, g, b = 255, 255, 255
                    self._saved_r, self._saved_g, self._saved_b = 255, 255, 255
                
                self._r, self._g, self._b = r, g, b
                payload = f"{r},{g},{b}"
                self.client.publish("esp32s3/rgb", payload, qos=1)
                self._led_on = True
                self.rgbStatusChanged.emit(r, g, b)
                self.ledStatusChanged.emit(True)
                
            else:
                # TURNING OFF: Save current color to memory, then send 0,0,0
                self._saved_r, self._saved_g, self._saved_b = self._r, self._g, self._b
                
                self.client.publish("esp32s3/rgb", "0,0,0", qos=1)
                self._r = 0
                self._g = 0
                self._b = 0
                self._led_on = False
                self.rgbStatusChanged.emit(0, 0, 0)
                self.ledStatusChanged.emit(False)
    
    @Slot(str)
    def send_preset(self, color_name: str):
        """
        Slot: Send a preset color by name.
        Called from QML when user clicks a color preset button.
        """
        presets = {
            "red": (255, 0, 0), 
            "orange": (255, 165, 0), 
            "yellow": (255, 255, 0),
            "green": (0, 255, 0), 
            "cyan": (0, 255, 255), 
            "blue": (0, 0, 255),
            "magenta": (255, 0, 255), 
            "white": (255, 255, 255),
        }
        if color_name in presets:
            r, g, b = presets[color_name]
            self.set_rgb(r, g, b)


def main():
    """Main entry point for the application."""
    # Create Qt application instance
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # Create MQTT bridge and expose it to QML
    mqtt_bridge = MQTTBridge()
    engine.rootContext().setContextProperty("mqtt", mqtt_bridge)
    
    # Load QML UI file
    qml_file = QUrl.fromLocalFile("main.qml")
    engine.load(qml_file)
    
    # Exit if QML failed to load
    if not engine.rootObjects():
        sys.exit(-1)
    
    # Connect to MQTT broker
    mqtt_bridge.connect_broker()
    
    # Run the application event loop
    exit_code = app.exec()
    
    # Clean disconnect on exit
    mqtt_bridge.disconnect_broker()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()