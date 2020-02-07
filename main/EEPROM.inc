cseg


; Address to write to passed in DPTR.  Data to write passed in register 'A'
EEPROM_Write:
	mov DEECON, DPH ; ECTL1/ECTL0 (DEECON[5:4]) = �00�, EADR8
	mov DEEDAT, a ; Byte to write
	mov DEEADR, DPL ; Address to write to.  This initializes the write process
	; Wait for write operation to complete
EEPROM_Write_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Write_L1 ; bit 7 of DEECON is EEIF
	ret

EEPROM_BlockFill:
	mov DEECON, #00110001B
	mov DEEDAT, a ; Byte to write
	mov DEEADR, #0 ; Address to write to.  This initializes the write process
	; Wait for write operation to complete
EEPROM_BlockFill_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_BlockFill_L1 ; bit 7 of DEECON is EEIF
	ret

; Address to read from passed in DPTR.  Data read returned via register 'A'
EEPROM_Read:
	mov DEECON, DPH ; ECTL1/ECTL0 (DEECON[5:4]) = �00�, EADR8=0
	mov DEEADR, DPL ; Address to read from.  This initializes the write process
	; wait for read operation to complete
EEPROM_Read_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Read_L1 ; bit 7 of DEECON is EEIF
	mov a, DEEDAT
	ret

Write_Byte:
    mov dptr, #Add_msg
    lcall SendString
    lcall getaddress
    push dpl
    push dph
    mov dptr, #Val_msg
    lcall SendString
    lcall getbyte
    pop dph
    pop dpl
    lcall EEPROM_Write
    ret