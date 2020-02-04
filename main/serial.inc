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
	lcall Send_nl
endmac

Serial_Read_Byte mac
	; read a byte in a
	lcall getbyte
endmac

Serial_Send_Byte mac
	; send a byte from a 
	lcall putbyte
endmac

Serial_Read_Address mac
	; read a byte to a
	lcall getaddress
endmac

Serial_Send_Address mac
	lcall putadd
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

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

Send_nl:;Send new line
    mov a, #'\r'
    lcall putchar
    mov a, #'\n'
    lcall putchar
    ret

getbyte:
    push b
    ; Get most significant nibble
    lcall getchar
    anl a, #00011111B ; To deal with upercase/lowercase
    jb acc.4, getbyte_1
    add a, #9
getbyte_1:
    anl a, #00001111B
    swap a
    mov b, a
    ; Get least significant nibble
    lcall getchar
    anl a, #00011111B ; To deal with upercase/lowercase
    jb acc.4, getbyte_2
    add a, #9
getbyte_2:
    anl a, #00001111B
    orl a, b
    pop b
    ret

getaddress:
    push acc
    lcall getchar
    anl a, #00000001B
    mov dph, a
    lcall getbyte
    mov dpl, a
    pop acc
    ret


putbyte:
    ; Preserve used registers
    push acc
    push dpl
    push dph
    ; Display a hex byte 
    push acc
    mov dptr, #hex
    swap a
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    pop acc
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    ; Restore used registers
    pop dph
    pop dpl
    pop acc
    ret
    
putadd:
    ; Preserve used registers
    push acc
    push dpl
    push dph
    ; Display a hex address     
    mov a, dph
    push dpl
    mov dptr, #hex
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    pop acc
    lcall putbyte
    ; Restore used registers
    pop dph
    pop dpl
    pop acc
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