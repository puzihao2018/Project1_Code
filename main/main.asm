

;-------------------;
;    Const Define   ;
;-------------------; 
XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)
CCU_RELOAD equ #2000



;-------------------;
;    Ports Define   ;
;-------------------; 
FLASH_CE equ P2.4
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
;$include(SPI.inc)
;$include(keys.inc)
;$include(temperature.inc)
$LIST
cseg

;-------------------;
;       Macros      ;
;-------------------; 
Check_State_Changed mac
    jnb FSM%0_State_Changed, skip%M
    clr FSM%0_State_Changed
    mov Cursor, #0
    
skip%M
endmac



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
    NOP

FSM0:
    ;-------------------;
    ;    Setting FSM    ;
    ;-------------------;
    Key_Scan()
    FSM0_Key_Read()
    
    FSM0_Start:
        mov a, FSM0_State
        FSM0_State0:
            cjne a, #0, FSM0_State1
            LCD_INTERFACE_SETTING()
            

        FSM0_State1:
            cjne a, #1, FSM0_State2
            LCD_INTERFACE_MODIFY1()

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
            ljmp FSM0


END
