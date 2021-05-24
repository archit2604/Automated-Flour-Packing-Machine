#make_bin#
;set loading address, .bin file will be loaded to this address:
#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#


; set entry point:
#CS=0000h#	; same as loading segment
#IP=0000h#	; same as loading offset

; set segment registers
#DS=0000h#	; same as loading segment
#ES=0000h#	; same as loading segment

; set stack
#SS=0000h#	; same as loading segment
#SP=FFFEh#	; set to top of loading segment

; set general registers (optional)
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

;Code---------------------------------------------------------------------------

;jump to the start of the code - reset address is kept at 0000:0000
       	jmp strt0
;jmp st1 - takes 3 bytes followed by nop that is 4 bytes
        nop  
;int 1 is not used so 1 x4 = 00004h - it is stored with 0
        dw 0000
        dw 0000   
;EOC (of ADC) is used as NMI - ip value points to adc_isr and CS value will remain at 0000
        dw adc_isr
        dw 0000
;int 3 to int 39 unused so ip and cs intialized to 0000		 
		db 244 dup(0)

;ivt entry for 40h
		dw hrdisp
		dw 0000

;int 3 to int 39 unused so ip and cs intialized to 0000		 
		db 764 dup(0)

;initializing variables and defaults---------------------------------------------------------
	org 1000h
		keyin  db ?
		wt     db 5
		mintemp   db 25
		mtemp  db 30
		count  db 0
		TB_DEC db 7dh,0beh,0bdh,0bbh,0deh,0ddh,0dbh,0eeh,0edh,0ebh,0ah


	org 0400h



    strt0: cli

;intialize ds, es,ss to start of RAM
          mov       ax,0100h
          mov       ds,ax
          mov       es,ax
          mov       ss,ax
          mov       sp,0FFFEH
          mov       si,0000 



;8255(1) initializing-----------------------------------------------------------
	;starting address ??
	;port a, port b, port c(lower) -> 0/p | port c(upper) -> i/p

		mov al,10001000b		
		out 06h,al 	;control reg.
		
		mov al,00h
		out 00h,al		;port A reset
		
		mov al,00h
		out 02h,al		;port B reset
		
		mov al,00h
		out 04h,al		;port C reset

		
;8255(2) initializing-----------------------------------------------------------
	;starting address ??
	;port a, port b, port c -> 0/p 

		mov al,10000000b		
		out 0eh,al 	;control reg.
		
		mov al,00h
		out 08h,al		;port A reset
		
		mov al,00h
		out 0ah,al		;port B reset
		
		mov al,00h
		out 0ch,al		;port C reset

		
;8255(3) initializing-----------------------------------------------------------
	;starting address ??
	;port a, port c -> 0/p | port b -> i/p

		mov al,10000010b		
		out 16h,al 	;control reg.
		
		mov al,00h
		out 10h,al		;port A reset
		
		mov al,00h
		out 14h,al		;port C reset


;8254 initializing--------------------------------------------------------------
	;starting address ??

		mov al,00010110b
		out 1eh,al

		mov al,01110100b
		out 1eh,al

		mov al,10110100b
		out 1eh,al

		mov al,05
		out 18h,al

		mov al,60h
		out 1ah,al

		mov al,0eah
		out 1ah,al

		mov al,60h
		out 1ch,al

		mov al,0eah
		out 1ch,al


;8259 initializing---------------------------------------------------------
	;starting address ??

	;ICW1  | a0 = 0
		mov al,00010011b
		out 20h,al

	;ICW2  | a0 = 1
		mov al,01000000b
		out 22h,al

	;ICW4  | a0 = 1
		mov al,00000001b
		out 22h,al

	;OCW1  | a0 = 1
		mov al,11111110b
		out 22h,al


;Start main function------------------------------------------------------
	strt1:
		sti

		call keypad

	;if key pressed == start
		mov al,keyin
		cmp al,0b7h
		jz strt3

	;if key pressed == weight
		mov al,keyin
		cmp al,0d7h
		jnz temp1
		call weight
		jmp strt1

	;if key pressed == temp
	temp1:	mov al,keyin
		cmp al,0e7h
		jnz strt1
		call temp
		jmp strt1


;Start packing------------------------------------------------------------
	strt3:
		sti
		mov di,01
		call chtemp
		cmp di,0
	;error for high temp
		jz stp
		
	;invoking dispense function
		call dispense

	;count update
		inc count

		jmp strt1

;Temp alarm-------------------------------------------------------
	stp: 	
	;turning alarm on
		mov al,00000011b
		out 0ch,al

	;check if stop keyy pressed again
	exstp:	call keypad
		mov al,keyin
		cmp al,77h
		jnz exstp

		mov al,00000000b
		out 0ch,al 	;turning alarm off
		jmp strt1

	adc_isr:
		pushf
		push bx
		push cx

	;dx is decremented to show NMI ISR is completed
		dec dx

		mov al,00000111b
		out 16h,al

		in al,12h
		mov bl,al

		mov al,00000110b
		out 16h,al

		mov al,bl

		pop cx
		pop bx
		popf
		iret

	hrdisp:
		pushf
		push bx
		push cx

		sti
	;display hourly counter1
		mov al,count
		call h2bcd
		out 0ah,al

	;reset count
		mov count,00

		pop cx
		pop bx
		popf
	;OCW2  | a0 = 0  (end of isr)
		mov al,00100000b
		out 20h,al
		iret


;procedure for taking keypad input----------------------------------------
keypad 	proc near
		pushf
		push bx
		push cx
		push dx
 	;all cols 00
	K0:	mov al,00h
		out 04h,al

	;check key release
	K1:	in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz K1

	;debounce
		mov cx,0027h		;2.5ms
	delay1:
		loop delay1

	;all cols 00
		mov al,00h
		out 04h,al

	;check key press
	K2:	in al,04h
		and al,0f0h
		cmp al,0f0h
		jz K2

	;debounce
		mov cx,0027h		;2.5ms
	delay2:
		loop delay2

	;all cols 00
		mov al,00h
		out 04h,al

	;check key press
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jz K2

	;check for col 1
		mov al,0eh
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz K3
	;check for col 2
		mov al,0dh
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz K3
	;check for col 3
		mov al,0bh
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz K3
	;check for col 4
		mov al,07h
		mov bl,al
		out 04h,al
		in al,04h
		and al,0f0h
		cmp al,0f0h
		jnz K2

	;key decode
	K3:	or al,bl
		mov keyin,al

		pop dx
		pop cx
		pop bx
		popf
		ret
keypad 	endp

;procedure for decoding digit key----------------------------------------------
digdec 	proc near
		pushf
		push bx
		push cx
		push dx
		push di

		mov cx,0Ah
		mov di,00h
xdig:	cmp al,TB_DEC[di]
		je xdec
		inc di
		loop xdig
xdec:	mov ax,di
		
		pop di
		pop dx
		pop cx
		pop bx
		popf
		ret
digdec	endp

;convert hex to bcd
h2bcd 	proc near
		pushf
		push bx
		push cx
		push dx

		mov       bl,al 
		mov       al,0
XH2B:	add       al,01
		daa
		dec       bl
		jnz       XH2B

		pop dx
		pop cx
		pop bx
		popf
		ret
h2bcd 	endp

;convert bcd to hex
bcd2h proc near
		pushf
		push bx
		push cx
		push dx
	
		mov bl,al
		and al,0F0h
		and bl,0Fh
		mov cl,04h
		ror al,cl
		mov cl,0Ah
		mul cl
		add al,bl

		pop dx
		pop cx
		pop bx
		popf
		ret
bcd2h endp

;procedure for or taking temperature input---------------------------------------
temp 	proc near
		pushf
		push bx
		push cx
		push dx

		mov al,keyin
		cmp al,0e7h
		jnz extm

	;turning temp led on
		mov al,00000001b
		out 02h,al

	;turning display on and setting displpay to 00
	T0:	mov al,00
		mov bl,al
		out 00h,al

	T1:	call keypad
		mov al,keyin

		call digdec		;digit decode
		cmp al,0ah
		jz T1

	T6:	out 00h,al
		mov bl,al
		mov cl,04
		shl bl,cl

	T2: call keypad
		mov al,keyin
		cmp al,7bh		;check for backspace
		jz  T0
		call digdec		;digit decode
		cmp al,0ah
		jz T2

		or bl,al
		mov al,bl
		out 00h,al

	T3: call keypad
		mov al,keyin
		cmp al,7bh		;check for backspace
		jz  T4

		cmp al,7eh		;check for enter
		jz  T5

		jmp T3

	T4: mov cl,04
		shr bl,cl
		mov al,bl
		jmp T6

	;setting displpay back to 00
	T5:	mov al,00
		out 00h,al

	;turning temp led off
		mov al,00000000b
		out 02h,al

		mov mintemp,bl 	;saving temp input
		mov al,bl
		call bcd2h
		add al,05
		mov mtemp,al

extm:	pop dx
		pop cx
		pop bx
		popf
		ret
temp 	endp


chtemp	proc near
		pushf
		push bx
		push cx
		push dx

	;dx is made 1 to check whether NMI ISR is executed
		mov dx,0001h

	;make ALE high
		mov al,00001011b
		out 16h,al

	;make SOC high
		mov al,00001001b
		out 16h,al

		nop
		nop
		nop
		nop

	;make SOC low
		mov al,00001000b
		out 16h,al

	;make ALE low
		mov al,00001010b
		out 16h,al

	cht: cmp dx,0
		jnz cht

		inc al
		inc al
		
		cmp al,mtemp		;checking if temperature is in range
		jle exctm
		dec di

	exctm:	call h2bcd		;Display temp
		out 08h,al

		pop dx
		pop cx
		pop bx
		popf
		ret
chtemp	endp

;procedure for taking weight(per bag) input--------------------------------------
weight 	proc near
		pushf
		push bx
		push cx
		push dx

		mov al,keyin
		cmp al,0d7h
		jnz exwt

	;turning weight led on
		mov al,00000010b
		out 02h,al

	;turning display on and setting displpay to 00
	W0:	mov al,00
		mov bl,al
		out 00h,al

	W1:	call keypad
		mov al,keyin

		call digdec		;digit decode
		cmp al,0ah
		jz W1

	W6:	out 00h,al
		mov bl,al
		mov cl,04
		shl bl,cl

	W2: call keypad
		mov al,keyin
		cmp al,7bh		;check for backspace
		jz  W0
		call digdec		;digit decode
		cmp al,0ah
		jz W2

		or bl,al
		mov al,bl
		out 00h,al

	W3: call keypad
		mov al,keyin
		cmp al,7bh		;check for backspace
		jz  W4

		cmp al,7eh		;check for enter
		jz  W5

		jmp W3

	W4: mov cl,04
		shr bl,cl
		mov al,bl
		jmp W6

	;setting displpay back to 00
	W5:	mov al,00
		out 00h,al

	;turning weight led off
		mov al,00000000b
		out 02h,al

		mov al,bl
		call bcd2h
		mov wt,al	;saving weight input

exwt:	pop dx
		pop cx
		pop bx
		popf
		ret
weight 	endp


dispense proc near
		pushf
		push bx
		push cx
		push dx
	
	;-----open valve------
		mov al,80h
		out 10h,al 
	
		mov cx,030ch	;0.05s
	delay3:
		loop delay3
	
		mov al,00h
		out 10h,al

	;wait for desired flour to fill down into the packet------
		mov bl,wt
	fl:	mov cx,0f3c0h	;rate of flow = 0.25kg/sec
	fdel:
		loop fdel
		dec bl
		jnz fl

	;-----close valve------
		mov al,40h
		out 10h,al 
	
	mov cx,030ch		;0.05s
	delay4:
		loop delay4
	
		mov al,00h
		out 10h,al

		pop dx
		pop cx
		pop bx
		popf
		ret
dispense endp	 