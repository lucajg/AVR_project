/*
 * test_telecommande.asm
 *
 *  Created: 2023-05-07 18:05:29
 *   Author: lucaj
 */ 

.include "macros.asm"
.include "definitions.asm"
.org 0
			rjmp	reset

.org INT7addr
			rjmp	ext_int7

.equ		T1 = 1778			; bit period T1 = 1778 usec
.equ		bouton = 0x0fe0
.equ		posMechant = 0x0fe1

ext_int7:
			in		_sreg, SREG
			push b0
			push b1
			push b2
			push b3
			PUSHX
			/*ldi		a0, 'a'
			rcall	LCD_putc*/

			
			CLR2	b1,b0			; clear 2-byte register
			ldi		b2,14			; load bit-counter
			WAIT_US		(T1/4)			; wait a quarter period
	
			loop:	P2C		PINE,IR			; move Pin to Carry (P2C)
			ROL2		b1,b0			; roll carry into 2-byte reg
			WAIT_US		(T1-4)			; wait bit period (- compensation)	
			DJNZ		b2,loop			; Decrement and Jump if Not Zero
			
			subi		b0, -48
			LDIX bouton
			st x, b0 
			/*PRINTF		LCD				; print formatted
			.db	"cmd=",FHEX,b,0*/
			POPX
			pop	b3
			pop	b2
			pop	b1
			pop	b0
			out		SREG, _sreg 
			reti

reset:
			LDSP	RAMEND
			OUTI	DDRE, 0x00
			OUTI	EIMSK, 0b10000000
			OUTI	EICRB, 0b00000000
			

			rcall LCD_init
			rcall LCD_clear

			sei
			rjmp main

.include	"lcd.asm"
.include	"printf.asm"

main:
telecommande :	;com		b0					; complement b0
			LDIX bouton
			ld r16, x
			
			cpi r16,'P'
			brne pasP
			LDIX posMechant
			ldi r17, 1
			st x, r17
			rjmp fini
		pasP:
			cpi r16,'Q'
			brne fini
			LDIX posMechant
			ldi r17, 0
			st x, r17
		fini:
			/*LDIX posMechant
			
			CA	LCD_pos, 0x0f

			ld a0, x
			subi a0, -48
			rcall		LCD_putc*/
			rcall print_mechant

			LDIX bouton ; pour savoir si on doit poser un obstacle
			


			rjmp main
print_mechant:
			push r16
			push a0
			LDIX posMechant
			ld r16, x
			cpi r16,1
			brne mechantbas
			CA	LCD_pos, 0x0f
			ldi a0, '<'
			rcall		LCD_putc
			CA	LCD_pos, 0x4f
			ldi a0, ' '
			rcall		LCD_putc
			rjmp end_print_mechant
	mechantbas :
			CA	LCD_pos, 0x4f
			ldi a0, '<'
			rcall		LCD_putc
			CA	LCD_pos, 0x0f
			ldi a0, ' '
			rcall		LCD_putc
end_print_mechant:
			pop a0
			pop r16
			ret 
pose_obstacle:
			push r16
			push a0
			LDIX posMechant
			ld r16, x
			cpi r16,
			brne obstacle_bas
			
			rcall		LCD_putc
			rjmp end_print_mechant
	obstacle_bas :
			CA	LCD_pos, 0x4f
			ldi a0, '-'
			rcall		LCD_putc
			CA	LCD_pos, 0x0f
			ldi a0, ' '
			rcall		LCD_putc
end_pose_obstacle:
			pop a0
			pop r16
			ret