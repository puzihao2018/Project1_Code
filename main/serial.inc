CSEG


;---------------------------------;
;           Basic Macros          ;
;---------------------------------;
Serial_Initialize mac
	;Serial_Initialize()
    lcall _Serial_Initialize
endmac

Serial_Send_Char mac
    mov a, %0
    lcall putchar
endmac

Serial_Read_Char mac
	;Serial_Read_Char(direct)
    lcall getchar
    mov %0, a
endmac

Serial_Send_Newline mac
	lcall Send_NewLine
endmac

Serial_Send_BCD mac
	push ar0
	mov r0, %0
	lcall ?Send_BCD
	pop ar0
endmac

Serial_Send_Constant_String mac
	mov dptr, %0
	lcall SendString
endmac

;---------------------------------;
; Initialize the serial port      ;
;---------------------------------;
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
putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

SendString:
    clr a
    movc a, @a+dptr
    jz SendString_L1
    lcall putchar
    inc dptr
    sjmp SendString  
SendString_L1:
	ret

;---------------------------------;
; Send a BCD number to PuTTY      ;
;---------------------------------;
?Send_BCD:
	push acc
	; Write most significant digit
	mov a, r0
	swap a
	anl a, #0fh
	orl a, #30h
	lcall putchar
	; write least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall putchar
	pop acc
	ret

Send_NewLine:
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar	
	ret


SendTemp0:
	mov dptr, #HexAscii 
	
	
	
	mov a, bcd+3
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, bcd+3
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	
	mov a, bcd+2
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, bcd+2
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	
	mov a, bcd+1
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, bcd+1
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar


	mov a, bcd+0
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, bcd+0
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	ret
