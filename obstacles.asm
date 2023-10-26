/*
 * obstacles.asm
 *   Authors: Luca Jimenez, Geoffroy Renaut
 */ 

; === macros ===

; purpose: print a single obstacle at a given position on the LCD
; arg: register, immediate value (from 0 to 7); used: r18 (a0)
.macro		AFFICHAGE_OBSTACLE		; prints an 'o' if there is an obstacle on this spot on the LCD, prints ' ' otherwise
			ldi		a0,'-'			; load '-' in a0			
			sbrs	@0, @1			
			ldi		a0,' '			; load ' ' in a0 is bit @1 of @0 is clear
			rcall	lcd_putc		; put corresponding charcter in the LCD
			.endmacro

; purpose: print entire line of obstacles on LCD
; arg: immediate value, register, register ; used: r18 (a0)
.macro		AFFICHAGE_LIGNE_OBSTACLES			
			CA		LCD_POS, @0					; set initial position of cursor

			AFFICHAGE_OBSTACLE @1, 7			; filling the rectangles of the LCD one by one
			AFFICHAGE_OBSTACLE @1, 6
			AFFICHAGE_OBSTACLE @1, 5	
			rcall		LCD_cursor_right		; skip the column of the charcater
			AFFICHAGE_OBSTACLE @1, 3
			AFFICHAGE_OBSTACLE @1, 2
			AFFICHAGE_OBSTACLE @1, 1
			AFFICHAGE_OBSTACLE @1, 0

			AFFICHAGE_OBSTACLE @2, 7
			AFFICHAGE_OBSTACLE @2, 6
			AFFICHAGE_OBSTACLE @2, 5
			AFFICHAGE_OBSTACLE @2, 4
			AFFICHAGE_OBSTACLE @2, 3
			AFFICHAGE_OBSTACLE @2, 2
			AFFICHAGE_OBSTACLE @2, 1
			.endmacro

; === subroutines ===

; purpose:	shift the obstacles left in the memory
; arg: ; used:	a0,a1,a2,a3
shift_obstacles:

			LDIX	obstacles_addr
			LDX4	a0,a1,a2,a3			; load obstacles from RAM

			LSL2	a0,a1				; shift upper line of obstacles left
			LSL2	a2,a3				; shift lower line of obstacles left

			LDIX	obstacles_addr		
			STX4	a0,a1,a2,a3			; store shifted obstacles in RAM

			ret

; purpose: display all the obstacles at the posiitions where ther can't be any players
; arg: ; used:	b0,b1,b2,b3
print_obstacles:
			LDIX	obstacles_addr
			LDX4	b0,b1,b2,b3

			AFFICHAGE_LIGNE_OBSTACLES 0x00, b0, b1		; print first row of obstacles
			AFFICHAGE_LIGNE_OBSTACLES 0x40, b2, b3		; print second row of obstacles

			ret
