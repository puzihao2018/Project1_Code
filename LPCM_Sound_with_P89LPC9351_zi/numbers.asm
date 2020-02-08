
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
CCU_RELOAD  EQU ((65536-((CLK/(4*CCU_RATE)))))
BAUD        EQU 115200
BRVAL       EQU ((CLK/BAUD)-16)

FLASH_CE    EQU P2.4
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite

number_off_set EQU 17200 ;the distance between each number
;number start at ff

;starting addressed of different sound tracks
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
$include(num.inc)


MainProgram:
    mov SP, #0x7F
    
    lcall Ports_Init ; Default all pins as bidirectional I/O. See Table 42.
    ;lcall Double_Clk
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
