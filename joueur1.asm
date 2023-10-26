/*
 * joueur1.asm
 *   Authors: Luca Jimenez, Geoffroy Renaut
 */ 

  ; === custom character ===
 personnage:
.db			0b00000000,0b00011111,0b00000100,0b00001110,0b00001110,0b00000100,0b00011111,0b00000000,0b00000000,0b00000000

; purpose:
; arg: ; used:
.macro		AFFICHAGE_PERSONNAGE

			CA		LCD_POS, @0
			
			LDIX	obstacles_addr+@1
			ld		b0, x
			sbrc	b0, 4
			ldi		a0,'-'
			sbrs	b0, 4
			ldi		a0,' '
			rcall		lcd_putc

			CA		LCD_POS, @2
			CA		lcd_putc, 0x00
			.endmacro

; purpose: store cusstom character of player1 in the CGRAM
; arg: ; used:
LCD_storeCGRAM_personnage: 
			lds		u, LCD_IR						;read IR to check busy flag  (bit7)
			JB1		u,7,LCD_storeCGRAM_personnage	;Jump if Bit=1 (still busy)
			ldi		r16, 0b01000000					;2MSBs:write into CGRAM(instruction),
													;	6LSBs:address in CGRAM and in charact.
			sts		LCD_IR, r16						;store w in IR
			ldi		zl,low(2*personnage)+7			
			ldi		zh,high(2*personnage)
			mov		r23,zl			
			dec		r23
			mov		r24,r23			;store upper limit of character in memory
			ldi		r18,8			;load size of caracter in table arrow0
			sub		zl,r22			;subtract current value of moving offset

   loop01: 
  			lds		u, LCD_IR	
			JB1		u,7,loop01	 
			lpm						;load from z into r0
			mov		r16,r0
			adiw	zl,1
			mov		r23,r24			;garantee z remains in character memory
			sub		r23,zl			;zone, if not then restart at the begining
			brge	_reg01			;of character definition
			subi	zl,8
	
		  _reg01:	sts	LCD_DR, r16		;load definition of one charecter line 
			dec		r18
			brne	loop01
			rcall	LCD_home		;leaving CGRAM
			ret

; purpose:	display player1 on the LCD
; arg: r9; used: r17
print_personnage:
			ldi		r17, 200			;
			cp		r9, r17				;
			brlo	personnage_up		; check if value given by distnace sensor 
										;	is lower than 200
		personnage_down:
			AFFICHAGE_PERSONNAGE 0x03,3,0x43
			rjmp    end_print_personnage
		personnage_up:		
			AFFICHAGE_PERSONNAGE 0x43,1,0x03
		end_print_personnage:
			ret

; purpose: determine if there if an obstacle has the same position as the player
; arg: ; used: r9, r17, r22 (b0), (r26, r27)(x),
test_collision:
			ldi		r17, 200
			cp		r9, r17
			brlo	up_test_collision		; test wether the player1 is 
											;	in the lower or upper row
		down_test_collision:
			LDIX	obstacles_addr+1		; get lower left group of obstacles
			ld		b0, x		
			sbrs	b0, 4					;
			rjmp	end_test_collision		; end subroutine if there is no obstacle 
											;	on the same spot as the player1
			cbr		b0, (1<<4)				; delete obstacle if collision took place
			st		x, b0					; store updated set of obstacles
			rjmp	diminuer_vies

		up_test_collision:
			LDIX	obstacles_addr+3		; get upper left group of obstacles
			ld		b0, x					; 
			sbrs	b0, 4					;
			rjmp	end_test_collision		; end subroutine if there is no obstacle 
											;	on the same spot as the player1
			cbr		b0, (1<<4)				; delete obstacle if collision took place
			st		x, b0					; store updated set of obstacles
	
		diminuer_vies:
			ldix	vies_addr	
			ld		r16, x					; get lives from RAM
			dec		r16						; decrease live
			st		x, r16					; store updated lives in RAM

		end_test_collision:
			LDIX	vies_addr				; get lives from RAM
			ld		r16, x					;
			cpi		r16, 0x00				; test if player has zero lives
			brne	not_game_over			
			jmp		game_over				; go to game_over routine if the 
											;	player has zero lives
		not_game_over:
			ret

; purpose: check if maximum number of points (255) has been reached
; arg: ; used: r16
test_points:
			LDIX	points_addr
			ld		r16, x	
			cpi		r16, 0xff
			brlo	not_won
			jmp		game_won	
		not_won:
			ret

; purpose: diplay lives on LEDs
; arg: ; used: r16, r17
affichage_vies :
			clr		r17				
			LDIX	vies_addr				;
			ld		r16, x					; get lives from RAM
			sec								; set carry
			rol		r17						; rotate r17 left (carry enters r17)
			dec		r16						;
			brne	PC-3					; repeat set carry and rotate left for the all lives
			com		r17						; complement r17 before sending signal to LEDs
			out		PORTB, r17				; send signal to LEDs
			ret

