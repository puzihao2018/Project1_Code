; LPC9351_Receiver.asm:  This program implements a simple serial port
; communication protocol to program, verify, and read SPI flash memories.  Since
; the program was developed to store wav audio files, it also allows 
; for the playback of said audio.  It is assumed that the wav sampling rate is
; 22050Hz, 8-bit, mono.
;
; Copyright (C) 2012-2019  Jesus Calvino-Fraga, jesusc (at) ece.ubc.ca
; 
; This program is free software; you can redistribute it and/or modify it
; under the terms of the GNU General Public License as published by the
; Free Software Foundation; either version 2, or (at your option) any
; later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
; 
; Connections:
; 
; P89LPC9351  SPI_FLASH
; P2.5        Pin 6 (SPI_CLK)
; P2.2        Pin 5 (MOSI)
; P2.3        Pin 2 (MISO)
; P2.4        Pin 1 (CS/)
; GND         Pin 4
; 3.3V        Pins 3, 7, 8
;
; P0.4 is the DAC output which should be connected to the input of an amplifier (LM386 or similar)

$NOLIST
$MOD9351
$LIST


CLK         EQU 14746000  ; Microcontroller system clock frequency in Hz
CCU_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  EQU ((65536-((CLK/(2*CCU_RATE)))))
BAUD        EQU 115200
BRVAL       EQU ((CLK/BAUD)-16)

FLASH_CE    EQU P2.4
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite

number_off_set EQU 17200 ;the distance between each number
;number start at ff

decimal_start  EQU 360000
decimal_off_set EQU 24100
decimal_playtime EQU 50000

special_dec_start EQU 174000 ;numbers from 10 to 19
special_off_set EQU 21500
special_playtime EQU 21500;19000

hundreds_start EQU 563000
hundreds_off_set EQU 37000

current_temp_is_start EQU 674000
current_temp_playtime EQU 35000

degree_start EQU 710000
degree_playtime EQU 11018

celsius_start EQU 732236
celsius_playtime EQU 17000

current_process_is_start EQU 757000
current_process_is_playtime EQU 27000
	
ramp_to_soak_start EQU 790000
ramp_to_soak_playtime EQU 25000

preheat_and_soak_start EQU 822000
preheat_and_soak_playtime EQU 27000

ramp_to_peak_start EQU 857000
ramp_to_peak_playtime EQU 19000

reflow_start EQU 885000
reflow_playtime EQU 15000

cooling_start EQU 906000
cooling_playtime EQU 14000

dseg at 30H
	w:   ds 3 ; 24-bit play counter.  Decremented in CCU ISR.
	number: ds 1;
	x: ds 4;
	y: ds 4;
	bcd: ds 5;
	digits: ds 1;
	tenth: ds 1;
	individual_offest: ds 1;

BSEG
	mf: dbit 1
	nodigit: dbit 1 ; if playing from 10 to 19 then we don't need to
					;play the last digit
	skiphundred: dbit 1
	skiptenth: dbit 1
cseg

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
	ljmp CCU_ISR

$include(math32.inc)

;---------------------------------;
; Routine to initialize the CCU.  ;
; We are using the CCU timer in a ;
; manner similar to the timer 2   ;
; available in other 8051s        ;
;---------------------------------;
CCU_Init:
	mov TH2, #high(CCU_RELOAD)
	mov TL2, #low(CCU_RELOAD)
	mov TOR2H, #high(CCU_RELOAD)
	mov TOR2L, #low(CCU_RELOAD)
	mov TCR21, #10000000b ; Latch the reload value
	mov TICR2, #10000000b ; Enable CCU Timer Overflow Interrupt
	setb ECCU ; Enable CCU interrupt
	setb TMOD20 ; Start CCU timer
	ret

;---------------------------------;
; ISR for CCU.  Used to playback  ;
; the WAV file stored in the SPI  ;
; flash memory.                   ;
;---------------------------------;
CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit. Actually, it clears all the bits!
	setb P2.6 ; To check the interrupt rate with oscilloscope.//empty??
	
	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing ;ff replenished the register, equivalent to borrow a bit from higher number
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:

	lcall Send_SPI ; Read the next byte from the SPI Flash...
	mov AD1DAT3, a ; and send it to the DAC ; !!a register that directly send value to speaker
	
	sjmp CCU_ISR_Done

stop_playing:
	clr TMOD20 ; Stop CCU timer
	setb FLASH_CE  ; Disable SPI Flash

CCU_ISR_Done:	
	pop psw
	pop acc
	clr P2.6
	reti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;every thing from this point on is the interface with computer
;---------------------------------;
; Initial configuration of ports. ;
; After reset the default for the ;
; pins is 'Open Drain'.  This     ;
; routine changes them pins to    ;
; Quasi-bidirectional like in the ;
; original 8051.                  ;
; Notice that P1.2 and P1.3 are   ;
; always 'Open Drain'. If those   ;
; pins are to be used as output   ;
; they need a pull-up resistor.   ;
;---------------------------------;
Ports_Init:
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H ;00H stand for all port 0 mode, P0M1 and P0M2 stand for mode 12 
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1 kohm pull-up resistors if used as outputs!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
	ret

;---------------------------------;
; Sends a byte via serial port    ;
;---------------------------------;
putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

;---------------------------------;
; Initialize the serial port      ;
;---------------------------------;
InitSerialPort:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	; Make sure that TXD(P1.0) and RXD(P1.1) are configured as bidrectional I/O
	anl	P1M1,#11111100B
	anl	P1M2,#11111100B
	ret

;---------------------------------;
; Initialize ADC1/DAC1 as DAC1.   ;
; Warning, the ADC1/DAC1 can work ;
; only as ADC or DAC, not both.   ;
; The P89LPC9351 has two ADC/DAC  ;
; interfaces.  One can be used as ;
; ADC and the other can be used   ;
; as DAC.  Also configures the    ;
; pin associated with the DAC, in ;
; this case P0.4 as 'Open Drain'. ;
;---------------------------------;
InitDAC:
    ; Configure pin P0.4 (DAC1 output pin) as open drain
	orl	P0M1,   #00010000B
	orl	P0M2,   #00010000B
    mov ADMODB, #00101000B ; Select main clock/2 for ADC/DAC.  Also enable DAC1 output (Table 25 of reference manual)
	mov	ADCON1, #00000100B ; Enable the converter
	mov AD1DAT3, #0x80     ; Start value is 3.3V/2 (zero reference for AC WAV file)
	ret

;---------------------------------;
; Change the internal RC osc. clk ;
; from 7.373MHz to 14.746MHz.     ;
;---------------------------------;
Double_Clk:
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B ; double the clock speed to 14.746MHz
    movx @dptr,a
	ret

;---------------------------------;
; Initialize the SPI interface    ;
; and the pins associated to SPI. ;
;---------------------------------;
Init_SPI:
	; Configure MOSI (P2.2), CS* (P2.4), and SPICLK (P2.5) as push-pull outputs (see table 42, page 51)
	anl P2M1, #low(not(00110100B))
	orl P2M2, #00110100B
	; Configure MISO (P2.3) as input (see table 42, page 51)
	orl P2M1, #00001000B
	anl P2M2, #low(not(00001000B)) 
	; Configure SPI
	mov SPCTL, #11010000B ; Ignore /SS, Enable SPI, DORD=0, Master=1, CPOL=0, CPHA=0, clk/4
	ret

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;

WaitHalfSec:
    mov R2, #89
L3: mov R1, #220
L2: mov R0, #230
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*250=5.629ms
    djnz R2, L3 ; 5.629ms*89=0.5s (approximately)
    ret

Wait250ms:
    mov R2, #89
Ll3: mov R1, #200
Ll2: mov R0, #160
Ll1: djnz R0, Ll1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, Ll2 ; 22.51519us*250=5.629ms
    djnz R2, Ll3 ; 5.629ms*89=0.5s (approximately)
    ret

Wait200ms:
    mov R2, #80
Lll3: mov R1, #200
Lll2: mov R0, #100
Lll1: djnz R0, Lll1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, Lll2 ; 22.51519us*250=5.629ms
    djnz R2, Lll3 ; 5.629ms*89=0.5s (approximately)
    ret

Send_SPI:
	mov SPDAT, a
Send_SPI_1:
	mov a, SPSTAT 
	jnb acc.7, Send_SPI_1 ; Check SPI Transfer Completion Flag
	mov SPSTAT, a ; Clear SPI Transfer Completion Flag
	mov a, SPDAT ; return received byte via accumulator
	ret


;middle_bit_extract: ;extact decimal from 0-99
serial_get:
	lcall getchar ; Wait for data to arrive
	cjne a, #'#', forever_loop ; Message format is #n[data] where 'n' is '0' to '9'
	clr TMOD20 ; Stop the CCU from playing previous request
	setb FLASH_CE ; Disable SPI Flash	
	lcall getchar

MainProgram:
    mov SP, #0x7F
    
    lcall Ports_Init ; Default all pins as bidirectional I/O. See Table 42.
    lcall Double_Clk
	lcall InitSerialPort
	lcall InitDAC ; Call after 'Ports_Init
	lcall CCU_Init
	lcall Init_SPI
	
	clr TMOD20 ; Stop CCU timer
	setb EA ; Enable global interrupts.

	mov number, #0x0 ;;not needed
	mov individual_offest, #0x0
	clr nodigit
	clr skiphundred
	clr skiptenth
	
forever_loop: ;if pressed reset everyting
	jb RI, serial_get
	jb P3.0, forever_loop ; Check if push-button pressed
	jnb P3.0, $ ; Wait for push-button release

	lcall current_process_is
	lcall ramp_to_soak
	lcall current_temp_is
	mov number, #222 ;240
	lcall playnumbers
	lcall degree
	lcall celsius
	
	lcall current_process_is
	lcall reflow
	lcall current_temp_is
	mov number, #140 ;240
	lcall playnumbers
	lcall degree
	lcall celsius

	mov number, #140 ;240
	lcall playnumbers

	mov number, #154 ;240
	lcall playnumbers

	mov number, #165 ;240
	lcall playnumbers

	mov number, #176 ;240
	lcall playnumbers

	mov number, #187 ;240
	lcall playnumbers

	mov number, #198 ;240
	lcall playnumbers

	mov number, #217 ;31
	lcall playnumbers

	mov number, #118 ;73
	lcall playnumbers

	mov number, #119 ;19
	lcall playnumbers

	mov number, #114
	lcall playnumbers

	mov number, #115
	lcall playnumbers

	mov number, #111
	lcall playnumbers

	mov number, #112
	lcall playnumbers

	mov number, #113
	lcall playnumbers

	mov number, #119
	lcall playnumbers

	ljmp forever_loop

high_bit:
	clr TMOD20 ; Stop the CCU from playing previous request timer 2 control register
	setb FLASH_CE ;disable spi flash
	load_x(0)
    mov x, number
	lcall Hex2bcd

	mov bcd+2,#0x0
	mov bcd+0,#0
	mov a,bcd+1
	ANL A,#00001111b
	mov bcd+1,#0x0
	mov bcd,A
	lcall Bcd2hex
	mov tenth, x+0

	mov a,tenth
	cjne a, #0x00, proceed1
	setb skiphundred
	ret
proceed1:
	load_x(0) ;clear x
    mov x, tenth
	load_y(0)
	mov y,#low(hundreds_off_set)
	mov y+1,#high(hundreds_off_set)
    lcall mul32
	load_y(hundreds_start) ;add ff
	lcall add32

	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, x+2
	lcall Send_SPI
	mov a, x+1
	lcall Send_SPI
	mov a, x
	lcall Send_SPI

	; How many bytes to play? one number,  Asume 4Mbytes memory
	mov w+2, #0x00
	mov w+1, #high(hundreds_off_set)
	mov w+0, #low(hundreds_off_set)
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer

	ret

middle_bit:
	clr TMOD20 ; Stop the CCU from playing previous request timer 2 control register
	setb FLASH_CE ;disable spi flash
	load_x(0)
    mov x, number
	lcall Hex2bcd

	mov bcd+2,#0x0
	mov bcd+1,#0
	mov a,bcd+0
	swap a
	ANL A,#00001111b
	mov bcd,A
	lcall Bcd2hex
	mov tenth, x+0

	mov a,tenth
	cjne a, #0x00, proceed2
	setb skiptenth 
	ret
proceed2:
	cjne a, #0x01, continue
	ljmp special_decimal
continue:
	load_x(0) ;clear x
    mov x, tenth
	load_y(0)
	mov y,#low(decimal_off_set)
	mov y+1,#high(decimal_off_set)
    lcall mul32
	load_y(decimal_start) ;add ff
	lcall add32

	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, x+2
	lcall Send_SPI
	mov a, x+1
	lcall Send_SPI
	mov a, x
	lcall Send_SPI

	; How many bytes to play? one number,  Asume 4Mbytes memory
	mov w+2, #0x00
	mov w+1, #low(decimal_playtime)
	mov w+0, #high(decimal_playtime)
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer
	ret

special_decimal:  ;bits from 10 to 19
	clr TMOD20 ; Stop the CCU from playing previous request timer 2 control register
	setb FLASH_CE ;disable spi flash
	load_x(0)
    mov x, number
	lcall Hex2bcd

	mov bcd+2,#0x0
	mov bcd+1,#0
	mov a,bcd+0
	ANL A,#00001111b
	mov bcd,A
	lcall Bcd2hex
	mov digits, x+0
	mov a,digits

proceed4:
	load_x(0) ;clear x
    mov x, digits
	load_y(0)
	mov y,#low(special_off_set)
	mov y+1,#high(special_off_set)
    lcall mul32
	load_y(special_dec_start) ;add ff
	lcall add32
	;*****************************************
	load_y(0)
	mov y,individual_offest
	lcall add32
	mov individual_offest,#0x0

	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, x+2
	lcall Send_SPI
	mov a, x+1
	lcall Send_SPI
	mov a, x
	lcall Send_SPI

	; How many bytes to play? one number,  Asume 4Mbytes memory
	mov w+2, #0x00
	mov w+1, #high(special_playtime)
	mov w+0, #low(special_playtime)
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer
	setb nodigit ;to stop displaying the last digit
	ret

lower_bit: ;extract decimal fr0m 0-9
	jnb nodigit, continue2
	clr nodigit
	ret
continue2:
	clr TMOD20 ; Stop the CCU from playing previous request timer 2 control register
	setb FLASH_CE ;disable spi flash
	load_x(0)
    mov x, number
	lcall Hex2bcd

	mov bcd+2,#0x0
	mov bcd+1,#0
	mov a,bcd+0
	ANL A,#00001111b
	mov bcd,A
	lcall Bcd2hex
	mov digits, x+0
	mov a,digits
	cjne a, #0x00, proceed3
	ret
proceed3:
	load_x(0) ;clear x
    mov x, digits
	load_y(0)
	mov y,#low(number_off_set)
	mov y+1,#high(number_off_set)
    lcall mul32
	load_y(255) ;add ff
	lcall add32

	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, x+2
	lcall Send_SPI
	mov a, x+1
	lcall Send_SPI
	mov a, x
	lcall Send_SPI

	; How many bytes to play? one number,  Asume 4Mbytes memory
	mov w+2, #0x00
	mov w+1, #0x3e
	mov w+0, #0xa4
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer
	ret



playnumbers:
	lcall high_bit
	jb skiphundred,nozero1
	lcall WaitHalfSec
nozero1:
	clr skiphundred
	lcall middle_bit
	jb skiptenth,nozero
	lcall Wait250ms
nozero:
	clr skiptenth
	lcall lower_bit
	lcall Wait200ms
	ret

current_temp_is:
	load_x(current_temp_is_start) ;starting point
	load_y(current_temp_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	lcall Wait200ms
	ret
degree:
	load_x(degree_start) ;starting point
	load_y(degree_playtime) ;starting point
	lcall play_sentence
	lcall Wait200ms
	ret
celsius:
	load_x(celsius_start) ;starting point
	load_y(celsius_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	ret
current_process_is:
	load_x(current_process_is_start) ;starting point
	load_y(current_process_is_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	ret
ramp_to_soak:
	load_x(ramp_to_soak_start) ;starting point
	load_y(ramp_to_soak_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	ret
preheat_and_soak:
	load_x(preheat_and_soak_start) ;starting point
	load_y(preheat_and_soak_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	ret
ramp_to_peak:
	load_x(ramp_to_peak_start) ;starting point
	load_y(ramp_to_soak_playtime) ;starting point
	lcall play_sentence
	lcall WaitHalfSec
	ret
reflow:
	load_x(reflow_start) ;starting point
	load_y(reflow_playtime) ;starting point
	lcall play_sentence
	lcall Wait250ms
	ret
cooling:
	load_x(cooling_start) ;starting point
	load_y(cooling_playtime) ;starting point
	lcall play_sentence
	lcall Wait200ms
	ret


play_sentence: ;extract decimal fr0m 0-9
	clr TMOD20 ; Stop the CCU from playing previous request timer 2 control register
	setb FLASH_CE ;disable spi flash
	;lcall Wait250ms;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, x+2
	lcall Send_SPI
	mov a, x+1
	lcall Send_SPI
	mov a, x
	lcall Send_SPI

	; How many bytes to play? one number,  Asume 4Mbytes memory
	mov w+2, #0x00
	mov w+1, y+1
	mov w+0, y
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer

	ret




