; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P3.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P4.5 is pressed.
$NOLIST
$MODLP51
$LIST

; There is a couple of typos in MODLP51 in the definition of the timer 0/1 reload
; special function registers (SFRs), so:

TIMER0_RELOAD_L DATA 0xf2
TIMER1_RELOAD_L DATA 0xf3
TIMER0_RELOAD_H DATA 0xf4
TIMER1_RELOAD_H DATA 0xf5



;=====================================================================================
;constant definition parts
CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))
;lab3 parts
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))




;========================================================================================
;PIN define started here!!!!!!!!!!!!!!!!!!!!\
;following pins are used in lab2
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
BOOT_BUTTON	equ P2.1
SOUND_OUT	equ P3.7
UPDOWN	equ P0.0
;following pins are used in lab3
;SPI interface pin with ADC
CE_ADC	EQU  P2.2 
MY_MOSI	EQU  P2.3 
MY_MISO	EQU  P2.4 
MY_SCLK	EQU  P2.5

;=======================================================================================

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

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR
;=================================================================================================================================
;globol variable declaraion
; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
;lab 3 variables
Result:	ds 4	;ADC readings, 32 bits in total, 10 bits(1023) in used
x: ds 4	;x for math
y: ds 4	;y for math
voltage_raw: ds 4	;voltage raw data
voltage: ds 2	;voltage+0 is digits(1), voltage + 1 is decimal points(0.01) example: voltage+0 = 3, 
;voltage+1 = 56, the real voltage is 3.56V

;in order to use math32.inc, some variables needed to be defined manully
bcd: ds 4

raw_temperature: ds 4 ;save raw temperature in C
temperature: ds 2	;temperature+0 is range 0-99 +1 is 01XX-99XX


buffer: ds 40 ;for serial interface recieve chars





; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
;math32 need it
mf: dbit 1
temperature_report_flag: dbit 1
display_temperature_flag: dbit 1

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
;=================================================================================================================================
;include files
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)	;32bit Math computation
$LIST
;================================================================================================================================
;some useful predefined string for display
;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'TEMP SYS', 0
Voltage_reading_head:	db 'Current Voltage is: ','', 0
Voltage_reading_end:	db 'V', '\r', '\n', 0
temperature_reading_end: db '\r', '\n', 0

display_help_string: db 'help', '\r', '\n', 0
display_temperature_string:	db 'temperature', '\r', '\n', 0
report_temperature_string:	db 'report', '\r', '\n', 0
info_string: db 'info\r\n', 0

welcome_string1:	db	'\r\n=============================================================|', '\r', '\n', 0
welcome_string2:	db	'|   ||             =========       BBB     3333333333333     |', '\r', '\n', 0
welcome_string3:	db	'|   ||             =       =       B  B               33     |', '\r', '\n', 0	
welcome_string4:	db	'|   ||             =       =       BBB     3333333333333     |', '\r', '\n', 0
welcome_string5:	db	'|   ||             =========       B  B               33     |', '\r', '\n', 0
welcome_string6:	db	'|   ||             =       =       B  B               33     |', '\r', '\n', 0
welcome_string7:	db	'|   ||========     =       =       BBB     3333333333333     |', '\r', '\n', 0
welcome_string8:	db	'=============================================================|', '\r', '\n', 0
welcome_string9:	db	'Welcome to lab3 temperature detect system v0.1A', '\r', '\n Author: Shijia Zhang\r\n\r\n', 0



haha: db 'haha','\r','\n',0
newline: db '\r\n', 0
compare_success_info: db 'compare successfully\r\n',0
command_prefix: db '>> ',0
compare_fail_string: db 'Unknown command, Please try again','\r','\n',0
help_info: db 'lab3 temperature detect system v0.1a help\r\n\r\ntemperature:          display current temperature and voltage reading of the probe\r\n\r\nreport:          continuely reporting current temperature, used for python script\r\n\r\ninfo:          print copyright information\r\n\r\n',0
report_info: db 'now reporting temperature continueously, this can be read by python script\r\n to stop reporting, press reset button\r\n\r\nreport will start within 5s........\r\n', 0
C_display_prefix: db 'Current temperature is: ', 0
C_display_suffix: db 'C\r\n', 0
information: db 'lab3 temperature detect system v0.1A\r\nAuthor: Shijia Zhang\r\nStudent number: 81102261\r\nOnly for ELEC291 Lab3\r\n', 0



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
	; Set autoreload value
	mov TIMER0_RELOAD_H, #high(TIMER0_RELOAD)
	mov TIMER0_RELOAD_L, #low(TIMER0_RELOAD)
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
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P3.7!
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl P3.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(500), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(500), Timer2_ISR_done
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	jnb UPDOWN, Timer2_ISR_decrement
	add a, #0x01
	sjmp Timer2_ISR_da
Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;

;=================================;
;lab3 func				  		  ;
;=================================;
;SPI communication with ADC start
;Since SPI in ADC is passive, we dont need to use any timer for controlling data transmission
;first we need to init SPI, using codes in PPT
;MY_XXXX mean first SPI device in lab3/project 1, which is ADC(lab3)
;May be more devices will be used in future projects
INI_SPI: 
	clr MY_SCLK           ; Mode 0,0 default 
	clr CE_ADC            ; Enable device (active low) 
	ret
DO_SPI: 
	;push AR1
	push AR2
	mov R1,#0				; Received byte stored in R1 
	mov R2, #8            ; Loop counter (8-bits) 
DO_SPI_LOOP: 
	mov a, R0             ; Byte to write is in R0 
	rlc a                 ; Carry flag has bit to write 
	mov R0, a 				;Move prepared data in acc back to R0 for new bytes
	mov MY_MOSI, c 
	setb MY_SCLK          ; Transmit 
	mov	c, MY_MISO        ; Read received bit 
	mov a, R1             ; Save received bit in R1 
	rlc a 
	mov R1, a 
	clr MY_SCLK 
	djnz R2, DO_SPI_LOOP 
	pop AR2
	;pop AR1
	ret

;here is COM port init 
; Configure the serial port and baud rate
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
	push AR0
	push AR1
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
	pop AR1
	pop AR0
    ret

; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

getchar:
	jnb RI, getchar
	clr RI
	mov a, SBUF
getchar_reponse:
    jnb TI, getchar_reponse
    clr TI
    mov SBUF, a	
	ret

GeString:
	mov R0, #buffer
GSLoop:
	lcall getchar
	push acc
	clr c
	subb a, #10H
	pop acc
	jc GSDone
	mov @R0, a
	inc R0
	sjmp GSLoop
GSDone:
	mov a, #0AH
	mov @R0, a
	ret
		

;compare recieved string and predefined string
;if they are equal, Cflag = 1
;if they dont, Cfalg = 0
;a is predefined string's initial address 
compare_buffer:
	push AR0
	push AR1
	mov R0, #buffer
	clr a
	movc a, @a+DPTR
compare_loop:
	push acc
	clr c
	subb a, #10H
	pop acc
	;if current pointer position at \n in predefined string, treat as two strings are equal
	jc compare_equal
	
	clr c
	subb a, @R0
	jnz compare_not_equal
	;only equal char can run to here
	inc R0
	inc DPTR
	movc a, @a+DPTR
	sjmp compare_loop
compare_equal:
	setb c
	pop AR1
	pop AR0
	ret
compare_not_equal:
	clr c
	pop AR1
	pop AR0
	ret

waitfoursec:
	push AR0
	push AR1
	push AR2 
	push AR3
	mov R3, #10
waitfoursecL4: mov R2, #89
waitfoursecL3: mov R1, #250
waitfoursecL2: mov R0, #166
waitfoursecL1: djnz R0, waitfoursecL1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, waitfoursecL2 ; 22.51519us*250=5.629ms
    djnz R2, waitfoursecL3 ; 5.629ms*89=0.5s (approximately)
	djnz R3, waitfoursecL4 ;0.5*10 = 5s

	pop AR3
	pop AR2
	pop AR1
	pop AR0
    ret




main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    setb half_seconds_flag
	mov BCD_counter, #0x00
	;here is lab3 part required initializations
	;first init SPI connection between PC and 8051 processor
	lcall INI_SPI
	lcall InitSerialPort
	;reset Result to 0 in 32bit
	CLR_VAR32(Result)
	CLR_VAR32(voltage_raw)
	CLR_VAR32(x)
	CLR_VAR32(y)
	clr temperature_report_flag

	;displaying welcome
	mov DPTR, #welcome_string1
	lcall SendString
	mov DPTR, #welcome_string2
	lcall SendString
	mov DPTR, #welcome_string3
	lcall SendString
	mov DPTR, #welcome_string4
	lcall SendString
	mov DPTR, #welcome_string5
	lcall SendString
	mov DPTR, #welcome_string6
	lcall SendString
	mov DPTR, #welcome_string7
	lcall SendString
	mov DPTR, #welcome_string8
	lcall SendString
	mov DPTR, #welcome_string9
	lcall SendString





	
	; After initialization the program stays in this 'forever' loop
loop:
	jb BOOT_BUTTON, commandline  ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb BOOT_BUTTON, commandline  ; if the 'BOOT' button is not pressed skip
	jnb BOOT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_counter, a
	setb TR2                ; Start timer 2\
	clr temperature_report_flag
	sjmp loop_b             ; Display the new value


;if in reporting temperature
;ignore the input of serial and directly run the loop_a
	
commandline:
;=========================================================================================
; Lab3 serial user interface command detect at here										 ;
; try to receive string and save to buffer												 ;
; then compare with the predefined string to find out the next step program should do	 ;
;=========================================================================================
;here for some function to skip the commandline process(report)
jb temperature_report_flag, loop_a

get_command:
;here received string
	mov DPTR, #command_prefix
	lcall SendString
	lcall GeString
	mov DPTR, #newline
	lcall SendString
	;command "vector table"
	mov DPTR, #display_help_string
	lcall compare_buffer
	jc display_help
	

	mov DPTR, #display_temperature_string
	lcall compare_buffer
	jc display_temperature

	mov DPTR, #report_temperature_string
	lcall compare_buffer
	jc report_temperature

	mov DPTR, #info_string
	lcall compare_buffer
	jc display_information

	mov DPTR, #compare_fail_string
	lcall SendString
	ljmp get_command


display_help:

	clr c
	mov DPTR, #help_info
	lcall SendString
	ljmp get_command
display_temperature:
	clr c
	setb display_temperature_flag
	ljmp loop_b
report_temperature:
	clr c
	mov DPTR, #report_info
	lcall SendString
	setb temperature_report_flag
	lcall waitfoursec
	ljmp loop_a
display_information:
	clr c
	mov DPTR, #information
	lcall SendString
	ljmp get_command

loop_a_jump:
	ljmp loop
loop_a:
	jnb half_seconds_flag, loop_a_jump
loop_b:
    clr half_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
	;Set_Cursor(1, 14)     ; the place in the LCD where we want the BCD counter value
	;Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'

;=====================================================
;	Here, lab3 part start
;	methods could be used in project1
;
;
;
;=====================================================
;due to in loop b, the data form ADC will be updated per half second
	clr CE_ADC 
	mov R0, #00000001B	; Start bit:1 
	lcall DO_SPI
	mov R0, #10000000B	; Single ended, read channel 0 
	lcall DO_SPI 
	mov a, R1          ; R1 contains bits 8 and 9 
	anl a, #00000011B  ; We need only the two least significant bits 
	mov Result+1, a    ; Save result high.
	mov R0, #55H; It doesn't matter what we transmit... 
	lcall DO_SPI 
	mov Result+0, R1     ; R1 contains bits 0 to 7.  Save result low. 
	setb CE_ADC
	;recieved data from ADC completed

	;now we should analysis data
	;step1: convert raw data to corresponding voltage reading
	;step2: convert voltage reading to temperature reading

	;Vout=(V_reading x V_reference(410))) / 1024 
	;First compute V_reading x V_reference(410)
	;x = V_reading
	CP_X(Result)
	;y = 410D
	mov y+0, #10011010b
	mov y+1, #00000001b
	mov y+2, #00000000b
	mov y+3, #00000000b
	;x = x*y
	lcall mul32

	;Then x = x / 1023b
	;y = 1023b
	mov y+0, #11111111b
	mov y+1, #00000011b
	mov y+2, #00000000b
	mov y+3, #00000000b
	;x = x / y
	lcall div32
	;now x = Voltage
	;copy Voltage_raw = x
	CP_VAR32(voltage_raw, x)

	;===========================================================
	;here is serial display lookup table
	;according flags, decide which content should we display next
	jb temperature_report_flag, Display_temperature_serial
	jb display_temperature_flag, Display_temperature_detail_serial_jump
	;no flag is set??? back to loop, only bug will cause it.
	ljmp loop


Display_temperature_detail_serial_jump:
	ljmp Display_temperature_detail_serial
display_voltage_serial:
	;then we transfer voltage to form a X.XX for display
	;get digit (1)
	;x = x/100 = digit in range (0-4) 0.XXV-4.10V
	;y = 100d
	mov y+0, #01100100b
	mov y+1, #00000000b
	mov y+2, #00000000b
	mov y+3, #00000000b
	lcall div32
	mov a, x+0
	mov voltage+0, a
	;then compute decimal places 0.XX
	;x = voltage+0 * 100
	mov x+0, a
	mov x+1, #00000000b
	mov x+2, #00000000b
	mov x+3, #00000000b
	;y should be already 100D
	;x = x * y
	lcall mul32
	;y = x
	CP_VAR32(y,x)
	;x = voltage_raw
	CP_X(voltage_raw)
	;x = x - y
	lcall sub32
	;now x should be equal to XX(0.XX) save them into voltage+1
	mov a, x+0
	mov voltage+1, a
	;voltage calculation ended

	;now transmit votage reading to serial port and check on putty
	;displaying: "voltage reading is X.XX V"
	mov DPTR, #Voltage_reading_head
	lcall SendString
	mov a, voltage+0
	;transfer binary digits to coresponding ASCII char
	add a, #48
	lcall putchar
	mov a, #'.'
	lcall putchar
	;transfer decimal place digits to coresponding ASCII char
	;first print high-bit digits
	mov a, voltage+1
	mov b, #10
	div ab
	;print high bit digits
	add a, #48
	lcall putchar
	;print low bit digits
	mov a, b
	add a, #48
	lcall putchar
	;display ending part
	mov DPTR, #Voltage_reading_end
	lcall SendString
	ljmp loop

Display_temperature_serial:
	;transfer voltage to temperature
	;after calibrate 24 degree = 3.01(301) V
	;at 0 degree v = 2.77(277) V
	CP_VAR32(x, voltage_raw) 
	Load_y(277)
	lcall sub32
	CP_VAR32(raw_temperature, x)

	;display raw temperature, allow temperature is readed by python script
	;display 00XX
	Load_y(100)
	;x = raw_temperature
	CP_VAR32(x, raw_temperature)
	;x = x/y
	lcall div32
	;now x should have range 0-99
	mov a, x+0
	mov b, #10
	div ab
	;print high bit digits
	addc a, #00110000b
	lcall putchar
	;print low bit digits
	mov a, b
	addc a, #00110000b
	lcall putchar
	;now display 0-99
	;x * 100 to recovery 
	lcall mul32
	;y = x
	CP_VAR32(y,x)
	; raw_temperature - y
	CP_VAR32(x, raw_temperature)
	lcall sub32
	mov a, x+0
	mov b, #10
	div ab
	;print high bit digits
	addc a, #00110000b
	lcall putchar
	;print low bit digits
	mov a, b
	addc a, #00110000b
	lcall putchar
	;display ending part
	mov DPTR, #temperature_reading_end
	lcall SendString
    ljmp loop
Display_temperature_detail_serial:
	clr display_temperature_flag ;avoid back to here agian after excute to here
	mov DPTR, #C_display_prefix
	lcall SendString
	;transfer voltage to temperature
	;after calibrate 24 degree = 3.01(301) V
	;at 0 degree v = 2.77(277) V
	CP_VAR32(x, voltage_raw) 
	Load_y(277)
	lcall sub32
	CP_VAR32(raw_temperature, x)

	;display raw temperature, allow temperature is readed by python script
	;display 00XX
	Load_y(100)
	;x = raw_temperature
	CP_VAR32(x, raw_temperature)
	;x = x/y
	lcall div32
	;now x should have range 0-99
	mov a, x+0
	mov b, #10
	div ab
	;print high bit digits
	;addc a, #00110000b
	;lcall putchar
	;print low bit digits
	mov a, b
	jz display_temperature_00
	addc a, #00110000b
	lcall putchar
display_temperature_00:
	;now display 0-99
	;x * 100 to recovery 
	lcall mul32
	;y = x
	CP_VAR32(y,x)
	; raw_temperature - y
	CP_VAR32(x, raw_temperature)
	lcall sub32
	mov a, x+0
	mov b, #10
	div ab
	;print high bit digits
	addc a, #00110000b
	lcall putchar
	;print low bit digits
	mov a, b
	addc a, #00110000b
	lcall putchar
	;display ending part
	mov DPTR, #C_display_suffix
	lcall SendString
    ljmp loop
END
