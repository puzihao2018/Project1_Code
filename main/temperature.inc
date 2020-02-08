cseg



Read_Oven_Temp:
	; Take 256 (4^4) consecutive measurements of ADC0 channel 0 at about 10 us intervals and accumulate in x
	Load_x(0)
    mov x+0, ad0dat2
	mov R7, #255
    lcall Wait10us
accumulate_loop0:
    mov y+0, ad0dat2
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    lcall add32
    lcall Wait10us
	djnz R7, accumulate_loop0
	
	; Now divide by 16 (2^4)
	Load_Y(16)
	lcall div32
	; x has now the 12-bit representation of the temperature
	
	; Convert to temperature (C)
	Load_Y(33000) ; Vref is 3.3V
	lcall mul32
	Load_Y(((1<<12))) ; 2^12-1
	lcall div32
	Load_Y(60)
	lcall sub32

	;mov32(Current_Oven_Volt,x); store the hex value of voltage
	
	Load_y(7438)
	lcall mul32
	Load_y(10000)
	lcall div32
	;now we got the relateive temp number in hex

	mov32(y, Current_Room_Temp)
	lcall add32
	;now we got the true value of oven in hex
	lcall hex2bcd
	lcall SendTemp0; send to PC through serial port
	lcall Send_Newline
	Load_y(100)
	lcall div32;divide by 100 to get the value in integer
	; now x contains the value in hex
	Load_y(350)
	lcall x_lt_y
	jb mf, Temp_OK
	;if not ok
	ljmp Read_Oven_Temp;re-read the value

	Temp_OK:
	mov32(Current_Oven_Temp, x)
	ret

Read_Room_Temp:
	
	Load_x(0)
    mov x+0, ad0dat2
	mov R7, #255
    lcall Wait10us
    
accumulate_loop1:
    mov y+0, ad0dat3
    mov y+1, #0
    mov y+2, #0
    mov y+3, #0
    lcall add32
    lcall Wait10us
	djnz R7, accumulate_loop1
	
	; Now divide by 16 (2^4)
	Load_Y(16)
	lcall div32
	; x has now the 12-bit representation of the temperature
	
	; Convert to temperature (C)
	Load_Y(33000) ; Vref is 3.3V
	lcall mul32
	Load_Y(((1<<12))) ; 2^12-1
	lcall div32
	Load_Y(60)
	lcall sub32
	
	;now we got the voltage value
	;mov32(Current_Room_Volt,x)
	
	Load_Y(27300)
	lcall sub32
	;now we got the temperature
	mov32(Current_Room_Temp,x)
	
	ret
