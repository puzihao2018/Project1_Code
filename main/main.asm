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

TIMER0_RATE   EQU 4096    ; 4096Hz
TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 100     ; 100Hz, for a timer tick of 10ms
TIMER1_RELOAD EQU ((65536-(XTAL/(2*TIMER1_RATE))))

;-------------------;
;    Ports Define   ;
;-------------------; 
BUTTON equ P0.1
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.4
LCD_D5 equ P1.3
LCD_D6 equ P1.2
LCD_D7 equ P3.1
;ADC00 equ P1.7; Read Oven Temperature
;ADC01 equ P0.0; Read Room Temperature
;ADC02 equ P2.1; Read Keyboard0
;ADC03 equ P2.0; Read Keyboard1



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
	ljmp Timer0_ISR
    ; External interrupt 1 vector
org 0x0013
	reti
    ; Timer/Counter 1 overflow interrupt vector
org 0x001B
	reti
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
    BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop

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
	Current_Room_Volt: ds 4
	Current_Oven_Volt: ds 4

    Cursor:     ds 1
    NEW_BCD:    ds 3    ; 3 digit BCD used to store current entered number
    NEW_HEX:    ds 4    ; 32 bit number of new entered number
    ;for math32.inc
    x: ds 4
    y: ds 4
    bcd: ds 5
    x_backup: ds 4
    y_backup: ds 4
;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg
    FSM0_State_Changed:  dbit 1
    Main_State:          dbit 1; 0 for setting, 1 for reflowing
    ;for math32.inc
    mf: dbit 1
    lessthan_flag: dbit 1
    equal_flag: dbit 1
    greater_flag: dbit 1
    half_seconds_flag: dbit 1; 500ms in double rate mode
;-----------------------;
;     Include Files     ;
;-----------------------; 
$NOLIST
    $include(lcd_4bit.inc) 
    $include(math32.inc)
    ;$include(DAC.inc)
    $include(LPC9351.inc)
    $include(serial.inc)

    ;$include(keys.inc)
    $include(temperature.inc)
$LIST


;-----------------------;
;    Program Segment    ;
;-----------------------; 
cseg

HexAscii: db '0123456789ABCDEF'
hex: db '0123456789abcdef',0

;LCD		   '1234567890123456'
Hello: 		db 'Hello World'		,0
WELCOME1: 	db 'WELCOME!        '	,0
WELCOME2: 	db 'Super Reflow!   '	,0
MAIN_FACE1:	db 'Setting: Prof   '	,0
MAIN_FACE2: db 'Start       Stop'   ,0
SETTING1: 	db 'STMP:   STM:   s'	,0
SETTING2:   db 'RTMP:   RTM:   s'   ,0
MODIFY_DOWN:db 'OLD:    NEW:    '   ,0
MODIFY1:	db 'MODIFY:TEMP_SOAK'	,0
MODIFY2:	db 'MODIFY:TIME_SOAK'	,0
MODIFY3:	db 'MODIFY:TEMP_RFLW'	,0
MODIFY4:	db 'MODIFY:TEMP_SOAK'	,0
MODIFY5:    db 'MODIFY:TEMP_SOAK'   ,0
WORKING:    db 'TEMP:   TIME:   '   ,0
STEP1:		db 'STMP:    RAMPING'   ,0
STEP2:      db 'STM:   s SOAKING'   ,0
STEP3:      db 'RTMP:    RAMPING'   ,0
STEP4:      db 'RTM:   s REFLOW '   ,0
STEP5:      db '         COOLING'   ,0
STEP6:      db '         FINISH '   ,0


;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0   ; not start timer 0, wait until used
	ret
;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;
Timer0_ISR:
    mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
    ;codes here
    reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 1                     ;
;---------------------------------;
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

;---------------------------------;
; ISR for timer 1                 ;
;---------------------------------;
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
	mov Count10ms, #0
    ;codes here

Timer1_ISR_done:
	pop psw
	pop acc
	reti

;---------------------------------;
; Routine to initialize the CCU   ;
; We are using the CCU timer in a ;
; manner similar to timer 2       ;
;---------------------------------;
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

;---------------------------------;
; ISR for CCU                     ;
;---------------------------------;
CCU_ISR:
	mov TIFR2, #0 ; Clear CCU Timer Overflow Interrupt Flag bit.
    ;codes here
	reti

;-------------------;
;       Macros      ;
;-------------------; 

MainProgram:
    mov SP, #0x7F
    Ports_Initialize()
    LCD_Initailize()
    Clock_Double()

    ADC_Initialize()

    mov FSM0_State, #0
    mov FSM1_State, #0
    mov Profile_Num, #0
    LCD_INTERFACE_WELCOME()
    lcall WaitHalfSec

;start fsm
MainLoop:
    jnb Main_State, FSM0    ;if 0, go to FSM0 to setting interface
    ;ljmp FSM1               ;if 1, go to FSM1 to reflow process

FSM0:
    ;-------------------;
    ;    Setting FSM    ;
    ;-------------------;

    ;Checking Keyboard
    ;Key_Scan()
    FSM0_Start:
        mov a, FSM0_State
        FSM0_State0:
            cjne a, #0, FSM0_State1
            LCD_INTERFACE_MAIN()

            jb BUTTON, FSM0_State0_Done
            Wait_Milli_Seconds(#75)
            jb BUTTON, FSM0_State0_Done
            jnb BUTTON, $
            mov FSM0_State, #0x01
            
            FSM0_State0_Done:
            ljmp MainLoop

        FSM0_State1:
            ;cjne a, #1, FSM0_State2
            LCD_INTERFACE_STEP1()

            LCD_Set_Cursor(1,6)
            LCD_Display_BCD(#Result+1)
			LCD_Display_BCD(#Result)

            
            jb BUTTON, FSM0_State1_Done
            Wait_Milli_Seconds(#75)
            jb BUTTON, FSM0_State1_Done
            jnb BUTTON, $
            mov FSM0_State, #0x00
            
           	FSM0_State1_Done:
            ljmp MainLoop

        FSM0_State2:
            cjne a, #2, FSM0_State3
            LCD_INTERFACE_MODIFY2()

        FSM0_State3:
            cjne a, #3, FSM0_State4
            LCD_INTERFACE_MODIFY3()

        FSM0_State4:
            cjne a, #4, FSM0_State5
            LCD_INTERFACE_MODIFY4()

        FSM0_State5:
            cjne a, #5, FSM0_Done
            LCD_INTERFACE_MODIFY5()

        FSM0_Done:
            ljmp MainLoop

    ;---------------------------------;
    ; FSM1 using Timer Interrupt      ;
    ;---------------------------------;
    ;update status and send data to LCD and PC every one/half seconds
    FSM1:
    mov a, FSM0_State
    FSM1_State0:
        cjne a, #0, FSM1_State1
        setb OVEN; turn oven on
        lcall Update_Temp_Info
        Compare(Current_Oven_Temp, TEMP_RFLW)
        jb lessthan_flag, FSM1_State0_Done
        ;if temp greater
        inc FSM1_State; go to next state
        FSM1_State0_Done:
            mov Time_Counter, #0; reset timer
            ljmp Timer1_ISR_done

    FSM1_State1:
        cjne a, #1, FSM1_State2
        inc Time_Counter; increment every 1 second
        ;compare time
        mov x+3, #0
        mov x+2, #0
        mov x+1, #0
        mov x,   Time_Counter
        mov32(y, TIME_SOAK)
        lcall x_lt_y
        jb mf, FSM1_State1_Continue
        ;time over, change state
        inc FSM1_State; increment states
        FSM1_State1_Continue:
            ;next: check temp
            Compare(Current_Oven_Temp, TEMP_SOAK)
            jb lessthan_flag, FSM1_State1_ON
            ;if temp is higher than expected
            clr OVEN ; if temp is higher, close oven
            ljmp FSM1_State1_Done

            FSM1_State1_ON:
            setb OVEN   ;if temp is lower, turn on oven
        FSM1_State1_Done:
            ljmp Timer1_ISR_done

    FSM1_State2: ;temp ramp up until TEMP_RFLW
        cjne a, #2, FSM1_State3
        
	FSM1_State3:
		NOP
        
END
