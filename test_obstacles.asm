/*
 * test_obstacles.asm
 *
 *  Created: 2023-05-05 17:45:02
 *   Author: lucaj
 */ 
.include	"macros.asm"				; include macro definitions
.include	"definitions.asm"			; include register/constant definitions

; === interrupt vector table ===
.org		0
			rjmp	reset
.org		INT7addr
			rjmp	ext_int7
.org		OVF0addr
			rjmp	overflow0

; === definitions ===
.equ		T1							= 1778			; bit period T1 = 1778 usec
.equ		bouton						= 0x0fe0
.equ		pos_mechant_addr			= 0x0fe1
.equ		vies_addr					= 0x0fe2
.equ		points_addr					= 0x0ff0
.equ		obstacles_addr				= 0x1000
.equ		addr_caractere_personnage	= 0x00
.equ		addr_caractere_mechant		= 0x01
.equ		mute_button					= 0x3d
.equ		five_button					= '5'
.equ		power_button				= 0x3c
.equ		channel_up_button			= 'P'
.equ		channel_down_button			= 'Q'
.set		timer0						= 255

; === interruption service routines ===
ext_int7:
			in		_sreg, SREG			; store context
			PUSH4	b3,b2,b1,b0 
			PUSHX

			CLR2	b1,b0				; clear 2-byte register
			ldi		b2,14				; load bit-counter
			WAIT_US	(T1/4)				; wait a quarter period
	
			loop_int7:	P2C		PINE,IR		; move Pin to Carry (P2C)
			ROL2	b1,b0				; roll carry into 2-byte reg
			WAIT_US	(T1-4)				; wait bit period (- compensation)	
			DJNZ	b2,loop_int7		; Decrement and Jump if Not Zero
			
			subi	b0, -48				; interpretation of result
			LDIX bouton
			st x, b0 
			
			POPX
			POP4	b3,b2,b1,b0 
			out		SREG, _sreg		;restore context
			reti

overflow0:
			in		_sreg, SREG		; store context
			push	w
			push	_w
			PUSH4	a3,a2,a1,a0
			PUSH4	b3,b2,b1,b0
			PUSHZ
			PUSHX						; store pointer x in the stack

			ldi		_w, -timer0+3
			out		TCNT0, _w		; restart timer
			
			; points
			LDIX	points_addr
			ld		r16,x				; load points from RAM
			inc		r16					; increment points
			st		x, r16				; store points in RAM

			; obstacles
			rcall	shift_obstacles	; shift the obstacles left
			
			; music
			tst		r7						; test if music on or off
			breq	end_ovf0	
			ldi		zl, low(2*tetris)		; pointer z to begin of musical score
			ldi		zh, high(2*tetris)
			add		zl, r6
			lpm							; load note to play
			tst		r0						; test end of music (NUL)
			brne	PC+2	
			clr		r6						; clr r6 (notes offset) if end of music reached
			mov		a0,r0					; move note to a0
			ldi		b0,7					; load play duration (50*2.5ms = 125ms)
			rcall	sound				; play the sound
			inc r6

		end_ovf0:
			POPX
			POPZ
			POP4	b3,b2,b1,b0	
			POP4	a3,a2,a1,a0			
			pop		_w
			pop		w
			out		SREG, _sreg			; restore context
			reti

; === custom characters ===
personnage:
.db			0b00000000,0b00011111,0b00000100,0b00001110,0b00001110,0b00000100,0b00011111,0b00000000,0b00000000,0b00000000
mechant:
.db			0b00000000,0b00000000,0b00011111,0b00000110,0b00001111,0b00001111,0b00000110,0b00011111,0b00000000,0b00000000

; === reset routine ===
reset:
			LDSP	RAMEND					; load Stack Pointer
			OUTI	DDRD, 0x00				; set PORTD (ditance sensor) as input	
			OUTI	DDRE, (1 << SPEAKER)	; set PORTE IR sensor pins as inputs and buzzer pin as output
			OUTI	DDRB, 0xff				; set PORTB (LEDs) as output

			OUTI	EIMSK, 0b10000000
			OUTI	EICRB, 0b00000000
			
			rcall	LCD_init
			rcall LCD_clear

			OUTI	ASSR, (1<<AS0)			; set clock source to quartz for timer 0
			OUTI	TCCR0,3					; set prescaler to to
			OUTI	TIMSK,0					; not enable timer interrupts for now
			
			rcall	LCD_storeCGRAM_personnage	; load player1 custom character to CGRAM
			rcall	LCD_storeCGRAM_mechant		; load player2 custom character to CGRAM
			
			rcall	sharp_init

			clr r6
			clr r7

			sei
			rjmp	main

; ===   ===
.include	"lcd.asm"			; include the LCD routines
.include	"sharp.asm"			; include the SHARP GP2D02 distance sensor routines
.include	"printf.asm"		; include formatting printing routines
.include	"sound.asm"			; include sound routines


; === music score ===
tetris:
.db	mi4,si3,do4,re4,do4,si3,la3,la3,do4,mi4,re4,do4,si3,si3,do4,re4,mi4,do4,la3,la3
.db	re4,fa4,la4,so4,fa4,mi4,do4,mi4,re4,do4,si3,si3,do4,re4,mi4,do4,la3,la3, 0, 0, 0, 0
/*.db	0*/

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

; purpose:
; arg: ; used:
.macro		AFFICHAGE_MECHANT    
			CA		LCD_pos, @0					; move cursor on last rectangle of the second line
			CA		LCD_putc, addr_caractere_mechant		; put custom character on desired rectangle
			CA		LCD_pos, @1					; move cursor on last rectangle of the first line
			CA		LCD_putc, ' '					; put space in the desired rectangle
			.endmacro

main:
			LDSP	RAMEND						; the stack will be overwrtitten
			rcall	LCD_clear	
			LDIX	vies_addr
			ldi		r16, 5							; initialise number of lives to 5
			st		x, r16
			clr		r6								; clear r6 wich gives the position of the current musical note
			clr		r8								; clear r8 which is a counter that allows the user to change music if it is at 0
	start_screen:
			rcall	LCD_home
			PRINTF	LCD				; print formatted
			.db		"Press power      ",0		; start screen message
			rcall	LCD_lf
			PRINTF	LCD				; print formatted
			.db		"button to start  ",0
			LDIX	bouton
		wait_for_power_button:
			ld		r16,x
			cpi		r16, power_button
			breq	start_game
			rjmp	wait_for_power_button
	start_game:
			LDIX	points_addr					; reset points
			ldi		r16, 0						;
			st		x, r16						;
			LDI4    b3,b1,b2,b0,0				; reset obstacles
			LDIX	obstacles_addr				;
			STX4	b3,b1,b2,b0					;
			OUTI	TIMSK,(1<<TOIE0)			; activate overflow timer 0, which controls the shifting of the obstacles, the music and the point incrments
	game_loop:									
			rcall	print_obstacles

			rcall	sharp						; get data from Sharp distance sensor
			mov		r9, a0						; store result from sharp in r9

			rcall	test_collision				; test for collision between player1 and obstacles
			rcall	print_personnage			; display player1

			rcall	modifier_position_mechant	; modify (if needed) the position of the player 2
			rcall	print_mechant

			rcall	affichage_vies				; display lives on LEDs

			rcall	pose_obstacle				; laying an obstacle if button '5' is pressed

		next_task_game_loop:
			LDIX	bouton					;
			ld		r16,	x				; get pressed button info from RAM
			cpi		r16, mute_button		; test if the mute button was pressed
			brne	end_game_loop				
			ldi		r16, 0x00
			cp		r8, r16						; if mute button was pressed, test if r8 is clear 
			brne    end_game_loop
			ldi		r16, 0x05					;
			mov		r8, r16						; r8 is used as a buffer to counter to avoid rapid toggling of the music
			ldi		r17, 0x01					; if r8 is clear, toggle r17 
			eor		r7, r17
			

		end_game_loop:
			ldi		r16, 0x00					;
			cp		r8, r16						;
			breq	PC+2						;
			dec r8								; if r8 is not clear, decrement r8 
			LDIX	bouton						;
			clr		r16							;
			st		x, r16						; clear button informatiion stored in RAM
			rjmp	game_loop					; continue game loop
	
; purpose:
; arg: ; used:
shift_obstacles:

			LDIX	obstacles_addr
			LDX4	a0,a1,a2,a3			; load obstacles from RAM

			LSL2	a0,a1				; shift upper line of obstacles left
			LSL2	a2,a3				; shift lower line of obstacles left

			LDIX	obstacles_addr		
			STX4	a0,a1,a2,a3			; store shifted obstacles in RAM

			ret

; purpose:
; arg: ; used:
print_obstacles:
			LDIX	obstacles_addr
			LDX4	b0,b1,b2,b3

			AFFICHAGE_LIGNE_OBSTACLES 0x00, b0, b1		; print first row of obstacles
			AFFICHAGE_LIGNE_OBSTACLES 0x40, b2, b3		; print second row of obstacles

			ret

; purpose:	display player1 on the LCD
; arg: r9; used: r17
print_personnage:
			ldi		r17, 200			;
			cp		r9, r17				;
			brlo	personnage_up		; check if value given by distnace sensor is lower than 200
		personnage_down:
			AFFICHAGE_PERSONNAGE 0x03,3,0x43
			rjmp    end_print_personnage
		personnage_up:		
			AFFICHAGE_PERSONNAGE 0x43,1,0x03
		end_print_personnage:
			ret

; purpose: store cusstom character of player1 in the CGRAM
; arg: ; used:
LCD_storeCGRAM_personnage: 
			lds		u, LCD_IR						;read IR to check busy flag  (bit7)
			JB1		u,7,LCD_storeCGRAM_personnage		;Jump if Bit=1 (still busy)
			ldi		r16, 0b01000000					;2MSBs:write into CGRAM(instruction),
												;6LSBs:address in CGRAM and in charact.
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
			lpm					;load from z into r0
			mov		r16,r0
			adiw	zl,1
			mov		r23,r24			;garantee z remains in character memory
			sub		r23,zl			;zone, if not then restart at the begining
			brge	_reg01		;of character definition
			subi	zl,8
	
		  _reg01:	sts	LCD_DR, r16		;load definition of one charecter line 
			dec		r18
			brne	loop01
			rcall	LCD_home		;leaving CGRAM
			ret

; purpose: store cusstom character of player2 in the CGRAM
; arg: ; used:
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
; arg: ; used: 
modifier_position_mechant :
			LDIX	bouton
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
; arg: ; used:
print_mechant:
			push	r16				
			push	a0

			LDIX	pos_mechant_addr	; access player2's
			ld		r16, x				; position in the RAM.
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
; arg: ; used:
pose_obstacle:
			LDIX	bouton					;
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
			rjmp end_pose_obstacle
	obstacle_bas :
			LDIX	obstacles_addr			
			ld r16, x						; get lower right set of obstacles
			sbr	r16,0b00000001				; set lsb of the set of obsatcles
			st	x,r16						; store updated lower right set of obstacles
	end_pose_obstacle:
			ret

; purpose: determine if there if an obstacle has the same position as the player
; arg: ; used: r9, r17, r22 (b0), (r26, r27)(x),
test_collision:
			ldi		r17, 200
			cp		r9, r17
			brlo	up_test_collision		; test wether the player1 is in the lower or upper row
		down_test_collision:
			LDIX	obstacles_addr+1		; get lower left group of obstacles
			ld		b0, x					;
			sbrs	b0, 4					;
			rjmp	end_test_collision		; end subroutine if there is no obstacle on the same rectangle as the player1
			cbr		b0, (1<<4)				; delete obstacle if collision took place
			st		x, b0					; store updated set of obstacles
			rjmp	diminuer_vies

		up_test_collision:
			LDIX	obstacles_addr+3		; get upper left group of obstacles
			ld		b0, x					; 
			sbrs	b0, 4					;
			rjmp	end_test_collision		; end subroutine if there is no obstacle on the same rectangle as the player1
			cbr		b0, (1<<4)				; delete obstacle if collision took place
			st		x, b0					; store updated set of obstacles
	
		diminuer_vies:
			LDIX	vies_addr	
			ld		r16, x					; get lives from RAM
			dec		r16						; decrease live
			st		x, r16					; store updated lives in RAM

		end_test_collision:
			LDIX	vies_addr				; get lives from RAM
			ld		r16, x					;
			cpi		r16, 0x00				; test if player has zero lives
			brne	not_game_over			
			jmp		game_over				; go to game_over routine if the player has zero lives
		not_game_over:
			ret

; purpose: diplay lives on LEDs
; arg: ; used: r16, r17
affichage_vies :
			clr		r17				
			LDIX	vies_addr				;
			ld		r16, x					; get lives from RAMa
			sec								; set carry
			rol		r17						; rotate r17 left (carry enters r17)
			dec		r16						;
			brne	PC-3					; repeat set carry and rotate left for the all lives
			com		r17						; complement r17 before sending signal to LEDs
			out		PORTB, r17				; send signal to LEDs
			ret

; purpose:
; arg: ; used:
game_over:
			OUTI	PORTB, 0xff				; turn off LEDs
			/*LDIX	vies_addr				;
			ldi		r16, 5					;
			st		x, r16					;*/
			LDIX	points_addr
			ld		b0, x					; get points from RAM
			clr		b1						;
			clr		b2						;
			clr		b3						;
			rcall	LCD_clear
			
			rcall	LCD_lf
			PRINTF		LCD					; print formatted
		.db	" Point(s) :  ",FDEC,b,0

			
		blinking_message:
			rcall	LCD_home				; place cursor to beginning of LCD
			PRINTF	LCD						; print formatted
		.db	"   GAME OVER !   ",0
			WAIT_MS	500
			rcall	LCD_home
			PRINTF	LCD						; print formatted
		.db	"                 ",0
			WAIT_MS	500

			rcall	LCD_home				; place cursor to beginning of LCD
			PRINTF	LCD						; print formatted
		.db	"   GAME OVER !   ",0
			WAIT_MS	500
			rcall	LCD_home
			PRINTF	LCD						; print formatted
		.db	"                 ",0
			WAIT_MS	500

			rcall	LCD_home				; place cursor to beginning of LCD
			PRINTF	LCD						; print formatted
		.db	"   GAME OVER !   ",0
			WAIT_MS	500
			rcall	LCD_home
			PRINTF	LCD						; print formatted
		.db	"                 ",0
			WAIT_MS	500
				

			OUTI	TIMSK,0					; disable timer 0 
			jmp main
