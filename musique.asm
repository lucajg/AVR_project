/*
 * musique.asm
 *   Authors: Luca Jimenez, Geoffroy Renaut
 */ 

 ; === music score ===
tetris:
.db	mi4,si3,do4,re4,do4,si3,la3,la3,do4,mi4,re4,do4,si3,si3,do4,re4,mi4,do4,la3,la3
.db	re4,fa4,la4,so4,fa4,mi4,do4,mi4,re4,do4,si3,si3,do4,re4,mi4,do4,la3,la3, 0, 0, 0, 0

; purpose: enable/disable the music
; arg:  string; used:  r7,r8,r16
music_toggle:
			LDIX	bouton_addr					;
			ld		r16,	x					; get pressed button info from RAM
			cpi		r16, mute_button			; test if the mute button was pressed
			brne	decrement_delay_counter				
			ldi		r16, 0x00
			cp		r8, r16						; if mute button was pressed, 
												;	test if r8 is clear 
			brne    decrement_delay_counter
			ldi		r16, 0x05					;
			mov		r8, r16						; r8 is used as a buffer to counter 
												;	to avoid rapid toggling of the music
			ldi		r17, 0x01					; if r8 is clear, toggle r17 
			eor		r7, r17
			

		decrement_delay_counter:
			ldi		r16, 0x00					;
			cp		r8, r16						;
			breq	PC+2						;
			dec r8								; if r8 is not clear, decrement r8 

			ret