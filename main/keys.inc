

;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30
key_digit:     ds 1 ;0-16

;-------------------;
;    Flags Define   ;
;-------------------; 
bseg
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.


cseg

;-----------------------------------;
;           Complex Macros          ;
;-----------------------------------;
Key_Scan()


;---------------------------------;
;           Basic Macros          ;
;---------------------------------;