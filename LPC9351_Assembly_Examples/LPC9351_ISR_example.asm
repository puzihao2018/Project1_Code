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

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count10ms:    ds 1 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed

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
Initial_Message:  db 'BCD_counter: xx ', 0

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
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer1_Init
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit_LPC9351.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    setb half_seconds_flag
	mov BCD_counter, #0x00
	
	; After initialization the program stays in this 'forever' loop
loop:
	jb CLEAR, loop_a  ; if the 'CLEAR' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit_LPC9351.inc'
	jb CLEAR, loop_a  ; if the 'CLEAR' button is not pressed skip
	jnb CLEAR, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'CLEAR' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR1                 ; Stop timer 1
	clr a
	mov Count10ms, a
	; Now clear the BCD counter
	mov BCD_counter, a
	setb TR1                ; Start timer 1
	sjmp loop_b             ; Display the new value
loop_a:
	jnb half_seconds_flag, loop
loop_b:
    clr half_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
	Set_Cursor(1, 14)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit_LPC9351.inc'
    ljmp loop
END
