import os
import time
import msvcrt  # Windows icin klavye okuma
from smart_home_api import AirConditionerSystemConnection

# --- CONFIGURATION ---
BOARD1_PORT = "COM7"   # Proteus'taki COMPIM portun
BAUD_RATE = 9600

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def print_header():
    clear_screen()
    print("==================================================")
    print("      SMART HOME - AC CONTROL UNIT (BOARD 1)")
    print("==================================================")
    print(f" STATUS: Connected | PORT: {BOARD1_PORT} | BAUD: {BAUD_RATE}")
    print("--------------------------------------------------")

def main():
    # 1. Baglanti Nesnesini Olustur
    ac_unit = AirConditionerSystemConnection()
    ac_unit.setComPort(BOARD1_PORT)

    clear_screen()
    print(f"Connecting to Board 1 on {BOARD1_PORT}...")
    
    # 2. Baglantiyi Dene
    if not ac_unit.open():
        print("\n[!] CONNECTION FAILED!")
        print(f"Could not open {BOARD1_PORT}. Please check:")
        print(" 1. Is Proteus simulation running?")
        print(" 2. Are com0com ports (COM7 <-> COM8) active?")
        print(" 3. Is the baud rate 9600 in COMPIM?")
        return

    print("[OK] Connection Established. Fetching data...")
    time.sleep(2)

    # 3. Ana Dongu
    while True:
        try:
            # --- VERI GUNCELLEME ---
            ac_unit.update()

            # --- EKRAN CIZIMI ---
            print_header()
            
            # Sensor Verileri
            amb_temp = ac_unit.getAmbientTemp()
            des_temp = ac_unit.getDesiredTemp()
            fan_spd = ac_unit.getFanSpeed()
            
            print(f"\n [SENSORS]")
            print(f"  > Ambient Temperature :  {amb_temp:.1f} C")
            print(f"  > Target Temperature  :  {des_temp:.1f} C")
            print(f"  > Fan Speed           :  {fan_spd} RPS")
            
            # Durum Cubugu
            print("\n" + "-"*50)
            print(" [CONTROLS]")
            print("  [1] Set Target Temperature")
            print("  [2] Exit")
            print("--------------------------------------------------")
            print(" Waiting for command... (Press Key)")

            # --- KLAVYE KONTROLU (Non-Blocking) ---
            if msvcrt.kbhit():
                key = msvcrt.getch().decode('utf-8').lower()

                if key == '1':
                    print("\n[INPUT] Enter New Target Temperature (10-50): ", end='', flush=True)
                    try:
                        # Input alirken akisi durduruyoruz (Blocking)
                        val_str = input()
                        val = float(val_str)
                        
                        if 10.0 <= val <= 50.0:
                            print(f"Sending {val} C to Board 1...")
                            if ac_unit.setDesiredTemp(val):
                                print("[OK] Command Sent!")
                            else:
                                print("[ERR] Communication Error!")
                        else:
                            print("[ERR] Invalid Range! Use 10.0 - 50.0")
                        
                        time.sleep(1.5) # Mesajin okunmasi icin bekle
                        
                    except ValueError:
                        print("[ERR] Invalid Input! Please enter a number.")
                        time.sleep(1)

                elif key == '2':
                    print("\nExiting...")
                    ac_unit.close()
                    break
            
            # Dongu Hizini Ayarla (Cok hizli yenileme goz yorar)
            time.sleep(0.5)

        except KeyboardInterrupt:
            print("\n[!] Force Exit.")
            ac_unit.close()
            break
        except Exception as e:
            print(f"\n[!] Error: {e}")
            ac_unit.close()
            break

if __name__ == "__main__":
    main()