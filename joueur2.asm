/*
 * joueur2.asm
 *   Author: Luca Jimenez, Geoffroy Renaut
 */ 

 ; === custom character ===
 mechant:
.db			0b00000000,0b00000000,0b00011111,0b00000110,0b00001111,0b00001111,0b00000110,0b00011111,0b00000000,0b00000000

 ; === macros ===
; purpose: draw player 2 on the correct row
; arg: ; used:
.macro		AFFICHAGE_MECHANT    
			CA		LCD_pos, @0						; move cursor on last rectangle of the second line
			CA		LCD_putc, addr_caractere_mechant	; put custom character 
														;	on desired rectangle
			CA		LCD_pos, @1						; move cursor on last rectangle of the first line
			CA		LCD_putc, ' '					; put space in the desired rectangle
			.endmacro

 ; === subroutines ===

; purpose: store player 2's custom character on the CGRAM
; arg: ; used: r16, z, r18, r23, r24
LCD_storeCGRAM_mechant: 
			lds		u, LCD_IR						;read IR to check busy flag  (bit7)
			JB1		u,7,LCD_storeCGRAM_mechant		;Jump if Bit=1 (still busy)
			ldi		r16, 0b01001000					;2MSBs:write into CGRAM(instruction),
												;6LSBs:address in CGRAM and in charact.
			sts		LCD_IR, r16						;store w in IR
			ldi		zl,low(2*mechant)+9
			ldi		zh,high(2*mechant)
			mov		r23,zl			
			dec		r23
			mov		r24,r23			;store upper limit of character in memory
			ldi		r18,8			;load size of caracter in table arrow0
			sub		zl,r22			;subtract current value of moving offset

		   loop02: 
  			lds		u, LCD_IR	
			JB1		u,7,loop02	 
			lpm						;load from z into r0
			mov		r16,r0
			adiw	zl,1
			mov		r23,r24			;garantee z remains in character memory
			sub		r23,zl			;zone, if not then restart at the begining
			brge	_reg02			;of character definition
			subi	zl,8
	
		  _reg02:	sts	LCD_DR, r16		;load definition of one charecter line 
			dec		r18
			brne	loop02
			rcall	LCD_home		;leaving CGRAM
			ret


; purpose:	Modify player 2's position according to the pressed button
; arg: ; used:	r16,r17,x
modifier_position_mechant :
			LDIX	bouton_addr
			ld		r16, x					; get button info from RAM
			cpi		r16, channel_up_button
			brne	not_up
			LDIX	pos_mechant_addr
			ldi		r17, 1					; set player2 position to 1
			st		x, r17
			rjmp	fini_pos_mechant
		not_up:
			cpi		r16, channel_down_button
			brne	fini_pos_mechant
			LDIX	pos_mechant_addr
			ldi		r17, 0					; set player2 position to 0
			st		x, r17
		fini_pos_mechant:
			ret

; purpose:	display player 2 on the LCD
; arg: ; used: r16,r18 (a0),r26,r27
print_mechant:
			push	r16				
			push	a0

			LDIX	pos_mechant_addr	; access player2's
			ld		r16, x				; position in the RAM
			cpi		r16,1				; compare position to 1
			brne	mechant_bas			; branch to mechant_bas if position is not equal to 1
	mechant_haut :
			AFFICHAGE_MECHANT 0x0f,0x4f	
			rjmp	end_print_mechant
	mechant_bas :
			AFFICHAGE_MECHANT 0x4f,0x0f
	end_print_mechant:
			pop		a0
			pop		r16
			ret

; purpose: lay an obstacle at the position of the player2
; arg: ; used: r16, r26, r27
pose_obstacle:
			ldix	bouton_addr					;
			ld		r16,	x				; get pressed button info from RAM
			cpi		r16, five_button		; test if button '5' is pressed
			brne	end_pose_obstacle		;
			LDIX	pos_mechant_addr
			ld		r16, x
			cpi		r16,1					; check where the player2 is
			brne	obstacle_bas			; branch to obstacle bas if player2 is in the lower row
			LDIX	obstacles_addr+2		;
			ld		r16, x					; get upper right set of obstacles
			sbr		r16,0b00000001			; set lsb of the set of obsatcles
			st		x,r16					; store updated upper right set of obstacles
			rjmp	end_pose_obstacle
	obstacle_bas:
			LDIX	obstacles_addr			
			ld		r16, x						; get lower right set of obstacles
			sbr		r16,0b00000001				; set lsb of the set of obsatcles
			st		x,r16						; store updated lower right set of obstacles
	end_pose_obstacle:
			ret