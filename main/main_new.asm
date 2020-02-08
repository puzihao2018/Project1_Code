$NOLIST
$MOD9351
$LIST

;-------------------;
;    Const Define   ;
;-------------------; 
XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CCU_RATE      EQU 100      ; 100Hz, for an overflow rate of 10ms
CCU_RELOAD    EQU ((65536-(XTAL/(2*CCU_RATE))))

;TIMER0_RATE   EQU 4096    ; 4096Hz
;TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 100     ; 100Hz, for a timer tick of 10ms
TIMER1_RELOAD EQU ((65536-(XTAL/(2*TIMER1_RATE))))
QUITTIME      EQU 30
QUITTEMP      EQU 60

;-------------------;
;    Ports Define   ;
;-------------------; 
BUTTON equ P0.1
LED    equ P0.2
LCD_RS equ P0.5
LCD_RW equ P0.6
LCD_E  equ P0.7
LCD_D4 equ P3.1
LCD_D5 equ P1.2
LCD_D6 equ P1.3
LCD_D7 equ P1.4
;ADC00 equ P1.7; Read Oven Temperature
;ADC01 equ P0.0; Read Room Temperature
;ADC02 equ P2.1; Read Keyboard0
;ADC03 equ P2.0; Read Keyboard1
OVEN   equ P2.7
ALARM  equ P1.6

;------------------------;
;    Interrupt Vectors   ;
;------------------------; 
; Reset vector
org 0x0000
    ljmp MainProgram
    ; External interrupt 0 vector
org 0x0003
	reti
    ; Timer/Counter 0 overflow interrupt vector
org 0x000B
	reti
    ; External interrupt 1 vector
org 0x0013
	reti

    ; Timer/Counter 1 overflow interrupt vector
org 0x001B
	ljmp Timer1_ISR
    ; Serial port receive/transmit interrupt vector
org 0x0023 
	reti
    ; CCU interrupt vector
org 0x005b 
	ljmp CCU_ISR

;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30
    Count10ms:    ds 1 ; Used to determine when half second has passed
    Time_Global:  ds 1 ; to store the time of whole process
    Time_Counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

    FSM0_State: ds 1
    FSM1_State: ds 1

    Profile_Num: ds 1

    TEMP_SOAK:  ds 4
    TIME_SOAK:  ds 4
    TEMP_RFLW:  ds 4
    TIME_RFLW:  ds 4
    TEMP_SAFE:  ds 4
    Current_Room_Temp: ds 4
	Current_Oven_Temp: ds 4

    Cursor:     ds 1
    NEW_BCD:    ds 3    ; 3 digit BCD used to store current entered number
    NEW_HEX:    ds 4    ; 32 bit number of new entered number
    ;for math32.inc
    x: ds 4
    y: ds 4
    bcd: ds 5

;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg
    FSM0_State_Changed:  dbit 1
    Main_State:          dbit 1 ; 0 for setting, 1 for reflowing
    ;for math32.inc
    mf: dbit 1
    lessthan_flag: dbit 1
    equal_flag: dbit 1
    greater_flag: dbit 1
    half_seconds_flag: dbit 1 ; 500ms in double rate mode
;-----------------------;
;     Include Files     ;
;-----------------------; 
;$NOLIST
    $include(lcd_4bit.inc) 
    $include(math32.inc)
    $include(LPC9351.inc)
    $include(serial.inc)
    $include(temperature.inc)
;$LIST

cseg


MainProgram:
    mov SP, #0x7F
    Ports_Initialize()
    LCD_Initailize()

    ;Clock_Double()
    ADC_Initialize()
    mov Time_Global, #0x00
    mov TEMP_SOAK+3, #0x00
    mov TEMP_SOAK+2, #0x00
    mov TEMP_SOAK+1, #0x00
    mov TEMP_SOAK, #100
    mov TEMP_RFLW+3, #0
    mov TEMP_RFLW+2, #0
    mov TEMP_RFLW+1, #0
    mov TEMP_RFLW, #220
    mov TIME_SOAK+3, #0
    mov TIME_SOAK+2, #0
    mov TIME_SOAK+1, #0
    mov TIME_SOAK, #30
    mov TIME_RFLW+3, #0
    mov TIME_RFLW+2, #0
    mov TIME_RFLW+1, #0
    mov TIME_RFLW, #10
    mov TEMP_SAFE, #0
    mov TEMP_SAFE, #0
    mov TEMP_SAFE, #0
    mov TEMP_SAFE, #60
    mov FSM0_State, #0
    mov FSM1_State, #0
    clr ALARM
    setb EA   ; Enable Global interrupts
    LCD_INTERFACE_WELCOME()
    clr OVEN


loop:
    jb BUTTON, loop
    Wait_Milli_Seconds(#75)
    jb BUTTON, loop
    jnb BUTTON, $
    lcall Timer1_Init
loop_a:
    jnb half_seconds_flag, loop_a
loop_b:
    clr half_seconds_flag
    cpl LED
    lcall FSM1
	sjmp loop_a

Display_3BCD_from_x mac
    lcall hex2bcd
    ;now the bcd num of time is stored in bcd
    LCD_Display_NUM(bcd+1);
    LCD_Display_BCD(bcd);
endmac
;----------------------------;
;     Interrupt Services     ;
;----------------------------; 

Timer1_Init:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	; Enable the timer and interrupts
    setb ET1  ; Enable timer 1 interrupt
    setb TR1  ; Start timer 1
	ret

CCU_Init:
	mov TH2, #high(CCU_RELOAD)
	mov TL2, #low(CCU_RELOAD)
	mov TOR2H, #high(CCU_RELOAD)
	mov TOR2L, #low(CCU_RELOAD)
	mov TCR21, #10000000b ; Latch the reload value
	mov TICR2, #10000000b ; Enable CCU Timer Overflow Interrupt
	setb ECCU ; Enable CCU interrupt
	clr TMOD20 ; not start CCU timer yet, wait until used
	ret

Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	cpl P2.6 ; To check the interrupt rate with oscilloscope. It must be precisely a 10 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 8-bit 10-mili-second counter
	inc Count10ms

Inc_Done:
	; Check if half second has passed
	mov a, Count10ms
	cjne a, #50, Timer1_ISR_done ; Warning: this instruction changes the carry flag!
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
    inc Time_Global
	mov Count10ms, #0
Timer1_ISR_done:
	pop psw
	pop acc
	reti

CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit.
    ;codes here
	reti

Display_Working_Status:
    LCD_Set_Cursor(1,6)
    mov32(x, Current_Oven_Temp)
    Display_3BCD_from_x()

    LCD_Set_Cursor(1, 14)
    mov x+3, #0
    mov x+2, #0
    mov x+1, #0
    mov x, Time_Global
    Display_3BCD_from_x()

    ret

Update_Temp mac
    lcall Read_Room_Temp
    lcall Read_Oven_Temp

    mov32(x, Current_Oven_Temp)
    mov32(y, %0)
    lcall x_lt_y
endmac

FSM1:
    
    ;---------------------------------;
    ; FSM1 using Timer Interrupt      ;
    ;---------------------------------;
    ;update status and send data to LCD and PC every one/half seconds

    mov a, FSM1_State
    FSM1_State0:
        cjne a, #0, JUMP_FSM1_State1
        sjmp Start_FSM1_State0
        JUMP_FSM1_State1:
        ljmp FSM1_State1
        
        Start_FSM1_State0:
        setb OVEN; turn oven on
        Update_Temp(TEMP_SOAK)    ;Read Temperatures
        LCD_INTERFACE_STEP1();display interface
        lcall Display_Working_Status
        LCD_Set_Cursor(2,6)
        mov32(x, TEMP_SOAK)
        Display_3BCD_from_x()

        jb mf, FSM1_State0_Error_Check;check Error and continue if smaller than set time
        ;if temp greater
        inc FSM1_State; go to next state            
        mov Time_Counter, TIME_SOAK; move the TIME_SOAK in counter and count down
        sjmp FSM1_State0_Done

        FSM1_State0_Error_Check:
        mov a, Time_Global
        cjne a, #QUITTIME, FSM1_State0_Done; not time, done
        ;if time reached, check temp
        mov32(x, Current_Oven_Temp);move current oven temp in x
        mov y+3, #0
        mov y+2, #0
        mov y+1, #0
        mov y, #QUITTEMP
        lcall x_lt_y; check if current oven temp is smaller than quittemp

        jnb mf, FSM1_State0_Done; the oven is working properly
        ;if not working right
        ljmp FSM1_WARNING



        FSM1_State0_Done:
            ljmp FSM1_DONE


    FSM1_State1:
        cjne a, #1, JUMP_FSM1_State2
            sjmp Start_FSM1_State1
        JUMP_FSM1_State2:
            ljmp FSM1_State2
        
        Start_FSM1_State1:
        djnz Time_Counter, FSM1_State1_Continue; decrement every 1 second
        ;time over, change state
        inc FSM1_State; increment states
        ljmp FSM1_State1_Done

        FSM1_State1_Continue:
        ;next: check temp
        ;read temp and compare
        Update_Temp(TEMP_SOAK)   ;Update current temp info
        LCD_INTERFACE_STEP2()
        lcall Display_Working_Status; update time and temp on lcd
        ;if temp is lower than expected, jump to ON
        LCD_Set_Cursor(2,5)
        Load_x(0)
        mov x, Time_Counter
        Display_3BCD_from_x()

        jb mf, FSM1_State1_ON
        ;if temp is higher, close oven
        clr OVEN 
        sjmp FSM1_State1_Done

        FSM1_State1_ON:
        setb OVEN   ;if temp is lower, turn on oven
        FSM1_State1_Done:
            ljmp FSM1_DONE

    FSM1_State2: ;temp ramp up until TEMP_RFLW
        cjne a, #2, JUMP_FSM1_State3
            sjmp Start_FSM1_State2
        JUMP_FSM1_State3:
            ljmp FSM1_State3

        Start_FSM1_State2:
        setb OVEN; turn on oven

        ;read temperature
        Update_Temp(TEMP_RFLW)
        jb mf, FSM1_State2_Continue
        ;if temp reached
        inc FSM1_State
        mov Time_Counter, #0
        ljmp FSM1_DONE

        FSM1_State2_Continue:
        LCD_INTERFACE_STEP3()
        lcall Display_Working_Status
        LCD_Set_Cursor(2,6)
        mov32(x, TEMP_RFLW)
        Display_3BCD_from_x()

        FSM1_State2_Done:
            ljmp FSM1_DONE
        
	FSM1_State3: ; keep temp at TEMP_RFLW for a few time
        cjne a, #3, JUMP_FSM1_State4
            sjmp Start_FSM1_State3
        JUMP_FSM1_State4:
            ljmp FSM1_State4
        
        Start_FSM1_State3:
        inc Time_Counter; increment every 1 second
        ;compare time
        LCD_INTERFACE_STEP4()
        mov x+3, #0
        mov x+2, #0
        mov x+1, #0
        mov x,   Time_Counter
        mov32(y, TIME_RFLW)
        lcall x_lt_y

        jb mf, FSM1_State3_Continue
        ;time over, change state
        inc FSM1_State; increment states
        ljmp FSM1_State3_Done

        FSM1_State3_Continue:
        ;next: check temp
        ;read temp and compare
        lcall Read_Room_Temp
        lcall Read_Oven_Temp
        mov32(x, Current_Oven_Temp)
        mov32(y, TEMP_RFLW)
        lcall x_lt_y

        ;if temp is lower than expected, jump to ON
        jb lessthan_flag, FSM1_State3_ON
        ;if temp is higher, close oven
        clr OVEN 
        sjmp FSM1_State3_Done

        FSM1_State3_ON:
        setb OVEN   ;if temp is lower, turn on oven
        FSM1_State3_Done:
            ljmp FSM1_DONE
        

    
    FSM1_State4:; cool down until safe temp
        cjne a, #4, FSM1_State5
        clr OVEN
        ;read temperature
        lcall Read_Room_Temp
        lcall Read_Oven_Temp
        mov32(x, Current_Oven_Temp)
        mov32(y, TEMP_SAFE)
        lcall x_lt_y
        ;if temp is not smaller than TEMP_SAFE, do nothing
        jnb mf, FSM1_State4_Done
        ;if temp is smaller than expected
        inc FSM1_State
        mov Time_Counter, #0

        FSM1_State4_Done:
            ljmp FSM1_DONE

    FSM1_State5: ; already cool done, display something, play some music
        cjne a, #5, FSM1_DONE
        clr OVEN; double check oven is not on


    FSM1_WARNING:
        clr OVEN
        LCD_INTERFACE_WARNING()
        setb ALARM
        sjmp $


    FSM1_DONE:
    ret

END