CSEG
;---------------------------------;
; Initialize the serial port      ;
;---------------------------------;
;Serial_Initialize()
Serial_Initialize mac
    lcall _Serial_Initialize
endmac

_Serial_Initialize:
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
; Sends a byte via serial port    ;
;---------------------------------;

Serial_Send_Char mac
    mov a, %0
    lcall putchar
endmac

putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
;Serial_Read_Char(direct)
Serial_Read_Char mac
    lcall getchar
    mov %0, a
endmac

getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret



