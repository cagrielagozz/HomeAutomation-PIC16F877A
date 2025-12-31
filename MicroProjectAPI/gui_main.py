import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from smart_home_api import AirConditionerSystemConnection, CurtainControlSystemConnection

# --- DEFAULTS ---
DEFAULT_PORT_KLIMA = "COM7"
DEFAULT_PORT_PERDE = "COM9"

# --- COLOR PALETTE (Professional Light Theme) ---
COLOR_BG_MAIN = "#F4F6F9"       # Very Light Grey (Background)
COLOR_BG_PANEL = "#FFFFFF"      # White (Panels)
COLOR_TEXT_MAIN = "#2C3E50"     # Dark Navy/Grey (Text)
COLOR_TEXT_LIGHT = "#7F8C8D"    # Lighter Grey (Subtitles)
COLOR_ACCENT = "#34495E"        # Dark Grey (Headers)
COLOR_BUTTON = "#4A6FA5"        # Steel Blue (Primary Actions)
COLOR_BUTTON_TEXT = "#FFFFFF"
COLOR_SUCCESS = "#27AE60"       # Sober Green
COLOR_BORDER = "#D5DBDB"        # Light Border

# --- FONT SETTINGS ---
# Eger Montserrat yuklu degilse sistem Arial kullanir
FONT_HEADER = ("Montserrat", 16, "bold")
FONT_SUBHEADER = ("Montserrat", 11, "bold")
FONT_NORMAL = ("Montserrat", 9)
FONT_MONITOR_LABEL = ("Montserrat", 9, "bold")
FONT_MONITOR_VAL = ("Montserrat", 10)

class HomeAutomationGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Control Panel")
        self.root.geometry("850x500")
        self.root.configure(bg=COLOR_BG_MAIN)
        self.root.resizable(False, False)

        # API Objects
        self.klima = AirConditionerSystemConnection()
        self.perde = CurtainControlSystemConnection()
        
        # Thread Control
        self.running = True
        self.thread = threading.Thread(target=self.update_loop, daemon=True)
        
        # Styling and Layout
        self.configure_styles()
        self.create_widgets()
        
        # Start Thread
        self.thread.start()

    def configure_styles(self):
        style = ttk.Style()
        style.theme_use('clam') 

        # Frame Styles
        style.configure("Main.TFrame", background=COLOR_BG_MAIN)
        style.configure("Panel.TFrame", background=COLOR_BG_PANEL)
        
        # Labelframe (Panel Borders)
        style.configure("Panel.TLabelframe", background=COLOR_BG_PANEL, bordercolor=COLOR_BORDER)
        style.configure("Panel.TLabelframe.Label", background=COLOR_BG_PANEL, foreground=COLOR_ACCENT, font=FONT_SUBHEADER)

        # Label Styles
        style.configure("Header.TLabel", background=COLOR_BG_MAIN, foreground=COLOR_TEXT_MAIN, font=FONT_HEADER)
        style.configure("Normal.TLabel", background=COLOR_BG_PANEL, foreground=COLOR_TEXT_MAIN, font=FONT_NORMAL)
        style.configure("MonitorTitle.TLabel", background=COLOR_BG_PANEL, foreground=COLOR_TEXT_LIGHT, font=FONT_MONITOR_LABEL)
        style.configure("MonitorVal.TLabel", background=COLOR_BG_PANEL, foreground=COLOR_TEXT_MAIN, font=FONT_MONITOR_VAL)

        # Button Styles (Professional Blue)
        style.configure("Action.TButton", font=FONT_NORMAL, background=COLOR_BUTTON, foreground=COLOR_BUTTON_TEXT, borderwidth=1)
        style.map("Action.TButton", background=[('active', '#3B5B8C')]) 
        
        # Connect Button (Sober Green/Grey)
        style.configure("Connect.TButton", font=FONT_NORMAL, background=COLOR_TEXT_LIGHT, foreground="white", borderwidth=1)
        style.map("Connect.TButton", background=[('active', '#5E6D6E')])

        # Entry Style
        style.configure("TEntry", fieldbackground="#FDFFE6", bordercolor=COLOR_BORDER) # Hafif sari arka plan (input oldugu belli olsun)

        # Horizontal Scale
        style.configure("Horizontal.TScale", background=COLOR_BG_PANEL)

    def create_widgets(self):
        # --- HEADER ---
        header_frame = ttk.Frame(self.root, style="Main.TFrame", padding=(20, 15))
        header_frame.pack(fill=tk.X)
        ttk.Label(header_frame, text="Smart Home Automation System", style="Header.TLabel").pack(anchor=tk.CENTER)
        ttk.Label(header_frame, text="Engineering Term Project - Control Interface", font=("Montserrat", 9), background=COLOR_BG_MAIN, foreground=COLOR_TEXT_LIGHT).pack(anchor=tk.CENTER)

        # --- MAIN CONTAINER ---
        main_panel = ttk.Frame(self.root, style="Main.TFrame", padding=15)
        main_panel.pack(fill=tk.BOTH, expand=True)

        # ================= LEFT PANEL: AIR CONDITIONER =================
        left_frame = ttk.LabelFrame(main_panel, text=" Board 1: Air Conditioner ", style="Panel.TLabelframe", padding=15)
        left_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))

        # Connection Area
        conn_frame1 = ttk.Frame(left_frame, style="Panel.TFrame")
        conn_frame1.pack(fill=tk.X, pady=(0, 15))
        
        ttk.Label(conn_frame1, text="COM Port:", style="Normal.TLabel").pack(side=tk.LEFT, padx=(0,5))
        self.port_klima_var = tk.StringVar(value=DEFAULT_PORT_KLIMA)
        ttk.Entry(conn_frame1, textvariable=self.port_klima_var, width=10).pack(side=tk.LEFT, padx=(0,10))
        self.btn_conn_klima = ttk.Button(conn_frame1, text="Connect", style="Connect.TButton", command=self.toggle_klima_conn)
        self.btn_conn_klima.pack(side=tk.LEFT)

        # Monitor Area
        self.create_separator(left_frame)
        self.lbl_amb_temp = self.create_monitor_row(left_frame, "Ambient Temperature:", "--.- °C")
        self.lbl_des_temp = self.create_monitor_row(left_frame, "Target Temperature:", "--.- °C")
        self.lbl_fan_speed = self.create_monitor_row(left_frame, "Fan Speed:", "-- rps")
        self.create_separator(left_frame)

        # Control Area
        ctrl_frame1 = ttk.Frame(left_frame, style="Panel.TFrame")
        ctrl_frame1.pack(fill=tk.X, pady=10)
        ttk.Label(ctrl_frame1, text="Set Temperature (°C):", style="Normal.TLabel").pack(anchor=tk.W, pady=(0,5))
        
        input_frame1 = ttk.Frame(ctrl_frame1, style="Panel.TFrame")
        input_frame1.pack(fill=tk.X)
        self.entry_set_temp = ttk.Entry(input_frame1, width=10)
        self.entry_set_temp.pack(side=tk.LEFT, padx=(0,5))
        ttk.Button(input_frame1, text="Update Target", style="Action.TButton", command=self.send_klima_cmd).pack(side=tk.LEFT)

        # ================= RIGHT PANEL: CURTAIN & SENSORS =================
        right_frame = ttk.LabelFrame(main_panel, text=" Board 2: Curtain & Sensors ", style="Panel.TLabelframe", padding=15)
        right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=(10, 0))

        # Connection Area
        conn_frame2 = ttk.Frame(right_frame, style="Panel.TFrame")
        conn_frame2.pack(fill=tk.X, pady=(0, 15))
        
        ttk.Label(conn_frame2, text="COM Port:", style="Normal.TLabel").pack(side=tk.LEFT, padx=(0,5))
        self.port_perde_var = tk.StringVar(value=DEFAULT_PORT_PERDE)
        ttk.Entry(conn_frame2, textvariable=self.port_perde_var, width=10).pack(side=tk.LEFT, padx=(0,10))
        self.btn_conn_perde = ttk.Button(conn_frame2, text="Connect", style="Connect.TButton", command=self.toggle_perde_conn)
        self.btn_conn_perde.pack(side=tk.LEFT)
        
        # Checkbox for Simulation
        self.sim_mode_var = tk.BooleanVar(value=False)
        chk = tk.Checkbutton(conn_frame2, text="Sim. Mode", variable=self.sim_mode_var, 
                             command=self.toggle_sim_mode, bg=COLOR_BG_PANEL, fg=COLOR_TEXT_MAIN, 
                             activebackground=COLOR_BG_PANEL, font=FONT_NORMAL)
        chk.pack(side=tk.RIGHT)

        # Monitor Area
        self.create_separator(right_frame)
        self.lbl_out_temp = self.create_monitor_row(right_frame, "Outdoor Temperature:", "--.- °C")
        self.lbl_out_pres = self.create_monitor_row(right_frame, "Pressure:", "--.- hPa")
        self.lbl_light = self.create_monitor_row(right_frame, "Light Intensity:", "--.- Lux")
        self.lbl_curtain = self.create_monitor_row(right_frame, "Curtain Status:", "--.- %")
        self.create_separator(right_frame)

        # Control Area
        ctrl_frame2 = ttk.Frame(right_frame, style="Panel.TFrame")
        ctrl_frame2.pack(fill=tk.X, pady=10)
        ttk.Label(ctrl_frame2, text="Manual Curtain Control (%):", style="Normal.TLabel").pack(anchor=tk.W, pady=(0,5))
        
        self.scale_curtain = ttk.Scale(ctrl_frame2, from_=0, to=100, orient=tk.HORIZONTAL, style="Horizontal.TScale")
        self.scale_curtain.pack(fill=tk.X, pady=(0,10))
        ttk.Button(ctrl_frame2, text="Move Curtain", style="Action.TButton", command=self.send_perde_cmd).pack(fill=tk.X)

        # --- STATUS BAR ---
        self.status_bar = tk.Label(self.root, text="System Ready", bd=1, relief=tk.GROOVE, anchor=tk.W, bg="#E5E7E9", fg=COLOR_TEXT_MAIN, font=("Arial", 9))
        self.status_bar.pack(side=tk.BOTTOM, fill=tk.X)

    def create_monitor_row(self, parent, title, initial_val):
        frame = ttk.Frame(parent, style="Panel.TFrame")
        frame.pack(fill=tk.X, pady=4)
        ttk.Label(frame, text=title, style="MonitorTitle.TLabel").pack(side=tk.LEFT)
        lbl_val = ttk.Label(frame, text=initial_val, style="MonitorVal.TLabel")
        lbl_val.pack(side=tk.RIGHT)
        return lbl_val

    def create_separator(self, parent):
        sep = ttk.Separator(parent, orient="horizontal")
        sep.pack(fill=tk.X, pady=8)

    # --- LOGIC ---
    def toggle_klima_conn(self):
        if not self.klima.is_connected:
            self.klima.setComPort(self.port_klima_var.get())
            if self.klima.open():
                self.btn_conn_klima.config(text="Disconnect")
                self.style_connected(self.btn_conn_klima)
                self.status_bar.config(text=f"AC Unit Connected on {self.port_klima_var.get()}", fg="green")
            else:
                messagebox.showerror("Connection Error", f"Could not connect to {self.port_klima_var.get()}")
        else:
            self.klima.close()
            self.btn_conn_klima.config(text="Connect")
            self.style_disconnected(self.btn_conn_klima)
            self.status_bar.config(text="AC Unit Disconnected", fg="black")

    def toggle_perde_conn(self):
        if self.sim_mode_var.get(): return 

        if not self.perde.is_connected:
            self.perde.setComPort(self.port_perde_var.get())
            if self.perde.open():
                self.btn_conn_perde.config(text="Disconnect")
                self.style_connected(self.btn_conn_perde)
                self.status_bar.config(text=f"Curtain System Connected on {self.port_perde_var.get()}", fg="green")
            else:
                messagebox.showerror("Connection Error", f"Could not connect to {self.port_perde_var.get()}")
        else:
            self.perde.close()
            self.btn_conn_perde.config(text="Connect")
            self.style_disconnected(self.btn_conn_perde)
            self.status_bar.config(text="Curtain System Disconnected", fg="black")

    def style_connected(self, btn):
        # Buton stilini dinamik olarak yesil yap (ttk style map ile ugrasmamak icin kucuk bir hack)
        # ttk'de stil degisimi karmasik oldugu icin sadece text degisimi yeterli, 
        # ancak status bar yesil oluyor.
        pass

    def style_disconnected(self, btn):
        pass

    def toggle_sim_mode(self):
        is_sim = self.sim_mode_var.get()
        self.perde.set_simulation_mode(is_sim)
        if is_sim:
            self.btn_conn_perde.config(state=tk.DISABLED)
            self.status_bar.config(text="Board 2: Running in Simulation Mode", fg="blue")
            if self.perde.is_connected:
                self.perde.close()
                self.btn_conn_perde.config(text="Connect")
                self.style_disconnected(self.btn_conn_perde)
        else:
            self.btn_conn_perde.config(state=tk.NORMAL)
            self.status_bar.config(text="Simulation Mode Deactivated", fg="black")

    def send_klima_cmd(self):
        try:
            val = float(self.entry_set_temp.get())
            if self.klima.setDesiredTemp(val):
                self.status_bar.config(text=f"Command Sent: Set AC Target to {val}°C", fg="black")
            else:
                messagebox.showwarning("Invalid Range", "Temperature must be between 10.0 and 50.0")
        except ValueError:
            messagebox.showerror("Invalid Input", "Please enter a numeric value.")

    def send_perde_cmd(self):
        val = self.scale_curtain.get()
        self.perde.setCurtainStatus(val)
        self.status_bar.config(text=f"Command Sent: Set Curtain to {val:.1f}%", fg="black")

    def update_loop(self):
        while self.running:
            try:
                if self.klima.is_connected:
                    self.klima.update()
                
                if self.perde.is_connected or self.perde.simulation_mode:
                    self.perde.update()

                self.root.after(0, self.update_gui_elements)
                time.sleep(0.5)
            except Exception as e:
                print(f"Update Error: {e}")

    def update_gui_elements(self):
        # Update AC
        if self.klima.is_connected:
            self.lbl_amb_temp.config(text=f"{self.klima.getAmbientTemp():.1f} °C", foreground="#2C3E50")
            self.lbl_des_temp.config(text=f"{self.klima.getDesiredTemp():.1f} °C", foreground=COLOR_SUCCESS)
            self.lbl_fan_speed.config(text=f"{self.klima.getFanSpeed()} rps")
        else:
            self.lbl_amb_temp.config(text="--.- °C", foreground=COLOR_TEXT_LIGHT)
            self.lbl_des_temp.config(text="--.- °C", foreground=COLOR_TEXT_LIGHT)

        # Update Curtain/Sensor
        if self.perde.is_connected or self.perde.simulation_mode:
            self.lbl_out_temp.config(text=f"{self.perde.getOutdoorTemp():.1f} °C")
            self.lbl_out_pres.config(text=f"{self.perde.getOutdoorPress():.1f} hPa")
            self.lbl_light.config(text=f"{self.perde.getLightIntensity():.1f} Lux")
            self.lbl_curtain.config(text=f"{self.perde.getCurtainStatus():.1f} %")
        else:
            self.lbl_out_temp.config(text="--.- °C")

if __name__ == "__main__":
    root = tk.Tk()
    app = HomeAutomationGUI(root)
    root.mainloop()