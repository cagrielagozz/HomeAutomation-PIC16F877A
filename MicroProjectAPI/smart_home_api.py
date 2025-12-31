import serial
import time
import random  # For simulation mode

class HomeAutomationSystemConnection:
    def __init__(self):
        self.comPort = "COM1" 
        self.baudRate = 9600
        self.ser = None
        self.is_connected = False

    def setComPort(self, port):
        self.comPort = port

    def open(self):
        try:
            # Timeout is critical to prevent UI freezing
            self.ser = serial.Serial(self.comPort, self.baudRate, timeout=0.1)
            self.ser.flushInput()
            self.ser.flushOutput()
            self.is_connected = True
            return True
        except Exception as e:
            print(f"Connection Error ({self.comPort}): {e}")
            self.is_connected = False
            return False

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()
        self.is_connected = False

    def _send_byte(self, byte_val):
        if self.ser and self.ser.is_open:
            try:
                self.ser.write(bytes([byte_val]))
                time.sleep(0.02) 
            except:
                pass

    def _read_byte(self):
        if self.ser and self.ser.is_open:
            try:
                val = self.ser.read(1)
                if val:
                    return ord(val)
            except:
                pass
        return None

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    """
    Board #1 (Air Conditioner) Driver
    Protocol:
      GET: 0x01 (Des.Frac), 0x02 (Des.Int), 0x03 (Amb.Frac), 0x04 (Amb.Int), 0x05 (Fan)
      SET: 10xxxxxx (Frac), 11xxxxxx (Int)
    """
    def __init__(self):
        super().__init__()
        self.desiredTemperature = 0.0
        self.ambientTemperature = 0.0
        self.fanSpeed = 0

    def setDesiredTemp(self, temp):
        if not (10.0 <= temp <= 50.0):
            print("Error: Temperature must be between 10.0 and 50.0")
            return False
        
        int_part = int(temp)
        frac_part = int(round((temp - int_part) * 10))

        cmd_frac = 0x80 | (frac_part & 0x3F)
        self._send_byte(cmd_frac)
        
        cmd_int = 0xC0 | (int_part & 0x3F)
        self._send_byte(cmd_int)
        return True

    def update(self):
        if not self.is_connected: return

        self._send_byte(0x01) # Get Desired Frac
        d_frac = self._read_byte()
        self._send_byte(0x02) # Get Desired Int
        d_int = self._read_byte()
        
        if d_int is not None and d_frac is not None:
            self.desiredTemperature = float(d_int) + (float(d_frac) / 10.0)

        self._send_byte(0x03) # Get Amb Frac
        a_frac = self._read_byte()
        self._send_byte(0x04) # Get Amb Int
        a_int = self._read_byte()

        if a_int is not None and a_frac is not None:
            self.ambientTemperature = float(a_int) + (float(a_frac) / 10.0)

        self._send_byte(0x05) # Get Fan
        fan = self._read_byte()
        if fan is not None:
            self.fanSpeed = fan

    def getDesiredTemp(self): return self.desiredTemperature
    def getAmbientTemp(self): return self.ambientTemperature
    def getFanSpeed(self): return self.fanSpeed


class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    """
    Board #2 (Curtain) Protocol Implementation
    """
    def __init__(self):
        super().__init__()
        self.curtainStatus = 0.0
        self.outdoorTemperature = 0.0
        self.outdoorPressure = 0.0
        self.lightIntensity = 0.0
        self.simulation_mode = False 

    def set_simulation_mode(self, active):
        self.simulation_mode = active

    def setCurtainStatus(self, status):
        if status < 0.0: status = 0.0
        if status > 100.0: status = 100.0
        
        if self.simulation_mode:
            self.curtainStatus = status
            return True

        int_part = int(status)
        frac_part = int(round((status - int_part) * 10))

        cmd_frac = 0x80 | (frac_part & 0x3F) # 10xxxxxx
        self._send_byte(cmd_frac)
        
        cmd_int = 0xC0 | (int_part & 0x3F) # 11xxxxxx
        self._send_byte(cmd_int)
        return True

    def update(self):
        if self.simulation_mode:
            self.outdoorTemperature = round(random.uniform(15.0, 30.0), 1)
            self.outdoorPressure = round(random.uniform(1000.0, 1020.0), 1)
            self.lightIntensity = round(random.uniform(200.0, 800.0), 1)
            return

        if not self.is_connected: return

        # 1. Curtain Status
        self._send_byte(0x01)
        c_frac = self._read_byte()
        self._send_byte(0x02)
        c_int = self._read_byte()
        if c_int is not None and c_frac is not None:
            self.curtainStatus = float(c_int) + (float(c_frac) / 10.0)

        # 2. Outdoor Temp
        self._send_byte(0x03)
        t_frac = self._read_byte()
        self._send_byte(0x04)
        t_int = self._read_byte()
        if t_int is not None and t_frac is not None:
            self.outdoorTemperature = float(t_int) + (float(t_frac) / 10.0)

        # 3. Outdoor Pressure
        self._send_byte(0x05)
        p_frac = self._read_byte()
        self._send_byte(0x06)
        p_int = self._read_byte()
        if p_int is not None and p_frac is not None:
            self.outdoorPressure = float(p_int) + (float(p_frac) / 10.0)

        # 4. Light Intensity
        self._send_byte(0x07)
        l_frac = self._read_byte()
        self._send_byte(0x08)
        l_int = self._read_byte()
        if l_int is not None and l_frac is not None:
            self.lightIntensity = float(l_int) + (float(l_frac) / 10.0)

    def getCurtainStatus(self): return self.curtainStatus
    def getOutdoorTemp(self): return self.outdoorTemperature
    def getOutdoorPress(self): return self.outdoorPressure
    def getLightIntensity(self): return self.lightIntensity