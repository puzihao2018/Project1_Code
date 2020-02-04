
CCU_RELOAD equ #2000



;-------------------;
;    Ports Define   ;
;-------------------; 

BUTTON equ P3.0

;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30
Cursor:     ds 1
FSM0_State: ds 1
FSM1_State: ds 1

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


;-----------------------;
;     Include Files     ;
;-----------------------; 
$NOLIST
$include(lcd_4bit.inc) 
$include(math32.inc)
;$include(DAC.inc)
$include(LPC9351.inc)
;$include(serial.inc)
$include(SPI.inc)
;$include(keys.inc)
;$include(temperature.inc)
$LIST
cseg

;-------------------;
;       Macros      ;
;-------------------; 




MainProgram:
    Ports_Initialize()
    LCD_Initailize()
    Clock_Double()

    mov FSM0_State, #0
    mov FSM1_State, #0
    LCD_INTERFACE_WELCOME()
    lcall WaitHalfSec

;start fsm
MainLoop:

END
