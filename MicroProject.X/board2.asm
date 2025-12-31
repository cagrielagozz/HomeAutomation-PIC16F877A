;******************************************************************************
;   Project:        Term Project - Board #2 (Curtain Control System)
;   Target:         PIC16F877A
;   Frequency:      4 MHz (HS Oscillator)
;   Description:    Manages Stepper Motor (Curtain), Sensors (LDR, BMP180),
;                   and UART Communication with PC.
;   Authors:	    Ça?r? Elagöz, U?ur Semih Karaman, Halil Arslan, Melis Çoksüren   
;******************************************************************************
    
;==============================================================================
;   PIN CONNECTION DIAGRAM (PINOUT)
;==============================================================================
;   1. STEP MOTOR (Curtain Movement)
;------------------------------------------------------------------------------
;   Port: PORTB (RB4, RB5, RB6, RB7)
;   Type: Digital Output
;   Description: Driver pins for 4-Phase Unipolar Step Motor.
;
;   RB4  ---> IN1 (Coil 1 / A)
;   RB5  ---> IN2 (Coil 2 / B)
;   RB6  ---> IN3 (Coil 3 / C)
;   RB7  ---> IN4 (Coil 4 / D)
;
;------------------------------------------------------------------------------
;   2. LDR LIGHT SENSOR (Ambient Light)
;------------------------------------------------------------------------------
;   Port: RA0 (AN0)
;   Type: Analog Input
;   Description: Measures ambient light intensity. Reads voltage divider output.
;
;   RA0 (AN0) <--- LDR Analog Output
;
;------------------------------------------------------------------------------
;   3. BMP180 (Outdoor Temperature & Pressure Sensor)
;------------------------------------------------------------------------------
;   Port: I2C (RC3, RC4)
;   Type: I2C Communication
;   Description: Interface for outdoor temperature and pressure data.
;
;   RC3 (SCL) <---> BMP180 SCL (Clock)
;   RC4 (SDA) <---> BMP180 SDA (Data)
;
;------------------------------------------------------------------------------
;   4. ROTARY POTENTIOMETER (Manual Curtain Adjustment)
;------------------------------------------------------------------------------
;   Port: RA1 (AN1)
;   Type: Analog Input
;   Description: User knob for manual curtain level setting (0% - 100%).
;
;   RA1 (AN1) <--- Potentiometer Wiper (Middle Pin)
;
;------------------------------------------------------------------------------
;   5. LCD DISPLAY (hd44780 - 16x2 Character)
;------------------------------------------------------------------------------
;   Bus Mode: 4-Bit Mode (D4-D7)
;   Control:  RS, E (RW is usually grounded)
;
;   RD2  ---> LCD RS (Register Select)
;   RD3  ---> LCD E  (Enable)
;   RD4  ---> LCD D4 (Data 4)
;   RD5  ---> LCD D5 (Data 5)
;   RD6  ---> LCD D6 (Data 6)
;   RD7  ---> LCD D7 (Data 7)
;   GND  ---> LCD RW (Read/Write) - Write Mode Only
;
;------------------------------------------------------------------------------
;   6. SERIAL COMMUNICATION (UART - PC Connection)
;------------------------------------------------------------------------------
;   Port: RC6, RC7
;   Type: UART (Asynchronous Serial)
;
;   RC6 (TX) ---> UART Transmit (Send Data to PC)
;   RC7 (RX) <--- UART Receive (Receive Data from PC)
;
;------------------------------------------------------------------------------    
    
    

    PROCESSOR   16F877A
    #include    <xc.inc>

    ; --- CONFIGURATION BITS ---
    CONFIG  FOSC = HS           ; Oscillator Selection: High Speed Crystal
    CONFIG  WDTE = OFF          ; Watchdog Timer: Disabled
    CONFIG  PWRTE = ON          ; Power-up Timer: Enabled
    CONFIG  BOREN = OFF         ; Brown-out Reset: Disabled
    CONFIG  LVP = OFF           ; Low Voltage Programming: Disabled
    CONFIG  CPD = OFF           ; Data EEPROM Code Protection: Disabled
    CONFIG  WRT = OFF           ; Flash Program Memory Write: Disabled
    CONFIG  CP = OFF            ; Flash Program Memory Code Protection: Disabled

;====================================================================
; VARIABLE DEFINITIONS (RAM - BANK 0)
;====================================================================
PSECT udata
    ; --- Timing & Counters ---
    CNT1:               DS 1
    CNT2:               DS 1
    CNT3:               DS 1
    LOOP_COUNTER:       DS 1
    STEP_LOOP_CNT:      DS 1

    ; --- Curtain Control ---
    CURTAIN_TARGET:     DS 1
    CURTAIN_CURRENT:    DS 1
    CURTAIN_REQ_FRAC:   DS 1
    STEP_INDEX:         DS 1

    ; --- Sensor Data ---
    LIGHT_LEVEL:        DS 1
    TEMP_VALUE:         DS 1
    TEMP_FRAC:          DS 1
    PRESSURE_H:         DS 1
    PRESSURE_L:         DS 1
    
    ; --- Potentiometer Logic ---
    POT_VAL_NEW:        DS 1
    POT_VAL_LAST:       DS 1
    UART_MODE:          DS 1

    ; --- UART Variables ---
    UART_RX_DATA:       DS 1
    UART_CMD:           DS 1
    UART_TEMP:          DS 1

    ; --- Display Variables ---
    LCD_TEMP:           DS 1
    BCD_H:              DS 1
    BCD_T:              DS 1
    BCD_O:              DS 1
    MATH_TEMP:          DS 1

    ; --- I2C / BMP180 Variables ---
    B2_I2C_DATA:        DS 1
    BMP_MSB:            DS 1
    BMP_LSB:            DS 1

;====================================================================
; RESET VECTOR
;====================================================================
    PSECT code, abs
    ORG 0x0000
    GOTO MAIN
    ORG 0x0004
    RETFIE

;====================================================================
; LOOKUP TABLES
;====================================================================
GET_STEP_SEQ:
    ANDLW   0x03
    ADDWF   PCL, F
    RETLW   0b00000001
    RETLW   0b00000010
    RETLW   0b00000100
    RETLW   0b00001000

MAP_63_TO_100:
    ANDLW   0x3F
    ADDWF   PCL, F
    RETLW 0   ; 0
    RETLW 2   ; 1
    RETLW 3   ; 2
    RETLW 5   ; 3
    RETLW 6   ; 4
    RETLW 8   ; 5
    RETLW 10  ; 6
    RETLW 11  ; 7
    RETLW 13  ; 8
    RETLW 14  ; 9
    RETLW 16  ; 10
    RETLW 17  ; 11
    RETLW 19  ; 12
    RETLW 21  ; 13
    RETLW 22  ; 14
    RETLW 24  ; 15
    RETLW 25  ; 16
    RETLW 27  ; 17
    RETLW 29  ; 18
    RETLW 30  ; 19
    RETLW 32  ; 20
    RETLW 33  ; 21
    RETLW 35  ; 22
    RETLW 37  ; 23
    RETLW 38  ; 24
    RETLW 40  ; 25
    RETLW 41  ; 26
    RETLW 43  ; 27
    RETLW 44  ; 28
    RETLW 46  ; 29
    RETLW 48  ; 30
    RETLW 49  ; 31
    RETLW 51  ; 32
    RETLW 52  ; 33
    RETLW 54  ; 34
    RETLW 56  ; 35
    RETLW 57  ; 36
    RETLW 59  ; 37
    RETLW 60  ; 38
    RETLW 62  ; 39
    RETLW 63  ; 40
    RETLW 65  ; 41
    RETLW 67  ; 42
    RETLW 68  ; 43
    RETLW 70  ; 44
    RETLW 71  ; 45
    RETLW 73  ; 46
    RETLW 75  ; 47
    RETLW 76  ; 48
    RETLW 78  ; 49
    RETLW 79  ; 50
    RETLW 81  ; 51
    RETLW 83  ; 52
    RETLW 84  ; 53
    RETLW 86  ; 54
    RETLW 87  ; 55
    RETLW 89  ; 56
    RETLW 90  ; 57
    RETLW 92  ; 58
    RETLW 94  ; 59
    RETLW 95  ; 60
    RETLW 97  ; 61
    RETLW 98  ; 62
    RETLW 100 ; 63

;====================================================================
; MAIN PROGRAM
;====================================================================
MAIN:
    CALL    SYSTEM_INIT
    CALL    UART_INIT
    CALL    B2_I2C_INIT
    CALL    LCD_INIT
    CALL    LCD_STATIC_UI

    ; --- Initial Values ---
    CLRF    CURTAIN_CURRENT
    CLRF    CURTAIN_TARGET
    CLRF    STEP_INDEX
    CLRF    UART_MODE
    CLRF    POT_VAL_LAST
    
    ; Clear Sensor Vars
    CLRF    TEMP_VALUE
    CLRF    TEMP_FRAC
    CLRF    PRESSURE_H
    CLRF    PRESSURE_L

;====================================================================
; MAIN LOOP
;====================================================================
LOOP:
    CALL    UART_HANDLE

    ; Logic Update Frequency
    INCF    LOOP_COUNTER, F
    MOVLW   10
    SUBWF   LOOP_COUNTER, W
    BTFSS   STATUS, 0
    GOTO    LOOP
    CLRF    LOOP_COUNTER

    CALL    READ_SENSORS
    CALL    LOGIC_CONTROL
    CALL    UPDATE_DISPLAY
    
    GOTO    LOOP

;====================================================================
; I2C & BMP180 SUBROUTINES (CORRECTED BANKING)
;====================================================================

B2_I2C_INIT:
    BANKSEL SSPSTAT
    BSF     SSPSTAT, 7      ; SMP=1
    BCF     SSPSTAT, 6      ; CKE=0
    
    BANKSEL SSPCON
    MOVLW   0b00101000      ; SSPEN=1, Master Mode
    MOVWF   SSPCON
    
    BANKSEL SSPADD
    MOVLW   9               ; 100kHz @ 4MHz
    MOVWF   SSPADD
    BANKSEL PORTA
    RETURN

B2_I2C_WAIT:
    BANKSEL SSPSTAT
B2_I2C_WAIT_LOOP:
    BTFSC   SSPSTAT, 2      ; R/W bit
    GOTO    B2_I2C_WAIT_LOOP
    
    BANKSEL SSPCON2
    MOVF    SSPCON2, W
    ANDLW   0x1F            ; Check ACKEN, RCEN, PEN, RSEN, SEN
    BTFSS   STATUS, 2
    GOTO    B2_I2C_WAIT_LOOP
    BANKSEL PORTA
    RETURN

B2_I2C_START:
    CALL    B2_I2C_WAIT
    BANKSEL SSPCON2
    BSF     SSPCON2, 0      ; SEN
    GOTO    B2_I2C_WAIT

B2_I2C_RESTART:
    CALL    B2_I2C_WAIT
    BANKSEL SSPCON2
    BSF     SSPCON2, 1      ; RSEN
    GOTO    B2_I2C_WAIT

B2_I2C_STOP:
    CALL    B2_I2C_WAIT
    BANKSEL SSPCON2
    BSF     SSPCON2, 2      ; PEN
    GOTO    B2_I2C_WAIT

B2_I2C_WRITE:
    ; WREG has data. Make sure to save it safely.
    BANKSEL B2_I2C_DATA
    MOVWF   B2_I2C_DATA
    
    CALL    B2_I2C_WAIT
    
    BANKSEL B2_I2C_DATA
    MOVF    B2_I2C_DATA, W
    
    BANKSEL SSPBUF
    MOVWF   SSPBUF          ; Load buffer
    
    CALL    B2_I2C_WAIT
    
    BANKSEL SSPCON2
    BTFSC   SSPCON2, 6      ; Check ACKSTAT
    RETURN                  ; NACK received
    RETURN                  ; ACK received

B2_I2C_READ:
    ; WREG has ACK (0) or NACK (1) request
    BANKSEL UART_TEMP
    MOVWF   UART_TEMP       ; Save request safely
    
    CALL    B2_I2C_WAIT
    BANKSEL SSPCON2
    BSF     SSPCON2, 3      ; RCEN (Enable Receive)
    CALL    B2_I2C_WAIT
    
    BANKSEL SSPBUF
    MOVF    SSPBUF, W       ; Read Buffer
    BANKSEL B2_I2C_DATA
    MOVWF   B2_I2C_DATA     ; Save Data
    
    CALL    B2_I2C_WAIT
    
    ; --- ACK/NACK Sequence ---
    BANKSEL UART_TEMP
    BTFSC   UART_TEMP, 0    ; Check if NACK needed
    GOTO    DO_NACK
    ; DO ACK
    BANKSEL SSPCON2
    BCF     SSPCON2, 5      ; ACKDT = 0
    GOTO    COMPLETE_ACK
DO_NACK:
    BANKSEL SSPCON2
    BSF     SSPCON2, 5      ; ACKDT = 1
COMPLETE_ACK:
    BSF     SSPCON2, 4      ; ACKEN (Start ACK sequence)
    CALL    B2_I2C_WAIT
    
    BANKSEL B2_I2C_DATA
    MOVF    B2_I2C_DATA, W  ; Return read value in W
    RETURN

BMP180_READ_TEMP:
    ; 1. Start Measurement
    CALL    B2_I2C_START
    MOVLW   0xEE            ; Address (Write)
    CALL    B2_I2C_WRITE
    MOVLW   0xF4            ; Control Register
    CALL    B2_I2C_WRITE
    MOVLW   0x2E            ; Command: Read Temperature
    CALL    B2_I2C_WRITE
    CALL    B2_I2C_STOP
    
    ; 2. Wait
    MOVLW   10
    CALL    DELAY_MS
    
    ; 3. Read Result
    CALL    B2_I2C_START
    MOVLW   0xEE
    CALL    B2_I2C_WRITE
    MOVLW   0xF6            ; Data Register MSB
    CALL    B2_I2C_WRITE
    
    CALL    B2_I2C_RESTART
    MOVLW   0xEF            ; Address (Read)
    CALL    B2_I2C_WRITE
    
    MOVLW   0               ; ACK
    CALL    B2_I2C_READ
    BANKSEL BMP_MSB
    MOVWF   BMP_MSB
    
    MOVLW   1               ; NACK
    CALL    B2_I2C_READ
    BANKSEL BMP_LSB
    MOVWF   BMP_LSB
    
    CALL    B2_I2C_STOP
    
    BANKSEL BMP_MSB
    MOVF    BMP_MSB, W
    BANKSEL TEMP_VALUE
    MOVWF   TEMP_VALUE      ; Use MSB for visualization
    RETURN

BMP180_READ_PRESS:
    ; 1. Start Measurement
    CALL    B2_I2C_START
    MOVLW   0xEE
    CALL    B2_I2C_WRITE
    MOVLW   0xF4
    CALL    B2_I2C_WRITE
    MOVLW   0x34            ; Command: Read Pressure
    CALL    B2_I2C_WRITE
    CALL    B2_I2C_STOP
    
    ; 2. Wait
    MOVLW   10
    CALL    DELAY_MS
    
    ; 3. Read Result
    CALL    B2_I2C_START
    MOVLW   0xEE
    CALL    B2_I2C_WRITE
    MOVLW   0xF6
    CALL    B2_I2C_WRITE
    
    CALL    B2_I2C_RESTART
    MOVLW   0xEF
    CALL    B2_I2C_WRITE
    
    MOVLW   0               ; ACK
    CALL    B2_I2C_READ
    BANKSEL BMP_MSB
    MOVWF   BMP_MSB
    
    MOVLW   1               ; NACK
    CALL    B2_I2C_READ
    BANKSEL BMP_LSB
    MOVWF   BMP_LSB
    
    CALL    B2_I2C_STOP
    
    BANKSEL BMP_MSB
    MOVF    BMP_MSB, W
    BANKSEL PRESSURE_H
    MOVWF   PRESSURE_H
    
    BANKSEL BMP_LSB
    MOVF    BMP_LSB, W
    BANKSEL PRESSURE_L
    MOVWF   PRESSURE_L
    RETURN

;====================================================================
; UART SUBROUTINES
;====================================================================

UART_INIT:
    BANKSEL SPBRG
    MOVLW   25
    MOVWF   SPBRG
    MOVLW   0b00100100
    MOVWF   TXSTA
    BANKSEL RCSTA
    MOVLW   0b10010000
    MOVWF   RCSTA
    BANKSEL PORTA
    RETURN

UART_TX_BYTE:
    BANKSEL UART_TEMP
    MOVWF   UART_TEMP
    BANKSEL TXSTA
WAIT_TX:
    BTFSS   TXSTA, 1
    GOTO    WAIT_TX
    BANKSEL TXREG
    MOVF    UART_TEMP, W
    MOVWF   TXREG
    BANKSEL PORTA
    RETURN

UART_HANDLE:
    BANKSEL RCSTA
    BTFSC   RCSTA, 1
    GOTO    UART_ERR_OERR
    BTFSC   RCSTA, 2
    GOTO    UART_ERR_FERR
    
    BANKSEL PIR1
    BTFSS   PIR1, 5
    RETURN
    
    BANKSEL RCREG
    MOVF    RCREG, W
    BANKSEL UART_RX_DATA
    MOVWF   UART_RX_DATA
    
    BTFSC   UART_RX_DATA, 7
    GOTO    CMD_IS_SET
    
    MOVF    UART_RX_DATA, W
    XORLW   0x01
    BTFSC   STATUS, 2
    GOTO    SND_REQ_L
    
    MOVF    UART_RX_DATA, W
    XORLW   0x02
    BTFSC   STATUS, 2
    GOTO    SND_REQ_H
    
    MOVF    UART_RX_DATA, W
    XORLW   0x03
    BTFSC   STATUS, 2
    GOTO    SND_TEMP_L
    
    MOVF    UART_RX_DATA, W
    XORLW   0x04
    BTFSC   STATUS, 2
    GOTO    SND_TEMP_H
    
    MOVF    UART_RX_DATA, W
    XORLW   0x05
    BTFSC   STATUS, 2
    GOTO    SND_PRES_L
    
    MOVF    UART_RX_DATA, W
    XORLW   0x06
    BTFSC   STATUS, 2
    GOTO    SND_PRES_H
    
    MOVF    UART_RX_DATA, W
    XORLW   0x07
    BTFSC   STATUS, 2
    GOTO    SND_LIG_L
    
    MOVF    UART_RX_DATA, W
    XORLW   0x08
    BTFSC   STATUS, 2
    GOTO    SND_LIG_H
    RETURN

UART_ERR_OERR:
    BCF     RCSTA, 4
    BSF     RCSTA, 4
    RETURN

UART_ERR_FERR:
    MOVF    RCREG, W
    RETURN

; --- SEND RESPONSES ---
SND_REQ_L:
    MOVF    CURTAIN_REQ_FRAC, W
    GOTO    UART_TX_BYTE
SND_REQ_H:
    MOVF    CURTAIN_TARGET, W
    GOTO    UART_TX_BYTE
SND_TEMP_L:
    MOVF    TEMP_FRAC, W
    GOTO    UART_TX_BYTE
SND_TEMP_H:
    MOVF    TEMP_VALUE, W
    GOTO    UART_TX_BYTE
SND_PRES_L:
    MOVF    PRESSURE_L, W
    GOTO    UART_TX_BYTE
SND_PRES_H:
    MOVF    PRESSURE_H, W
    GOTO    UART_TX_BYTE
SND_LIG_L:
    MOVLW   0
    GOTO    UART_TX_BYTE
SND_LIG_H:
    MOVF    LIGHT_LEVEL, W
    GOTO    UART_TX_BYTE

; --- SET COMMANDS ---
CMD_IS_SET:
    BTFSC   UART_RX_DATA, 6
    GOTO    SET_INT
    
SET_FRAC:
    MOVF    UART_RX_DATA, W
    ANDLW   0x3F
    MOVWF   CURTAIN_REQ_FRAC
    MOVLW   1
    MOVWF   UART_MODE
    RETURN

SET_INT:
    MOVF    UART_RX_DATA, W
    ANDLW   0x3F
    CALL    MAP_63_TO_100
    MOVWF   CURTAIN_TARGET
    MOVLW   1
    MOVWF   UART_MODE
    RETURN

;====================================================================
; SENSORS & LOGIC
;====================================================================

READ_SENSORS:
    ; 1. LDR
    MOVLW   0
    CALL    READ_ADC
    MOVWF   LIGHT_LEVEL
    
    ; 2. Pot
    MOVLW   2
    CALL    READ_ADC
    MOVWF   MATH_TEMP
    BCF     STATUS, 0
    RRF     MATH_TEMP, F
    MOVLW   100
    SUBWF   MATH_TEMP, W
    BTFSC   STATUS, 0
    MOVLW   100
    BTFSS   STATUS, 0
    MOVF    MATH_TEMP, W
    MOVWF   POT_VAL_NEW
    
    ; 3. BMP180
    CALL    BMP180_READ_TEMP
    CALL    BMP180_READ_PRESS

    ; 4. Mode
    MOVF    POT_VAL_NEW, W
    SUBWF   POT_VAL_LAST, W
    BTFSC   STATUS, 2
    GOTO    CHECK_MODE
    
    MOVF    POT_VAL_NEW, W
    MOVWF   POT_VAL_LAST
    CLRF    UART_MODE
    MOVWF   CURTAIN_TARGET

CHECK_MODE:
    MOVF    UART_MODE, W
    BTFSS   STATUS, 2
    RETURN
    MOVF    POT_VAL_NEW, W
    MOVWF   CURTAIN_TARGET
    RETURN

READ_ADC:
    BANKSEL ADCON0
    MOVWF   MATH_TEMP
    RLF     MATH_TEMP, F
    RLF     MATH_TEMP, F
    RLF     MATH_TEMP, W
    ANDLW   0b00111000
    IORLW   0b10000001
    MOVWF   ADCON0
    NOP
    NOP
    NOP
    NOP
    BSF     ADCON0, 2
WAIT_ADC:
    BTFSC   ADCON0, 2
    GOTO    WAIT_ADC
    BANKSEL ADRESH
    MOVF    ADRESH, W
    BANKSEL PORTA
    RETURN

LOGIC_CONTROL:
    MOVLW   60
    SUBWF   LIGHT_LEVEL, W
    BTFSS   STATUS, 0
    GOTO    NIGHT_MODE
    GOTO    MOTOR_CONTROL
NIGHT_MODE:
    MOVLW   100
    MOVWF   CURTAIN_TARGET
MOTOR_CONTROL:
    MOVF    CURTAIN_TARGET, W
    SUBWF   CURTAIN_CURRENT, W
    BTFSC   STATUS, 2
    RETURN
    BTFSS   STATUS, 0
    GOTO    MOVE_CLOSE
    GOTO    MOVE_OPEN

MOVE_CLOSE:
    MOVLW   10
    MOVWF   STEP_LOOP_CNT
L_CLOSE:
    CALL    STEP_FWD
    DECFSZ  STEP_LOOP_CNT, F
    GOTO    L_CLOSE
    INCF    CURTAIN_CURRENT, F
    RETURN

MOVE_OPEN:
    MOVLW   10
    MOVWF   STEP_LOOP_CNT
L_OPEN:
    CALL    STEP_BCK
    DECFSZ  STEP_LOOP_CNT, F
    GOTO    L_OPEN
    DECF    CURTAIN_CURRENT, F
    RETURN

STEP_FWD:
    INCF    STEP_INDEX, F
    GOTO    DRIVE_STEP
STEP_BCK:
    DECF    STEP_INDEX, F
DRIVE_STEP:
    MOVF    STEP_INDEX, W
    CALL    GET_STEP_SEQ
    MOVWF   PORTB
    MOVLW   5
    CALL    DELAY_MS
    RETURN

;====================================================================
; DISPLAY ROUTINES
;====================================================================
UPDATE_DISPLAY:
    MOVLW   0x82
    CALL    LCD_CMD
    MOVF    TEMP_VALUE, W
    CALL    PRINT_2DIGIT
    
    MOVLW   0x8B
    CALL    LCD_CMD
    MOVF    PRESSURE_H, W
    CALL    PRINT_2DIGIT
    
    MOVLW   0xC2
    CALL    LCD_CMD
    MOVF    LIGHT_LEVEL, W
    CALL    PRINT_3DIGIT
    
    MOVLW   0xCB
    CALL    LCD_CMD
    MOVF    CURTAIN_CURRENT, W
    CALL    PRINT_3DIGIT
    RETURN

; --- LCD UTILS ---
LCD_INIT:
    MOVLW   100
    CALL    DELAY_MS
    MOVLW   0x38
    CALL    LCD_CMD
    MOVLW   0x0C
    CALL    LCD_CMD
    MOVLW   0x01
    CALL    LCD_CMD
    MOVLW   0x06
    CALL    LCD_CMD
    RETURN

LCD_STATIC_UI:
    MOVLW   0x80
    CALL    LCD_CMD
    MOVLW   'T'
    CALL    LCD_DATA
    MOVLW   ':'
    CALL    LCD_DATA
    MOVLW   0x87
    CALL    LCD_CMD
    MOVLW   'P'
    CALL    LCD_DATA
    MOVLW   ':'
    CALL    LCD_DATA
    MOVLW   0xC0
    CALL    LCD_CMD
    MOVLW   'L'
    CALL    LCD_DATA
    MOVLW   ':'
    CALL    LCD_DATA
    MOVLW   0xC7
    CALL    LCD_CMD
    MOVLW   'C'
    CALL    LCD_DATA
    MOVLW   ':'
    CALL    LCD_DATA
    RETURN

LCD_CMD:
    BANKSEL PORTD
    MOVWF   PORTD
    BCF     PORTE, 0
    BSF     PORTE, 1
    NOP
    BCF     PORTE, 1
    MOVLW   2
    CALL    DELAY_MS
    RETURN

LCD_DATA:
    BANKSEL PORTD
    MOVWF   PORTD
    BSF     PORTE, 0
    BSF     PORTE, 1
    NOP
    BCF     PORTE, 1
    MOVLW   1
    CALL    DELAY_MS
    RETURN

PRINT_3DIGIT:
    MOVWF   LCD_TEMP
    CLRF    BCD_H
    CLRF    BCD_T
    CLRF    BCD_O
C_100:
    MOVLW   100
    SUBWF   LCD_TEMP, W
    BTFSS   STATUS, 0
    GOTO    C_10
    MOVWF   LCD_TEMP
    INCF    BCD_H, F
    GOTO    C_100
C_10:
    MOVLW   10
    SUBWF   LCD_TEMP, W
    BTFSS   STATUS, 0
    GOTO    C_1
    MOVWF   LCD_TEMP
    INCF    BCD_T, F
    GOTO    C_10
C_1:
    MOVF    LCD_TEMP, W
    MOVWF   BCD_O
    MOVF    BCD_H, W
    ADDLW   '0'
    CALL    LCD_DATA
    MOVF    BCD_T, W
    ADDLW   '0'
    CALL    LCD_DATA
    MOVF    BCD_O, W
    ADDLW   '0'
    CALL    LCD_DATA
    RETURN

PRINT_2DIGIT:
    MOVWF   LCD_TEMP
    CLRF    BCD_T
C_10_2:
    MOVLW   10
    SUBWF   LCD_TEMP, W
    BTFSS   STATUS, 0
    GOTO    C_1_2
    MOVWF   LCD_TEMP
    INCF    BCD_T, F
    GOTO    C_10_2
C_1_2:
    MOVF    BCD_T, W
    ADDLW   '0'
    CALL    LCD_DATA
    MOVF    LCD_TEMP, W
    ADDLW   '0'
    CALL    LCD_DATA
    RETURN

; --- SYSTEM INIT ---
SYSTEM_INIT:
    BANKSEL ADCON1
    MOVLW   0x02
    MOVWF   ADCON1
    BANKSEL TRISA
    MOVLW   0xFF
    MOVWF   TRISA
    CLRF    TRISB
    BSF     TRISC, 7
    BCF     TRISC, 6
    BSF     TRISC, 3
    BSF     TRISC, 4
    CLRF    TRISD
    CLRF    TRISE
    BANKSEL PORTA
    CLRF    PORTB
    CLRF    PORTD
    CLRF    PORTE
    RETURN

DELAY_MS:
    BANKSEL CNT3
    MOVWF   CNT3
DL1:
    MOVLW   200
    MOVWF   CNT1
DL2:
    DECFSZ  CNT1, F
    GOTO    DL2
    DECFSZ  CNT3, F
    GOTO    DL1
    RETURN

    END