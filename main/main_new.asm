$NOLIST
$MOD9351
$LIST

;-------------------;
;    Const Define   ;
;-------------------; 
XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CCU_RATE      EQU 100      ; 100Hz, for an overflow rate of 10ms
CCU_RELOAD    EQU ((65536-(XTAL/(2*CCU_RATE))))

TIMER0_RATE   EQU 4096    ; 4096Hz
TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 100     ; 100Hz, for a timer tick of 10ms
TIMER1_RELOAD EQU ((65536-(XTAL/(2*TIMER1_RATE))))

;-------------------;
;    Ports Define   ;
;-------------------; 
BUTTON equ P0.1
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.4
LCD_D5 equ P1.3
LCD_D6 equ P1.2
LCD_D7 equ P3.1
;ADC00 equ P1.7; Read Oven Temperature
;ADC01 equ P0.0; Read Room Temperature
;ADC02 equ P2.1; Read Keyboard0
;ADC03 equ P2.0; Read Keyboard1

;------------------------;
;    Interrupt Vectors   ;
;------------------------; 
; Reset vector
org 0x0000
    ljmp MainProgram
    ; External interrupt 0 vector
org 0x0003
	reti
    ; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
    ; External interrupt 1 vector
org 0x0013
	ljmp Timer1_ISR
    ; Timer/Counter 1 overflow interrupt vector
org 0x001B
	reti
    ; Serial port receive/transmit interrupt vector
org 0x0023 
	reti
    ; CCU interrupt vector
org 0x005b 
	ljmp CCU_ISR

;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30
    Count10ms:    ds 1 ; Used to determine when half second has passed
    Time_Counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

    FSM0_State: ds 1
    FSM1_State: ds 1

    Profile_Num: ds 1

    TEMP_SOAK:  ds 4
    TIME_SOAK:  ds 4
    TEMP_RFLW:  ds 4
    TIME_RFLW:  ds 4
    TEMP_SAFE:  ds 4
    Current_Room_Temp: ds 4
	Current_Oven_Temp: ds 4

    Cursor:     ds 1
    NEW_BCD:    ds 3    ; 3 digit BCD used to store current entered number
    NEW_HEX:    ds 4    ; 32 bit number of new entered number
    ;for math32.inc
    x: ds 4
    y: ds 4
    bcd: ds 5
    x_backup: ds 4
    y_backup: ds 4
;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg
    FSM0_State_Changed:  dbit 1
    Main_State:          dbit 1 ; 0 for setting, 1 for reflowing
    ;for math32.inc
    mf: dbit 1
    lessthan_flag: dbit 1
    equal_flag: dbit 1
    greater_flag: dbit 1
    half_seconds_flag: dbit 1 ; 500ms in double rate mode
;-----------------------;
;     Include Files     ;
;-----------------------; 
;$NOLIST
    $include(lcd_4bit.inc) 
    $include(math32.inc)
    ;$include(DAC.inc)
    $include(LPC9351.inc)
    $include(serial.inc)
    ;$include(keys.inc)
    $include(temperature.inc)
;$LIST

cseg
;----------------------------;
;     Interrupt Services     ;
;----------------------------; 
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0   ; not start timer 0, wait until used
	ret
Timer1_Init:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	; Enable the timer and interrupts
    setb ET1  ; Enable timer 1 interrupt
    setb TR1  ; Start timer 1
	ret
CCU_Init:
	mov TH2, #high(CCU_RELOAD)
	mov TL2, #low(CCU_RELOAD)
	mov TOR2H, #high(CCU_RELOAD)
	mov TOR2L, #low(CCU_RELOAD)
	mov TCR21, #10000000b ; Latch the reload value
	mov TICR2, #10000000b ; Enable CCU Timer Overflow Interrupt
	setb ECCU ; Enable CCU interrupt
	clr TMOD20 ; not start CCU timer yet, wait until used
	ret

Timer0_ISR:
    mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
    ;codes here
    reti

Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 8-bit 10-mili-second counter
	inc Count10ms

Inc_Done:
	; Check if half second has passed
	mov a, Count10ms
	cjne a, #50, Timer1_ISR_done 
    ;code here
Timer1_ISR_done:
	pop psw
	pop acc
	reti

CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit.
    ;codes here
	reti

MainProgram:

    sjmp MainProgram
END