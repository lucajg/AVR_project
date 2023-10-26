/*
 * test_obstacles.asm
 *
 *  Created: 2023-05-05 17:45:02
 *   Author: lucaj
 */ 
.include	"macros.asm"				; useful macros
.include	"definitions.asm"

.org		0
			rjmp	reset

.org		OVF0addr
			rjmp	overflow0

.set		timer0 = 255

overflow0:
			ldi _w, -timer0+3
			out		TCNT0, _w
			rcall	shift_obstacles
			reti

vaisseau:
.db			0b00000000,0b00011111,0b00000100,0b00001110,0b0001110,0b00000100,0b00011111,0b00000000

reset:
			LDSP	RAMEND						; load Stack Pointer
			rcall	LCD_init

			OUTI	ASSR, (1<<AS0)
			OUTI	TCCR0,4		
			OUTI	TIMSK,(1<<TOIE0)
			sei
			
			rcall	LCD_storeCGRAM
					
			rjmp	main

.include	"lcd.asm"					; LCD library

.macro		AFFICHAGE_OBSTACLE				; print an 'o' if there is an 
			ldi		a0,'o'						; obstacle on this spot on the LCD
			sbrs	@0, @1
			;ldi		a0,' '						; print a ' ' otherwise
			ldi		a0,' '
			rcall	lcd_putc
			;WAIT_MS	40
			.endmacro

main:
			LDIX	0x1000						; address where the obstacles are stored
			ldi		r16, 0x55
			ldi		r17, 0xAA
			STX4	r16,r16,r17,r17				; storing an example obstacle initial condition in the RAM
	loop:									; loop of printing and shifting the obstacles
			rcall	print_obstacles				
			JP0		PIND,6,main
			;WAIT_MS 800
			rjmp	loop
	

shift_obstacles:
			push	r16
			PUSHX
	 
			LDIX	0x1000
			LDX4	a0,a1,a2,a3

			LSL2	a0,a1
			LSL2	a2,a3

			LDIX	0x1000
			STX4	a0,a1,a2,a3

			POPX
			pop		r16
			ret

print_obstacles:
			push	r16
			PUSHX
	 
			LDIX	0x1000
			LDX4	b0,b1,b2,b3

			rcall	LCD_clear

			CA		LCD_POS, 0x00

			AFFICHAGE_OBSTACLE b0, 7
			AFFICHAGE_OBSTACLE b0, 6
			AFFICHAGE_OBSTACLE b0, 5
			AFFICHAGE_OBSTACLE b0, 4
			AFFICHAGE_OBSTACLE b0, 3
			AFFICHAGE_OBSTACLE b0, 2
			AFFICHAGE_OBSTACLE b0, 1
			AFFICHAGE_OBSTACLE b0, 0

			AFFICHAGE_OBSTACLE b1, 7
			AFFICHAGE_OBSTACLE b1, 6
			AFFICHAGE_OBSTACLE b1, 5
			AFFICHAGE_OBSTACLE b1, 4
			AFFICHAGE_OBSTACLE b1, 3
			AFFICHAGE_OBSTACLE b1, 2
			AFFICHAGE_OBSTACLE b1, 1
			AFFICHAGE_OBSTACLE b1, 0

			CA		LCD_POS, 0x40

			AFFICHAGE_OBSTACLE b2, 7
			AFFICHAGE_OBSTACLE b2, 6
			AFFICHAGE_OBSTACLE b2, 5
			AFFICHAGE_OBSTACLE b2, 4
			AFFICHAGE_OBSTACLE b2, 3
			AFFICHAGE_OBSTACLE b2, 2
			AFFICHAGE_OBSTACLE b2, 1
			AFFICHAGE_OBSTACLE b2, 0

			AFFICHAGE_OBSTACLE b3, 7
			AFFICHAGE_OBSTACLE b3, 6
			AFFICHAGE_OBSTACLE b3, 5
			AFFICHAGE_OBSTACLE b3, 4
			AFFICHAGE_OBSTACLE b3, 3
			AFFICHAGE_OBSTACLE b3, 2
			AFFICHAGE_OBSTACLE b3, 1
			AFFICHAGE_OBSTACLE b3, 0
	
		/*  affichage:
			ldi		a0,'o'
			sbrs	b0, r16-1
			ldi		a0,'_'
			rcall	lcd_putc
			dec		r16
			tst		r16
			brne	affichage*/

			POPX
			pop		r16
			ret


LCD_storeCGRAM: 
	lds	u, LCD_IR				;read IR to check busy flag  (bit7)
	JB1	u,7,LCD_storeCGRAM		;Jump if Bit=1 (still busy)
	ldi	r16, 0b01000000			;2MSBs:write into CGRAM(instruction),
								;6LSBs:address in CGRAM and in charact.
	sts	LCD_IR, r16				;store w in IR
	ldi	zl,low(2*vaisseau)+7
	ldi	zh,high(2*vaisseau)
	mov	r23,zl			
	dec	r23
	mov	r24,r23			;store upper limit of character in memory
	ldi	r18,8			;load size of caracter in table arrow0
	sub	zl,r22			;subtract current value of moving offset

   loop01: 
  	lds	u, LCD_IR	
	JB1	u,7,loop01	 
	lpm					;load from z into r0
	mov	r16,r0
	adiw	zl,1
	mov	r23,r24			;garantee z remains in character memory
	sub	r23,zl			;zone, if not then restart at the begining
	brge	_reg		;of character definition
	subi	zl,8
	
  _reg:	sts	LCD_DR, r16		;load definition of one charecter line 
	dec	r18
	brne	loop01
	rcall	LCD_home		;leaving CGRAM
	ret