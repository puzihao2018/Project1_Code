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

TIMER0_RATE   EQU 4096
TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))

;-------------------;
;    Ports Define   ;
;-------------------; 
BUTTON equ P0.1

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
	reti
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
    Cursor:     ds 1

    FSM0_State: ds 1
    FSM1_State: ds 1

    Profile_Num: ds 1

    TEMP_SOAK:  ds 4
    TIME_SOAK:  ds 4
    TEMP_RFLW:  ds 4
    TIME_RFLW:  ds 4
    TEMP_SAFE:  ds 4

    NEW_BCD:    ds 3    ; 3 digit BCD used to store current entered number
    NEW_HEX:    ds 4    ; 32 bit number of new entered number
    
;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg
    FSM0_State_Changed:  dbit 1
    Main_State:          dbit 1; 0 for setting, 1 for reflowing

;-----------------------;
;     Include Files     ;
;-----------------------; 
$NOLIST
    ;$include(lcd_4bit.inc) 
    $include(math32.inc)
    ;$include(DAC.inc)
    $include(LPC9351.inc)
    $include(serial.inc)
    ;$include(SPI.inc)
    ;$include(keys.inc)
    ;$include(temperature.inc)
$LIST


;-----------------------;
;    Program Segment    ;
;-----------------------; 
cseg at 0x0000

HexAscii: db '0123456789ABCDEF'

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    clr TR0   ; not start timer 0, wait until used
	ret
;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
    mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
    ;codes here
    reti

;---------------------------------;
; Routine to initialize the CCU   ;
; We are using the CCU timer in a ;
; manner similar to timer 2       ;
;---------------------------------;
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

;---------------------------------;
; ISR for CCU                     ;
;---------------------------------;
CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit.
    ;codes here
	reti



;-------------------;
;       Macros      ;
;-------------------; 


MainProgram:
    Ports_Initialize()
    LCD_Initailize()
    Clock_Double()
    SPI_Initialize()

    mov FSM0_State, #0
    mov FSM1_State, #0
    mov Profile_Num, #0
    LCD_INTERFACE_WELCOME()
    lcall WaitHalfSec

;start fsm
MainLoop:
    jnb Main_State, FSM0    ;if 0, go to FSM0 to setting interface
    ;ljmp FSM1               ;if 1, go to FSM1 to reflow process

FSM0:
    ;-------------------;
    ;    Setting FSM    ;
    ;-------------------;

    ;Checking Keyboard
    ;Key_Scan()
    FSM0_Start:
        mov a, FSM0_State
        FSM0_State0:
            cjne a, #0, FSM0_State1
            LCD_INTERFACE_MAIN()

            jb BUTTON, FSM0_State0_Done
            Wait_Milli_Seconds(#75)
            jb BUTTON, FSM0_State0_Done
            jnb BUTTON, $
            mov FSM0_State, #0x01
            
            FSM0_State0_Done:
            ljmp MainLoop

        FSM0_State1:
            ;cjne a, #1, FSM0_State2
            LCD_INTERFACE_STEP1()
            Read_ADC_Channel(0)
            LCD_Set_Cursor(1,6)
            LCD_Display_BCD(#Result+1)
			LCD_Display_BCD(#Result)

            
            jb BUTTON, FSM0_State1_Done
            Wait_Milli_Seconds(#75)
            jb BUTTON, FSM0_State1_Done
            jnb BUTTON, $
            mov FSM0_State, #0x00
            
           	FSM0_State1_Done:
            ljmp MainLoop

        FSM0_State2:
            cjne a, #2, FSM0_State3
            LCD_INTERFACE_MODIFY2()

        FSM0_State3:
            cjne a, #3, FSM0_State4
            LCD_INTERFACE_MODIFY3()

        FSM0_State4:
            cjne a, #4, FSM0_State5
            LCD_INTERFACE_MODIFY4()

        FSM0_State5:
            cjne a, #5, FSM0_Done
            LCD_INTERFACE_MODIFY5()

        FSM0_Done:
            ljmp MainLoop

END
