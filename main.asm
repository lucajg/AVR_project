/*
 * main.asm
 *   Authors: Luca Jimenez, Geoffroy Rrenault
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
.equ		bouton_addr					= 0x0fe0
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
; purpose: receive ir signal and store result in the RAM
; arg:  string; used: r1,b0,b1,b2,b3
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
			
			subi	b0, -48			; interpretation of result
			LDIX bouton_addr
			st x, b0 
			
			POPX
			POP4	b3,b2,b1,b0 
			out		SREG, _sreg		; restore context
			reti

; purpose: shift obstacles and play sound at regular intervals of time
; arg:  string; used: r1,r16,r17,r26,r27,r18,r0,b0
overflow0:
			in		_sreg, SREG		; store context
			push	w
			push	_w
			PUSH4	a3,a2,a1,a0
			PUSH4	b3,b2,b1,b0
			PUSHZ
			PUSHX					; store pointer x in the stack

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
			tst		r0					; test end of music (NUL)
			brne	PC+2	
			clr		r6					; clr r6 (notes offset) if end of music reached
			mov		a0,r0				; move note to a0
			ldi		b0,7				; load play duration (50*2.5ms = 125ms)
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

; purpose: display a message for 500 ms and then delete it
; arg:  string; used: 
.macro BLINKING_MESSAGE
			rcall	LCD_home				; place cursor to beginning of LCD
			PRINTF	LCD						; print formatted
		.db	@0,0
			WAIT_MS	500
			rcall	LCD_home
			PRINTF	LCD						; print formatted
		.db	"                 ",0
			WAIT_MS	500
		.endmacro

; === reset routine ===
reset:
			LDSP	RAMEND					; load Stack Pointer	
			OUTI	DDRE, (1 << SPEAKER)	; set PORTE IR sensor pins as inputs 
											;	and buzzer pin as output
			OUTI	DDRB, 0xff				; set PORTB (LEDs) as output

			OUTI	EIMSK, 0b10000000		; enable int7
			OUTI	EICRB, 0b00000000		; make int 7 happen for low voltage level
			
			OUTI	ASSR, (1<<AS0)			; set clock source to quartz for timer 0
			OUTI	TCCR0,3					; set prescaler to to
			OUTI	TIMSK,0					; not enable timer interrupts for now
			
			rcall	LCD_init
			rcall	sharp_init

			rcall	LCD_clear

			rcall	LCD_storeCGRAM_personnage	; load player1 custom character to CGRAM
			rcall	LCD_storeCGRAM_mechant		; load player2 custom character to CGRAM
			
			clr r6
			clr r7

			sei
			rjmp	main

; === included files ===
.include	"lcd.asm"			; include the LCD routines
.include	"sharp.asm"			; include the SHARP GP2D02 distance sensor routines
.include	"printf.asm"		; include formatting printing routines
.include	"sound.asm"			; include sound routines
.include	"joueur1.asm"		; incude player1 routines
.include	"joueur2.asm"		; incude player1 routines
.include	"obstacles.asm"		; incude player1 routines
.include	"musique.asm"		; include music score

; === main ===
main:
			LDSP	RAMEND						; the stack will be overwrtitten
			rcall	LCD_clear
			rcall	start_screen
			rcall	start_game
	game_loop:									
			rcall	print_obstacles
			rcall	sharp						; get data from Sharp distance sensor
			mov		r9, a0						; store result from sharp in r9
			rcall	test_collision				; test for collision between player1 and obstacles
			rcall	test_points
			rcall	print_personnage			; display player1
			rcall	modifier_position_mechant	; modify (if needed) the position of the player 2
			rcall	print_mechant
			rcall	affichage_vies				; display lives on LEDs
			rcall	pose_obstacle				; laying an obstacle if button '5' is pressed
			rcall	music_toggle			
		reset_button_data:
			LDIX	bouton_addr					;
			clr		r16							;
			st		x, r16						; clear button informatiion stored in RAM
			rjmp	game_loop					; continue game loop

; === subroutines ===

; purpose: wait for players to be ready to start the game
; arg: ; used: r16, r26,r27 (x)
start_screen:
			rcall	LCD_home
			PRINTF	LCD							; print formatted
			.db		"Press power      ",0		; start screen message
			rcall	LCD_lf
			PRINTF	LCD							; print formatted
			.db		"button to start  ",0
			LDIX	bouton_addr
		wait_for_power_button:
			ld		r16,x
			cpi		r16, power_button
			breq	PC+2
			rjmp	wait_for_power_button
			ret

; purpose: setup lives, points, obstacles and music before starting the game
; arg: ; used: r6, r8, r16, b3, b2, b1, b0, r26, r27 (x)
start_game:
			LDIX	points_addr				; reset points
			ldi		r16, 0					;
			st		x, r16					;
			LDI4    b3,b1,b2,b0,0			; reset obstacles
			LDIX	obstacles_addr			;
			STX4	b3,b1,b2,b0				;
			LDIX	vies_addr
			ldi		r16, 5					; initialise number of lives to 5
			st		x, r16
			clr		r6						; clear r6 wich gives the position 
											;	of the current musical note
			clr		r8						; clear r8 which is a counter that allows 
											;	the user to change music if it is at 0
			OUTI	TIMSK,(1<<TOIE0)		; activate overflow timer 0, which controls 
											;	the shifting of the obstacles, 
											;	the music and the point incrments
			ret

; purpose: display message when game is lost
; arg: ; used: b3,b2,b1,b0
game_over:
			OUTI	PORTB, 0xff				; turn off LEDs

			LDIX	points_addr
			ld		b0, x					; get points from RAM
			clr		b1						;
			clr		b2						;
			clr		b3						;

			rcall	LCD_clear
			rcall	LCD_lf
			PRINTF		LCD					; print formatted
		.db	" Point(s) :  ",FDEC,b,0

			BLINKING_MESSAGE "   GAME OVER !   "
			BLINKING_MESSAGE "   GAME OVER !   "
			BLINKING_MESSAGE "   GAME OVER !   "

			OUTI	TIMSK,0					; disable timer 0 
			jmp		main

; purpose: display message when game is won
; arg: ; used: 
game_won:
			OUTI	PORTB, 0x00				; turn on LEDs
			rcall	LCD_clear
			rcall	LCD_lf
			PRINTF		LCD					; print formatted
		.db	" Max Points !  ",0

			BLINKING_MESSAGE "   You won !     "
			BLINKING_MESSAGE "   You won !     "
			BLINKING_MESSAGE "   You won !     "

			OUTI	TIMSK,0					; disable timer 0 
			jmp		main

