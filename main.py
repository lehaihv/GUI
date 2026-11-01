import sys
import ssl
import time
import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Slot, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


class MQTTBridge(QObject):
    connectionStatusChanged = Signal(str)
    ledStatusChanged = Signal(bool)
    rgbStatusChanged = Signal(int, int, int)
    
    def __init__(self):
        super().__init__()
        
        self.broker = "broker.hivemq.com"
        self.port = 8883
        self.client_id = "python_gui_controller_v3" 
        
        self._connected = False
        self._led_on = False
        
        # Active color (what sliders show)
        self._r = 0
        self._g = 0
        self._b = 0
        
        # Saved color (memory for when we turn back ON)
        self._saved_r = 255
        self._saved_g = 255
        self._saved_b = 255
        
        # Lock to ignore delayed MQTT messages for 1 second after a command
        self._ignore_until = 0 
        
        self.client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=self.client_id,
            protocol=mqtt.MQTTv311
        )
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        
        self.client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLS)
        self._emit_all()
    
    def _emit_all(self):
        status = "Connected" if self._connected else "Disconnected"
        self.connectionStatusChanged.emit(status)
        self.ledStatusChanged.emit(self._led_on)
        self.rgbStatusChanged.emit(self._r, self._g, self._b)
    
    def connect_broker(self):
        try:
            self.client.connect(self.broker, self.port, keepalive=60)
            self.client.loop_start()
            self.connectionStatusChanged.emit("Connecting...")
        except Exception as e:
            self.connectionStatusChanged.emit(f"Error: {e}")
    
    def disconnect_broker(self):
        self.client.loop_stop()
        self.client.disconnect()
        self._connected = False
        self.connectionStatusChanged.emit("Disconnected")
    
    def _on_connect(self, client, userdata, flags, reason_code, properties):
        if reason_code == 0:
            self._connected = True
            client.subscribe("esp32s3/led/status")
            client.subscribe("esp32s3/rgb/status")
            self.connectionStatusChanged.emit("Connected")
        else:
            self.connectionStatusChanged.emit(f"Failed (rc={reason_code})")
    
    def _on_disconnect(self, client, userdata, disconnect_flags, reason_code, properties):
        self._connected = False
        self.connectionStatusChanged.emit("Disconnected")
    
    def _on_message(self, client, userdata, msg):
        # CRITICAL FIX: Ignore messages if we just sent a command (prevents auto-on glitch)
        if time.time() < self._ignore_until:
            return

        payload = msg.payload.decode().strip()
        topic = msg.topic
        
        if topic == "esp32s3/led/status":
            new_state = (payload.upper() == "ON")
            if self._led_on != new_state:
                self._led_on = new_state
                self.ledStatusChanged.emit(new_state)
        
        elif topic == "esp32s3/rgb/status":
            try:
                parts = payload.split(",")
                if len(parts) == 3:
                    r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
                    if self._r != r or self._g != g or self._b != b:
                        self._r, self._g, self._b = r, g, b
                        # Only update 'on' state if values are not 0
                        self._led_on = (r > 0 or g > 0 or b > 0)
                        self.rgbStatusChanged.emit(r, g, b)
                        self.ledStatusChanged.emit(self._led_on)
            except ValueError:
                pass
    
    def _lock_updates(self):
        # Ignore incoming MQTT messages for 1.5 seconds
        self._ignore_until = time.time() + 1.5

    @Slot(bool)
    def set_led(self, on: bool):
        if self._connected:
            self._lock_updates()
            payload = "ON" if on else "OFF"
            self.client.publish("esp32s3/led/control", payload, qos=1)
            self._led_on = on
            self.ledStatusChanged.emit(on)
    
    @Slot(int, int, int)
    def set_rgb(self, r: int, g: int, b: int):
        if self._connected:
            self._lock_updates()
            r = max(0, min(255, r))
            g = max(0, min(255, g))
            b = max(0, min(255, b))
            
            # Update active and saved color
            self._r, self._g, self._b = r, g, b
            self._saved_r, self._saved_g, self._saved_b = r, g, b
            
            payload = f"{r},{g},{b}"
            self.client.publish("esp32s3/rgb", payload, qos=1)
            self._led_on = True
            self.rgbStatusChanged.emit(r, g, b)
            self.ledStatusChanged.emit(True)

    @Slot(bool)
    def set_rgb_power(self, is_on: bool):
        if self._connected:
            self._lock_updates()
            
            if is_on:
                # TURNING ON: Restore saved color
                r, g, b = self._saved_r, self._saved_g, self._saved_b
                
                # If saved color was somehow 0,0,0, default to White
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
                # TURNING OFF: Save current color, send 0,0,0
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
        presets = {
            "red": (255, 0, 0), "orange": (255, 165, 0), "yellow": (255, 255, 0),
            "green": (0, 255, 0), "cyan": (0, 255, 255), "blue": (0, 0, 255),
            "magenta": (255, 0, 255), "white": (255, 255, 255),
        }
        if color_name in presets:
            r, g, b = presets[color_name]
            self.set_rgb(r, g, b)


def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    mqtt_bridge = MQTTBridge()
    engine.rootContext().setContextProperty("mqtt", mqtt_bridge)
    
    qml_file = QUrl.fromLocalFile("main.qml")
    engine.load(qml_file)
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    mqtt_bridge.connect_broker()
    exit_code = app.exec()
    mqtt_bridge.disconnect_broker()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()