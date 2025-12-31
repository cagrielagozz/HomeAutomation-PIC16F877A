import time
import msvcrt
import os
from smart_home_api import CurtainControlSystemConnection

# --- AYARLAR ---
# Board 1 kapali, sadece Board 2 portunu aciyoruz.
# com0com: PC=COM9 <--> PIC=COM10
PC_PERDE_PORT = "COM9"
# ---------------

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main():
    perde = CurtainControlSystemConnection()
    perde.setComPort(PC_PERDE_PORT)

    print(f"Board 2 (Perde) Baglantisi Kuruluyor: {PC_PERDE_PORT}...")
    
    if not perde.open():
        print("!!! BAGLANTI HATASI !!!")
        print("Lutfen com0com ayarlarini (COM9 <-> COM10) kontrol edin.")
        return

    print("Baglanti Basarili! Veriler bekleniyor...")
    time.sleep(2)

    while True:
        try:
            # Verileri PIC'ten cek
            perde.update()

            clear_screen()
            print("##############################################")
            print("   BOARD 2 - PERDE & SENSOR SISTEMI")
            print("##############################################")
            print(f"BAGLI PORT: {PC_PERDE_PORT}")
            print("-" * 30)
            print(f"DIS SICAKLIK    :  {perde.getOutdoorTemp():.1f} C")
            print(f"DIS BASINC      :  {perde.getOutdoorPress():.1f} kPa") # Kodda 101 gonderiyor
            print(f"PERDE DURUMU    : %{perde.getCurtainStatus():.1f}")
            print(f"ISIK SIDDETI    :  {perde.getLightIntensity():.1f}")
            print("-" * 30)
            print("[1] Perdeyi %0 (ACIK) Yap")
            print("[2] Perdeyi %50 (YARI) Yap")
            print("[3] Perdeyi %100 (KAPALI) Yap")
            print("[4] Cikis")
            print("-" * 30)

            # Klavye Kontrolü (Non-blocking)
            if msvcrt.kbhit():
                key = msvcrt.getch().decode('utf-8').lower()

                if key == '1':
                    print("\n>> Perde %0'a ayarlaniyor...")
                    perde.setCurtainStatus(0.0)
                    time.sleep(1)
                elif key == '2':
                    print("\n>> Perde %50'ye ayarlaniyor...")
                    perde.setCurtainStatus(50.0)
                    time.sleep(1)
                elif key == '3':
                    print("\n>> Perde %100'e ayarlaniyor...")
                    perde.setCurtainStatus(100.0)
                    time.sleep(1)
                elif key == '4':
                    print("Cikis...")
                    perde.close()
                    break
            
            # Veri akis hizi
            time.sleep(0.5)

        except KeyboardInterrupt:
            perde.close()
            break

if __name__ == "__main__":
    main()