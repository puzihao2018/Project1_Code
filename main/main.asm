$NOLIST
$MOD9351
$LIST

org 0x0000 ; Reset vector
    ljmp MainProgram

org 0x0003 ; External interrupt 0 vector (not used in this code)
	reti

org 0x000B ; Timer/Counter 0 overflow interrupt vector (not used in this code)
	reti

org 0x0013 ; External interrupt 1 vector (not used in this code)
	reti

org 0x001B ; Timer/Counter 1 overflow interrupt vector (not used in this code
	reti

org 0x0023 ; Serial port receive/transmit interrupt vector (not used in this code)
	reti

org 0x005b ; CCU interrupt vector.  Used in this code to replay the wave file.
	reti


;-------------------;
;    Const Define   ;
;-------------------; 
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

state: ds 1

;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg


cseg
$NOLIST
$include(lcd_4bit.inc) 
$include(math32.inc)
;$include(DAC.inc)
$include(LPC9351.inc)
;$include(serial.inc)
;$include(SPI.inc)
$LIST

BUTTON_PUSHED mac
    jb BUTTON, NOTPUSHED%M
    Wait_Milli_Seconds(75)
    jb BUTTON, NOTPUSHED%M
    jnb BUTTON, $
    inc state
NOTPUSHED%M
endmac

MainProgram:
    Ports_Initialize()
    LCD_Initailize()
    mov state, #0

;start fsm
MainLoop:
    mov a, state
    FSM1_STATE0:
        cjne a, #0, FSM1_STATE1
        LCD_INTERFACE_WELCOME()
        jb BUTTON, FSM1_STATE0_DONE
        Wait_Milli_Seconds(#75)
        jb BUTTON, FSM1_STATE0_DONE
        jnb BUTTON, $
        inc state
    FSM1_STATE0_DONE:
        ljmp MainLoop
    FSM1_STATE1:
        cjne a, #1, FSM1_STATE1_DONE
        LCD_INTERFACE_SETTING()
        jb BUTTON, FSM1_STATE1_DONE
        Wait_Milli_Seconds(#75)
        jb BUTTON, FSM1_STATE1_DONE
        jnb BUTTON, $
        mov state, #0
    FSM1_STATE1_DONE:
        ljmp MainLoop
        

END
