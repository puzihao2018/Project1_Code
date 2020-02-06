

;---------------------------------;
; Initialize the SPI interface    ;
; and the pins associated to SPI. ;
;---------------------------------;
;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30
Result: ds 2

cseg
;---------------------------------;
;              Ports              ;
;---------------------------------;
FLASH_CE equ P2.4
MYADC_CE equ P2.7

;---------------------------------;
;              Consts             ;
;---------------------------------;
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0

;---------------------------------;
;           Basic Macros          ;
;---------------------------------;
SPI_Initialize mac
    lcall Init_SPI
endmac

;SPI_Send(direct)
;SPI_Send(#number)
SPI_Send mac
    mov a, %0
    lcall Send_SPI;
    mov %0, a
endmac

;---------------------------------;
;           Fucntion              ;
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

Send_SPI:
	mov SPDAT, a
Send_SPI_1:
	mov a, SPSTAT 
	jnb acc.7, Send_SPI_1 ; Check SPI Transfer Completion Flag
	mov SPSTAT, a ; Clear SPI Transfer Completion Flag
	mov a, SPDAT ; return received byte via accumulator
	ret

;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
MEM_Enable_Write mac
    lcall MEM_Enable_Write
endmac

_MEM_Enable_Write:
	setb MYADC_CE
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret


Read_ADC_Channel MAC
    mov b, #%0
    lcall _Read_ADC_Channel
ENDMAC

_Read_ADC_Channel:
    setb FLASH_CE 
    clr MYADC_CE
    mov a, #0b00000001 ;start bit:1 
    lcall Send_SPI

    mov a, b
    swap a
    anl a, #0xF0
    setb acc.7  ;Single mode (bit 7)
    lcall Send_SPI;send SPI and read to a
    anl a, #0b00000011; keep the last two digits only
    mov Result+1, a

    mov a, #55H     ; 0b10101010, used to debug through oscilloscope. Meaningless
    lcall Send_SPI
    mov Result, a   ; store current result
    setb MYADC_CE
    ;Wait_Milli_Seconds(#50)
    ret

