;------------------------------------------------------------------------------
;   Project:        Term Project - Board #1 (Air Conditioner)
;   Target:         PIC16F877A
;   Frequency:      4 MHz
;   Authors:	    Ça?r? Elagöz, U?ur Semih Karaman    
;------------------------------------------------------------------------------
    
;==============================================================================
;   PIN CONNECTION DIAGRAM (PINOUT)
;==============================================================================
;   1. TEMPERATURE SYSTEM
;------------------------------------------------------------------------------
;   RA0 (AN0)   <--- LM35 Temperature Sensor (Analog Input)
;   RA4 (T0CKI) <--- Fan Tachometer (Timer0 External Clock Input - RPM Measurement)
;   RE0         ---> Heater Control (1=ON, 0=OFF)
;   RE1         ---> Cooler/Fan Control (1=ON, 0=OFF)
;
;------------------------------------------------------------------------------
;   2. 7-SEGMENT DISPLAY (Multiplexed)
;------------------------------------------------------------------------------
;   PORTB (All)    ---> Segment Lines (a, b, c, d, e, f, g, dp)
;       RB0 -> a
;       RB1 -> b
;       ...
;       RB7 -> dp (Decimal Point)
;
;   PORTD (High 4) ---> Digit Select Lines (Active High Enable)
;       RD4 ---> DIGIT 1 (Leftmost - Displays "d", "A", or "F")
;       RD5 ---> DIGIT 2 (Tens Digit)
;       RD6 ---> DIGIT 3 (Ones Digit)
;       RD7 ---> DIGIT 4 (Rightmost - Fractional Part)
;
;------------------------------------------------------------------------------
;   3. KEYPAD (4x3 or 4x4 Matrix)
;------------------------------------------------------------------------------
;   PORTA (Selected) ---> Columns - OUTPUT (Scanning)
;       RA1 ---> Column 1 (1, 4, 7, *)
;       RA2 ---> Column 2 (2, 5, 8, 0)
;       RA3 ---> Column 3 (3, 6, 9, #)
;       RA5 ---> Column 4 (A, B, C, D)  *(Note: RA5 used as RA4 is T0CKI)*
;
;   PORTD (Low 4)    ---> Rows - INPUT (Reading)
;       RD0 <--- Row 1 (1, 2, 3, A)
;       RD1 <--- Row 2 (4, 5, 6, B)
;       RD2 <--- Row 3 (7, 8, 9, C)
;       RD3 <--- Row 4 (*, 0, #, D)
;
;------------------------------------------------------------------------------
;   4. SERIAL COMMUNICATION (UART)
;------------------------------------------------------------------------------
;   RC6 (TX)    ---> UART Transmit (Send Data to PC)
;   RC7 (RX)    <--- UART Receive (Receive Data from PC)
;
;------------------------------------------------------------------------------    

    PROCESSOR   16F877A
    #include    <xc.inc>

    ; --- CONFIGURATION BITS ---
    CONFIG  FOSC = HS       ; Oscillator Selection: High Speed Crystal
    CONFIG  WDTE = OFF      ; Watchdog Timer: Disabled
    CONFIG  PWRTE = ON      ; Power-up Timer: Enabled
    CONFIG  BOREN = OFF     ; Brown-out Reset: Disabled
    CONFIG  LVP = OFF       ; Low Voltage Programming: Disabled
    CONFIG  CPD = OFF       ; Data EEPROM Code Protection: Disabled
    CONFIG  WRT = OFF       ; Flash Program Memory Write: Disabled
    CONFIG  CP = OFF        ; Flash Program Memory Code Protection: Disabled    
    
;------------------------------------------------------------------------------
; VARIABLES (BANK 0 - UDATA)
;------------------------------------------------------------------------------
PSECT udata
    ; --- Counters / Timers ---
    DELAY_CNT1:     DS 1
    DELAY_CNT2:     DS 1
    DISP_TIMER:     DS 1
    DISP_PRESCALER: DS 1
    LOOP_COUNTER:   DS 1
    FEEDBACK_TIMER: DS 1
    
    ; --- Data Registers ---
    TEMP_AMB_INT:   DS 1    ; Ambient Temperature (Integer)
    TEMP_AMB_FRAC:  DS 1    ; Ambient Temperature (Fraction)
    TEMP_DES_INT:   DS 1    ; Desired Temperature (Integer)
    TEMP_DES_FRAC:  DS 1    ; Desired Temperature (Fraction)
    FAN_SPEED:      DS 1
    
    ; --- Display Data ---
    DISP_DIG1:      DS 1
    DISP_DIG2:      DS 1
    DISP_DIG3:      DS 1
    DISP_DIG4:      DS 1
    
    ; --- Input Management ---
    KEY_PRESSED:    DS 1
    LAST_KEY:       DS 1
    INPUT_STATE:    DS 1    ; 0:Normal, 1:Input, 2:Message, 3:Error
    INPUT_BUF:      DS 1    ; Buffer for integer input
    INPUT_FRAC:     DS 1    ; Buffer for fraction input
    IS_DOT:         DS 1    ; Is Dot pressed? (0=No, 1=Yes)
    
    ; --- Math / Temporary ---
    ADC_L:          DS 1
    MATH_TEMP:      DS 1
    DIGIT_TENS:     DS 1    ; BCD Conversion Tens Digit (Raw)
    DIGIT_ONES:     DS 1    ; BCD Conversion Ones Digit (Raw)
    
    ; --- UART ---
    UART_RX_DATA:   DS 1
    UART_TEMP:      DS 1

;------------------------------------------------------------------------------
; RESET VECTOR
;------------------------------------------------------------------------------
    PSECT   code, delta=2, abs
    ORG     0x0000
    GOTO    MAIN
    ORG     0x0004
    RETFIE

;------------------------------------------------------------------------------
; LOOKUP TABLE (7-Segment Character Map)
;------------------------------------------------------------------------------
GET_SEG:
    ANDLW   0x0F
    ADDWF   PCL, F
    RETLW   0b00111111      ; 0
    RETLW   0b00000110      ; 1
    RETLW   0b01011011      ; 2
    RETLW   0b01001111      ; 3
    RETLW   0b01100110      ; 4
    RETLW   0b01101101      ; 5
    RETLW   0b01111101      ; 6
    RETLW   0b00000111      ; 7
    RETLW   0b01111111      ; 8
    RETLW   0b01101111      ; 9
    RETLW   0b00000000      ; 10
    RETLW   0b00000000      ; 11
    RETLW   0b00000000      ; 12
    RETLW   0b00000000      ; 13
    RETLW   0b00000000      ; 14
    RETLW   0b00000000      ; 15

;------------------------------------------------------------------------------
; MAIN PROGRAM
;------------------------------------------------------------------------------
MAIN:
    CALL    SYSTEM_INIT
    CALL    UART_INIT
    
    ; Variable Initialization / Reset
    CLRF    TEMP_AMB_INT
    CLRF    TEMP_AMB_FRAC
    CLRF    TEMP_DES_FRAC
    CLRF    INPUT_STATE
    CLRF    IS_DOT
    
    ; Default Temperature: 25.0 C
    MOVLW   25
    MOVWF   TEMP_DES_INT
    MOVLW   0
    MOVWF   TEMP_DES_FRAC
    
    MOVLW   0xFF
    MOVWF   LAST_KEY

    ; Startup Signal / Beep
    BSF     PORTE, 0
    CALL    DELAY_MS
    BCF     PORTE, 0

;==============================================================================
; MAIN LOOP
;==============================================================================
LOOP:
    ; 1. Display Refresh (Multiplexing - High Speed)
    CALL    REFRESH_DISPLAY
    
    ; 2. UART Check / Handling
    CALL    UART_HANDLE
    
    ; 3. Logic Slowdown / Loop Timing
    INCF    LOOP_COUNTER, F
    MOVLW   25
    SUBWF   LOOP_COUNTER, W
    BTFSS   STATUS, 0
    GOTO    LOOP
    
    CLRF    LOOP_COUNTER
    
    ; --- SLOW LOGIC OPERATIONS ---
    
    ; Read sensor if not in input mode
    MOVF    INPUT_STATE, W
    BTFSS   STATUS, 2       ; Is State == 0?
    GOTO    SKIP_SENSOR
    
    CALL    READ_SENSOR
    CALL    CALC_FAN_LOGIC
    CALL    CONTROL_TEMP
    
SKIP_SENSOR:
    CALL    CHECK_KEYPAD
    CALL    UPDATE_DISPLAY_DATA
    CALL    HANDLE_TIMERS

    GOTO    LOOP

;==============================================================================
; SUBROUTINES
;==============================================================================

;------------------------------------------------------------------------------
; PREPARE DISPLAY DATA
;------------------------------------------------------------------------------
UPDATE_DISPLAY_DATA:
    MOVF    INPUT_STATE, W
    BTFSC   STATUS, 2       ; State 0 (Normal)
    GOTO    DISPLAY_NORMAL
    
    XORLW   1               ; State 1 (Input)
    BTFSC   STATUS, 2
    GOTO    DISPLAY_INPUT
    
    XORLW   3               ; Was State 2 (Saved)
    BTFSC   STATUS, 2
    GOTO    DISPLAY_SAVED
    
    ; State 3 (Error)
    GOTO    DISPLAY_ERROR

DISPLAY_INPUT:
    ; Split input into BCD
    MOVF    INPUT_BUF, W
    CALL    BIN_TO_BCD      ; Updates DIGIT_TENS and DIGIT_ONES
    
    MOVF    IS_DOT, W
    BTFSS   STATUS, 2       ; If IS_DOT != 0 (Dot pressed)
    GOTO    SHOW_INP_WITH_DOT
    
    ; --- If Dot NOT PRESSED (Integer Only) ---
    ; Format: [ ][ ][Tens][Ones]
    MOVLW   0
    MOVWF   DISP_DIG1
    MOVWF   DISP_DIG2       ; Left side blank
    
    MOVF    DIGIT_TENS, W   ; Tens digit
    CALL    GET_SEG
    MOVWF   DISP_DIG3
    
    MOVF    DIGIT_ONES, W   ; Ones digit
    CALL    GET_SEG
    MOVWF   DISP_DIG4
    RETURN

SHOW_INP_WITH_DOT:
    ; --- If Dot PRESSED (25.5 format) ---
    ; Format: [ ][Tens][Ones.][Fraction]
    MOVLW   0
    MOVWF   DISP_DIG1       ; Far left blank
    
    MOVF    DIGIT_TENS, W   ; Tens -> Shifted to DIG2
    CALL    GET_SEG
    MOVWF   DISP_DIG2
    
    MOVF    DIGIT_ONES, W   ; Ones -> Shifted to DIG3 + Dot
    CALL    GET_SEG
    IORLW   0b10000000      ; <--- Set Bit 7 (Dot point). (Instead of BSF)
    MOVWF   DISP_DIG3
    
    MOVF    INPUT_FRAC, W   ; Fraction -> DIG4
    CALL    GET_SEG
    MOVWF   DISP_DIG4
    RETURN

DISPLAY_SAVED:
    ; "SS" (Saved)
    MOVLW   0b01101101      ; S
    MOVWF   DISP_DIG1
    MOVWF   DISP_DIG2
    CLRF    DISP_DIG3
    CLRF    DISP_DIG4
    RETURN

DISPLAY_ERROR:
    ; "Err"
    MOVLW   0b01111001      ; E
    MOVWF   DISP_DIG1
    MOVLW   0b01010000      ; r
    MOVWF   DISP_DIG2
    MOVWF   DISP_DIG3
    CLRF    DISP_DIG4
    RETURN

DISPLAY_NORMAL:
    ; Automatic Display Rotation (Cycling)
    MOVF    DISP_TIMER, W
    SUBLW   60
    BTFSC   STATUS, 0
    GOTO    SHOW_DES
    MOVF    DISP_TIMER, W
    SUBLW   120
    BTFSC   STATUS, 0
    GOTO    SHOW_AMB
    GOTO    SHOW_FAN

SHOW_DES:
    ; "d XX.X"
    MOVLW   0b01011110      ; 'd' (Desired)
    MOVWF   DISP_DIG1
    
    MOVF    TEMP_DES_INT, W
    CALL    BIN_TO_BCD
    
    MOVF    DIGIT_TENS, W   ; Tens
    CALL    GET_SEG
    MOVWF   DISP_DIG2
    
    MOVF    DIGIT_ONES, W   ; Ones + Dot
    CALL    GET_SEG
    IORLW   0b10000000      ; <--- Set Bit 7 (Dot point)
    MOVWF   DISP_DIG3
    
    MOVF    TEMP_DES_FRAC, W ; Fraction
    CALL    GET_SEG
    MOVWF   DISP_DIG4
    RETURN

SHOW_AMB:
    ; "A XX.X"
    MOVLW   0b01110111      ; 'A' (Ambient)
    MOVWF   DISP_DIG1
    
    MOVF    TEMP_AMB_INT, W
    CALL    BIN_TO_BCD
    
    MOVF    DIGIT_TENS, W
    CALL    GET_SEG
    MOVWF   DISP_DIG2
    
    MOVF    DIGIT_ONES, W
    CALL    GET_SEG
    IORLW   0b10000000      ; <--- Set Bit 7 (Dot point)
    MOVWF   DISP_DIG3
    
    MOVF    TEMP_AMB_FRAC, W
    CALL    GET_SEG
    MOVWF   DISP_DIG4
    RETURN

SHOW_FAN:
    ; "F XX" (Fan Speed Integer)
    MOVLW   0b01110001      ; 'F' (Fan)
    MOVWF   DISP_DIG1
    
    MOVF    FAN_SPEED, W
    CALL    BIN_TO_BCD
    
    MOVF    DIGIT_TENS, W
    CALL    GET_SEG
    MOVWF   DISP_DIG2
    
    MOVF    DIGIT_ONES, W
    CALL    GET_SEG
    MOVWF   DISP_DIG3
    
    CLRF    DISP_DIG4       ; Last digit blank
    RETURN

;------------------------------------------------------------------------------
; HELPER FUNCTIONS
;------------------------------------------------------------------------------
BIN_TO_BCD:
    ; Splits value in WREG into Tens and Ones.
    ; Writes RAW results to DIGIT_TENS and DIGIT_ONES.
    MOVWF   MATH_TEMP
    CLRF    DIGIT_TENS
CALC_TENS:
    MOVLW   10
    SUBWF   MATH_TEMP, W
    BTFSS   STATUS, 0
    GOTO    CALC_DONE
    MOVWF   MATH_TEMP
    INCF    DIGIT_TENS, F
    GOTO    CALC_TENS
CALC_DONE:
    MOVF    MATH_TEMP, W
    MOVWF   DIGIT_ONES
    RETURN

;------------------------------------------------------------------------------
; KEYPAD AND INPUT LOGIC
;------------------------------------------------------------------------------
CHECK_KEYPAD:
    CALL    SCAN_RAW
    MOVWF   KEY_PRESSED
    
    MOVF    KEY_PRESSED, W
    SUBWF   LAST_KEY, W
    BTFSC   STATUS, 2
    RETURN
    
    MOVF    KEY_PRESSED, W
    MOVWF   LAST_KEY
    CALL    DELAY_MS        ; Debounce
    
    MOVF    KEY_PRESSED, W
    XORLW   0xFF
    BTFSC   STATUS, 2
    RETURN

    ; --- KEY PROCESSING ---
    MOVF    KEY_PRESSED, W
    XORLW   10              ; 'A' Key (Start Input)
    BTFSC   STATUS, 2
    GOTO    ON_KEY_A
    
    MOVF    KEY_PRESSED, W
    XORLW   15              ; '#' Key (Confirm/Enter)
    BTFSC   STATUS, 2
    GOTO    ON_KEY_HASH
    
    MOVF    KEY_PRESSED, W
    XORLW   14              ; '*' Key (Dot/Decimal)
    BTFSC   STATUS, 2
    GOTO    ON_KEY_STAR
    
    ; Is it a Digit?
    MOVF    KEY_PRESSED, W
    SUBLW   9
    BTFSS   STATUS, 0
    RETURN
    
    ; Are we in Input Mode?
    MOVF    INPUT_STATE, W
    XORLW   1
    BTFSS   STATUS, 2
    RETURN
    
    GOTO    ADD_DIGIT

ON_KEY_A:
    MOVLW   1
    MOVWF   INPUT_STATE
    CLRF    INPUT_BUF       ; Reset integer part
    CLRF    INPUT_FRAC      ; Reset fraction part
    CLRF    IS_DOT          ; Reset dot flag
    RETURN

ON_KEY_STAR:
    MOVF    INPUT_STATE, W
    XORLW   1
    BTFSS   STATUS, 2
    RETURN
    
    MOVLW   1
    MOVWF   IS_DOT          ; Now entering fractional part
    RETURN

ADD_DIGIT:
    MOVF    IS_DOT, W
    BTFSS   STATUS, 2       ; Is Dot pressed?
    GOTO    ADD_FRAC_DIGIT
    
    ; --- ADD INTEGER DIGIT ---
    ; Previous value x 10 + New Key
    MOVF    INPUT_BUF, W
    MOVWF   MATH_TEMP
    BCF     STATUS, 0
    RLF     INPUT_BUF, F    ; x2
    BCF     STATUS, 0
    RLF     INPUT_BUF, F    ; x4
    BCF     STATUS, 0
    RLF     INPUT_BUF, F    ; x8
    MOVF    MATH_TEMP, W
    ADDWF   MATH_TEMP, F    ; x2
    MOVF    MATH_TEMP, W
    ADDWF   INPUT_BUF, F    ; x8 + x2 = x10
    
    MOVF    KEY_PRESSED, W
    ADDWF   INPUT_BUF, F
    RETURN

ADD_FRAC_DIGIT:
    ; Only single digit fraction accepted, write directly.
    MOVF    KEY_PRESSED, W
    MOVWF   INPUT_FRAC
    RETURN

ON_KEY_HASH:
    MOVF    INPUT_STATE, W
    XORLW   1
    BTFSS   STATUS, 2
    RETURN

    ; --- LIMIT CHECK (10.0 - 50.0) ---
    CALL    CHECK_LIMITS
    MOVF    INPUT_STATE, W
    XORLW   3               ; Error State?
    BTFSC   STATUS, 2
    RETURN

    ; Save / Store
    MOVF    INPUT_BUF, W
    MOVWF   TEMP_DES_INT
    MOVF    INPUT_FRAC, W
    MOVWF   TEMP_DES_FRAC
    
    MOVLW   2               ; Message Mode (Saved)
    MOVWF   INPUT_STATE
    CLRF    FEEDBACK_TIMER
    RETURN

CHECK_LIMITS:
    ; Lower Limit Check (10)
    MOVLW   10
    SUBWF   INPUT_BUF, W
    BTFSS   STATUS, 0       
    GOTO    LIMIT_ERROR
    
    ; Upper Limit Check (50)
    MOVF    INPUT_BUF, W
    SUBLW   50
    BTFSS   STATUS, 0       
    GOTO    LIMIT_ERROR
    
    ; If exactly 50, Fraction must be 0
    MOVF    INPUT_BUF, W
    XORLW   50
    BTFSS   STATUS, 2
    RETURN
    
    ; If 50, check fraction
    MOVF    INPUT_FRAC, W
    BTFSS   STATUS, 2
    GOTO    LIMIT_ERROR
    RETURN

LIMIT_ERROR:
    MOVLW   3               ; Error State
    MOVWF   INPUT_STATE
    CLRF    FEEDBACK_TIMER
    RETURN

;------------------------------------------------------------------------------
; UART OPERATIONS
;------------------------------------------------------------------------------
UART_INIT:
    BSF     STATUS, 5       ; BANK 1
    MOVLW   51              ; 8MHz, 9600 Baud
    MOVWF   SPBRG
    MOVLW   0b00100100      ; TXEN=1, BRGH=1
    MOVWF   TXSTA
    BCF     STATUS, 5       ; BANK 0
    MOVLW   0b10010000      ; SPEN=1, CREN=1
    MOVWF   RCSTA
    RETURN

UART_TX_BYTE:
    MOVWF   UART_TEMP
    BSF     STATUS, 5
WAIT_TX:
    BTFSS   TXSTA, 1
    GOTO    WAIT_TX
    BCF     STATUS, 5
    MOVF    UART_TEMP, W
    MOVWF   TXREG
    RETURN

UART_HANDLE:
    BTFSS   PIR1, 5
    RETURN
    
    MOVF    RCREG, W
    MOVWF   UART_RX_DATA
    
    ; GET Commands
    MOVF    UART_RX_DATA, W
    XORLW   0x01
    BTFSC   STATUS, 2
    GOTO    SND_DES_FRAC
    MOVF    UART_RX_DATA, W
    XORLW   0x02
    BTFSC   STATUS, 2
    GOTO    SND_DES_INT
    MOVF    UART_RX_DATA, W
    XORLW   0x03
    BTFSC   STATUS, 2
    GOTO    SND_AMB_FRAC
    MOVF    UART_RX_DATA, W
    XORLW   0x04
    BTFSC   STATUS, 2
    GOTO    SND_AMB_INT
    MOVF    UART_RX_DATA, W
    XORLW   0x05
    BTFSC   STATUS, 2
    GOTO    SND_FAN
    
    ; SET Commands
    GOTO    CHECK_SET_CMD

SND_DES_FRAC:
    MOVF    TEMP_DES_FRAC, W
    GOTO    UART_TX_BYTE
SND_DES_INT:
    MOVF    TEMP_DES_INT, W
    GOTO    UART_TX_BYTE
SND_AMB_FRAC:
    MOVF    TEMP_AMB_FRAC, W
    GOTO    UART_TX_BYTE
SND_AMB_INT:
    MOVF    TEMP_AMB_INT, W
    GOTO    UART_TX_BYTE
SND_FAN:
    MOVF    FAN_SPEED, W
    GOTO    UART_TX_BYTE

CHECK_SET_CMD:
    MOVF    UART_RX_DATA, W
    MOVWF   MATH_TEMP
    ANDLW   0b00111111      ; Data part
    MOVWF   DIGIT_ONES      ; Store temporarily
    
    MOVF    MATH_TEMP, W
    ANDLW   0b11000000
    XORLW   0b10000000      ; Set Frac
    BTFSC   STATUS, 2
    GOTO    SET_DES_FRAC
    
    MOVF    MATH_TEMP, W
    ANDLW   0b11000000
    XORLW   0b11000000      ; Set Int
    BTFSC   STATUS, 2
    GOTO    SET_DES_INT
    RETURN

SET_DES_FRAC:
    MOVF    DIGIT_ONES, W
    MOVWF   TEMP_DES_FRAC
    RETURN
SET_DES_INT:
    MOVF    DIGIT_ONES, W
    MOVWF   TEMP_DES_INT
    RETURN

;------------------------------------------------------------------------------
; STANDARD ROUTINES
;------------------------------------------------------------------------------
REFRESH_DISPLAY:
    MOVF    DISP_DIG1, W
    MOVWF   PORTB
    BSF     PORTD, 4
    CALL    DELAY_US
    BCF     PORTD, 4
    
    MOVF    DISP_DIG2, W
    MOVWF   PORTB
    BSF     PORTD, 5
    CALL    DELAY_US
    BCF     PORTD, 5
    
    MOVF    DISP_DIG3, W
    MOVWF   PORTB
    BSF     PORTD, 6
    CALL    DELAY_US
    BCF     PORTD, 6
    
    MOVF    DISP_DIG4, W
    MOVWF   PORTB
    BSF     PORTD, 7
    CALL    DELAY_US
    BCF     PORTD, 7
    RETURN

;------------------------------------------------------------------------------
; SENSOR READING (GLOBAL CALIBRATION - SUBTRACT 1 DEGREE)
;------------------------------------------------------------------------------
READ_SENSOR:
    ; Clear Variables
    CLRF    MATH_TEMP       ; Total (Low Byte)
    CLRF    DIGIT_TENS      ; Total (High Byte)
    
    ; Taking 64 samples to minimize fluctuation
    MOVLW   64
    MOVWF   DIGIT_ONES      ; Loop counter

SAMPLE_LOOP:
    ; Short delay for capacitor charging
    MOVLW   10
    MOVWF   ADC_L
DELAY_LOOP:
    DECFSZ  ADC_L, F
    GOTO    DELAY_LOOP

    ; Start ADC
    BSF     ADCON0, 2
WAIT_ADC:
    BTFSC   ADCON0, 2
    GOTO    WAIT_ADC

    ; Read Result
    BSF     STATUS, 5       ; Bank 1
    MOVF    ADRESL, W
    BCF     STATUS, 5       ; Bank 0

    ; 16-Bit Addition
    ADDWF   MATH_TEMP, F
    BTFSC   STATUS, 0       ; Carry?
    INCF    DIGIT_TENS, F

    DECFSZ  DIGIT_ONES, F
    GOTO    SAMPLE_LOOP
    
    ; --- CALCULATION ---
    ; (Total / 64) / 2 = Total / 128
    ; Shifting left 1 bit and taking the High Byte (DIGIT_TENS) equals /128.
    
    BCF     STATUS, 0       ; Clear Carry
    RLF     MATH_TEMP, F    ; Shift Low left
    RLF     DIGIT_TENS, F   ; Shift High left (Result in DIGIT_TENS)
    
    ; --- EXACT SOLUTION: GLOBAL OFFSET ---
    ; No condition. Always subtract 1 degree.
    ; Because ADC formula yields ~0.7 - 1.0 degree higher than simulator.
    
    MOVF    DIGIT_TENS, W   ; Check for Zero (Prevent Underflow)
    BTFSC   STATUS, 2       
    GOTO    SKIP_OFFSET     ; If 0, do not subtract
    
    DECF    DIGIT_TENS, F   ; Subtract 1 degree from result

SKIP_OFFSET:
    MOVF    DIGIT_TENS, W
    MOVWF   TEMP_AMB_INT

    ; Fraction Part (Bit 7 of MATH_TEMP holds .5 info)
    CLRF    TEMP_AMB_FRAC
    BTFSC   MATH_TEMP, 7    
    GOTO    SET_HALF
    RETURN

SET_HALF:
    MOVLW   5
    MOVWF   TEMP_AMB_FRAC
    RETURN
    
CALC_FAN_LOGIC:
    MOVF    TEMP_DES_INT, W
    SUBWF   TEMP_AMB_INT, W 
    BTFSS   STATUS, 0
    GOTO    FAN_ZERO
    MOVWF   FAN_SPEED
    BCF     STATUS, 0
    RLF     FAN_SPEED, F
    MOVLW   99
    SUBWF   FAN_SPEED, W
    BTFSC   STATUS, 0
    GOTO    FAN_MAX
    RETURN
FAN_ZERO:
    CLRF    FAN_SPEED
    RETURN
FAN_MAX:
    MOVLW   99
    MOVWF   FAN_SPEED
    RETURN

CONTROL_TEMP:
    MOVF    TEMP_AMB_INT, W
    SUBWF   TEMP_DES_INT, W
    BTFSC   STATUS, 2
    GOTO    OFF_ALL
    BTFSS   STATUS, 0
    GOTO    COOL
HEAT:
    BSF     PORTE, 0
    BCF     PORTE, 1
    RETURN
COOL:
    BCF     PORTE, 0
    BSF     PORTE, 1
    RETURN
OFF_ALL:
    BCF     PORTE, 0
    BCF     PORTE, 1
    RETURN

SCAN_RAW:
    BSF     STATUS, 5
    MOVLW   0b00001111
    MOVWF   TRISD
    BCF     STATUS, 5
    
    BCF     PORTA, 1
    BSF     PORTA, 2
    BSF     PORTA, 3
    BSF     PORTA, 5
    CALL    DELAY_US
    BTFSS   PORTD, 0
    RETLW   1
    BTFSS   PORTD, 1
    RETLW   4
    BTFSS   PORTD, 2
    RETLW   7
    BTFSS   PORTD, 3
    RETLW   14 ; *
    
    BSF     PORTA, 1
    BCF     PORTA, 2
    CALL    DELAY_US
    BTFSS   PORTD, 0
    RETLW   2
    BTFSS   PORTD, 1
    RETLW   5
    BTFSS   PORTD, 2
    RETLW   8
    BTFSS   PORTD, 3
    RETLW   0
    
    BSF     PORTA, 2
    BCF     PORTA, 3
    CALL    DELAY_US
    BTFSS   PORTD, 0
    RETLW   3
    BTFSS   PORTD, 1
    RETLW   6
    BTFSS   PORTD, 2
    RETLW   9
    BTFSS   PORTD, 3
    RETLW   15 ; #
    
    BSF     PORTA, 3
    BCF     PORTA, 5
    CALL    DELAY_US
    BTFSS   PORTD, 0
    RETLW   10 ; A
    RETLW   0xFF

HANDLE_TIMERS:
    MOVF    INPUT_STATE, W
    BTFSC   STATUS, 2
    GOTO    TIMER_NORMAL
    
    MOVF    INPUT_STATE, W
    XORLW   1
    BTFSC   STATUS, 2
    RETURN
    
    INCF    FEEDBACK_TIMER, F
    MOVLW   150
    SUBWF   FEEDBACK_TIMER, W
    BTFSS   STATUS, 0
    RETURN
    
    CLRF    INPUT_STATE
    CLRF    DISP_TIMER
    RETURN

TIMER_NORMAL:
    INCF    DISP_PRESCALER, F
    MOVLW   3
    SUBWF   DISP_PRESCALER, W
    BTFSS   STATUS, 0
    RETURN
    CLRF    DISP_PRESCALER
    INCF    DISP_TIMER, F
    MOVLW   180
    SUBWF   DISP_TIMER, W
    BTFSC   STATUS, 0
    CLRF    DISP_TIMER
    RETURN

DELAY_US:
    MOVLW   50
    MOVWF   DELAY_CNT1
D_US:
    DECFSZ  DELAY_CNT1, F
    GOTO    D_US
    RETURN

DELAY_MS:
    MOVLW   200
    MOVWF   DELAY_CNT1
D_MS_O:
    MOVLW   200
    MOVWF   DELAY_CNT2
D_MS_I:
    DECFSZ  DELAY_CNT2, F
    GOTO    D_MS_I
    DECFSZ  DELAY_CNT1, F
    GOTO    D_MS_O
    RETURN

SYSTEM_INIT:
    BSF     STATUS, 5
    MOVLW   0b10001110
    MOVWF   ADCON1
    CLRF    TRISB
    CLRF    TRISE
    MOVLW   0b00001111
    MOVWF   TRISD
    MOVLW   0b00010001
    MOVWF   TRISA
    BCF     STATUS, 5
    CLRF    PORTB
    CLRF    PORTD
    CLRF    PORTE
    MOVLW   0b10000001
    MOVWF   ADCON0
    RETURN

    END