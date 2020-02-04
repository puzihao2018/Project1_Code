$NOLIST

cseg
$include(SPI.inc)
$include(math32.inc)
;-----------------------;
;    Variables Define   ;
;-----------------------; 
;Variable_name: ds n
dseg at 0x30

oven_temp:ds 4
room_temp:ds 4

;---------------------------------;
;           Basic Macros          ;
;---------------------------------;
Temp_Read mac

endmac

;---------------------------------;
;           Fucntion              ;
;---------------------------------;

