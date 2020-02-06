$NOLIST
CSEG

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

	; How many bytes to play? one number,
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

	; How many bytes to play? 
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

	; How many bytes to play? one number,
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

	; How many bytes to play? 
	mov w+2, #0x00
	mov w+1, y+1
	mov w+0, y
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb TMOD20 ; Start playback by enabling CCU timer

	ret


$LIST
