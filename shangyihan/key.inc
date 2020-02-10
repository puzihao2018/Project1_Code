cseg


;-----------------------;
;    Functions Define   ;
;-----------------------; 

;Key_Read: if read, return the button readed.
;Return 0 if read nothing.
Key_Read:
    push acc
    lcall ADC_to_PB; read lower 8 button
    ;mov a, keyin
    ;cjne a, #0, Continue_Read_Key; if nothing, continue read key
    ;ret; if read successfully, return
    ;Continue_Read_Key:
    lcall ADC_to_PB_1
	Wait_Milli_Seconds(#150)
	pop acc
    ret

ADC_to_PB:
    mov keyin, #0;clear input
	; Check PB6
	clr c
	mov a, AD0DAT0
	subb a, #(173-10) ; 2.8V=216*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L6
    mov keyin, #7
	ret
ADC_to_PB_L6:
	; Check PB5
	clr c
	mov a, AD0DAT0; P1.7
	subb a, #(155-10) ; 2.4V=185*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L5
	mov keyin, #6
	ret
ADC_to_PB_L5:
	; Check PB4
	clr c
	mov a, AD0DAT0
	subb a, #(130-10) ; 2.0V=154*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L4
	mov keyin, #5
	ret
ADC_to_PB_L4:
	; Check PB3
	clr c
	mov a, AD0DAT0
	subb a, #(108-10) ; 1.6V=123*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L3
	mov keyin, #4
	ret
ADC_to_PB_L3:
	; Check PB2
	clr c
	mov a, AD0DAT0
	subb a, #(78-10) ; 1.2V=92*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L2
	mov keyin, #3
	ret
ADC_to_PB_L2:
	; Check PB1
	clr c
	mov a, AD0DAT0
	subb a, #(61-10) ; 0.8V=61*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L1
	mov keyin, #2
	ret
ADC_to_PB_L1:
	; Check PB1
	clr c
	mov a, AD0DAT0
	subb a, #(29-10) ; 0.4V=30*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L0
	mov keyin, #1
	ret
ADC_to_PB_L0:
	; No pusbutton pressed	
	ret

ADC_to_PB_1:
	; Check PB6
	clr c
	mov a, AD0DAT1
	subb a, #(206-10) ; 2.8V=216*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L6_2
	mov keyin, #14
	ret
ADC_to_PB_L6_2:
	; Check PB5
	clr c
	mov a, AD0DAT1
	subb a, #(185-10) ; 2.4V=185*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L5_2
	mov keyin, #13
	ret
ADC_to_PB_L5_2:
	; Check PB4
	clr c
	mov a, AD0DAT1
	subb a, #(154-10) ; 2.0V=154*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L4_2
	mov keyin, #12
	ret
ADC_to_PB_L4_2:
	; Check PB3
	clr c
	mov a, AD0DAT1
	subb a, #(123-10) ; 1.6V=123*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L3_2
	mov keyin, #11
	ret
ADC_to_PB_L3_2:
	; Check PB2
	clr c
	mov a, AD0DAT1
	subb a, #(92-10) ; 1.2V=92*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L2_2
	mov keyin, #10
	ret
ADC_to_PB_L2_2:
	; Check PB1
	clr c
	mov a, AD0DAT1
	subb a, #(61-10) ; 0.8V=61*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L1_2
	mov keyin, #9
	ret
ADC_to_PB_L1_2:
	; Check PB1
	clr c
	mov a, AD0DAT1
	subb a, #(30-10) ; 0.4V=30*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L01
	mov keyin, #8
	ret
ADC_to_PB_L01:
	; No pusbutton pressed	
	ret
