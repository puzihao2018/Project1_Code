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

cseg
;-------------------;
;    Const Define   ;
;-------------------; 
CCU_RELOAD equ #2000
;-------------------;
;    Ports Define   ;
;-------------------; 
FLASH_CE equ P2.4

LCD_RS equ P1.2
LCD_RW equ P3.1
LCD_E  equ P3.0
LCD_D4 equ P0.3
LCD_D5 equ P0.2
LCD_D6 equ P0.1
LCD_D7 equ P0.0


$NOLIST
$include(lcd_4bit.inc) 
;$include(math32.inc)
;$include(DAC.inc)
$include(LPC9351.inc)
;$include(serial.inc)
;$include(SPI.inc)
$LIST


Hello: db 'Hello World',0

MainProgram:
    Ports_Initialize()
    LCD_Initailize()
    LCD_Set_Cursor(1,1)
    LCD_Display_char(#'A')
    LCD_Set_Cursor(2,1)
    LCD_Send_Constant_String(#Hello)
    sjmp $
END
