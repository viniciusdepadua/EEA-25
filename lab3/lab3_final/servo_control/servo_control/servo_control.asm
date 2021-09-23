/*
 * servo_control.asm
 *
 *  Created: 9/19/2021 6:05:20 PM
 *   Author: vinic
 */ 


 ;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .equ  BAUD_RATE = 103
   .equ  RETURN = 0x0A				   ; Retorno do cursor.
   .equ  LINEFEED = 0x0D               ; Descida do cursor.
   .equ  CONST_ICR1 = 39999            ; Constante para o registrador ICR1 do TIMER1.
   .equ  INIT_OCnX = 2999			   ; Constante de início 	
   .equ  USART1_RXC1_vect = 0x0048	   ; Vetor para atendimento a interrupções RXC1.


;*****************************
; Segmento de código (FLASH) *
;*****************************
   .cseg

; Ponto de entrada para RESET.
   .org  0 
   jmp   RESET

;*************************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO RECEPTOR DA USART1   *
;*************************************************************
   .org  USART1_RXC1_vect

VETOR_USART1RX:
   jmp   USART1_RX1_INTERRUPT
   .org  0x100



RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS              ; Inicializa PORTH.
   call  USART1_INIT             ; Inicializa USART1.
   call  TIMER1_INIT_MODE14      ; Inicializa TIMER1.
   sei                           ; Habilita interrupções.



FOREVER:
	jmp FOREVER



;****************************************************************************************
;*                        INTERRUPT DRIVER DO RECEPTOR DA USART1                        *
;                                USART1_RX1_INTERRUPT                                   * 


USART1_RX1_INTERRUPT:

; Esta interrupção foi disparada porque a USART1 recebeu um caracter
;   e este já está disponível em UDR1 podendo ser lido imediatamente,
;   sem a necessidade de testar o bit RXC1 do registrador UCSR1A.
   lds   r16,udr1               ; R16 <-- caractere recebido.
   sts   CARACTERE, r16
   call  USART1_TRANSMIT        ; Imprime caractere recebido.


   CPI r20, 0b00000100
   breq READ_DIGIT1

   CPI r20, 0b00000011
   breq READ_DIGIT2

   CPI r20, 0b00000010
   breq READ_SIGN

   CPI r20, 0b00000001
   breq READ_SERVO

   CPI  r16, 'S'
   breq INIT_PROTOCOL

   reti



;*                         FIM DO INTERRUPT DRIVER DO RECEPTOR DA USAR11                *
;****************************************************************************************



;*********************************************************************
;  Subroutines related to state machine in r20
;  Checks if switch is open
;*********************************************************************
INIT_PROTOCOL:
	inc r20
	reti

READ_SERVO:
	mov r21, r16
	inc r20
	reti

READ_SIGN:
	mov r22, r16
	inc r20
	reti

READ_DIGIT2:
	mov  r23, r16
	subi r23, 48     ; '0' == 48 
	ldi  r25, 10     ;  second decimal number so multiply by 10
	mul  r23, r25    
	mov  r23, r0
	inc  r20
	reti

READ_DIGIT1:
	ldi  r20, 0b00000000
	mov  r24, r16
	subi r24, 48    ; '0' == 48
	add  r24, r23   ;  xy = 10*x + y

	cpi r22, '+'  
	breq PLUS_SIGN
	cpi r22, '-'
	breq MINUS_SIGN

	reti

;***************************************************************************************
;  Subroutines SERVO_N
;  sets output values and duty cycle so that the correct angle is outputed
;  depends of the calculations on the duty cycle
;***************************************************************************************

SERVO_0:

	mov   r16, r18
    sts   ocr1ah, r16
    mov   r16, r17		  ; port para duty cycle de OC1A
    sts   ocr1al, r16

	reti


SERVO_1:

	mov   r16, r18
    sts   ocr1bh, r16
    mov   r16, r17  		  ; port para duty cycle de OC1A
    sts   ocr1bl, r16

	reti

SERVO_2:

    mov   r16, r18
    sts   ocr1ch, r16
    mov   r16, r17		  ; port para duty cycle de OC1A
    sts   ocr1cl, r16

    reti

;***************************************************************************************
;  Subroutines PLUS_SIGN and MINUS_SIGN
;  do the calculations for duty cycle constant: duty = 11 * angle + 2999 + 1/9 * angle
;  or duty = 2999 - 11 * angle - 1/9 * angle
;***************************************************************************************

PLUS_SIGN:

	ldi   r18, INIT_OCnX >> 8    ; initial position high
    ldi   r17, INIT_OCnX & 0xff  ; initial position low

	ldi r16, 11                  ; 
	mul r24, r16                 ; 

	add r17, r0                  ; duty = 11 * angle + 2999 til here
	adc r18, r1

	ldi r16, 32                  ; since it is too hard to do angle / 9, i did (angle * 32) >> 8
	mul r24, r16

	ldi r16, 0

	add r17, r1                  ; duty = 11 * angle + 1/8 * angle + 2999
	adc r18, r16

	cpi  r21, '0'
	breq SERVO_0

	cpi  r21, '1'
	breq SERVO_1

	cpi  r21, '2'
	breq SERVO_2

	reti

MINUS_SIGN:
	ldi   r18, INIT_OCnX >> 8    ; initial position high
    ldi   r17, INIT_OCnX & 0xff  ; initial position low

	ldi r16, 11
	mul r24, r16

	sub r17, r0
	sbc r18, r1

	ldi r16, 32
	mul r24, r16

	ldi r16, 0

	sub r17, r1                   ; duty = 11 * angle + 1/8 * angle + 2999
	sbc r18, r16

	cpi  r21, '0'
	breq SERVO_0

	cpi  r21, '1'
	breq SERVO_1

	cpi  r21, '2'
	breq SERVO_2

	reti



;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTB como saída     *
;    em PB5, PB6 e PB7 e entrada   *
;    no terminal T1                 *
;  Inicializa PORTH como saída     *
;    e emite 0x00 em ambos.        *
;***********************************
INIT_PORTS:
   ldi   r16, 0b11100000        ; Para emitir nos servos a onda quadrada gerada pelo TIMER1.
   out   ddrb, r16
   ldi   r20, 0b00000000        ; registrador responsável pelo armazenamento do "estado" -> incrementa-se de acordo com cada char recebido de acordo com o protocolo na usart
   ldi   r21, 0b00000000        ; registrador responsável por armazenar qual servo será mudado
   ldi   r22, 0b00000000        ; registrador responsável por armazenar sinal do ângulo
   ldi   r23, 0b00000000        ; registrador responsável por armazenar casa 2a casa decinal do ângulo
   ldi   r24, 0b00000000        ; registrador responsável por armazenar casa 1a casa decimal do ângulo
   ret



;****************************************
;  USART1_INIT                          *
;  Subrotina para inicializar a USART.  *
;****************************************
; Inicializa USART1: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR1 (USART1 Baud Rate Register)
;     - UCSR1 (USART1 Control Status Register B)
;     - UCSR1 (USART1 Control Status Register C)
USART1_INIT:
   ldi   r17, high(BAUD_RATE)   ;Estabelece Baud Rate.
   sts   ubrr1h, r17
   ldi   r16, low(BAUD_RATE)
   sts   ubrr1l, r16


;**************************************************************************************************
; ICSRB1 inicializado com interrupções RXCIE1 (interrompe quando recebe caractere) habilitadas.   *
;**************************************************************************************************
   ldi   r16,(1<<rxcie1)|(1<<rxen1)|(1<<txen1)   ;Interrupções do receptor,
                                                 ;  receptor e transmissor.
   sts   ucsr1b,r16
   ldi   r16,(0<<usbs1)|(1<<ucsz11)| (1<<ucsz10)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr1c,r16             ;sem paridade.

   ret

;*************************************
;  USART1_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************

USART1_TRANSMIT:
   push  r17                    ; Salva R17 na pilha.

WAIT_TRANSMIT1:
   lds   r17, ucsr1a
   sbrs  r17, udre1             ;Aguarda BUFFER do transmissor ficar vazio.      
   rjmp  WAIT_TRANSMIT1
   sts   udr1, r16              ;Escreve dado no BUFFER.

   pop   r17                    ;Restaura R17 e retorna.
   ret

;*******************************************
;  USART1_RECEIVE                           *
;  Subrotina                               *
;  Aguarda a recepção de dado pela USART   *
;  e retorna com o dado em R16.            *
;*******************************************

USART1_RECEIVE:
   push  r17                    ; Salva R17 na pilha.

WAIT_RECEIVE1:
   lds   r17,ucsr1a
   sbrs  r17,rxc1
   rjmp  WAIT_RECEIVE1          ;Aguarda chegada do dado.
   lds   r16,udr1               ;Le dado do BUFFER e retorna.

   pop   r17                    ;Restaura R17 e retorna.
   ret



;*********************************
; TIMER1_INIT_MODE14              *
; ICR1 = 39999, PRESCALER/8      *
;*********************************
TIMER1_INIT_MODE14:
; ICR1 = 39999
   ldi   r16, CONST_ICR1>>8
   sts   icr1h, r16
   ldi   r16, CONST_ICR1 & 0xff		  ; ldi   r16, 40000 & 0xff
   sts   icr1l, r16

   ldi   r16, INIT_OCnX>>8
   sts   ocr1ah, r16
   ldi   r16, INIT_OCnX & 0xff		  ; port para duty cycle de OC1A
   sts   ocr1al, r16
   
   ldi   r16, INIT_OCnX>>8
   sts   ocr1bh, r16
   ldi   r16, INIT_OCnX & 0xff		  ; port para duty cycle de OC1B
   sts   ocr1bl, r16

   ldi   r16, INIT_OCnX>>8
   sts   ocr1ch, r16
   ldi   r16, INIT_OCnX & 0xff		  ; port para duty cycle de OC1C
   sts   ocr1cl, r16

; Modo 14, CTC: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Comutar OC1A para gerar onda quadrada: (COM1A1,COM1A0)=(1,0), (Tabela 3)
   ldi   r16, (1<<com1a1) | (0<<com1a0) | (1<<com1b1) | (0<<com1b0) | (1<<com1c1) | (0<<com1c0) | (1<<wgm11) | (0<<wgm10)
   sts   tccr1a, r16

; Modo 14, CTC: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0), (Tabela 2)
; Clock select: (CS12,CS11,CS10)=(0,1,0), PRESCALER/8, (Tabela 1)
; No input capture: (ICNC1) | (0<<ICES1)
   ldi   r16,(0<<icnc1) | (0<<ices1) | (1<<wgm13) | (1<<wgm12) | (0<<cs12) |(1<<cs11) | (0<<cs10)
   sts   tccr1b, r16

; Timer/Counter 1 Interrupt(s) initialization
; desligamos a interrupção
   ldi   r16, (0<<icie1) | (0<<ocie1c) | (0<<ocie1b) | (0<<ocie1a) | (0<<toie1)
   sts   timsk1, r16

   ret



;************************************
; Segmento de dados (RAM)           *
; Mostra como alocar espaço na RAM  *
; para variaveis.                   *
;************************************
   .dseg
   .org   0x200
CARACTERE:
   .byte   1

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit