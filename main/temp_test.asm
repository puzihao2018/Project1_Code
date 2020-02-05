$MOD9351

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
Read_Temp mac
    clr MYADC_CE
    Read_ADC_Channel(%0)
    setb MYADC_CE
endmac



Send_Result:
    mov x+3, #0x00
    mov x+2, #0x00
    mov x+1, Result+1
    mov x,   Result
    Load_y(4100)
    lcall mul32
    Load_y(1024)
    lcall div32
    Load_y(2750)
    lcall sub32
    Load_y(10)
    lcall mul32
    lcall hex2bcd
    LCD_Set_Cursor(1,1)
    LCD_Display_BCD(bcd+1)
    LCD_Set_Cursor(1,3)
    LCD_Display_BCD(bcd)
    ret

MainProgram:
    Ports_Initialize()
    LCD_Initailize()
    Clock_Double()
    SPI_Initialize()
    LCD_INTERFACE_WELCOME()
    lcall WaitHalfSec

MainLoop:
	Read_Temp(0)
    lcall Send_Result
    sjmp MainLoop

END
