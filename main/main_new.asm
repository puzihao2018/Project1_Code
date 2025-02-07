$NOLIST
$MOD9351
$LIST

;-------------------;
;    Const Define   ;
;-------------------; 
XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CCU_RATE      EQU 22050
CCU_RELOAD    EQU ((65536-((XTAL/(2*CCU_RATE)))))

;TIMER0_RATE   EQU 4096    ; 4096Hz
;TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 100     ; 1000Hz, for a timer tick of 1ms
TIMER1_RELOAD EQU ((65536-(XTAL/(2*TIMER1_RATE))))
QUITTIME      EQU 60
QUITTEMP      EQU 50
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
hundreds_off_set EQU 36000

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
;-------------------;
;    Ports Define   ;
;-------------------; 
;ADC01 equ P0.0; Read Room Temperature
LCD_RS equ P0.1
LCD_RW equ P0.2
LCD_E  equ P0.3
;Soundout  P0.4
LCD_D4 equ P0.5
LCD_D5 equ P0.6
LCD_D6 equ P0.7
LCD_D7 equ P3.0
;          P3.1
;          P1.2
Start  equ P1.3
Stop   equ P1.4
LED    equ P1.6
;ADC00 equ P1.7; Read Oven Temperature
;ADC03 equ P2.0; Read Keyboard1
;ADC02 equ P2.1; Read Keyboard0
;MOSI  equ P2.2
;MISO  equ P2.3
FLASH_CE EQU P2.4
;SPICK equ P2.5
;WAVEOUT   P2.6
OVEN   equ P2.7

;------------------------;
;    Interrupt Vectors   ;
;------------------------; 
; Reset vector
org 0x0000
    ljmp MainProgram

; External interrupt 0 vector, start
org 0x0003
	ljmp EI0_ISR

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	reti

; External interrupt 1 vector, stop
org 0x0013
	ljmp EI1_ISR

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
    Time_Global:  ds 2 ; to store the time of whole process
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
    bcd_bitnumber: ds 1

    individual_offest: ds 1

    NEW_BCD:    ds 2    ; 3 digit BCD used to store current entered number
    ;for math32.inc
    x: ds 4
    y: ds 4
    bcd: ds 5
    Count5s: ds 1
    ;z
    w:   ds 3 ; 24-bit play counter.  Decremented in CCU ISR.
	number: ds 1;
    digits: ds 1;
	tenth: ds 1;
    speak_state:       ds 1;
    ;key
    keyin: ds 1


;-------------------;
;    Flags Define   ;
;-------------------; 
;Flag_name: dbit 1
bseg
    FSM0_State_Changed:  dbit 1
    Main_State:          dbit 1 ; 0 for setting, 1 for reflowing
    ;for math32.inc
    mf: dbit 1
    enable_time_global: dbit 1
    half_seconds_flag: dbit 1 ; 500ms in double rate mode
        nodigit: dbit 1 ; if playing from 10 to 19 then we don't need to
                    ;play the last digit
	skiphundred: dbit 1
	skiptenth: dbit 1
    speak_enable: dbit 1
;-----------------------;
;     Include Files     ;
;-----------------------; 
;$NOLIST
    $include(lcd_4bit.inc) 
    $include(math32.inc)
    $include(LPC9351.inc)
    $include(serial.inc)
    $include(temperature.inc)
    $include(speaker.inc)
    $include(key.inc)
;$LIST

cseg

MainProgram:
    mov SP, #0x7F
    Ports_Initialize()
    LCD_Initailize()
    Serial_Initialize()
    ADC_Initialize()
    LCD_INTERFACE_WELCOME()
    lcall Data_Initialization
    lcall InitDAC
    lcall CCU_Init
	lcall Init_SPI
    lcall External_Interrupt0_Init
    lcall External_Interrupt1_Init
    mov TEMP_SOAK+3, #0x00
    mov TEMP_SOAK+2, #0x00
    mov TEMP_SOAK+1, #0x00
    mov TEMP_SOAK, #150
    mov TEMP_RFLW+3, #0
    mov TEMP_RFLW+2, #0
    mov TEMP_RFLW+1, #0
    mov TEMP_RFLW, #217
    mov TIME_SOAK+3, #0
    mov TIME_SOAK+2, #0
    mov TIME_SOAK+1, #0
    mov TIME_SOAK, #60
    mov TIME_RFLW+3, #0
    mov TIME_RFLW+2, #0
    mov TIME_RFLW+1, #0
    mov TIME_RFLW, #75
    mov TEMP_SAFE+3, #0
    mov TEMP_SAFE+2, #0
    mov TEMP_SAFE+1, #0
    mov TEMP_SAFE, #60
    clr TMOD20 ; Stop CCU timer
    setb EA   ; Enable Global interrupts
    clr OVEN
    lcall WaitHalfSec

Main_Loop:
    jb Main_State,loop_b
loop_a:; for FSM0
	ljmp FSM0

loop_b: ; for FSM1
    jnb half_seconds_flag, Main_Loop
    clr half_seconds_flag
    inc Count5s
    mov a, Count5s
    cjne a, #5, skip3
    mov Count5s, #0
    jnb speak_enable, skip3
    lcall Speak_Process
    skip3:
	sjmp Main_Loop


;----------------------------;
;           Macros           ;
;----------------------------; 
Display_3BCD mac
    ;Display_3BCD(bcd to display)
    ;now the bcd num of time is stored in bcd
    LCD_Display_NUM(%0+1);
    LCD_Display_BCD(%0);
endmac

Display_3BCD_from_x mac
    lcall hex2bcd
    ;now the bcd num of time is stored in bcd
    LCD_Display_NUM(bcd+1);
    LCD_Display_BCD(bcd);
endmac

Update_Temp mac
    lcall Read_Room_Temp
    lcall Read_Oven_Temp

    mov32(x, Current_Oven_Temp)
    mov32(y, %0)
    lcall x_lt_y
endmac

;----------------------------;
;         Functions          ;
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

External_Interrupt0_Init:
	; Enable the external interrupt
    setb EX0  ; Enable timer 1 interrupt
	ret

External_Interrupt1_Init:
	; Enable the external interrupt
    setb EX1  ; Enable timer 1 interrupt
	ret

Display_Working_Status:
    LCD_Set_Cursor(1,6)
    mov32(x, Current_Oven_Temp)
    Display_3BCD_from_x()

    LCD_Set_Cursor(1, 14)
    mov x+3, #0
    mov x+2, #0
    mov x+1, Time_Global+1
    mov x, Time_Global
    Display_3BCD_from_x()
    ret

Data_Initialization:
    mov Time_Global+1, #0x00
    mov Time_Global+0, #0x00
    mov FSM0_State, #0x00
    mov FSM1_State, #0x00
    mov NEW_BCD, #0
    mov NEW_BCD+1, #0
    mov number, #0x0 ;;not needed
    mov Count5s, #0x00
    mov speak_state, #0x00
    mov bcd_bitnumber, #0x03
    
    clr LED
    clr speak_enable
    clr enable_time_global
    clr nodigit
	clr skiphundred
	clr skiptenth
    clr Main_State
    clr OVEN
    ret

Speak_Process:
    lcall current_temp_is
    mov number, Current_Oven_Temp+0
    lcall playnumbers
    lcall degree
    lcall celsius
    ret

;----------------------------;
;     Interrupt Services     ;
;----------------------------; 
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
	; Check if one second has passed
	mov a, Count10ms
	cjne a, #100, Timer1_ISR_done
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
    
    jnb enable_time_global, skip1
	; Increment the 16-bit one mili second counter
	inc Time_Global+0    ; Increment the low 8-bits first
	mov a, Time_Global+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz skip1
	inc Time_Global+1

	skip1:
    mov Count10ms, #0

    cpl LED
    lcall FSM1;call FSM1 here

Timer1_ISR_done:
	pop psw
	pop acc
	reti

EI0_ISR:
    clr IT0
    clr EX0
    setb Main_State
    lcall current_process_is
    lcall ramp_to_soak
    lcall Timer1_Init
    reti

EI1_ISR:
    clr IT1
    clr TR1; disable timer 1
    clr OVEN
    setb EX0
    lcall clear_speaking
    lcall Data_Initialization
    reti

;---------------------------------;
;      Finite State Machines      ;
;---------------------------------;
FSM0:
    ;-------------------;
    ;    Setting FSM    ;
    ;-------------------;

    ;Checking Keyboard
    ;Key_Scan()
    FSM0_Start:
        mov a, FSM0_State
        sjmp FSM0_State0

        FSM0_State1_bridge:
            ljmp FSM0_State1 
        FSM0_State0:
            cjne a, #0, FSM0_State1_bridge

            ;display a word
            LCD_INTERFACE_SETTING()

            LCD_Set_Cursor(2,13)
            mov x,#0x0
            mov x+1,#0x0
            mov x+2,#0x0
            mov x+3,#0x0
            mov x, TIME_RFLW
            Display_3BCD_from_x()

            LCD_Set_Cursor(1,13)
            mov x,#0x0
            mov x+1,#0x0
            mov x+2,#0x0
            mov x+3,#0x0
            mov x, TIME_SOAK
            Display_3BCD_from_x()

            LCD_Set_Cursor(2,6)
            mov x,#0x0
            mov x+1,#0x0
            mov x+2,#0x0
            mov x+3,#0x0
            mov x, TEMP_RFLW
            Display_3BCD_from_x()

            LCD_Set_Cursor(1,6)
            mov x,#0x0
            mov x+1,#0x0
            mov x+2,#0x0
            mov x+3,#0x0
            mov x, TEMP_SOAK
            Display_3BCD_from_x()


            lcall Key_Read
            Load_x(0)
            mov x, keyin
            Load_y(13)
            lcall x_eq_y

            jnb mf,FSM0_State0_down
            inc FSM0_State 
            lcall change_state_flag
            ljmp FSM0_Done
        
        FSM0_State0_down:

            ;lcall Key_Read
            Load_x(0)
            mov x, keyin
            Load_y(14)
            lcall x_eq_y

            jnb mf,FSM0_State0_bridge
            mov FSM0_State, #0x04 
            lcall change_state_flag
            ljmp FSM0_Done
        FSM0_State0_bridge:
            ljmp FSM0_Done

        FSM0_State2_bridge:
            ljmp FSM0_State2
        
        FSM0_State1:
            cjne a, #1, FSM0_State2_bridge
            
            ;print words
            LCD_INTERFACE_MODIFY1()
            LCD_Set_Cursor(2,5)
            ;mov x,#0x0
            ;mov x+1,#0x0
            ;mov x+2,#0x0
            ;mov x+3,#0x0
            mov x,TEMP_SOAK
            Display_3BCD_from_x()

            LCD_Set_Cursor(2,13)
            Display_3BCD(NEW_BCD)
            ;LCD_Set_Cursor(1,13)
            ;Display_3BCD(NEW_BCD)
            ;Wait_Milli_Seconds(#250)
            ;Wait_Milli_Seconds(#250)
            
            ; the left bit of bcd
            lcall check_button
            
            jnb mf,normal_button_jump_2
            
            lcall write_bcd
        
            
            ; the middle bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_2
            lcall write_bcd
            
          

            ; the right bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_2
            lcall write_bcd


            
            ljmp state_1_continue_1
        

        normal_button_jump_2:
            
            ljmp  normal_button
            
           
        state_1_continue_1:    
            ;mov FSM0_State, #0x02
            ;jb BUTTON, FSM0_State1_Done
            ;Wait_Milli_Seconds(#75)
            ;jb BUTTON, FSM0_State1_Done
            ;jnb BUTTON, $
            ;mov FSM0_State, #0x00
            
           	FSM0_State1_Done:
            ljmp Main_Loop

        FSM0_State3_bridge:
            ljmp FSM0_State3
        FSM0_State2:
            cjne a, #2, FSM0_State3_bridge
            ;LCD_INTERFACE_MODIFY2()

            ;print words
            LCD_INTERFACE_MODIFY2()
            LCD_Set_Cursor(2,5)

            ;mov x,#0x0
            ;mov x+1,#0x0
            ;mov x+2,#0x0
            ;mov x+3,#0x0
            mov x,TIME_SOAK
            Display_3BCD_from_x()

            LCD_Set_Cursor(2,13)
            Display_3BCD(NEW_BCD)
            
            
            ; the left bit of bcd
            lcall check_button
            
            jnb mf,normal_button_jump_3
            
            lcall write_bcd
        
            
            ; the middle bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_3
            lcall write_bcd
            
          

            ; the right bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_3
            lcall write_bcd


            
           
        

            ljmp state_2_continue_1
        normal_button_jump_3:
            ljmp  normal_button
            
           
        state_2_continue_1:    
            ;mov FSM0_State, #0x03
            ;jb BUTTON, FSM0_State1_Done
            ;Wait_Milli_Seconds(#75)
            ;jb BUTTON, FSM0_State1_Done
            ;jnb BUTTON, $
            ;mov FSM0_State, #0x00
            
           	FSM0_State2_Done:
            ljmp Main_Loop

        FSM0_State4_bridge:
            ljmp FSM0_State4

        FSM0_State3:
            cjne a, #3, FSM0_State4_bridge
            ;LCD_INTERFACE_MODIFY2()

            ;print words
            LCD_INTERFACE_MODIFY3()
            LCD_Set_Cursor(2,5)

            ;mov x,#0x0
            ;mov x+1,#0x0
            ;mov x+2,#0x0
            ;mov x+3,#0x0
            mov x,TEMP_RFLW
            Display_3BCD_from_x()

            LCD_Set_Cursor(2,13)
            Display_3BCD(NEW_BCD)
            
            
            ; the left bit of bcd
            lcall check_button
            
            jnb mf,normal_button_jump_4
            
            lcall write_bcd
        
            
            ; the middle bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_4
            lcall write_bcd
            
          

            ; the right bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_4
            lcall write_bcd


            
           
            ljmp state_3_continue_1
        normal_button_jump_4:
            ljmp  normal_button
            
           
        state_3_continue_1:    
            ;mov FSM0_State, #0x02
            ;jb BUTTON, FSM0_State1_Done
            ;Wait_Milli_Seconds(#75)
            ;jb BUTTON, FSM0_State1_Done
            ;jnb BUTTON, $
            ;mov FSM0_State, #0x00
            
           	FSM0_State3_Done:
            ljmp Main_Loop

        FSM0_State5_bridge:
            ljmp FSM0_Done
        FSM0_State4:
            cjne a, #4, FSM0_State5_bridge
            ;LCD_INTERFACE_MODIFY2()

            ;print words
            LCD_INTERFACE_MODIFY4()
            LCD_Set_Cursor(2,5)


            ;mov x,#0x0
            ;mov x+1,#0x0
            ;mov x+2,#0x0
            ;mov x+3,#0x0
            mov x,TIME_RFLW
            Display_3BCD_from_x()

            LCD_Set_Cursor(2,13)
            Display_3BCD(NEW_BCD)
            
            
            ; the left bit of bcd
            lcall check_button
            
            jnb mf,normal_button_jump_5
            
            lcall write_bcd
        
            
            ; the middle bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_5
            lcall write_bcd
            
          

            ; the right bit of bcd
            lcall check_button
            jnb mf,normal_button_jump_5
            lcall write_bcd


            
           
        

            ljmp state_4_continue_1
        normal_button_jump_5:
            ljmp  normal_button
        state_4_continue_1:    
            ;mov FSM0_State, #0x02
            ;jb BUTTON, FSM0_State1_Done
            ;Wait_Milli_Seconds(#75)
            ;jb BUTTON, FSM0_State1_Done
            ;jnb BUTTON, $
            ;mov FSM0_State, #0x00
            
           	FSM0_State4_Done:
            ljmp Main_Loop

        ;FSM0_State5:
            ;cjne a, #5, FSM0_Done
            ;LCD_INTERFACE_MODIFY5()

        FSM0_Done:
            ljmp Main_Loop

    check_button:
            ;scan number button
            lcall Key_Read
           
            Load_x(0)
            mov x, keyin
            Load_y(11)
            lcall x_lt_y
            
            mov a, keyin
            cjne a,#0x00,continue_check
            sjmp check_button
    continue_check:
            ret
   

    write_bcd:
                mov a , bcd_bitnumber
                cjne a, #0x03, bcd_bit_2
                
                Wait_Milli_Seconds(#250)
                mov a, keyin
                cjne a,#0x0A,continue_bcd
                mov a,#0x00
    continue_bcd:
                anl a, #0x0f
	            ;orl a, NEW_BCD+1
	            mov NEW_BCD+1,a
                mov bcd_bitnumber, #0x02
                ;display new_bcd
                LCD_Set_Cursor(2,13)
                Display_3BCD(NEW_BCD)

                Wait_Milli_Seconds(#250)
                
                ret


    bcd_bit_2:
                mov a , bcd_bitnumber
                cjne a, #0x02, bcd_bit_1
                Wait_Milli_Seconds(#250)
                mov a, NEW_BCD
                anl a, #0x0f
                mov NEW_BCD,a
                mov a, keyin
                cjne a,#0x0A,continue_bcd_1
                mov a,#0x00
    continue_bcd_1:
                anl a, #0x0f
                swap a
	            orl a, NEW_BCD
	            mov NEW_BCD,a
                mov bcd_bitnumber, #0x01
                ;display new_bcd
                LCD_Set_Cursor(2,13)
                Display_3BCD(NEW_BCD)

                Wait_Milli_Seconds(#250)
           
                ret

    bcd_bit_1:  
                Wait_Milli_Seconds(#250)
                mov a, NEW_BCD
                anl a, #0xf0
                mov NEW_BCD,a
                mov a, keyin
                cjne a,#0x0A,continue_bcd_2
                mov a,#0x00
    continue_bcd_2:
                anl a, #0x0f
	            orl a, NEW_BCD
	            mov NEW_BCD,a
                mov bcd_bitnumber, #0x03
                ;display new_bcd
                LCD_Set_Cursor(2,13)
                Display_3BCD(NEW_BCD)

                Wait_Milli_Seconds(#250)
                
                ret
                
    normal_button:
                mov a, keyin
               
                cjne a, #11, button_c_u_d
                
                ljmp scanstate
    button_c_u_d:
                mov a, keyin
                cjne a,#12, button_u_d
                mov a, #0x0
                mov NEW_BCD,a
                mov NEW_BCD+1,a
                mov bcd_bitnumber,#0x03
                ljmp FSM0_Done
    button_u_d:
                mov a,keyin
                cjne a,#13,button_d
                mov a, FSM0_State
                cjne a,#0x04, state_add
                mov FSM0_State, #0x00
                lcall change_state_flag
                ljmp FSM0_Done
    state_add:
                inc FSM0_State
                lcall change_state_flag
                ljmp FSM0_Done

    button_d:
                mov a, FSM0_State
                cjne a, #0x00, state_minus
                mov FSM0_State, #0x04
                lcall change_state_flag
                ljmp FSM0_Done

    state_minus:
                dec FSM0_State
                lcall change_state_flag
                ljmp FSM0_Done



    scanstate:
                mov a, FSM0_State
                
                cjne a,#0x00,change_temp_soak

                ljmp FSM0_Done
    change_temp_soak:
                cjne a,#0x01,change_time_soak
                mov bcd, NEW_BCD
                mov bcd+1,NEW_BCD+1
                mov bcd+2,#0x0
                mov bcd+3,#0x0
                mov bcd+4,#0x0

                lcall bcd2hex
                mov TEMP_SOAK,x
                LCD_Set_Cursor(1,1)
                Display_3BCD(TEMP_SOAK)
                ljmp FSM0_Done
    change_time_soak:
                cjne a,#0x02,change_temp_reflow
                mov bcd, NEW_BCD
                mov bcd+1,NEW_BCD+1
                mov bcd+3,#0x0
                mov bcd+4,#0x0
                lcall bcd2hex
                mov TIME_SOAK,x
                ljmp FSM0_Done
    change_temp_reflow:
                cjne a,#0x03,change_time_reflow
                mov bcd, NEW_BCD
                mov bcd+1,NEW_BCD+1
                mov bcd+2,#0x0
                mov bcd+3,#0x0
                mov bcd+4,#0x0
                lcall bcd2hex
                mov TEMP_RFLW,x
                ljmp FSM0_Done
    change_time_reflow:
                mov bcd, NEW_BCD
                mov bcd+1,NEW_BCD+1
                mov bcd+2,#0x0
                mov bcd+3,#0x0
                mov bcd+4,#0x0
                lcall bcd2hex
                mov TIME_RFLW,x
                ljmp FSM0_Done
    change_state_flag:
            mov NEW_BCD,#0x0
            mov NEW_BCD+1,#0x0
            ret


    ;---------------------------------;
    ; FSM1 using Timer Interrupt      ;
    ;---------------------------------;
    ;update status and send data to LCD and PC every one/half seconds
FSM1:
    mov a, FSM1_State
    FSM1_State0:
        cjne a, #0, JUMP_FSM1_State1
        sjmp Start_FSM1_State0
        JUMP_FSM1_State1:
        ljmp FSM1_State1
        
        Start_FSM1_State0:
        setb enable_time_global
        setb speak_enable
        setb OVEN; turn oven on
        Update_Temp(TEMP_SOAK)    ;Read Temperatures
        LCD_INTERFACE_STEP1();display interface
        lcall Display_Working_Status
        LCD_Set_Cursor(2,6)
        mov32(x, TEMP_SOAK)
        Display_3BCD_from_x()

        jb mf, FSM1_State0_Error_Check;check Error and continue if smaller than set time
        ;if temp greater
        lcall clear_speaking
        lcall preheat_and_soak
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
        lcall clear_speaking
        lcall ramp_to_peak
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
        lcall clear_speaking
        lcall reflow
        inc FSM1_State
        mov Time_Counter, TIME_RFLW
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
        djnz Time_Counter, FSM1_State3_Continue
        ;if time's up
        lcall clear_speaking
        lcall cooling
        inc FSM1_State
        ljmp FSM1_State3_Done

        FSM1_State3_Continue:
        LCD_INTERFACE_STEP4()
        lcall Display_Working_Status
        Update_Temp(TEMP_RFLW); update temp info, set or clr mf flag
        LCD_Set_Cursor(2,5)
        Load_x(0)
        mov x, Time_Counter
        Display_3BCD_from_x()

        ;if temp is lower than expected, jump to ON
        jb mf, FSM1_State3_ON
        ;if temp is higher, close oven
        clr OVEN 
        sjmp FSM1_State3_Done

        FSM1_State3_ON:
        setb OVEN   ;if temp is lower, turn on oven
        FSM1_State3_Done:
            ljmp FSM1_DONE
        

    
    FSM1_State4:; cool down until safe temp
        cjne a, #4, JUMP_FSM1_State5
            sjmp Start_FSM1_State4
        JUMP_FSM1_State5:
            ljmp FSM1_State5
        
        Start_FSM1_State4:
        clr OVEN
        ;read temperature
        Update_Temp(TEMP_SAFE)
        ;if temp is smaller than TEMP_SAFE, go state 5
        jnb mf, FSM1_State4_Continue
        ;if temp is smaller than expected
        inc FSM1_State
        mov Time_Counter, #0

        FSM1_State4_Continue:
        LCD_INTERFACE_STEP5()
        lcall Display_Working_Status
        LCD_Set_Cursor(2,5)
        Load_x(0)
        mov x, TEMP_SAFE
        lcall hex2bcd
        Display_3BCD_from_x()

        FSM1_State4_Done:
            ljmp FSM1_DONE

    FSM1_State5: ; already cool done, display something, play some music
    	cjne a, #5, JUMP_FSM1_DOne
            sjmp Start_FSM1_State5
        JUMP_FSM1_Done:
            ljmp FSM1_Done
            
        Start_FSM1_State5:
        clr OVEN; double check oven is not on
        clr enable_time_global; stop counting
        clr speak_enable
        LCD_INTERFACE_STEP6()
        lcall Display_Working_Status
        sjmp FSM1_Done


    FSM1_WARNING:
        clr OVEN
        LCD_INTERFACE_WARNING()
        clr speak_enable
        mov FSM1_State, #6

    FSM1_DONE:
    ret

END