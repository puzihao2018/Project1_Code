; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P3.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'CLEAR' pushbutton connected to P1.7 is pressed.
$NOLIST
$MOD9351
$LIST

CLK           EQU 7373000  ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 100     ; 100Hz, for a timer tick of 10ms
TIMER1_RELOAD EQU ((65536-(CLK/(2*TIMER1_RATE))))

CLEAR         equ P1.7
SOUND_OUT     equ P2.7
UPDOWN        equ P2.4

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector
org 0x001B
	ljmp Timer1_ISR

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
org 0x003B
;keyboard interrupt
    lcall button_cascade
	reti


; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count10ms:    ds 1 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
mode_counter: ds 1 ; mode of setting
var_parameter1: ds 1
var_parameter2: ds 1
var_parameter3: ds 1
var_parameter4: ds 1


; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
is_working: dbit 1 ; is the device in a cycle

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P0.7
LCD_RW equ P3.0
LCD_E  equ P3.1
LCD_D4 equ P2.0
LCD_D5 equ P2.1
LCD_D6 equ P2.2
LCD_D7 equ P2.3
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Reflow Oven Controller v0', 0

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
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	cpl SOUND_OUT ; Connect speaker to this pin
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 1                     ;
;---------------------------------;
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

;---------------------------------;
; ISR for timer 1                 ;
;---------------------------------;
Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	cpl P2.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 10 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 8-bit 10-mili-second counter
	inc Count10ms

Inc_Done:
	; Check if half second has passed
	mov a, Count10ms
	cjne a, #50, Timer1_ISR_done ; Warning: this instruction changes the carry flag!
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the 10-milli-seconds counter, it is a 8-bit variable
	mov Count10ms, #0
	; Increment the BCD counter
	mov a, BCD_counter
	jnb UPDOWN, Timer1_ISR_decrement
	add a, #0x01
	sjmp Timer1_ISR_da
Timer1_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer1_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a
	
Timer1_ISR_done:
	pop psw
	pop acc
	reti

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;


button_pressed: db 'pressed one', 0
another_button_pressed: db 'pressed two', 0

main:
	; Initialization
    mov SP, #0x7F

    ;lcall Timer0_Init
    ;lcall Timer1_Init
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #01H
    mov P0M2, #01H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
    mov mode_counter, #0x00
    mov var_parameter1, #0x100
    mov var_parameter2, #0x90
    mov var_parameter3, #0x200
    mov var_parameter4, #0x30
    setb EA   ; Enable Global interrupts
	setb EKBI
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit_LPC9351.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#home_message)
forever:
    ljmp forever

isr_every_second:
    get_temperature()
    lcall display_temperature
    lcall display_time
    ;runningtime_counter
    mov a, runtime_c
    add a, #0x01
    da a 
    mov runtime_c, a
    jnb is_operating, skipit
    jb done_safety, heat_to_soak
    Set_Cursor(0,0)
    Send_Constant_String(#presoak)
    setb heater_on
    mov a, runtime_c
    cjne a, #0x60, skipit
    mov a, realtemp
    cjne a, #0x50, safety_fail
    setb done_safety
heat_to_soak:
    jb done_heattosoak, wait_soak
    
hts_heater_routine:
    mov a, realtemp
    cjne a, var_parameter1, hts_ne
    setb done_heattosoak
    clr heater_on
    ljmp soak
hts_ne:
    jc hts_gt
    ;lt
    ljmp skipit
hts_gt:
    setb done_heattosoak
    clr_heater_on
    ljmp soak

soak:
    jb done_soak, heat_to_max
    Set_Cursor(0,0)
    Send_Constant_String(#Soaking)
    mov a, runtime_c
    cjne a, var_parameter2, s_heater_routine
    setb done_soak
    ljmp heat_to_max
s_heater_routine:
    mov a, realtemp
    cjne a, var_parameter1, s_ne
    clr heater_on
    ljmp skipit
s_ne:
    jc s_gt
    ;lt
    setb heater_on
    ljmp skipit
s_gt:
    clr heater_on
    ljmp skipit


heat_to_max:
    jb done_htm, solder
    Set_Cursor(0,0)
    Send_Constant_String(#Heating_to_solder)
htm_heater_routine:
    mov a, realtemp
    cjne a, var_parameter3, htm_ne
    setb done_htm 
    clr heater_on
    ljmp solder
htm_ne:
    jc htm_gt
    ;lt
    ljmp skipit
htm_gt:
    setb done_htm 
    clr heater_on
    ljmp solder

solder:
    jb done_solder, finished
    Set_Cursor(0,0)
    Send_Constant_String(#soldering)
    mov a, runtime_c
    cjne a, var_parameter4, so_heater_routine
    setb done_solder
    ljmp finished
so_heater_routine:
    mov a, realtemp
    cjne a, var_parameter3, so_ne
    clr heater_on
    ljmp skipit
so_ne:
    jc so_gt
    ;lt
    setb heater_on
    ljmp skipit
so_gt:
    clr heater_on
    ljmp skipit

finished:
    Set_Cursor(0,0)
    Send_Constant_String(#Wait_cooling)
    mov a, realtemp
    cjne a, realtemp, skipit
    ljmp resetto_home

resetto_home:
    clr is_operating
    clr done_safety
    clr done_heattosoak
    clr done_soak
    clr done_solder
    mov mode_counter, #0x00
    mov runtime_c, #0x00
    lcall menu_update_lcd

skipit:
    ret    


button_cascade:
menu_button:
    jb MENU_BUT, up_button  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit_LPC9351.inc'
	jb MENU_BUT, up_button  ; if the 'CLEAR' button is not pressed skip
	jnb MENU_BUT, $
    lcall menu_button_handle
    ret
up_button:
    jb UP_BUT, down_button  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit_LPC9351.inc'
	jb UP_BUT, down_button  ; if the 'CLEAR' button is not pressed skip
	jnb UP_BUT, $
    lcall increase_button_handle
    ret
down_button:
    jb DOWN_BUT, startstop_button  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit_LPC9351.inc'
	jb DOWN_BUT, startstop_button  ; if the 'CLEAR' button is not pressed skip
	jnb DOWN_BUT, $
    lcall decrease_button_handle
    ret
startstop_button:
    jb SS_BUT, endbutton_cascade  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit_LPC9351.inc'
	jb SS_BUT, endbutton_cascade  ; if the 'CLEAR' button is not pressed skip
	jnb SS_BUT, $
    lcall startstop_handle
    ret

endbutton_cascade:
    ret

menu_button_handle:
    mov a, mode_counter
    cjne a, #0x04, menu_no_reset
    add a, #0x01
    da a
    mov mode_counter, a
    lcall menu_update_lcd
    ret 
menu_no_reset:
    mov mode_counter, #0x00
    lcall menu_update_lcd
    ret
menu_update_lcd:
    cjne a, #0x00, menu_1234
    Set_Cursor(0,0)
    Send_Constant_String(#home_message)
    ret
menu_1234:
    cjne a, #0x01, menu_234
    Set_Cursor(0,0)
    Send_Constant_String(#p1_message)
    ret  
menu_234:
    cjne a, #0x02, menu_34
    Set_Cursor(0,0)
    Send_Constant_String(#p2_message)
    ret 
menu_34:
    cjne a, #0x03, menu_4
    Set_Cursor(0,0)
    Send_Constant_String(#p3_message)
    ret
menu_4:
    Set_Cursor(0,0)
    Send_Constant_String(#p4_message)
    ret

startstop_handle:
    jnb is_operating, startproc
    ;stopproc
    clr is_operating
    Set_Cursor(0,0)
    Send_Constant_String(#Warning_hot)
startproc:
    setb is_operating
    ret

decrease_button_handle:
    mov a, mode_counter
    cjne a, #0x00, down_1234
    ;home screen so do nothing
    ret
down_1234:
    cjne a, #0x01, down_234  
    ;parameter 1 setting
    ;decrement parameter 1
    mov a, var_parameter1
    add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter1, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter1) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter1+1)
    ret
down_234:
    cjne a, #2, down_34 
    ;parameter 2 setting
    ;decrement parameter 2
    mov a, var_parameter2
    add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter2, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter2) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter2+1)
    ret
down_34:
    cjne a, #3, down_4 
    ;parameter 3 setting
    ;decrement parameter 3
    mov a, var_parameter3
    add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter3, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter3) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter3+1)
    ret
down_4:
    ;parameter 4 setting
    ;decrement parameter 4
    mov a, var_parameter4
    add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter4, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter4) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter4+1)
    ret

increase_button_handle:
    mov a, mode_counter
    cjne a, #0, up_1234
    ;home screen so do nothing
    ret
up_1234:
    cjne a, #1, up_234  
    ;parameter 1 setting
    ;decrement parameter 1
    mov a, var_parameter1
    add a, #0x01 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter1, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter1) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter1+1)
    ret
up_234:
    cjne a, #2, up_34 
    ;parameter 2 setting
    ;decrement parameter 2
    mov a, var_parameter2
    add a, #0x01 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter2, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter2) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter2+1)
    ret
up_34:
    cjne a, #3, up_4 
    ;parameter 3 setting
    ;decrement parameter 3
    mov a, var_parameter3
    add a, #0x01 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter3, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter3) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter3+1)
    ret
up_4:
    ;parameter 4 setting
    ;decrement parameter 4
    mov a, var_parameter4
    add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
    da a
    mov var_parameter4, a
    Set_Cursor(2, 0)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(var_parameter4) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    Display_BCD(var_parameter4+1)
    ret


END
