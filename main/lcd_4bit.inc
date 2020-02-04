cseg

; When using a 7.373MHz clock
; one cycle takes 2.0/7.373MHz = 271.26 ns

;---------------------------------;
;            Constants            ;
;---------------------------------;
			  ;'1234567890123456'
Hello: 		db 'Hello World'		,0

WELCOME1: 	db 'WELCOME!        '	,0
WELCOME2: 	db 'Super Reflow!   '	,0

SETTING1: 	db 'STMP:   STM:   s'	,0
SETTING2:   db 'RTMP:   RTM:   s'   ,0

MODIFY_DOWN:db 'OLD:    NEW:    '   ,0
MODIFY1:	db 'MODIFY:TEMP_SOAK'	,0
MODIFY2:	db 'MODIFY:TIME_SOAK'	,0
MODIFY3:	db 'MODIFY:TEMP_RFLW'	,0
MODIFY4:	db 'MODIFY:TEMP_SOAK'	,0
MODIFY5:    db 'MODIFY:TEMP_SOAK'   ,0

WORKING:    db 'TEMP:   TIME:   '   ,0
STEP1:		db 'STMP:    RAMPING'   ,0
STEP2:      db 'STM:   s SOAKING'   ,0
STEP3:      db 'RTMP:    RAMPING'   ,0
STEP4:      db 'RTM:   s REFLOW '   ,0
STEP5:      db '         COOLING'   ,0
STEP6:      db '         FINISH '   ,0

;---------------------------------;
;              Ports              ;
;---------------------------------;

LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.4
LCD_D5 equ P1.3
LCD_D6 equ P1.2
LCD_D7 equ P3.1

;---------------------------------;
;           Basic Macros          ;
;---------------------------------;
LCD_Initailize mac
	lcall LCD_4BIT
endmac

LCD_WriteData mac
	mov a, %0
	lcall ?LCD_WriteData
endmac
	
LCD_WriteCommand mac
	mov a, %0
	lcall ?LCD_WriteCommand
endmac

LCD_Send_Constant_String mac
	push dph
	push dpl
	push acc
	mov dptr, %0
	lcall ?Send_Constant_String
	pop acc
	pop dpl
	pop dph
endmac

LCD_Set_Cursor mac
	push acc
	mov a, #%1
	dec a
	lcall ?Set_Cursor_%0 ; Select column and row
	pop acc
endmac

LCD_Display_BCD mac
	push ar0
	mov r0, %0
	lcall ?Display_BCD
	pop ar0
endmac

LCD_Display_char mac
	push acc
	mov a, %0
	lcall ?LCD_WriteData
	pop acc
endmac

Wait_Milli_Seconds mac
	push AR2
	mov R2, %0
	lcall ?Wait_Milli_Seconds
	pop AR2
endmac

;---------------------------------;
;         Interface Macros        ;
;---------------------------------;

LCD_INTERFACE_WELCOME mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WELCOME1)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#WELCOME2)
endmac

LCD_INTERFACE_SETTING mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#SETTING1)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#SETTING2)
endmac

LCD_INTERFACE_MODIFY1 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#MODIFY1)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#MODIFY_DOWN)
endmac

LCD_INTERFACE_MODIFY2 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#MODIFY2)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#MODIFY_DOWN)
endmac

LCD_INTERFACE_MODIFY3 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#MODIFY3)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#MODIFY_DOWN)
endmac

LCD_INTERFACE_MODIFY4 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#MODIFY4)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#MODIFY_DOWN)
endmac

LCD_INTERFACE_MODIFY5 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#MODIFY5)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#MODIFY_DOWN)
endmac

LCD_INTERFACE_STEP1 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP1)
endmac

LCD_INTERFACE_STEP2 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP2)
endmac

LCD_INTERFACE_STEP3 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP3)
endmac

LCD_INTERFACE_STEP4 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP4)
endmac

LCD_INTERFACE_STEP5 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP5)
endmac

LCD_INTERFACE_STEP6 mac
	LCD_Set_Cursor(1,1)
	LCD_Send_Constant_String(#WORKING)
	LCD_Set_Cursor(2,1)
	LCD_Send_Constant_String(#STEP6)
endmac


;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
	push AR0
	mov R0, #74
L0: 
	djnz R0, L0 ; 2 cycles->2*271.26ns*74=40us
	pop AR0
    ret

;---------------------------------;
; Wait 500 microseconds           ;
;---------------------------------;
WaitHalfSec:
    mov R2, #40
H3: mov R1, #250
H2: mov R0, #184
H1: djnz R0, H1 ; 2 machine cycles-> 2*0.27126us*184=100us
    djnz R1, H2 ; 100us*250=0.025s
    djnz R2, H3 ; 0.025s*20=0.5s
    ret

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
?Wait_Milli_Seconds:
	push AR0
	push AR1
L3: mov R1, #10
L2: mov R0, #184
L1: djnz R0, L1 ; 2 cycles->2*271.26ns*184=100us
    djnz R1, L2 ; 100us*10=1ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret
	
;---------------------------------;
; Toggles the 'E' pin in the LCD  ;
;---------------------------------;
LCD_pulse:
	setb LCD_E
	lcall Wait40uSec
	clr LCD_E
    lcall Wait40uSec
    ret

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
	; Write high 4 bits first
	mov c, ACC.7
	mov LCD_D7, c
	mov c, ACC.6
	mov LCD_D6, c
	mov c, ACC.5
	mov LCD_D5, c
	mov c, ACC.4
	mov LCD_D4, c
    lcall LCD_pulse
	; Write low 4 bits next
	mov c, ACC.3
	mov LCD_D7, c
	mov c, ACC.2
	mov LCD_D6, c
	mov c, ACC.1
	mov LCD_D5, c
	mov c, ACC.0
	mov LCD_D4, c
    lcall LCD_pulse
	ret

;---------------------------------;
; Write data to LCD               ;
;---------------------------------;
?LCD_WriteData:
	setb LCD_RS
	ljmp LCD_byte

;---------------------------------;
; Write command to LCD            ;
;---------------------------------;
?LCD_WriteCommand:
	clr LCD_RS
	ljmp LCD_byte

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
	clr LCD_E   ; Resting state of LCD's enable pin is zero
	clr LCD_RW  ; We are only writing to the LCD in this program
	
	; After power on, let the LCD start up before initializing
	Wait_Milli_Seconds(#40)
	
	; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
	LCD_WriteCommand(#0x33)
	LCD_WriteCommand(#0x33)
	LCD_WriteCommand(#0x32) ; change to 4-bit mode

	; Configure the LCD
	LCD_WriteCommand(#0x28)
	LCD_WriteCommand(#0x0c)
	LCD_WriteCommand(#0x01) ;  Clear screen command (takes some time)

    ;Wait for the clear screen command to finish.
	Wait_Milli_Seconds(#2)
    ret

;---------------------------------;
; Send a constant string to LCD   ;
;---------------------------------;
?Send_Constant_String:
    clr a
    movc a, @a+dptr
    jz ?Send_Constant_String_Done
    lcall ?LCD_WriteData
    inc dptr
    sjmp ?Send_Constant_String
?Send_Constant_String_Done:
    ret	

;---------------------------------;
; Set LCD cursor at row, column   ;
;---------------------------------;
?Set_Cursor_2:
	orl a, #01000000B
?Set_Cursor_1:
	orl a, #10000000B
	ljmp ?LCD_WriteCommand ; Select column and row

;---------------------------------;
; Display a BCD number in the LCD ;
;---------------------------------;
?Display_BCD:
	push acc
	; Write most significant digit
	mov a, r0
	swap a
	anl a, #0fh
	orl a, #30h
	lcall ?LCD_WriteData
	; write least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall ?LCD_WriteData
	pop acc
	ret

$LIST